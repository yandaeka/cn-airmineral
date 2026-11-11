-- =====================================================================
-- CN Air Mineral — Fungsi akun Lab / Penjamin Mutu
-- Lab: uji QC (produksi), kalibrasi & peralatan, sanitasi, absensi.
-- Lab TIDAK mencatat perawatan mesin (itu tugas Produksi).
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================
update public.cn_akses set baca = '{produksi}', tulis = '{produksi}' where nama = 'perawatan';

do $$
begin
  execute 'drop policy if exists baca on public.perawatan';
  execute 'drop policy if exists tambah on public.perawatan';
  execute 'drop policy if exists ubah on public.perawatan';
  execute $p$create policy baca on public.perawatan for select to authenticated using (public.is_owner() or public.my_role() = 'produksi')$p$;
  execute $p$create policy tambah on public.perawatan for insert to authenticated with check (public.is_owner() or public.my_role() = 'produksi')$p$;
  execute $p$create policy ubah on public.perawatan for update to authenticated using (public.is_owner() or public.my_role() = 'produksi') with check (public.is_owner() or public.my_role() = 'produksi')$p$;
end $$;

select 'Fungsi lab diperbarui' as hasil;
