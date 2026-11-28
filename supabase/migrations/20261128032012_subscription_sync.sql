-- sync สถานะสมาชิกจาก RevenueCat (เรียกจาก Edge Function subscription เท่านั้น · แผน: docs/rate-limit.md)

alter table public.subscriptions
  add column synced_at         timestamptz,  -- เวลาที่ RevenueCat ตอบข้อมูลชุดที่เก็บอยู่
  add column sync_requested_at timestamptz;  -- ครั้งล่าสุดที่ผู้ใช้สั่ง sync เอง

-- id ที่เป็นผู้ใช้ในระบบจริง — การถาม RevenueCat ด้วย id ที่ไม่รู้จักจะสร้างลูกค้าเปล่าขึ้นมา
create function public.existing_users(p_ids uuid[]) returns setof uuid
language sql stable security definer set search_path = '' as $$
  select id from auth.users where id = any (p_ids)
$$;

-- ผู้ใช้สั่ง sync ได้ทุก 5 วินาที (กันยิง API ของ RevenueCat รัว) — true = ให้ทำได้
create function public.claim_subscription_sync(p_user uuid) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.subscriptions as s (user_id, sync_requested_at) values (p_user, now())
  on conflict (user_id) do update set sync_requested_at = excluded.sync_requested_at
    where s.sync_requested_at is null or s.sync_requested_at <= now() - interval '5 seconds';
  return found;
end $$;

-- บันทึกวันหมดอายุที่อ่านได้เมื่อ p_checked_at คืน true ถ้าตอนนี้เป็นสมาชิก
-- ข้อมูลที่เก่ากว่าชุดที่เก็บอยู่ถูกทิ้ง (webhook หลายตัวทำงานพร้อมกันได้) และไม่แตะ manual_until
create function public.apply_subscription(p_user uuid, p_expires timestamptz, p_checked_at timestamptz) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.subscriptions as s (user_id, expires_at, synced_at) values (p_user, p_expires, p_checked_at)
  on conflict (user_id) do update set expires_at = excluded.expires_at, synced_at = excluded.synced_at
    where s.synced_at is null or s.synced_at <= excluded.synced_at;
  return public.plan_of(p_user) = 'pro';
end $$;

revoke execute on function
  public.existing_users(uuid[]), public.claim_subscription_sync(uuid),
  public.apply_subscription(uuid, timestamptz, timestamptz)
  from public, anon, authenticated;
grant execute on function
  public.existing_users(uuid[]), public.claim_subscription_sync(uuid),
  public.apply_subscription(uuid, timestamptz, timestamptz)
  to service_role;
