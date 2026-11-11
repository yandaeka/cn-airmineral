-- =====================================================================
-- CN Air Mineral — Audit Internal (data audit, temuan, dan foto dokumentasi)
-- Hanya owner yang bisa membuka dan mengisi. Jalankan sekali di Supabase → SQL Editor → Run.
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array['audit','audit_temuan','audit_foto'] loop
    execute format('create table if not exists public.%I (
      id text primary key,
      data jsonb not null default ''{}''::jsonb,
      created_by uuid references auth.users(id) on delete set null,
      created_at timestamptz not null default now(),
      updated_by uuid references auth.users(id) on delete set null,
      updated_at timestamptz not null default now())', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists owner_semua on public.%I', t);
    execute format('create policy owner_semua on public.%I for all to authenticated using (public.is_owner()) with check (public.is_owner())', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('drop trigger if exists cn_audit on public.%I', t);
    execute format('create trigger cn_audit before insert or update on public.%I for each row execute function public.cn_audit()', t);
  end loop;
end $$;

-- Foto dokumentasi audit disimpan di bucket "foto" (folder audit/), dibaca owner saja
drop policy if exists cn_foto_audit_baca on storage.objects;
create policy cn_foto_audit_baca on storage.objects for select to authenticated
  using (bucket_id = 'foto' and name like 'audit/%' and public.is_owner());
drop policy if exists cn_foto_audit_tambah on storage.objects;
create policy cn_foto_audit_tambah on storage.objects for insert to authenticated
  with check (bucket_id = 'foto' and name like 'audit/%' and public.is_owner());
drop policy if exists cn_foto_audit_hapus on storage.objects;
create policy cn_foto_audit_hapus on storage.objects for delete to authenticated
  using (bucket_id = 'foto' and name like 'audit/%' and public.is_owner());
