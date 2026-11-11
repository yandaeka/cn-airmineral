-- =====================================================================
-- CN Air Mineral — Akun Lab / Penjamin Mutu boleh mengisi hasil uji QC
-- (TDS, pH, bau-rasa-warna) di data Produksi, sesuai PK.8.5.01 dan FM.9.1.02-01.
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Lab hanya diizinkan MENGUBAH baris Produksi (tidak menambah). Pembatasan
-- kolom dijaga di aplikasi: form Uji QC hanya mengubah tds, ph, organoleptik.
-- =====================================================================
drop policy if exists lab_uji_qc on public.produksi;
create policy lab_uji_qc on public.produksi for update to authenticated
  using (public.my_role() = 'lab')
  with check (public.my_role() = 'lab');

select 'Akses uji QC untuk lab siap' as hasil;
