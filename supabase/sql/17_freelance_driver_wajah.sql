-- =====================================================================
-- CN Air Mineral — Peran Freelance & Driver + Absen wajah
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Jalankan SEBELUM mengunggah aplikasi versi 2.3.
-- =====================================================================

-- ---------- 1. Peran baru: freelance (bantu produksi) & driver --------
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('owner','sales','gudang','produksi','lab','freelance','driver'));

do $$
declare f text; fn text;
begin
  foreach fn in array array['public.cn_buat_pengguna(text,text,text,text)','public.cn_atur_pengguna(uuid,text,text,boolean)'] loop
    select pg_get_functiondef(fn::regprocedure) into f;
    f := regexp_replace(f, $q$\('owner','sales','gudang','produksi'[^)]*\)$q$,
                           $q$('owner','sales','gudang','produksi','lab','freelance','driver')$q$, 'g');
    execute f;
  end loop;
end $$;

-- akun freelance & driver hanya perlu membaca data karyawan (untuk kartu absen) dan pengaturan (jam masuk)
update public.cn_akses set baca = baca || '{freelance,driver}'::text[]
 where nama in ('pengaturan','karyawan') and not ('driver' = any(baca));
do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama in ('pengaturan','karyawan') loop
    execute format('drop policy if exists baca on public.%I', t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
  end loop;
end $$;

-- ---------- 2. Tabel wajah (sidik wajah per karyawan) & absen_tolak ------
-- wajah      : 1 baris per karyawan. Dibuat otomatis saat absen pertama (langsung aktif).
--              Dibaca owner atau pemilik wajah itu sendiri; diubah/dihapus hanya owner (reset).
-- absen_tolak: catatan absen yang ditolak karena wajah tidak cocok. Hanya owner yang melihat.
create table if not exists public.wajah (
  id text primary key, data jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null, updated_at timestamptz not null default now());
create table if not exists public.absen_tolak (
  id text primary key, data jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null, updated_at timestamptz not null default now());

alter table public.wajah enable row level security;
alter table public.absen_tolak enable row level security;
drop trigger if exists cn_audit on public.wajah;
create trigger cn_audit before insert or update on public.wajah for each row execute function public.cn_audit();
drop trigger if exists cn_audit on public.absen_tolak;
create trigger cn_audit before insert or update on public.absen_tolak for each row execute function public.cn_audit();
create index if not exists absen_tolak_tgl on public.absen_tolak ((data->>'tanggal'));

drop policy if exists baca   on public.wajah;
drop policy if exists tambah on public.wajah;
drop policy if exists ubah   on public.wajah;
drop policy if exists hapus  on public.wajah;
create policy baca on public.wajah for select to authenticated
  using (public.is_owner() or data->>'nama' = (select p.nama from public.profiles p where p.id = auth.uid()));
create policy tambah on public.wajah for insert to authenticated
  with check (public.is_owner() or (public.my_role() is not null
              and data->>'nama' = (select p.nama from public.profiles p where p.id = auth.uid())));
create policy ubah on public.wajah for update to authenticated
  using (public.is_owner()) with check (public.is_owner());
create policy hapus on public.wajah for delete to authenticated
  using (public.is_owner());

drop policy if exists baca   on public.absen_tolak;
drop policy if exists tambah on public.absen_tolak;
drop policy if exists ubah   on public.absen_tolak;
drop policy if exists hapus  on public.absen_tolak;
create policy baca on public.absen_tolak for select to authenticated using (public.is_owner());
create policy tambah on public.absen_tolak for insert to authenticated with check (public.my_role() is not null);
create policy hapus on public.absen_tolak for delete to authenticated using (public.is_owner());

grant select, insert, update, delete on public.wajah, public.absen_tolak to authenticated;
revoke all on public.wajah, public.absen_tolak from anon;

-- ikut cadangan otomatis (cn_akses dipakai daftar tabel cadangan)
-- catatan: jangan jalankan ulang skrip lama yang membuat ulang aturan semua tabel dari cn_akses
-- (06_peran_lab.sql) setelah skrip ini, karena aturan khusus wajah/absen_tolak akan tertimpa.
insert into public.cn_akses(nama, baca, tulis) values
  ('wajah', '{}', '{}'), ('absen_tolak', '{}', '{}')
on conflict (nama) do nothing;

-- riwayat perubahan (jika fitur riwayat sudah dipasang)
do $$
begin
  if exists (select 1 from pg_proc where proname = 'cn_catat') then
    execute 'drop trigger if exists cn_catat_trg on public.wajah';
    execute 'create trigger cn_catat_trg after insert or update or delete on public.wajah for each row execute function public.cn_catat()';
    execute 'drop trigger if exists cn_catat_trg on public.absen_tolak';
    execute 'create trigger cn_catat_trg after insert or update or delete on public.absen_tolak for each row execute function public.cn_catat()';
  end if;
end $$;

-- pembaruan langsung di aplikasi (realtime)
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['wajah','absen_tolak'] loop
      if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

select 'Peran freelance & driver + absen wajah siap' as hasil;
