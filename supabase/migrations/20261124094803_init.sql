-- anything - diary's: schema แรก (phase 1)
-- ทุกตารางผูกกับ auth.uid() ผ่าน RLS — ผู้ใช้เห็น/แก้ได้เฉพาะข้อมูลของตัวเอง
-- หมวดและ metric เป็นตารางจริง (แทน config.json ของระบบ markdown เดิม) และมี foreign key บังคับ:
-- AI จะบันทึกหมวด/metric ที่ไม่มีอยู่ไม่ได้ ต้องสร้าง definition ก่อน

-- ---------- หมวด ----------
create table public.categories (
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  key         text not null check (key ~ '^[a-z][a-z0-9_]{0,31}$'),
  label       text not null check (length(label) between 1 and 40),
  color       text not null check (color ~ '^#[0-9a-fA-F]{6}$'),
  description text not null default '',
  sort        int  not null default 0,
  primary key (user_id, key)
);

-- ---------- นิยาม metric ----------
create table public.metric_defs (
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  key         text not null check (key ~ '^[a-z][a-z0-9_]{0,31}$'),
  label       text not null check (length(label) between 1 and 40),
  unit        text not null default '',
  description text not null default '',
  primary key (user_id, key)
);

-- ---------- บันทึก (เหตุการณ์ + บันทึกรายวัน) ----------
create table public.entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  kind        text not null default 'event' check (kind in ('event', 'daily')),
  date        date not null,
  end_date    date,
  category    text not null,
  title       text not null default '',
  body        text not null default '',          -- markdown (checklist อยู่ในนี้: - [ ] / - [x])
  every       text check (every ~ '^(daily|weekly|monthly|yearly|[1-9][0-9]{0,2}[dwmy])$'),
  times       int  check (times between 1 and 1000),
  until       date,
  source      text not null default 'manual' check (source in ('manual', 'ai', 'import')),
  legacy_ref  text,                               -- ที่มาจากไฟล์ markdown เดิม เช่น data/2025.md:7
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,                        -- ลบแบบ soft delete กู้คืนได้
  foreign key (user_id, category) references public.categories (user_id, key) on update cascade,
  check (end_date is null or end_date > date),
  check (every is null or end_date is null),                    -- เกิดซ้ำใช้ช่วงวันที่ไม่ได้
  check ((times is null and until is null) or every is not null),
  check (until is null or until >= date),
  check (kind = 'event' or (end_date is null and every is null)) -- daily เป็นวันเดียวเสมอ
);
create index entries_user_date on public.entries (user_id, date desc) where deleted_at is null;
create unique index entries_one_daily_per_day on public.entries (user_id, date)
  where kind = 'daily' and deleted_at is null;

-- ---------- ค่าตัวเลข ----------
create table public.metric_values (
  id        uuid primary key default gen_random_uuid(),
  user_id   uuid not null default auth.uid() references auth.users on delete cascade,
  entry_id  uuid not null references public.entries on delete cascade,
  key       text not null,
  value     numeric not null,
  unit      text not null default '',
  unique (entry_id, key),
  foreign key (user_id, key) references public.metric_defs (user_id, key) on update cascade
);
create index metric_values_user_key on public.metric_values (user_id, key);

-- ---------- บันทึกการตัดสินใจของ AI (ตรวจย้อนหลังได้ว่า AI เสนออะไร ผู้ใช้รับหรือไม่) ----------
create table public.ai_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users on delete cascade,
  provider    text not null check (provider in ('on_device', 'ai_studio')),
  model       text not null,
  input       text not null,
  output      jsonb,                    -- actions ที่ AI เสนอ (หลังตรวจแล้ว)
  status      text not null check (status in ('applied', 'rejected', 'invalid', 'error')),
  error       text,
  created_at  timestamptz not null default now()
);
create index ai_logs_user_created on public.ai_logs (user_id, created_at desc);

-- ---------- updated_at อัตโนมัติ ----------
create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;
create trigger entries_touch before update on public.entries
  for each row execute function public.touch_updated_at();

-- ---------- RLS ----------
alter table public.categories    enable row level security;
alter table public.metric_defs   enable row level security;
alter table public.entries       enable row level security;
alter table public.metric_values enable row level security;
alter table public.ai_logs       enable row level security;

create policy own_rows on public.categories    for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy own_rows on public.metric_defs   for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy own_rows on public.entries       for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy own_rows on public.metric_values for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
-- log ของ AI: เพิ่มและอ่านได้ แต่แก้/ลบไม่ได้ (เป็นหลักฐาน)
create policy own_logs_select on public.ai_logs for select to authenticated
  using (user_id = (select auth.uid()));
create policy own_logs_insert on public.ai_logs for insert to authenticated
  with check (user_id = (select auth.uid()));

-- ---------- ค่าเริ่มต้นของผู้ใช้ใหม่ (แอปเรียกหลังล็อกอินครั้งแรก) ----------
create function public.seed_defaults() returns void
language sql security invoker set search_path = '' as $$
  insert into public.categories (key, label, color, description, sort) values
    ('milestone',    'เหตุการณ์สำคัญ', '#c0392b', 'จุดเปลี่ยนของชีวิต: เกิด เรียนจบ เปลี่ยนงาน ซื้อบ้าน/รถ แต่งงาน', 0),
    ('finance',      'การเงิน',        '#846400', 'รายรับ รายจ่ายก้อนใหญ่ หนี้ ค่างวด การลงทุน', 1),
    ('health',       'สุขภาพ',         '#17825a', 'ร่างกาย ออกกำลังกาย การนอน หาหมอ ตรวจสุขภาพ', 2),
    ('travel',       'เดินทาง',        '#b05a0c', 'ทริป ท่องเที่ยว การเดินทางไกล', 3),
    ('work',         'งาน',            '#2f62e0', 'งาน อาชีพ โปรเจกต์ ผลงาน', 4),
    ('learning',     'เรียนรู้',        '#7c3aed', 'เรียน อ่านหนังสือ คอร์ส ทักษะใหม่', 5),
    ('relationship', 'ความสัมพันธ์',    '#c0306a', 'ครอบครัว แฟน เพื่อน งานสังสรรค์', 6),
    ('daily',        'ประจำวัน',        '#3a7682', 'บันทึกประจำวันทั่วไปที่ไม่เข้าหมวดอื่น', 7),
    ('review',       'สรุปโดย AI',      '#5b5b66', 'บทสรุป ข้อสังเกต และสิ่งที่ควรทำ ที่ AI เขียน', 8)
  on conflict do nothing;
  insert into public.metric_defs (key, label, unit, description) values
    ('weight',      'น้ำหนัก',  'kg',    ''),
    ('height',      'ส่วนสูง',  'cm',    ''),
    ('sleep',       'การนอน',  'ชม.',   ''),
    ('steps',       'ก้าวเดิน',  'ก้าว',  ''),
    ('run',         'ระยะวิ่ง',  'km',    ''),
    ('mood',        'อารมณ์',   'คะแนน', '1 (แย่มาก) – 5 (ดีมาก)'),
    ('spend',       'ใช้จ่าย',   'บาท',   ''),
    ('installment', 'ค่างวด',   'บาท',   '')
  on conflict do nothing;
$$;
grant execute on function public.seed_defaults() to authenticated;
