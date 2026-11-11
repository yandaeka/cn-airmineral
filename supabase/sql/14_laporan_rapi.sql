-- =====================================================================
-- CN Air Mineral — Format laporan mingguan Telegram dirapikan
-- (bagian dipisah garis, tanpa baris kosong berlebihan). Isi dan angka sama.
-- Jalankan setelah 11. Aman dijalankan ulang.
-- =====================================================================
create or replace function cn_private.isi_laporan(p_akhir date default null) returns text
language plpgsql stable security definer set search_path = public as $$
declare
  hari_ini date := (now() at time zone 'Asia/Makassar')::date;
  e date := coalesce(p_akhir, date_trunc('week', hari_ini)::date - 1);
  s date := e - 6; e1 date := s - 1; s1 date := s - 7;
  cfg jsonb; s0 text; stok0 numeric;
  pj record; pj1 numeric; pr record; kas record; keluar_ops numeric; pt record; stok numeric;
  t text := ''; baris text; url text;
begin
  select data into cfg from public.pengaturan where id = 'umum';
  s0 := coalesce(cfg->>'tgl_stok_awal', '2000-01-01'); stok0 := cn_private.num(cfg->>'stok_awal_jadi');
  select app_url into url from cn_private.bot where id = 1;

  -- penjualan minggu ini & minggu lalu
  with j as (select data d, cn_private.num(data->>'dus') dus, cn_private.num(data->>'retur') rt, cn_private.num(data->>'harga') hg,
                    cn_private.num(data->>'diskon') dk, cn_private.num(data->>'bonus') bn
               from public.penjualan where data->>'tanggal' between s::text and e::text)
  select coalesce(sum(dus-rt),0) dus, coalesce(sum(bn),0) bonus, coalesce(sum(dus*hg-dk-rt*hg),0) bersih,
         coalesce(sum(dus*hg-dk-rt*hg) filter (where d->>'jenis'='Tunai'),0) tunai,
         coalesce(sum(dus*hg-dk-rt*hg) filter (where d->>'jenis'='Kredit'),0) kredit, count(*) n
    into pj from j;
  select coalesce(sum(cn_private.num(data->>'dus')*cn_private.num(data->>'harga')-cn_private.num(data->>'diskon')-cn_private.num(data->>'retur')*cn_private.num(data->>'harga')),0)
    into pj1 from public.penjualan where data->>'tanggal' between s1::text and e1::text;

  t := '<b>📊 LAPORAN MINGGUAN</b>' || chr(10) || 'CN Air Mineral · ' || cn_private.tgl(s) || ' – ' || cn_private.tgl(e) || chr(10);
  t := t || chr(10) || '──────────────' || chr(10) || '<b>💧 Penjualan</b>' || chr(10) || cn_private.angka(pj.dus) || ' dus · <b>' || cn_private.rp(pj.bersih) || '</b> (' || pj.n || ' nota)';
  if pj1 > 0 then
    t := t || chr(10) || 'Minggu lalu ' || cn_private.rp(pj1) || ' → ' || case when pj.bersih >= pj1 then '▲ ' else '▼ ' end
         || round(abs(pj.bersih - pj1) * 100 / pj1) || '%';
  end if;
  t := t || chr(10) || 'Tunai ' || cn_private.rp(pj.tunai) || ' · Kredit ' || cn_private.rp(pj.kredit) || ' · Bonus ' || cn_private.angka(pj.bonus) || ' dus';
  select string_agg('• ' || cn_private.h(sl) || ' — ' || cn_private.angka(dus) || ' dus · ' || cn_private.rp(nilai), chr(10) order by nilai desc) into baris
    from (select upper(coalesce(data->>'sales','-')) sl, sum(cn_private.num(data->>'dus')-cn_private.num(data->>'retur')) dus,
                 sum(cn_private.num(data->>'dus')*cn_private.num(data->>'harga')-cn_private.num(data->>'diskon')-cn_private.num(data->>'retur')*cn_private.num(data->>'harga')) nilai
            from public.penjualan where data->>'tanggal' between s::text and e::text group by 1) x;
  if baris is not null then t := t || chr(10) || 'Per sales:' || chr(10) || baris; end if;

  -- produksi
  select coalesce(sum(cn_private.num(data->>'aktual')),0) ak, coalesce(sum(cn_private.num(data->>'reject')),0) rj, count(*) hari
    into pr from public.produksi where data->>'tanggal' between s::text and e::text;
  t := t || chr(10) || '──────────────' || chr(10) || '<b>🏭 Produksi</b>' || chr(10) || cn_private.angka(pr.ak - pr.rj) || ' dus jadi dalam ' || pr.hari || ' hari'
       || case when pr.ak > 0 then ' · reject ' || cn_private.angka(pr.rj) || ' (' || replace(round(pr.rj*100/pr.ak,1)::text,'.',',') || '%)' else '' end;

  -- kas
  select coalesce(sum(cn_private.num(data->>'nominal')) filter (where data->>'jenis'='Penjualan tunai'),0) tunai,
         coalesce(sum(cn_private.num(data->>'nominal')) filter (where data->>'jenis'='Penagihan piutang'),0) tagih,
         coalesce(sum(cn_private.num(data->>'nominal')) filter (where data->>'jenis' in ('Modal','Lainnya')),0) lain
    into kas from public.pembayaran where data->>'tanggal' between s::text and e::text;
  select coalesce(sum(cn_private.num(data->>'nominal')),0) into keluar_ops from public.pengeluaran where data->>'tanggal' between s::text and e::text;
  t := t || chr(10) || '──────────────' || chr(10) || '<b>💰 Kas</b>' || chr(10) || 'Masuk ' || cn_private.rp(kas.tunai + kas.tagih + kas.lain)
       || ' (tunai ' || cn_private.rp(kas.tunai) || ', tagihan ' || cn_private.rp(kas.tagih) || ')' || chr(10)
       || 'Pengeluaran tercatat ' || cn_private.rp(keluar_ops);

  -- piutang (kredit)
  with inv as (
    select p.data->>'no' no, upper(coalesce(p.data->>'pelanggan_nama','-')) toko, upper(coalesce(p.data->>'sales','-')) sl,
           nullif(p.data->>'jatuh_tempo','')::date jt,
           cn_private.num(p.data->>'dus')*cn_private.num(p.data->>'harga')-cn_private.num(p.data->>'diskon')-cn_private.num(p.data->>'retur')*cn_private.num(p.data->>'harga')
             - coalesce((select sum(cn_private.num(b.data->>'nominal')) from public.pembayaran b where b.data->>'ref' = p.data->>'no'),0) sisa
      from public.penjualan p where p.data->>'jenis' = 'Kredit')
  select coalesce(sum(sisa) filter (where sisa > 0),0) total, count(*) filter (where sisa > 0) n,
         coalesce(sum(sisa) filter (where sisa > 0 and jt < hari_ini),0) lewat, count(*) filter (where sisa > 0 and jt < hari_ini) nl
    into pt from inv;
  t := t || chr(10) || '──────────────' || chr(10) || '<b>📒 Piutang</b>' || chr(10) || 'Total piutang ' || cn_private.rp(pt.total) || ' (' || pt.n || ' nota)'
       || chr(10) || 'Lewat jatuh tempo <b>' || cn_private.rp(pt.lewat) || '</b> (' || pt.nl || ' nota)';
  with inv as (
    select upper(coalesce(p.data->>'pelanggan_nama','-')) toko, upper(coalesce(p.data->>'sales','-')) sl, nullif(p.data->>'jatuh_tempo','')::date jt,
           cn_private.num(p.data->>'dus')*cn_private.num(p.data->>'harga')-cn_private.num(p.data->>'diskon')-cn_private.num(p.data->>'retur')*cn_private.num(p.data->>'harga')
             - coalesce((select sum(cn_private.num(b.data->>'nominal')) from public.pembayaran b where b.data->>'ref' = p.data->>'no'),0) sisa
      from public.penjualan p where p.data->>'jenis' = 'Kredit')
  select string_agg('• ' || cn_private.h(toko) || ' (' || cn_private.h(sl) || ') — ' || cn_private.rp(sisa) || ', ' || hari || ' hr', chr(10) order by sisa desc) into baris
    from (select toko, sl, sum(sisa) sisa, max(hari_ini - jt) hari from inv where sisa > 0 and jt < hari_ini group by toko, sl order by sum(sisa) desc limit 5) x;
  if baris is not null then t := t || chr(10) || 'Lewat tempo terbesar:' || chr(10) || baris; end if;

  -- stok teoritis hari ini
  select stok0
       + coalesce((select sum(cn_private.num(data->>'aktual')-cn_private.num(data->>'reject')) from public.produksi where data->>'tanggal' >= s0),0)
       - coalesce((select sum(cn_private.num(data->>'dus')-cn_private.num(data->>'retur')+cn_private.num(data->>'bonus')) from public.penjualan where data->>'tanggal' >= s0),0)
       + coalesce((select sum(case when data->>'arah'='Masuk' then 1 else -1 end * cn_private.num(data->>'qty')) from public.mutasi where data->>'tanggal' >= s0),0)
    into stok;
  t := t || chr(10) || '──────────────' || chr(10) || '<b>📦 Stok barang jadi</b>' || chr(10) || cn_private.angka(stok) || ' dus (hari ini, menurut catatan)';

  -- yang perlu dicek
  baris := null;
  with k as (select data->>'tanggal' tg, upper(data->>'sales') sl, sum(cn_private.num(data->>'dus')+cn_private.num(data->>'bonus')) muat
               from public.keluar where data->>'tanggal' between s::text and e::text group by 1,2),
       n as (select data->>'tanggal' tg, upper(data->>'sales') sl, sum(cn_private.num(data->>'dus')-cn_private.num(data->>'retur')+cn_private.num(data->>'bonus')) nota
               from public.penjualan where data->>'tanggal' between s::text and e::text group by 1,2)
  select string_agg('• Muatan tanpa nota: ' || cn_private.h(k.sl) || ' ' || cn_private.tgl(k.tg::date) || ' — ' || cn_private.angka(k.muat - coalesce(n.nota,0)) || ' dus', chr(10) order by k.tg)
    into baris from k left join n on n.tg = k.tg and n.sl = k.sl where k.muat - coalesce(n.nota,0) > 0;
  declare op record; teo numeric; cek text := coalesce(baris,'');
  begin
    select data->>'tanggal' tg, cn_private.num(data->>'fisik') fisik into op from public.opname order by data->>'tanggal' desc limit 1;
    if op.tg is not null and op.tg >= s0 then
      select stok0
        + coalesce((select sum(cn_private.num(data->>'aktual')-cn_private.num(data->>'reject')) from public.produksi where data->>'tanggal' between s0 and op.tg),0)
        - coalesce((select sum(cn_private.num(data->>'dus')-cn_private.num(data->>'retur')+cn_private.num(data->>'bonus')) from public.penjualan where data->>'tanggal' between s0 and op.tg),0)
        + coalesce((select sum(case when data->>'arah'='Masuk' then 1 else -1 end * cn_private.num(data->>'qty')) from public.mutasi where data->>'tanggal' between s0 and op.tg),0)
        into teo;
      if op.fisik <> teo then
        cek := cek || case when cek <> '' then chr(10) else '' end || '• Opname terakhir ' || cn_private.tgl(op.tg::date) || ': fisik '
               || cn_private.angka(op.fisik) || ' vs catatan ' || cn_private.angka(teo) || ' (selisih ' || cn_private.angka(op.fisik - teo) || ' dus)';
      end if;
    end if;
    if pj.n = 0 then cek := cek || case when cek <> '' then chr(10) else '' end || '• Tidak ada nota penjualan minggu ini — pastikan sales menginput.'; end if;
    if stok < 0 then cek := cek || case when cek <> '' then chr(10) else '' end || '• Stok catatan minus — ada penjualan tanpa produksi tercatat.'; end if;
    t := t || chr(10) || '──────────────' || chr(10) || '<b>⚠️ Perlu dicek</b>' || chr(10) || case when cek = '' then 'Tidak ada temuan. 👍' else cek end;
  end;

  t := t || cn_private.kejadian(s, e, hari_ini);
  if url is not null then t := t || chr(10) || chr(10) || '──────────────' || chr(10) || 'Buka aplikasi: ' || url; end if;
  return left(t, 4000);
end $$;

select 'Format laporan mingguan dirapikan' as hasil;
