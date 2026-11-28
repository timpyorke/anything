-- รูปของรายการที่ลบแล้ว (soft delete) ลบถาวรหลัง 30 วัน เพื่อคืนพื้นที่โควตา — ข้อความของรายการยังอยู่
-- ไฟล์ใน storage ต้องลบผ่าน Storage API (ลบด้วย SQL ไม่ได้) จึงให้ Edge Function purge-photos ทำ
-- และให้ cron เรียกวันละครั้ง (แผน: docs/rate-limit.md)

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- ---------- ฟังก์ชันที่ purge-photos ใช้ ----------
-- path ของรูปที่ครบกำหนดลบ เก่าสุดก่อน
create function public.purgeable_photos(p_limit int) returns setof text
language sql stable security definer set search_path = '' as $$
  select p.path
  from public.entry_photos p
  join public.entries e on e.id = p.entry_id
  where e.deleted_at < now() - interval '30 days'
  order by e.deleted_at, p.seq
  limit p_limit
$$;

-- ลบแถวของรูปที่ลบไฟล์แล้ว — ตรวจกำหนดซ้ำ รายการที่ถูกกู้คืนระหว่างนั้นจึงไม่ถูกแตะ
create function public.forget_photos(p_paths text[]) returns void
language sql security definer set search_path = '' as $$
  delete from public.entry_photos p
  using public.entries e
  where e.id = p.entry_id
    and e.deleted_at < now() - interval '30 days'
    and p.path = any (p_paths)
$$;

create function public.check_purge_token(p_token text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from vault.decrypted_secrets where name = 'purge_token' and decrypted_secret = p_token
  )
$$;

revoke execute on function public.purgeable_photos(int), public.forget_photos(text[]), public.check_purge_token(text)
  from public, anon, authenticated;
grant execute on function public.purgeable_photos(int), public.forget_photos(text[]), public.check_purge_token(text)
  to service_role;

-- ---------- ตั้งเวลา ----------
-- token สุ่มขึ้นในฐานข้อมูลและอยู่ใน Vault เท่านั้น ไม่มีใครต้องคัดลอกไปตั้งที่อื่น
select vault.create_secret(
    encode(extensions.gen_random_bytes(32), 'hex'), 'purge_token', 'token ที่ cron ส่งให้ purge-photos')
where not exists (select 1 from vault.secrets where name = 'purge_token');

-- 03:17 เวลาไทย · ต้องมี secret 'project_url' ใน Vault (ค่าต่างกันในแต่ละโปรเจกต์) ถ้าไม่มีจะไม่เรียกอะไร
select cron.schedule('purge-deleted-photos', '17 20 * * *', $$
  select net.http_post(
    url := u.decrypted_secret || '/functions/v1/purge-photos',
    headers := jsonb_build_object('content-type', 'application/json', 'x-purge-token', t.decrypted_secret),
    timeout_milliseconds := 60000
  )
  from vault.decrypted_secrets u, vault.decrypted_secrets t
  where u.name = 'project_url' and t.name = 'purge_token'
$$);
