-- =====================================================================
-- CN Air Mineral — Peran Manager Pabrik (lihat produksi & stok, absensi)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Jalankan SEBELUM mengunggah aplikasi versi 2.30 terbaru.
-- =====================================================================

-- 1. Tambah peran manager
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('owner','sales','gudang','produksi','lab','freelance','driver','komisaris','manager'));

-- 2. Izinkan owner membuat/mengatur akun manager
do $$
declare f text; fn text;
begin
  foreach fn in array array['public.cn_buat_pengguna(text,text,text,text)','public.cn_atur_pengguna(uuid,text,text,boolean)'] loop
    select pg_get_functiondef(fn::regprocedure) into f;
    f := regexp_replace(f, $q$\('owner','sales','gudang','produksi'[^)]*\)$q$,
                           $q$('owner','sales','gudang','produksi','lab','freelance','driver','komisaris','manager')$q$, 'g');
    execute f;
  end loop;
end $$;

-- 3. Manager hanya BACA data produksi & stok (tanpa keuangan, gaji, piutang, pengaturan)
update public.cn_akses set baca = baca || '{manager}'::text[]
 where nama in ('produk','bahan','produksi','pemakaian','mutasi','opname','karyawan','penjualan','keluar')
   and not ('manager' = any(baca));

-- 4. Manager boleh mencatat absensi (sama seperti driver & freelance)
update public.cn_akses set
  baca  = (select array_agg(distinct x) from unnest(baca  || '{manager}'::text[]) x),
  tulis = (select array_agg(distinct x) from unnest(tulis || '{manager}'::text[]) x)
where nama = 'absensi';

do $$
declare t record;
begin
  for t in select * from public.cn_akses where 'manager' = any(baca) and nama <> 'absensi' loop
    execute format('drop policy if exists baca on public.%I', t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
  end loop;
  for t in select * from public.cn_akses where nama = 'absensi' loop
    execute format('drop policy if exists baca on public.%I',   t.nama);
    execute format('drop policy if exists tambah on public.%I', t.nama);
    execute format('drop policy if exists ubah on public.%I',   t.nama);
    execute format('drop policy if exists hapus on public.%I',  t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
    execute format('create policy tambah on public.%I for insert to authenticated with check (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.tulis);
    execute format($p$create policy ubah on public.%I for update to authenticated
      using (public.is_owner() or (public.my_role() = any(%L::text[]) and created_by = auth.uid()
             and (created_at at time zone 'Asia/Makassar')::date = (now() at time zone 'Asia/Makassar')::date))
      with check (public.is_owner() or public.my_role() = any(%L::text[]))$p$, t.nama, t.tulis, t.tulis);
    execute format($p$create policy hapus on public.%I for delete to authenticated
      using (public.is_owner() or (public.my_role() = any(%L::text[]) and created_by = auth.uid()
             and (created_at at time zone 'Asia/Makassar')::date = (now() at time zone 'Asia/Makassar')::date))$p$, t.nama, t.tulis);
  end loop;
end $$;
