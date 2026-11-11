-- =====================================================================
-- CN Air Mineral — CV QQ Eka Putra
-- Struktur database Supabase (langkah 1)
-- Jalankan sekali di Supabase → SQL Editor → New query → Run.
-- Aman dijalankan ulang (idempotent).
-- =====================================================================

-- ---------- 1. Profil pengguna & peran --------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nama       text not null,                       -- harus sama dengan nama di Master Data → Karyawan (untuk sales)
  role       text not null check (role in ('owner','sales','gudang','produksi')),
  aktif      boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

-- Peran pengguna yang sedang login (dipakai semua aturan akses)
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and aktif
$$;

create or replace function public.is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() = 'owner', false)
$$;

drop policy if exists profiles_read  on public.profiles;
drop policy if exists profiles_owner on public.profiles;
create policy profiles_read  on public.profiles for select to authenticated using (id = auth.uid() or public.my_role() is not null);
create policy profiles_owner on public.profiles for all    to authenticated using (public.is_owner()) with check (public.is_owner());

-- ---------- 2. Tabel data (satu tabel per menu aplikasi) ----------------
-- Isi baris disimpan sebagai JSON (kolom data) agar aplikasi yang sekarang
-- bisa langsung dipakai tanpa ditulis ulang. Kolom audit diisi otomatis.
create or replace function public.cn_audit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.created_at := now();
  else
    new.created_by := old.created_by;          -- pembuat tidak bisa diganti
    new.created_at := old.created_at;
  end if;
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end $$;

-- Daftar tabel: nama | peran yang boleh membaca | peran yang boleh menambah/mengubah
-- (owner selalu boleh semuanya)
create table if not exists public.cn_akses(nama text primary key, baca text[] not null, tulis text[] not null);
alter table public.cn_akses enable row level security;
insert into public.cn_akses(nama, baca, tulis) values
  ('pengaturan',   '{sales,gudang,produksi}', '{}'),
  ('produk',       '{sales,gudang,produksi}', '{}'),
  ('bahan',        '{gudang,produksi}',       '{}'),
  ('karyawan',     '{sales,gudang,produksi}', '{}'),
  ('wilayah',      '{sales,gudang}',          '{}'),
  ('harga',        '{sales,gudang}',          '{}'),
  ('pelanggan',    '{sales,gudang}',          '{sales}'),
  ('penjualan',    '{sales,gudang}',          '{sales}'),
  ('pembayaran',   '{sales}',                 '{sales}'),
  ('keluar',       '{sales,gudang}',          '{gudang}'),
  ('produksi',     '{sales,gudang,produksi}', '{produksi}'),
  ('pemakaian',    '{gudang,produksi}',       '{produksi}'),
  ('mutasi',       '{sales,gudang}',          '{gudang}'),
  ('opname',       '{sales,gudang}',          '{gudang}'),
  ('inv_supplier', '{gudang}',                '{gudang}'),
  ('kreditur',     '{gudang}',                '{}'),
  ('pengeluaran',  '{}',                      '{}'),
  ('hutang_lain',  '{}',                      '{}'),
  ('bayar_hutang', '{}',                      '{}'),
  ('gaji',         '{}',                      '{}'),
  ('transfer',     '{}',                      '{}')
on conflict (nama) do update set baca = excluded.baca, tulis = excluded.tulis;

do $$
declare t record;
begin
  for t in select * from public.cn_akses loop
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

-- ---------- 3. Nomor nota anti-bentrok ---------------------------------
-- Dua sales yang menyimpan nota bersamaan tidak akan mendapat nomor sama.
create table if not exists public.nomor_urut (prefix text primary key, terakhir int not null default 0);
alter table public.nomor_urut enable row level security;   -- hanya lewat fungsi di bawah

create or replace function public.nomor_nota(tgl date) returns text
language plpgsql security definer set search_path = public as $$
declare p text := 'CN-' || to_char(tgl, 'YYYYMMDD') || '-'; n int; mx int;
begin
  if public.my_role() not in ('owner','sales') then raise exception 'Tidak berhak membuat nota'; end if;
  -- mulai dari nomor terbesar yang sudah ada (mis. nota hasil impor)
  select coalesce(max(nullif(regexp_replace(data->>'no', '^.*-', ''), '')::int), 0) into mx
    from public.penjualan where data->>'no' like p || '%';
  insert into public.nomor_urut as u (prefix, terakhir) values (p, mx + 1)
    on conflict (prefix) do update set terakhir = greatest(u.terakhir, mx) + 1
    returning terakhir into n;
  return p || lpad(n::text, 3, '0');
end $$;
grant execute on function public.nomor_nota(date) to authenticated;

-- ---------- 4. Sinkron langsung (realtime) -----------------------------
-- Perubahan dari satu HP langsung muncul di HP/laptop lain.
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    for t in select nama from public.cn_akses loop
      if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

-- ---------- 5. Tampilan siap pakai untuk rekap / ekspor -----------------
create or replace view public.v_penjualan with (security_invoker = true) as
select id,
       data->>'no'                          as no_nota,
       (data->>'tanggal')::date             as tanggal,
       data->>'sales'                       as sales,
       data->>'jenis'                       as jenis,
       data->>'pelanggan'                   as pelanggan_id,
       data->>'pelanggan_nama'              as pelanggan,
       coalesce((data->>'dus')::numeric,0)    as dus,
       coalesce((data->>'bonus')::numeric,0)  as bonus,
       coalesce((data->>'harga')::numeric,0)  as harga,
       coalesce((data->>'diskon')::numeric,0) as diskon,
       coalesce((data->>'retur')::numeric,0)  as retur,
       coalesce((data->>'dus')::numeric,0)*coalesce((data->>'harga')::numeric,0)
         - coalesce((data->>'diskon')::numeric,0)
         - coalesce((data->>'retur')::numeric,0)*coalesce((data->>'harga')::numeric,0) as total,
       nullif(data->>'jatuh_tempo','')::date as jatuh_tempo,
       created_at
from public.penjualan;

create or replace view public.v_pembayaran with (security_invoker = true) as
select id, (data->>'tanggal')::date as tanggal, data->>'jenis' as jenis, data->>'pembayar' as pembayar,
       data->>'metode' as metode, data->>'akun' as akun, coalesce((data->>'nominal')::numeric,0) as nominal,
       data->>'ref' as no_nota, created_at
from public.pembayaran;

create or replace view public.v_piutang with (security_invoker = true) as
select p.no_nota, p.tanggal, p.sales, p.pelanggan, p.total,
       coalesce(sum(b.nominal),0)            as dibayar,
       p.total - coalesce(sum(b.nominal),0)  as sisa,
       p.jatuh_tempo,
       greatest(0, (now() at time zone 'Asia/Makassar')::date - p.jatuh_tempo) as hari_lewat
from public.v_penjualan p
left join public.v_pembayaran b on b.no_nota = p.no_nota
group by p.no_nota, p.tanggal, p.sales, p.pelanggan, p.total, p.jatuh_tempo
having p.total - coalesce(sum(b.nominal),0) > 0;

-- ---------- 6. Hak dasar: hanya pengguna login, tamu (anon) tidak bisa apa-apa --
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on all tables in schema public from anon;
revoke all on public.nomor_urut from authenticated;

revoke all on public.cn_akses from authenticated;
