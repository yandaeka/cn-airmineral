-- 16_palet_produksi.sql
-- Tombol "+1 palet" di halaman Produksi mengubah catatan produksi hari ini.
-- Aturan bawaan hanya mengizinkan ubah jika pembuat catatan = akun yang login.
-- Catatan produksi hari ini sering dibuat akun lain (mis. owner), jadi ditambahkan
-- izin tambahan: akun produksi boleh mengubah catatan produksi dengan tanggal hari ini (WIB/WITA).
-- Izin ini menambah (permissive), tidak menghapus aturan yang sudah ada.

drop policy if exists produksi_palet_hari_ini on public.produksi;
create policy produksi_palet_hari_ini on public.produksi
  for update to authenticated
  using (
    public.my_role() = 'produksi'
    and data->>'tanggal' in (
      to_char(now() at time zone 'Asia/Jakarta', 'YYYY-MM-DD'),
      to_char(now() at time zone 'Asia/Makassar', 'YYYY-MM-DD'))
  )
  with check (
    public.my_role() = 'produksi'
    and data->>'tanggal' in (
      to_char(now() at time zone 'Asia/Jakarta', 'YYYY-MM-DD'),
      to_char(now() at time zone 'Asia/Makassar', 'YYYY-MM-DD'))
  );

select 'Izin tap palet untuk produksi siap' as hasil;
