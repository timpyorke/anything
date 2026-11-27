-- โควตาของ Free / Member: AI ที่แอปให้บริการเอง และพื้นที่เก็บรูป (แผน: docs/rate-limit.md)
-- ทุกอย่างบังคับในฐานข้อมูล ผู้ใช้อ่านสถานะของตัวเองได้ แต่แก้แผนหรือยอดใช้ไม่ได้

-- ---------- เพดานของแต่ละแผน (แก้ตัวเลขได้โดยไม่ต้องออกแอปใหม่) ----------
create table public.plans (
  plan          text primary key check (plan in ('free', 'pro')),
  ai_per_minute int    not null check (ai_per_minute >= 0),
  ai_per_day    int    not null check (ai_per_day >= 0),
  ai_per_month  int    not null check (ai_per_month >= 0),
  storage_bytes bigint not null check (storage_bytes >= 0)
);
insert into public.plans (plan, ai_per_minute, ai_per_day, ai_per_month, storage_bytes) values
  ('free',  3,  5,  30,  104857600),   -- 100 MB
  ('pro',  10, 40, 500, 5368709120);   -- 5 GB

-- ---------- สมาชิก (ไม่มีแถว = free) ----------
create table public.subscriptions (
  user_id      uuid primary key references auth.users on delete cascade,
  expires_at   timestamptz,   -- จาก RevenueCat (รวม grace period)
  manual_until timestamptz,   -- ให้สิทธิ์เอง/ทดสอบ การ sync จาก RevenueCat ไม่เขียนทับ
  updated_at   timestamptz not null default now()
);
create trigger subscriptions_touch before update on public.subscriptions
  for each row execute function public.touch_updated_at();

-- ---------- ยอดใช้ AI (1 แถว = 1 การเรียก; ไม่เก็บพรอมต์ รูป หรือคำตอบ) ----------
create table public.ai_usage (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references auth.users on delete cascade,
  -- refunded = ฝั่งเราหรือผู้ให้บริการพัง: ไม่นับในโควตารายวัน/เดือน แต่ยังนับในเพดานต่อนาที
  status        text not null default 'reserved' check (status in ('reserved', 'ok', 'refunded')),
  model         text,
  input_tokens  int,
  output_tokens int,
  created_at    timestamptz not null default now()
);
create index ai_usage_user_created on public.ai_usage (user_id, created_at desc);
create index ai_usage_created on public.ai_usage (created_at);

-- ---------- สิทธิ์ ----------
alter table public.plans         enable row level security;
alter table public.subscriptions enable row level security;
alter table public.ai_usage      enable row level security;

create policy read_plans on public.plans for select to authenticated using (true);
create policy own_select on public.subscriptions for select to authenticated
  using (user_id = (select auth.uid()));
create policy own_select on public.ai_usage for select to authenticated
  using (user_id = (select auth.uid()));

-- กันสองชั้น: ไม่มี policy สำหรับเขียน และไม่ให้สิทธิ์เขียนตั้งแต่แรก
revoke all on public.plans, public.subscriptions, public.ai_usage from anon, authenticated;
grant select on public.plans, public.subscriptions, public.ai_usage to authenticated;
grant select, insert, update, delete on public.plans, public.subscriptions, public.ai_usage to service_role;

-- ---------- ฟังก์ชันภายใน ----------
create function public.plan_of(p_user uuid) returns text
language sql stable security definer set search_path = '' as $$
  select case when exists (
    select 1 from public.subscriptions
    where user_id = p_user and greatest(expires_at, manual_until) > now()
  ) then 'pro' else 'free' end
$$;

-- ยอดใช้ AI ของช่วงปัจจุบัน — วันและเดือนตัดตามเวลาไทย (ไม่เชื่อเขตเวลาจากเครื่องผู้ใช้)
create function public.ai_usage_counts(p_user uuid, out last_minute int, out today int, out this_month int)
language sql stable security definer set search_path = '' as $$
  select
    (count(*) filter (where created_at > now() - interval '1 minute'))::int,
    (count(*) filter (where status <> 'refunded' and created_at >= date_trunc('day', now(), 'Asia/Bangkok')))::int,
    (count(*) filter (where status <> 'refunded' and created_at >= date_trunc('month', now(), 'Asia/Bangkok')))::int
  from public.ai_usage
  where user_id = p_user
    -- ต้นเดือนยังต้องเห็นแถวของนาทีก่อนที่อยู่เดือนเก่า
    and created_at >= least(date_trunc('month', now(), 'Asia/Bangkok'), now() - interval '1 minute')
$$;

-- ไฟล์รูปของผู้ใช้รวมกี่ไบต์ (เทียบช่วงชื่อแทน like เพื่อใช้ index (bucket_id, name collate "C") ได้)
create function public.storage_used(p_user uuid) returns bigint
language sql stable security definer set search_path = '' as $$
  select coalesce(sum((metadata->>'size')::bigint), 0)::bigint
  from storage.objects
  where bucket_id = 'entry-photos'
    and name collate "C" >= p_user::text || '/'
    and name collate "C" <  p_user::text || '0'   -- '0' คืออักขระถัดจาก '/'
