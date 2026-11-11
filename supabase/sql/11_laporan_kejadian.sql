-- =====================================================================
-- CN Air Mineral — Laporan mingguan ditambah "kejadian minggu itu":
-- uji QC, sanitasi, perawatan mesin, kalibrasi alat ukur, peralatan
-- bermasalah, dan stok bahan baku (menurut catatan).
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================

create or replace view cn_private.v_bahan_harian as
with prod as (
  select data->>'tanggal' as tg, sum(cn_private.num(data->>'aktual')) as ak
    from public.produksi group by 1),
pk as (
  select data->>'tanggal' as tg, data->'items' as it from public.pemakaian),
days as (
  select tg from prod union select tg from pk)
select nullif(d.tg,'')::date as tg, pr.ak, pk.it
  from days d left join prod pr on pr.tg = d.tg left join pk on pk.tg = d.tg;

create or replace function cn_private.kejadian(s date, e date, hari_ini date) returns text
language plpgsql stable security definer set search_path = public as $$
declare
  cfg jsonb; s0 date; tmax numeric; phmin numeric; phmax numeric; tgt numeric; bauto boolean;
  qc record; sn record; pw record; t text := ''; x text; xl text; xs text; b record;
  masuk numeric; pakai numeric; rijek numeric; kor numeric; stok numeric; hari numeric;
  bahan_txt text := '';
