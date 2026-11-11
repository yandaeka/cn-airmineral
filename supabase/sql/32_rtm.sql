-- =====================================================================
-- CN Air Mineral — Rapat Tinjauan Manajemen (RTM)
-- Hanya owner yang bisa membuka dan mengisi. Jalankan sekali di Supabase → SQL Editor → Run.
-- =====================================================================

create table if not exists public.rtm (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
alter table public.rtm enable row level security;
drop policy if exists owner_semua on public.rtm;
create policy owner_semua on public.rtm for all to authenticated using (public.is_owner()) with check (public.is_owner());
grant select, insert, update, delete on public.rtm to authenticated;
revoke all on public.rtm from anon;
drop trigger if exists cn_audit on public.rtm;
create trigger cn_audit before insert or update on public.rtm for each row execute function public.cn_audit();

-- Foto dokumentasi RTM disimpan di bucket "foto" (folder rtm/), dibaca owner saja
drop policy if exists cn_foto_rtm_baca on storage.objects;
create policy cn_foto_rtm_baca on storage.objects for select to authenticated
  using (bucket_id = 'foto' and name like 'rtm/%' and public.is_owner());
drop policy if exists cn_foto_rtm_tambah on storage.objects;
create policy cn_foto_rtm_tambah on storage.objects for insert to authenticated
  with check (bucket_id = 'foto' and name like 'rtm/%' and public.is_owner());
drop policy if exists cn_foto_rtm_hapus on storage.objects;
create policy cn_foto_rtm_hapus on storage.objects for delete to authenticated
  using (bucket_id = 'foto' and name like 'rtm/%' and public.is_owner());
