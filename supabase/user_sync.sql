-- یک‌بار در Supabase → SQL Editor اجرا کن.
-- داده‌های هر کاربر (تنظیمات، لغات ذخیره‌شده، لیست مدل‌های دانلودشده و ...) اینجا ذخیره می‌شود.
create table if not exists public.user_sync (
  user_id    uuid        not null references auth.users(id) on delete cascade,
  key        text        not null,                 -- 'data' | 'packs'
  value      jsonb       not null default '{}'::jsonb,
  device_id  text,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

alter table public.user_sync enable row level security;

drop policy if exists "user_sync_select_own" on public.user_sync;
drop policy if exists "user_sync_insert_own" on public.user_sync;
drop policy if exists "user_sync_update_own" on public.user_sync;
drop policy if exists "user_sync_delete_own" on public.user_sync;

create policy "user_sync_select_own" on public.user_sync
  for select using (auth.uid() = user_id);
create policy "user_sync_insert_own" on public.user_sync
  for insert with check (auth.uid() = user_id);
create policy "user_sync_update_own" on public.user_sync
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "user_sync_delete_own" on public.user_sync
  for delete using (auth.uid() = user_id);