begin
  select data into cfg from public.pengaturan where id = 'umum';
  s0    := coalesce(nullif(cfg->>'tgl_stok_awal',''), '2000-01-01')::date;
  tmax  := coalesce(nullif(cfg->>'tds_max',''), '500')::numeric;
  phmin := coalesce(nullif(cfg->>'ph_min',''), '6')::numeric;
  phmax := coalesce(nullif(cfg->>'ph_max',''), '8.5')::numeric;
  tgt   := coalesce(nullif(cfg->>'target_harian',''), '0')::numeric;
  bauto := coalesce((cfg->>'bahan_otomatis')::boolean, true);

  -- Uji QC batch minggu ini
  select count(*) n,
         count(*) filter (where nullif(data->>'tds','') is null and nullif(data->>'ph','') is null) belum,
         count(*) filter (where nullif(data->>'tds','') is not null and nullif(data->>'ph','') is not null
                          and cn_private.num(data->>'tds') <= tmax
                          and cn_private.num(data->>'ph') between phmin and phmax
                          and coalesce(data->>'organoleptik','Sesuai') <> 'Tidak sesuai') lulus
    into qc from public.produksi where data->>'tanggal' between s::text and e::text;
  t := t || chr(10) || '──────────────' || chr(10) || '<b>🧪 Uji QC</b>' || chr(10);
  if qc.n = 0 then
    t := t || 'Tidak ada produksi minggu ini.';
  else
    t := t || qc.n || ' batch: lulus ' || qc.lulus || ' · karantina ' || (qc.n - qc.belum - qc.lulus) || ' · belum diuji ' || qc.belum;
  end if;

  -- Sanitasi
  select count(*) n,
         count(*) filter (where (select count(*) from jsonb_each(coalesce(data->'cek','{}'::jsonb)) j where j.value = 'true'::jsonb) >= 5) lengkap
    into sn from public.sanitasi where data->>'tanggal' between s::text and e::text;
  t := t || chr(10) || '──────────────' || chr(10) || '<b>🧼 Sanitasi</b>' || chr(10)
       || 'Tercatat ' || sn.n || ' dari 7 hari · lengkap ' || sn.lengkap || ' hari';

  -- Perawatan mesin
  select count(*) n, string_agg(distinct data->>'mesin', ', ') ms
    into pw from public.perawatan where data->>'tanggal' between s::text and e::text;
  t := t || chr(10) || '──────────────' || chr(10) || '<b>🔧 Perawatan mesin</b>' || chr(10)
       || case when pw.n = 0 then 'Tidak ada catatan perawatan minggu ini.' else pw.n || ' catatan · ' || cn_private.h(pw.ms) end;

  -- Kalibrasi alat ukur
  select string_agg('• ' || cn_private.h(data->>'nama') || ' — sejak ' || cn_private.tgl((data->>'kalibrasi_berikutnya')::date), chr(10) order by data->>'nama')
    into xl from public.peralatan
   where data->>'jenis' = 'Pengukuran' and nullif(data->>'kalibrasi_berikutnya','')::date < hari_ini;
  select string_agg('• ' || cn_private.h(data->>'nama') || ' — ' || cn_private.tgl((data->>'kalibrasi_berikutnya')::date), chr(10) order by data->>'nama')
    into xs from public.peralatan
   where data->>'jenis' = 'Pengukuran' and nullif(data->>'kalibrasi_berikutnya','')::date between hari_ini and hari_ini + 14;
  t := t || chr(10) || '──────────────' || chr(10) || '<b>📏 Kalibrasi alat ukur</b>' || chr(10);
  if xl is null and xs is null then
    if exists (select 1 from public.peralatan where data->>'jenis' = 'Pengukuran') then
      t := t || 'Semua alat ukur masih dalam jadwal.';
    else
      t := t || 'Belum ada alat ukur yang didaftarkan.';
    end if;
  end if;
  if xl is not null then t := t || 'Lewat jatuh tempo:' || chr(10) || xl; end if;
  if xs is not null then t := t || case when xl is not null then chr(10) else '' end || 'Jatuh tempo dalam 14 hari:' || chr(10) || xs; end if;

  -- Peralatan yang tidak berkondisi baik
  select string_agg('• ' || cn_private.h(data->>'nama') || ' — ' || cn_private.h(data->>'kondisi'), chr(10) order by data->>'nama')
    into x from public.peralatan where coalesce(data->>'kondisi','Baik') <> 'Baik';
  if x is not null then
    t := t || chr(10) || '──────────────' || chr(10) || '<b>🛠️ Peralatan perlu perhatian</b>' || chr(10) || x;
  end if;

  -- Stok bahan baku, menurut catatan hari ini (logika sama dengan halaman Bahan Baku)
  for b in select id, coalesce(data->>'nama','') nama, coalesce(data->>'satuan','') satuan,
                  coalesce(cn_private.num(data->>'saldo_awal'),0) sa, cn_private.num(data->>'per_dus') pd
             from public.bahan order by data->>'nama' loop
    select coalesce(sum(cn_private.num(i->>'qty')),0) into masuk
      from public.inv_supplier v, jsonb_array_elements(coalesce(v.data->'items','[]'::jsonb)) i
     where i->>'bahan' = b.id and v.data->>'tanggal' >= s0::text;
    select coalesce(sum(case when z.m > 0 then z.m when bauto then z.ak * b.pd else 0 end),0),
           coalesce(sum(z.ri),0), coalesce(sum(z.ko),0)
      into pakai, rijek, kor
      from (select coalesce(vh.ak,0) ak,
                   cn_private.num(vh.it->b.id->>'pakai') m,
                   cn_private.num(vh.it->b.id->>'rijek') ri,
                   cn_private.num(vh.it->b.id->>'koreksi') ko
              from cn_private.v_bahan_harian vh where vh.tg >= s0) z;
    stok := b.sa + masuk - pakai - rijek + kor;
    if b.pd > 0 and tgt > 0 then hari := (stok / b.pd) / tgt; else hari := null; end if;
    bahan_txt := bahan_txt || chr(10) || '• ' || cn_private.h(b.nama) || ' — ' || cn_private.angka(stok) || ' ' || cn_private.h(b.satuan)
      || case when hari is not null then ' ≈ ' || replace(round(hari,1)::text,'.',',') || ' hari' || case when hari < 3 then ' ⚠️' else '' end else '' end;
  end loop;
  if bahan_txt <> '' then
    t := t || chr(10) || '──────────────' || chr(10) || '<b>🧴 Stok bahan baku (menurut catatan)</b>' || bahan_txt;
  end if;

  return t;
end $$;

-- Sisipkan bagian kejadian ke laporan, tepat sebelum tautan "Detail" (hanya sekali)
do $$
declare d text;
begin
  select pg_get_functiondef('cn_private.isi_laporan(date)'::regprocedure) into d;
  if position('cn_private.kejadian' in d) > 0 then
    raise notice 'Sudah terpasang';
  else
    d := replace(d, '  if url is not null then', '  t := t || cn_private.kejadian(s, e, hari_ini);' || chr(10) || '  if url is not null then');
    execute d;
  end if;
end $$;

select 'Laporan mingguan dengan kejadian siap' as hasil;
