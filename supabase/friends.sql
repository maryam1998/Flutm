-- ════════════════════════════════════════════════════════════════
--  تب «دوستان هم‌فرکانسی» — جدول‌ها و دسترسی‌ها (Supabase)
--  یک‌بار در Supabase ← SQL Editor ← New query بچسبان و Run بزن.
--  (چندبار اجرا کردنش مشکلی ندارد.)
--  خواندنِ پست‌ها برای همه آزاد است؛ نوشتن، پاسخ، «حس خوبی داد» و گزارش
--  فقط با ورودِ Google (نه مهمان) ممکن است.
-- ════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- کاربرِ واقعی = وارد شده و ناشناس نیست
create or replace function public.friend_is_real_user()
returns boolean
language sql
stable
as $$
  select auth.uid() is not null
     and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
$$;

-- ───────── پست‌ها ─────────
create table if not exists public.friend_posts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind         text not null check (kind in ('question','experience','gratitude')),
  title        text not null check (char_length(title) between 6 and 140),
  body         text not null default '' check (char_length(body) <= 1200),
  category     text not null default '' check (char_length(category) <= 40),
  author_name  text not null default 'همسفر' check (char_length(author_name) between 1 and 20),
  emotion_id   text,
  report_count int  not null default 0,
  created_at   timestamptz not null default now()
);
create index if not exists friend_posts_created_idx on public.friend_posts (created_at desc);

-- ───────── پاسخ‌ها ─────────
create table if not exists public.friend_answers (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.friend_posts(id) on delete cascade,
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  author_name  text not null default 'همسفر' check (char_length(author_name) between 1 and 20),
  body         text not null check (char_length(body) between 2 and 800),
  helpful      boolean not null default false,
  report_count int  not null default 0,
  created_at   timestamptz not null default now()
);
create index if not exists friend_answers_post_idx on public.friend_answers (post_id, created_at);

-- ───────── «حس خوبی داد» ─────────
create table if not exists public.friend_post_good (
  post_id uuid not null references public.friend_posts(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  primary key (post_id, user_id)
);
create table if not exists public.friend_answer_good (
  answer_id uuid not null references public.friend_answers(id) on delete cascade,
  user_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  primary key (answer_id, user_id)
);

-- ───────── گزارش‌ها ─────────
create table if not exists public.friend_reports (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  post_id    uuid references public.friend_posts(id) on delete cascade,
  answer_id  uuid references public.friend_answers(id) on delete cascade,
  reason     text not null default '' check (char_length(reason) <= 80),
  created_at timestamptz not null default now(),
  check ((post_id is null) <> (answer_id is null))
);
create unique index if not exists friend_reports_once_idx
  on public.friend_reports (user_id, coalesce(post_id, answer_id));

-- با هر گزارش، شمارنده‌ی محتوا بالا می‌رود؛ از ۳ گزارش به بالا برای بقیه پنهان می‌شود
create or replace function public.friend_count_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.post_id is not null then
    update public.friend_posts set report_count = report_count + 1 where id = new.post_id;
  else
    update public.friend_answers set report_count = report_count + 1 where id = new.answer_id;
  end if;
  return new;
end;
$$;
drop trigger if exists friend_reports_count on public.friend_reports;
create trigger friend_reports_count
  after insert on public.friend_reports
  for each row execute function public.friend_count_report();

-- فقط صاحبِ پرسش می‌تواند یک پاسخ را «کمکم کرد» کند (دوباره زدن برش می‌دارد)
create or replace function public.friend_mark_helpful(p_answer uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post  uuid;
  v_cur   boolean;
  v_owner uuid;
begin
  select post_id, helpful into v_post, v_cur from public.friend_answers where id = p_answer;
  if v_post is null then raise exception 'answer not found'; end if;
  select user_id into v_owner from public.friend_posts where id = v_post;
  if v_owner is distinct from auth.uid() then raise exception 'not allowed'; end if;
  update public.friend_answers set helpful = false where post_id = v_post;
  update public.friend_answers set helpful = not v_cur where id = p_answer;
end;
$$;
revoke all on function public.friend_mark_helpful(uuid) from public;
grant execute on function public.friend_mark_helpful(uuid) to authenticated;

-- ───────── دسترسی‌ها (RLS) ─────────
alter table public.friend_posts       enable row level security;
alter table public.friend_answers     enable row level security;
alter table public.friend_post_good   enable row level security;
alter table public.friend_answer_good enable row level security;
alter table public.friend_reports     enable row level security;

drop policy if exists posts_read    on public.friend_posts;
drop policy if exists posts_insert  on public.friend_posts;
drop policy if exists posts_delete  on public.friend_posts;
create policy posts_read   on public.friend_posts for select to anon, authenticated
  using (report_count < 3 or user_id = auth.uid());
create policy posts_insert on public.friend_posts for insert to authenticated
  with check (public.friend_is_real_user() and user_id = auth.uid());
create policy posts_delete on public.friend_posts for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists answers_read   on public.friend_answers;
drop policy if exists answers_insert on public.friend_answers;
drop policy if exists answers_delete on public.friend_answers;
create policy answers_read   on public.friend_answers for select to anon, authenticated
  using (report_count < 3 or user_id = auth.uid());
create policy answers_insert on public.friend_answers for insert to authenticated
  with check (public.friend_is_real_user() and user_id = auth.uid());
create policy answers_delete on public.friend_answers for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists pgood_read   on public.friend_post_good;
drop policy if exists pgood_insert on public.friend_post_good;
drop policy if exists pgood_delete on public.friend_post_good;
create policy pgood_read   on public.friend_post_good for select to anon, authenticated using (true);
create policy pgood_insert on public.friend_post_good for insert to authenticated
  with check (public.friend_is_real_user() and user_id = auth.uid());
create policy pgood_delete on public.friend_post_good for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists agood_read   on public.friend_answer_good;
drop policy if exists agood_insert on public.friend_answer_good;
drop policy if exists agood_delete on public.friend_answer_good;
create policy agood_read   on public.friend_answer_good for select to anon, authenticated using (true);
create policy agood_insert on public.friend_answer_good for insert to authenticated
  with check (public.friend_is_real_user() and user_id = auth.uid());
create policy agood_delete on public.friend_answer_good for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists reports_read   on public.friend_reports;
drop policy if exists reports_insert on public.friend_reports;
create policy reports_read   on public.friend_reports for select to authenticated
  using (user_id = auth.uid());
create policy reports_insert on public.friend_reports for insert to authenticated
  with check (public.friend_is_real_user() and user_id = auth.uid());
