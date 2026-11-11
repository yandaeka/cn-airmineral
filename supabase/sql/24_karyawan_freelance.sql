-- =====================================================================
-- CN Air Mineral — Pastikan driver, freelance & lab bisa membaca Master Karyawan
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================

update public.cn_akses set
  baca = (select array_agg(distinct x) from unnest(baca || '{driver,freelance,lab}'::text[]) x)
where nama = 'karyawan';

do $$
declare t record;
begin
  for t in select * from public.cn_akses where nama = 'karyawan' loop
    execute format('drop policy if exists baca on public.%I', t.nama);
    execute format('create policy baca on public.%I for select to authenticated using (public.is_owner() or public.my_role() = any(%L::text[]))', t.nama, t.baca);
  end loop;
end $$;

select nama, baca from public.cn_akses where nama in ('karyawan','absensi');
