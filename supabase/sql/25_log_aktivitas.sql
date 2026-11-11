-- =====================================================================
-- CN Air Mineral — Log aktivitas pengguna (dilihat owner)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================

create table if not exists public.log_aktivitas (
  id       bigserial primary key,
  waktu    timestamptz not null default now(),
  user_id  uuid references auth.users(id) on delete set null,
  nama     text,
  peran    text,
  aksi     text not null,
  detail   text
);
create index if not exists log_aktivitas_waktu on public.log_aktivitas (waktu desc);

alter table public.log_aktivitas enable row level security;
drop policy if exists tulis_log on public.log_aktivitas;
drop policy if exists baca_log on public.log_aktivitas;
create policy tulis_log on public.log_aktivitas for insert to authenticated
  with check (user_id = auth.uid());
create policy baca_log on public.log_aktivitas for select to authenticated
  using (public.is_owner());

grant select, insert on public.log_aktivitas to authenticated;
grant usage, select on sequence public.log_aktivitas_id_seq to authenticated;
revoke all on public.log_aktivitas from anon;
