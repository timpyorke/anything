-- รูปถ่ายของรายการ: ไฟล์อยู่ใน Storage (bucket ส่วนตัว) ตารางนี้ผูกไฟล์กับรายการ
create table public.entry_photos (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users on delete cascade,
  entry_id   uuid not null references public.entries on delete cascade,
  path       text not null unique,                       -- <user_id>/<ชื่อสุ่ม>.<นามสกุล>
  seq        bigint generated always as identity,        -- ลำดับที่แนบ
  created_at timestamptz not null default now(),
  check (starts_with(path, user_id::text || '/'))
);
create index entry_photos_entry on public.entry_photos (entry_id);

alter table public.entry_photos enable row level security;
create policy own_rows on public.entry_photos for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- bucket ส่วนตัว: ไม่มี URL สาธารณะ แอปดาวน์โหลดด้วยสิทธิ์ของผู้ใช้ที่ล็อกอิน
-- ขนาดและชนิดไฟล์ต้องตรงกับ maxPhotoBytes / imageMime ในแอป
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('entry-photos', 'entry-photos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do nothing;

-- ผู้ใช้อ่าน/เพิ่ม/ลบได้เฉพาะไฟล์ในโฟลเดอร์ของตัวเอง (ไม่ให้เขียนทับ จึงไม่มี update)
create policy entry_photos_select on storage.objects for select to authenticated
  using (bucket_id = 'entry-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy entry_photos_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'entry-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy entry_photos_delete on storage.objects for delete to authenticated
  using (bucket_id = 'entry-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
