-- ════════════════════════════════════════════════════════════════
--  اشتراکِ پولی — جدول‌ها و کد فعال‌سازی (Supabase)
--  یک‌بار در Supabase ← SQL Editor ← New query بچسبان و Run بزن.
-- ════════════════════════════════════════════════════════════════

-- کاربرانِ پولی (تاریخِ پایانِ اشتراک)
create table if not exists public.premium_users (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);
alter table public.premium_users enable row level security;
drop policy if exists premium_read_own on public.premium_users;
create policy premium_read_own on public.premium_users
  for select to authenticated using (user_id = auth.uid());
-- نوشتن فقط از سمتِ سرور (service role / تابعِ پایین) ممکن است؛ کاربر نمی‌تواند خودش را پولی کند.

-- کدهای فعال‌سازی (برای فروشِ دستی یا بعد از پرداخت در درگاه)
create table if not exists public.premium_codes (
  code    text primary key,
  days    int  not null default 30 check (days > 0),
  used_by uuid references auth.users(id),
  used_at timestamptz
);
alter table public.premium_codes enable row level security;
-- هیچ policy ای ندارد: کاربر مستقیم نمی‌تواند کدها را ببیند.

create or replace function public.redeem_premium_code(p_code text)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_days int;
  v_cur  timestamptz;
  v_new  timestamptz;
begin
  if auth.uid() is null
     or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'login required';
  end if;
  select days into v_days from public.premium_codes
    where code = upper(trim(p_code)) and used_by is null for update;
  if v_days is null then raise exception 'invalid code'; end if;
  select expires_at into v_cur from public.premium_users where user_id = auth.uid();
  v_new := greatest(now(), coalesce(v_cur, now())) + make_interval(days => v_days);
  update public.premium_codes set used_by = auth.uid(), used_at = now()
    where code = upper(trim(p_code));
  insert into public.premium_users (user_id, expires_at) values (auth.uid(), v_new)
    on conflict (user_id) do update set expires_at = v_new, updated_at = now();
  return v_new;
end;
$$;
revoke all on function public.redeem_premium_code(text) from public;
grant execute on function public.redeem_premium_code(text) to authenticated;

-- ساختنِ کد (از SQL Editor، با نقشِ مدیر): مثال ۵ کدِ ۳۰ روزه
--   insert into public.premium_codes (code, days)
--   select upper(substr(md5(random()::text), 1, 10)), 30 from generate_series(1, 5);
--   select * from public.premium_codes where used_by is null;
--
-- فعال‌کردنِ مستقیمِ یک کاربر (مثلاً بعد از پرداختِ موفق در درگاه، از Edge Function با service role):
--   insert into public.premium_users (user_id, expires_at)
--   values ('<USER-UUID>', now() + interval '30 days')
--   on conflict (user_id) do update set expires_at = excluded.expires_at;
