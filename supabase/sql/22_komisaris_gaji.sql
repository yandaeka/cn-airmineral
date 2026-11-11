-- =====================================================================
-- CN Air Mineral — Total gaji per bulan untuk komisaris (tanpa rincian)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Komisaris hanya menerima total per bulan, tidak bisa membaca tabel gaji.
-- =====================================================================

create or replace function public.cn_total_gaji_per_bulan()
returns table(bulan text, total numeric)
language sql stable security definer set search_path = public as $$
  select left(data->>'tanggal', 7) as bulan,
         sum(
           cn_private.num(data->>'gaji_pokok') + cn_private.num(data->>'tunjangan')
         + cn_private.num(data->>'gaji_harian') * cn_private.num(data->>'hari_kerja')
         + cn_private.num(data->>'dus_insentif') * cn_private.num(data->>'tarif_insentif')
         + cn_private.num(data->>'dus_bonus') * cn_private.num(data->>'tarif_bonus')
         + cn_private.num(data->>'lembur_jam') * cn_private.num(data->>'tarif_lembur')
         + cn_private.num(data->>'lembur_nominal')
         - cn_private.num(data->>'bpjs') - cn_private.num(data->>'pajak') - cn_private.num(data->>'potongan')
         ) as total
    from public.gaji
   where data->>'status' = 'Dibayar'
     and public.my_role() in ('owner','komisaris')
   group by 1;
$$;

revoke all on function public.cn_total_gaji_per_bulan() from public, anon;
grant execute on function public.cn_total_gaji_per_bulan() to authenticated;
