-- =====================================================================
-- CN Air Mineral — Peran Komisaris (hanya lihat, pantau dari HP)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Jalankan SEBELUM mengunggah aplikasi versi 2.30.
-- =====================================================================

-- 1. Tambah peran komisaris
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('owner','sales','gudang','produksi','lab','freelance','driver','komisaris'));

-- 2. Izinkan owner membuat/mengatur akun komisaris
do $$
declare f text; fn text;
begin
  foreach fn in array array['public.cn_buat_pengguna(text,text,text,text)','public.cn_atur_pengguna(uuid,text,text,boolean)'] loop
    select pg_get_functiondef(fn::regprocedure) into f;
    f := regexp_replace(f, $q$\('owner','sales','gudang','produksi'[^)]*\)$q$,
                           $q$('owner','sales','gudang','produksi','lab','freelance','driver','komisaris')$q$, 'g');
    execute f;
  end loop;
end $$;

-- 3. Komisaris hanya boleh MEMBACA tabel tertentu (tanpa karyawan, gaji, absensi, wajah, dus, muatan, keamanan)
update public.cn_akses set baca = baca || '{komisaris}'::text[]
 where nama in ('pengaturan','produk','bahan','wilayah','harga','pelanggan','penjualan','pembayaran',
                'pengeluaran','produksi','pemakaian','mutasi','opname','inv_supplier','hutang_lain',
                'bayar_hutang','transfer','kreditur')
   and not ('komisaris' = any(baca));

do $$
declare t record;
begin
  for t in select * from public.cn_akses where 'komisaris' = any(baca) loop
    execute format('drop policy if exists baca on public.%I', t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
  end loop;
end $$;