$$;

-- ---------- หักโควตา AI (เรียกจาก Edge Function เท่านั้น) ----------
-- ผ่าน: {"allowed": true, "usage_id": n}
-- ไม่ผ่าน: {"allowed": false, "code": "...", "plan": "...", "reset_at": "..."}
create function public.consume_ai_quota(p_user uuid, p_global_cap int) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_limit public.plans%rowtype;
  v_used  record;
  v_day   timestamptz;
  v_month timestamptz;
  v_code  text;
  v_id    bigint;
begin
  -- คำขอพร้อมกันของคนเดียวกันต้องเข้าคิว ไม่งั้นนับไม่ทันกัน (ปลดล็อกเมื่อจบ transaction)
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 0));

  v_day   := date_trunc('day', now(), 'Asia/Bangkok');
  v_month := date_trunc('month', now(), 'Asia/Bangkok');
  select * into strict v_limit from public.plans where plan = public.plan_of(p_user);
  select * into v_used from public.ai_usage_counts(p_user);

  -- เรียงจากรอนานสุดไปสั้นสุด ผู้ใช้จะได้เวลาที่กลับมาใช้ได้จริง
  v_code := case
    when v_used.this_month  >= v_limit.ai_per_month  then 'quota_month'
    when v_used.today       >= v_limit.ai_per_day    then 'quota_day'
    when v_used.last_minute >= v_limit.ai_per_minute then 'quota_minute'
    -- เพดานรวมทั้งระบบเป็นแบบ soft (ล็อกแยกรายคน); ไม่ได้ส่งเพดานมา = ปิดไว้ก่อน
    when (select count(*) from public.ai_usage where created_at >= v_day and status <> 'refunded')
         >= coalesce(p_global_cap, 0) then 'service_busy'
  end;

  if v_code is not null then
    return jsonb_build_object(
      'allowed', false,
      'code', v_code,
      'plan', v_limit.plan,
      'reset_at', case v_code
        when 'quota_month' then ((v_month at time zone 'Asia/Bangkok') + interval '1 month') at time zone 'Asia/Bangkok'
        when 'quota_minute' then now() + interval '1 minute'
        else v_day + interval '1 day'
      end);
  end if;

  insert into public.ai_usage (user_id) values (p_user) returning id into v_id;
  return jsonb_build_object('allowed', true, 'usage_id', v_id);
end $$;

-- ---------- ฟังก์ชันที่แอปเรียกได้ ----------
create function public.get_my_usage() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'plan', p.plan,
    'ai', jsonb_build_object(
      'day',   jsonb_build_object('used', c.today,      'limit', p.ai_per_day),
      'month', jsonb_build_object('used', c.this_month, 'limit', p.ai_per_month)),
    'storage', jsonb_build_object('used', public.storage_used(u.id), 'limit', p.storage_bytes))
  from (select auth.uid() as id) u
  join public.plans p on p.plan = public.plan_of(u.id)
  cross join lateral public.ai_usage_counts(u.id) c
  where u.id is not null
$$;

create function public.has_storage_room() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.storage_used((select auth.uid())) < p.storage_bytes
  from public.plans p
  where p.plan = public.plan_of((select auth.uid()))
$$;

-- ค่าเริ่มต้นของ Supabase ให้ client เรียกฟังก์ชันใน public ได้ทุกตัว จึงต้อง revoke
revoke execute on function
  public.plan_of(uuid), public.ai_usage_counts(uuid), public.storage_used(uuid), public.consume_ai_quota(uuid, int)
  from public, anon, authenticated;
grant execute on function public.consume_ai_quota(uuid, int) to service_role;
revoke execute on function public.get_my_usage(), public.has_storage_room() from public, anon;
grant execute on function public.get_my_usage(), public.has_storage_room() to authenticated;

-- ---------- พื้นที่เก็บรูป ----------
-- เพดานแบบ soft: ตอนตรวจยังไม่รู้ขนาดไฟล์ใหม่ จึงเกินได้ราว 1 ไฟล์ (มากกว่านั้นถ้าอัปโหลดขนานกัน)
-- เกินแล้วยังดูและลบได้ ระบบไม่ลบรูปให้
drop policy entry_photos_insert on storage.objects;
create policy entry_photos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'entry-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and public.has_storage_room());

-- ---------- AI ของแอปใน ai_logs (ต้องตรงกับ AiProviderKind.id ในแอป) ----------
alter table public.ai_logs drop constraint ai_logs_provider_check;
alter table public.ai_logs add constraint ai_logs_provider_check
  check (provider in ('on_device', 'ai_studio', 'anthropic', 'openai', 'openrouter', 'managed'));
