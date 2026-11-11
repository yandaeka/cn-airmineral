-- =====================================================================
-- CN Air Mineral — Absensi karyawan + penyimpanan foto (selfie & foto profil)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Semua peran boleh mencatat absen (HP masing-masing atau tablet bersama);
-- selain owner, catatan hanya bisa diubah oleh pencatatnya di hari yang sama.
-- =====================================================================
insert into public.cn_akses(nama, baca, tulis) values ('absensi', '{sales,gudang,produksi}', '{sales,gudang,produksi}')
on conflict (nama) do update set baca = excluded.baca, tulis = excluded.tulis;

do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama = 'absensi' loop
    execute format($f$
      create table if not exists public.%1$I (
        id         text primary key,
        data       jsonb not null default '{}'::jsonb,
        created_by uuid references auth.users(id) on delete set null,
        created_at timestamptz not null default now(),
        updated_by uuid references auth.users(id) on delete set null,
        updated_at timestamptz not null default now()
      )$f$, t.nama);
    execute format('alter table public.%I enable row level security', t.nama);
    execute format('drop trigger if exists cn_audit on public.%I', t.nama);
    execute format('create trigger cn_audit before insert or update on public.%I for each row execute function public.cn_audit()', t.nama);
    execute format('create index if not exists %1$s_tgl on public.%1$I ((data->>''tanggal''))', t.nama);

    execute format('drop policy if exists baca on public.%I',   t.nama);
    execute format('drop policy if exists tambah on public.%I', t.nama);
    execute format('drop policy if exists ubah on public.%I',   t.nama);
    execute format('drop policy if exists hapus on public.%I',  t.nama);

    -- Membaca: owner + peran di kolom "baca"
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
    -- Menambah: owner + peran di kolom "tulis"
    execute format('create policy tambah on public.%I for insert to authenticated with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis);
    -- Mengubah / menghapus: owner kapan saja; selain owner hanya data buatannya sendiri di hari yang sama (WITA)
    execute format($p$create policy ubah on public.%I for update to authenticated
      using (public.is_owner() or (public.my_role() = any(%L::text[]) and created_by = auth.uid()
             and (created_at at time zone 'Asia/Makassar')::date = (now() at time zone 'Asia/Makassar')::date))
      with check (public.is_owner() or public.my_role() = any(%L::text[]))$p$, t.nama, t.tulis, t.tulis);
    execute format($p$create policy hapus on public.%I for delete to authenticated
      using (public.is_owner() or (public.my_role() = any(%L::text[]) and created_by = auth.uid()
             and (created_at at time zone 'Asia/Makassar')::date = (now() at time zone 'Asia/Makassar')::date))$p$, t.nama, t.tulis);
  end loop;
end $$;

grant select, insert, update, delete on public.absensi to authenticated;
revoke all on public.absensi from anon;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='absensi') then
    alter publication supabase_realtime add table public.absensi;
  end if;
end $$;


-- ---------------------------------------------------------------------
-- Penyimpanan foto: bucket PRIVAT "foto"
--   absensi/<tanggal>/...  selfie absen  → hanya owner yang bisa melihat
--   karyawan/...           foto profil   → semua pengguna bisa melihat (Papan Live)
-- Maks 1 MB per file (aplikasi sudah mengompres ke ±50–100 KB).
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('foto', 'foto', false, 1048576, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false,
  file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists cn_foto_baca   on storage.objects;
drop policy if exists cn_foto_tambah on storage.objects;
drop policy if exists cn_foto_hapus  on storage.objects;

create policy cn_foto_baca on storage.objects for select to authenticated
  using (bucket_id = 'foto' and (public.is_owner() or name like 'karyawan/%'));

create policy cn_foto_tambah on storage.objects for insert to authenticated
  with check (bucket_id = 'foto' and (
       (name like 'absensi/%' and public.my_role() is not null)
    or (name like 'karyawan/%' and public.is_owner())));

create policy cn_foto_hapus on storage.objects for delete to authenticated
  using (bucket_id = 'foto' and public.is_owner());

select 'Tabel absensi & penyimpanan foto siap' as hasil;

-- ---------------------------------------------------------------------
-- Absensi: setiap akun hanya melihat dan mengisi absensinya sendiri
-- (owner tetap bisa melihat semua). Dicocokkan dari nama akun dengan nama karyawan.
-- ---------------------------------------------------------------------
drop policy if exists baca   on public.absensi;
drop policy if exists tambah on public.absensi;
drop policy if exists ubah   on public.absensi;
drop policy if exists hapus  on public.absensi;

create policy baca on public.absensi for select to authenticated
  using (public.is_owner() or data->>'nama' = (select p.nama from public.profiles p where p.id = auth.uid()));
create policy tambah on public.absensi for insert to authenticated
  with check (public.is_owner() or data->>'nama' = (select p.nama from public.profiles p where p.id = auth.uid()));
create policy ubah on public.absensi for update to authenticated
  using (public.is_owner() or (data->>'nama' = (select p.nama from public.profiles p where p.id = auth.uid())
         and created_by = auth.uid() and (created_at at time zone 'Asia/Makassar')::date = (now() at time zone 'Asia/Makassar')::date))
  with check (public.is_owner() or data->>'nama' = (select p.nama from public.profiles p where p.id = auth.uid()));
create policy hapus on public.absensi for delete to authenticated
  using (public.is_owner() or (data->>'nama' = (select p.nama from public.profiles p where p.id = auth.uid())
         and created_by = auth.uid() and (created_at at time zone 'Asia/Makassar')::date = (now() at time zone 'Asia/Makassar')::date));
select 'Aturan absensi per akun siap' as hasil;
