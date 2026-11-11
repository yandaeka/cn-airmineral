-- =====================================================================
-- CN Air Mineral — Manager Pabrik: lihat keuangan & gudang, catat produksi & gudang
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Policy ini ditambahkan (tidak mengubah policy lama).
-- =====================================================================

do $$
declare t text;
begin
  -- BACA: produksi, gudang, keuangan (tanpa tabel gaji)
  foreach t in array array['produk','bahan','produksi','pemakaian','mutasi','opname','karyawan',
     'penjualan','keluar','dus','muatan','pelanggan','wilayah','harga','pengaturan',
     'pengeluaran','pembayaran','transfer','kreditur','hutang_lain','bayar_hutang','inv_supplier'] loop
    execute format('drop policy if exists baca_mgr on public.%I', t);
    execute format('create policy baca_mgr on public.%I for select to authenticated using (public.my_role() = ''manager'')', t);
  end loop;

  -- TULIS: hanya data produksi & gudang
  foreach t in array array['produksi','pemakaian','keluar','mutasi','opname','muatan','dus'] loop
    execute format('drop policy if exists tulis_mgr_ins on public.%I', t);
    execute format('drop policy if exists tulis_mgr_upd on public.%I', t);
    execute format('drop policy if exists tulis_mgr_del on public.%I', t);
    execute format('create policy tulis_mgr_ins on public.%I for insert to authenticated with check (public.my_role() = ''manager'')', t);
    execute format('create policy tulis_mgr_upd on public.%I for update to authenticated using (public.my_role() = ''manager'') with check (public.my_role() = ''manager'')', t);
    execute format('create policy tulis_mgr_del on public.%I for delete to authenticated using (public.my_role() = ''manager'')', t);
  end loop;
end $$;
