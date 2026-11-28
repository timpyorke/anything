-- ลบบัญชี และอายุของยอดใช้ AI (แผน: docs/rate-limit.md)

-- ลบบัญชีแล้วยอดใช้ AI ยังอยู่แบบไม่ระบุตัวคน (ไม่มีเนื้อหา) — ถ้าลบตาม การสมัครแล้วลบวนไปจะข้าม
-- เพดานรวมของทั้งระบบได้ และค่าใช้จ่ายที่เกิดแล้วจะหายจากบัญชี
alter table public.ai_usage alter column user_id drop not null;
alter table public.ai_usage drop constraint ai_usage_user_id_fkey;
alter table public.ai_usage add constraint ai_usage_user_id_fkey
  foreign key (user_id) references auth.users on delete set null;

-- เก็บ 90 วัน (โควตาดูย้อนแค่เดือนปัจจุบัน) · 03:47 เวลาไทย
select cron.schedule('prune-ai-usage', '47 20 * * *', $$
  delete from public.ai_usage where created_at < now() - interval '90 days'
$$);
