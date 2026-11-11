-- =====================================================================
-- CN Air Mineral — Acuan Rencana Mutu (Lamp.04.03) untuk produk jadi
-- Standar produk jadi: TDS maks 500 mg/L, pH 6,5 – 8,5.
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================
update public.pengaturan
   set data = data || '{"tds_max":500,"ph_min":6.5,"ph_max":8.5}'::jsonb
 where id = 'umum';

select 'Acuan Rencana Mutu diterapkan' as hasil;
