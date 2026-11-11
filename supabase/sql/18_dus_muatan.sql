-- =====================================================================
-- CN Air Mineral — Ketelusuran dus & muatan kendaraan
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Jalankan SEBELUM mengunggah aplikasi versi 2.5.
--
-- dus    : 1 baris per dus (kode CN220-YYMMDD-NNNN). Dibuat saat produksi cetak label.
--          Status: Diproduksi → Dimuat → Terjual.
-- muatan : 1 baris per muatan kendaraan (dibuat gudang). Berisi kendaraan, sopir,
--          jumlah dus yang di-scan, jumlah kembali, dan konfirmasi sopir.
-- =====================================================================

create table if not exists public.dus (
  id text primary key, data jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null, updated_at timestamptz not null default now());
create table if not exists public.muatan (
  id text primary key, data jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null, updated_at timestamptz not null default now());

alter table public.dus enable row level security;
alter table public.muatan enable row level security;

drop trigger if exists cn_audit on public.dus;
create trigger cn_audit before insert or update on public.dus for each row execute function public.cn_audit();
drop trigger if exists cn_audit on public.muatan;
create trigger cn_audit before insert or update on public.muatan for each row execute function public.cn_audit();
create index if not exists dus_tgl on public.dus ((data->>'tanggal'));
create index if not exists dus_muatan on public.dus ((data->>'muatan_id'));
create index if not exists muatan_tgl on public.muatan ((data->>'tanggal'));

-- ---------- dus ----------
-- dibaca: owner, produksi, gudang, sales
-- dibuat: produksi (cetak label), owner
-- diubah: gudang (muat ke kendaraan), sales (terjual), produksi (koreksi), owner
drop policy if exists baca   on public.dus;
drop policy if exists tambah on public.dus;
drop policy if exists ubah   on public.dus;
drop policy if exists hapus  on public.dus;
create policy baca on public.dus for select to authenticated
  using (public.my_role() in ('owner','produksi','gudang','sales'));
create policy tambah on public.dus for insert to authenticated
  with check (public.my_role() in ('owner','produksi'));
create policy ubah on public.dus for update to authenticated
  using (public.my_role() in ('owner','produksi','gudang','sales'))
  with check (public.my_role() in ('owner','produksi','gudang','sales'));
create policy hapus on public.dus for delete to authenticated
  using (public.is_owner());

-- ---------- muatan ----------
-- dibaca: owner, gudang, sales, produksi, dan sopir yang namanya tercatat di muatan itu
-- dibuat/diubah: owner, gudang
-- sopir hanya boleh mengubah muatan miliknya (aplikasi hanya menulis kolom konfirmasi)
drop policy if exists baca   on public.muatan;
drop policy if exists tambah on public.muatan;
drop policy if exists ubah   on public.muatan;
drop policy if exists hapus  on public.muatan;
create policy baca on public.muatan for select to authenticated
  using (public.my_role() in ('owner','gudang','sales','produksi')
         or (public.my_role() = 'driver' and data->>'sopir' = (select p.nama from public.profiles p where p.id = auth.uid())));
create policy tambah on public.muatan for insert to authenticated
  with check (public.my_role() in ('owner','gudang'));
create policy ubah on public.muatan for update to authenticated
  using (public.my_role() in ('owner','gudang')
         or (public.my_role() = 'driver' and data->>'sopir' = (select p.nama from public.profiles p where p.id = auth.uid())))
  with check (public.my_role() in ('owner','gudang')
         or (public.my_role() = 'driver' and data->>'sopir' = (select p.nama from public.profiles p where p.id = auth.uid())));
create policy hapus on public.muatan for delete to authenticated
  using (public.is_owner());

-- ---------- peran driver: boleh membaca pengaturan & karyawan (kartu absen) ----------
-- (sudah ditambahkan di 17_freelance_driver_wajah.sql)

grant select, insert, update, delete on public.dus, public.muatan to authenticated;
revoke all on public.dus, public.muatan from anon;

-- daftar cadangan
insert into public.cn_akses(nama, baca, tulis) values
  ('dus', '{}', '{}'), ('muatan', '{}', '{}')
on conflict (nama) do nothing;

-- riwayat perubahan (jika fitur riwayat sudah dipasang)
do $$
begin
  if exists (select 1 from pg_proc where proname = 'cn_catat') then
    execute 'drop trigger if exists cn_catat_trg on public.dus';
    execute 'create trigger cn_catat_trg after insert or update or delete on public.dus for each row execute function public.cn_catat()';
    execute 'drop trigger if exists cn_catat_trg on public.muatan';
    execute 'create trigger cn_catat_trg after insert or update or delete on public.muatan for each row execute function public.cn_catat()';
  end if;
end $$;

-- pembaruan langsung di aplikasi (realtime)
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['dus','muatan'] loop
      if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

select 'Tabel dus & muatan siap' as hasil;
