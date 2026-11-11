-- =====================================================================
-- CN Air Mineral — Paket Bulan 1
--   • Halaman Pengguna (owner): tambah akun, reset password, peran, aktif
--   • Laporan mingguan otomatis ke Telegram (Senin 07.00 WITA)
--   • Cadangan otomatis mingguan di dalam database (simpan 8 minggu)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_net;
create extension if not exists pg_cron;

create schema if not exists cn_private;           -- tidak terbuka ke aplikasi/API
revoke all on schema cn_private from public;

-- Penjaga: hanya owner (lewat aplikasi) atau admin database (SQL Editor / jadwal otomatis)
create or replace function cn_private.wajib_owner() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.is_owner() or session_user in ('postgres','supabase_admin')) then
    raise exception 'Hanya owner yang boleh melakukan ini';
  end if;
end $$;

create or replace function cn_private.num(t text) returns numeric
language sql immutable as $$
  select case when t ~ '^\s*-?[0-9]+(\.[0-9]+)?\s*$' then t::numeric else 0 end
$$;

create or replace function cn_private.rp(x numeric) returns text
language sql immutable as $$
  select (case when x < 0 then '−' else '' end) || 'Rp' ||
         replace(to_char(round(abs(coalesce(x,0))), 'FM999,999,999,990'), ',', '.')
$$;

create or replace function cn_private.angka(x numeric) returns text
language sql immutable as $$
  select replace(to_char(round(coalesce(x,0)), 'FM999,999,999,990'), ',', '.')
$$;

create or replace function cn_private.tgl(d date) returns text
language sql immutable as $$
  select extract(day from d)::int || ' ' ||
         (array['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'])[extract(month from d)::int] ||
         ' ' || extract(year from d)::int
$$;

create or replace function cn_private.h(t text) returns text      -- aman untuk HTML Telegram
language sql immutable as $$ select replace(replace(replace(coalesce(t,''),'&','&amp;'),'<','&lt;'),'>','&gt;') $$;

-- =====================================================================
-- 1. PENGGUNA
-- =====================================================================
create or replace function public.cn_daftar_pengguna()
returns table(id uuid, username text, nama text, role text, aktif boolean, terakhir_login timestamptz, dibuat timestamptz)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  perform cn_private.wajib_owner();
  return query
    select u.id, split_part(u.email::text,'@',1), p.nama, p.role, coalesce(p.aktif,false), u.last_sign_in_at, u.created_at
    from auth.users u left join public.profiles p on p.id = u.id
    order by (p.role is null) desc, p.role, p.nama;
end $$;

create or replace function public.cn_buat_pengguna(p_username text, p_nama text, p_role text, p_password text)
returns uuid
language plpgsql volatile security definer set search_path = public, auth, extensions as $$
declare uid uuid := gen_random_uuid(); em text;
begin
  perform cn_private.wajib_owner();
  p_username := lower(trim(p_username));
  if p_username !~ '^[a-z0-9._-]{3,30}$' then raise exception 'Nama pengguna 3–30 huruf kecil/angka, tanpa spasi'; end if;
  if p_role not in ('owner','sales','gudang','produksi') then raise exception 'Peran tidak dikenal'; end if;
  if length(coalesce(p_password,'')) < 8 then raise exception 'Password minimal 8 karakter'; end if;
  if coalesce(trim(p_nama),'') = '' then raise exception 'Nama wajib diisi'; end if;
  em := p_username || '@cn.local';
  if exists (select 1 from auth.users where lower(email) = em) then raise exception 'Nama pengguna % sudah dipakai', p_username; end if;

  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', em,
          extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}', jsonb_build_object('nama', p_nama), now(), now(),
          '', '', '', '');
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), uid, uid::text, jsonb_build_object('sub', uid::text, 'email', em, 'email_verified', true),
          'email', now(), now(), now());
  insert into public.profiles (id, nama, role, aktif) values (uid, upper(trim(p_nama)), p_role, true);
  return uid;
end $$;

create or replace function public.cn_reset_password(p_id uuid, p_password text)
returns void
language plpgsql volatile security definer set search_path = public, auth, extensions as $$
begin
  perform cn_private.wajib_owner();
  if length(coalesce(p_password,'')) < 8 then raise exception 'Password minimal 8 karakter'; end if;
  update auth.users set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')), updated_at = now()
   where id = p_id;
  if not found then raise exception 'Akun tidak ditemukan'; end if;
end $$;

create or replace function public.cn_atur_pengguna(p_id uuid, p_nama text, p_role text, p_aktif boolean)
returns void
language plpgsql volatile security definer set search_path = public as $$
begin
  perform cn_private.wajib_owner();
  if p_role not in ('owner','sales','gudang','produksi') then raise exception 'Peran tidak dikenal'; end if;
  if p_id = auth.uid() and (p_role <> 'owner' or not p_aktif) then raise exception 'Tidak bisa menurunkan atau menonaktifkan akun Anda sendiri'; end if;
  insert into public.profiles (id, nama, role, aktif) values (p_id, upper(trim(p_nama)), p_role, p_aktif)
  on conflict (id) do update set nama = excluded.nama, role = excluded.role, aktif = excluded.aktif;
end $$;

-- =====================================================================
-- 2. CADANGAN OTOMATIS
-- =====================================================================
create table if not exists cn_private.cadangan (
  id bigserial primary key, dibuat timestamptz not null default now(),
  tabel text not null, jumlah int not null, data jsonb not null
);

create or replace function cn_private.buat_cadangan() returns int
language plpgsql volatile security definer set search_path = public as $$
declare t text; n int; total int := 0;
begin
  for t in select nama from public.cn_akses loop
    execute format('insert into cn_private.cadangan(tabel, jumlah, data)
                    select %L, count(*), coalesce(jsonb_agg(jsonb_build_object(''id'',id,''data'',data)), ''[]'') from public.%I', t, t);
    execute format('select count(*) from public.%I', t) into n; total := total + n;
  end loop;
  insert into cn_private.cadangan(tabel, jumlah, data)
    select 'profiles', count(*), coalesce(jsonb_agg(to_jsonb(p)), '[]') from public.profiles p;
  delete from cn_private.cadangan where dibuat < now() - interval '60 days';
  return total;
end $$;

create or replace function public.cn_daftar_cadangan()
returns table(waktu timestamptz, jumlah_tabel int, jumlah_baris int)
language plpgsql stable security definer set search_path = public as $$
begin
  perform cn_private.wajib_owner();
  return query select date_trunc('minute', c.dibuat), count(*)::int, sum(c.jumlah)::int
    from cn_private.cadangan c group by 1 order by 1 desc;
end $$;

create or replace function public.cn_buat_cadangan_sekarang() returns int
language plpgsql volatile security definer set search_path = public as $$
begin perform cn_private.wajib_owner(); return cn_private.buat_cadangan(); end $$;

-- =====================================================================
-- 3. TELEGRAM + LAPORAN MINGGUAN
-- =====================================================================
create table if not exists cn_private.bot (
  id int primary key default 1 check (id = 1),
  token text, chat_id text, app_url text, aktif boolean not null default true,
  diubah timestamptz default now()
);
insert into cn_private.bot(id) values (1) on conflict do nothing;
create table if not exists cn_private.kirim_log (id bigserial primary key, waktu timestamptz default now(), request_id bigint, jenis text);

create or replace function public.cn_atur_telegram(p_token text, p_chat_id text, p_app_url text, p_aktif boolean)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  perform cn_private.wajib_owner();
  update cn_private.bot set
    token   = case when coalesce(trim(p_token),'') = '' then token else trim(p_token) end,
    chat_id = trim(p_chat_id), app_url = nullif(trim(p_app_url),''), aktif = p_aktif, diubah = now()
  where id = 1;
end $$;

create or replace function public.cn_status_telegram()
returns table(ada_token boolean, token_akhir text, chat_id text, app_url text, aktif boolean, kirim_terakhir timestamptz, status_terakhir int, pesan_terakhir text)
language plpgsql stable security definer set search_path = public, net as $$
declare r cn_private.bot; lg cn_private.kirim_log; st int; ps text;
begin
  perform cn_private.wajib_owner();
  select * into r from cn_private.bot where id = 1;
  select * into lg from cn_private.kirim_log order by id desc limit 1;
  if lg.request_id is not null then
    begin
      select status_code, left(coalesce(content::text, error_msg), 300) into st, ps from net._http_response where id = lg.request_id;
    exception when others then st := null; ps := null;
    end;
  end if;
  return query select r.token is not null and r.token <> '', right(coalesce(r.token,''),4), r.chat_id, r.app_url, r.aktif, lg.waktu, st, ps;
end $$;

-- Isi laporan (teks HTML Telegram) untuk minggu yang berakhir pada p_akhir (default: Minggu kemarin)
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

  t := '<b>📊 Laporan Mingguan CN Air Mineral</b>' || chr(10) || cn_private.tgl(s) || ' – ' || cn_private.tgl(e) || chr(10) || chr(10);
  t := t || '<b>💧 Penjualan</b>' || chr(10) || cn_private.angka(pj.dus) || ' dus · <b>' || cn_private.rp(pj.bersih) || '</b> (' || pj.n || ' nota)';
  if pj1 > 0 then
    t := t || chr(10) || 'Minggu lalu ' || cn_private.rp(pj1) || ' → ' || case when pj.bersih >= pj1 then '▲ ' else '▼ ' end
         || round(abs(pj.bersih - pj1) * 100 / pj1) || '%';
  end if;
  t := t || chr(10) || 'Tunai ' || cn_private.rp(pj.tunai) || ' · Kredit ' || cn_private.rp(pj.kredit) || ' · Bonus ' || cn_private.angka(pj.bonus) || ' dus';
  select string_agg('• ' || cn_private.h(sl) || ' — ' || cn_private.angka(dus) || ' dus · ' || cn_private.rp(nilai), chr(10) order by nilai desc) into baris
    from (select upper(coalesce(data->>'sales','-')) sl, sum(cn_private.num(data->>'dus')-cn_private.num(data->>'retur')) dus,
                 sum(cn_private.num(data->>'dus')*cn_private.num(data->>'harga')-cn_private.num(data->>'diskon')-cn_private.num(data->>'retur')*cn_private.num(data->>'harga')) nilai
            from public.penjualan where data->>'tanggal' between s::text and e::text group by 1) x;
  if baris is not null then t := t || chr(10) || baris; end if;

  -- produksi
  select coalesce(sum(cn_private.num(data->>'aktual')),0) ak, coalesce(sum(cn_private.num(data->>'reject')),0) rj, count(*) hari
    into pr from public.produksi where data->>'tanggal' between s::text and e::text;
  t := t || chr(10) || chr(10) || '<b>🏭 Produksi</b>' || chr(10) || cn_private.angka(pr.ak - pr.rj) || ' dus jadi dalam ' || pr.hari || ' hari'
       || case when pr.ak > 0 then ' · reject ' || cn_private.angka(pr.rj) || ' (' || replace(round(pr.rj*100/pr.ak,1)::text,'.',',') || '%)' else '' end;

  -- kas
  select coalesce(sum(cn_private.num(data->>'nominal')) filter (where data->>'jenis'='Penjualan tunai'),0) tunai,
         coalesce(sum(cn_private.num(data->>'nominal')) filter (where data->>'jenis'='Penagihan piutang'),0) tagih,
         coalesce(sum(cn_private.num(data->>'nominal')) filter (where data->>'jenis' in ('Modal','Lainnya')),0) lain
    into kas from public.pembayaran where data->>'tanggal' between s::text and e::text;
  select coalesce(sum(cn_private.num(data->>'nominal')),0) into keluar_ops from public.pengeluaran where data->>'tanggal' between s::text and e::text;
  t := t || chr(10) || chr(10) || '<b>💰 Kas</b>' || chr(10) || 'Masuk ' || cn_private.rp(kas.tunai + kas.tagih + kas.lain)
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
  t := t || chr(10) || chr(10) || '<b>📒 Piutang</b>' || chr(10) || 'Total ' || cn_private.rp(pt.total) || ' (' || pt.n || ' nota)'
       || chr(10) || 'Lewat jatuh tempo <b>' || cn_private.rp(pt.lewat) || '</b> (' || pt.nl || ' nota)';
  with inv as (
    select upper(coalesce(p.data->>'pelanggan_nama','-')) toko, upper(coalesce(p.data->>'sales','-')) sl, nullif(p.data->>'jatuh_tempo','')::date jt,
           cn_private.num(p.data->>'dus')*cn_private.num(p.data->>'harga')-cn_private.num(p.data->>'diskon')-cn_private.num(p.data->>'retur')*cn_private.num(p.data->>'harga')
             - coalesce((select sum(cn_private.num(b.data->>'nominal')) from public.pembayaran b where b.data->>'ref' = p.data->>'no'),0) sisa
      from public.penjualan p where p.data->>'jenis' = 'Kredit')
  select string_agg('• ' || cn_private.h(toko) || ' (' || cn_private.h(sl) || ') — ' || cn_private.rp(sisa) || ', ' || hari || ' hr', chr(10) order by sisa desc) into baris
    from (select toko, sl, sum(sisa) sisa, max(hari_ini - jt) hari from inv where sisa > 0 and jt < hari_ini group by toko, sl order by sum(sisa) desc limit 5) x;
  if baris is not null then t := t || chr(10) || 'Terbesar lewat tempo:' || chr(10) || baris; end if;

  -- stok teoritis hari ini
  select stok0
       + coalesce((select sum(cn_private.num(data->>'aktual')-cn_private.num(data->>'reject')) from public.produksi where data->>'tanggal' >= s0),0)
       - coalesce((select sum(cn_private.num(data->>'dus')-cn_private.num(data->>'retur')+cn_private.num(data->>'bonus')) from public.penjualan where data->>'tanggal' >= s0),0)
       + coalesce((select sum(case when data->>'arah'='Masuk' then 1 else -1 end * cn_private.num(data->>'qty')) from public.mutasi where data->>'tanggal' >= s0),0)
    into stok;
  t := t || chr(10) || chr(10) || '<b>📦 Stok barang jadi</b>' || chr(10) || cn_private.angka(stok) || ' dus (menurut catatan, hari ini)';

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
    t := t || chr(10) || chr(10) || '<b>⚠️ Perlu dicek</b>' || chr(10) || case when cek = '' then 'Tidak ada temuan. 👍' else cek end;
  end;

  if url is not null then t := t || chr(10) || chr(10) || 'Detail: ' || url; end if;
  return left(t, 4000);
end $$;

create or replace function public.cn_pratinjau_laporan(p_akhir date default null) returns text
language plpgsql stable security definer set search_path = public as $$
begin perform cn_private.wajib_owner(); return cn_private.isi_laporan(p_akhir); end $$;

create or replace function cn_private.kirim_telegram(p_teks text, p_jenis text) returns bigint
language plpgsql volatile security definer set search_path = public as $$
declare r cn_private.bot; rid bigint;
begin
  select * into r from cn_private.bot where id = 1;
  if coalesce(r.token,'') = '' or coalesce(r.chat_id,'') = '' then raise exception 'Token bot / chat ID Telegram belum diisi'; end if;
  select net.http_post(
           url := 'https://api.telegram.org/bot' || r.token || '/sendMessage',
           body := jsonb_build_object('chat_id', r.chat_id, 'text', p_teks, 'parse_mode', 'HTML', 'disable_web_page_preview', true),
           headers := '{"Content-Type":"application/json"}'::jsonb) into rid;
  insert into cn_private.kirim_log(request_id, jenis) values (rid, p_jenis);
  return rid;
end $$;

-- Dipanggil jadwal otomatis (Senin pagi) atau tombol "Kirim laporan uji" di aplikasi
create or replace function public.cn_kirim_laporan(p_akhir date default null) returns bigint
language plpgsql volatile security definer set search_path = public as $$
declare r cn_private.bot;
begin
  perform cn_private.wajib_owner();
  select * into r from cn_private.bot where id = 1;
  if session_user in ('postgres','supabase_admin') and auth.uid() is null and not r.aktif then return null; end if;  -- jadwal dimatikan
  return cn_private.kirim_telegram(cn_private.isi_laporan(p_akhir), 'laporan');
end $$;

-- ---------- hak panggil fungsi: hanya pengguna login (fungsi sendiri mengecek owner) --
do $$
declare f text;
begin
  foreach f in array array['cn_daftar_pengguna()','cn_buat_pengguna(text,text,text,text)','cn_reset_password(uuid,text)',
    'cn_atur_pengguna(uuid,text,text,boolean)','cn_daftar_cadangan()','cn_buat_cadangan_sekarang()',
    'cn_atur_telegram(text,text,text,boolean)','cn_status_telegram()','cn_pratinjau_laporan(date)','cn_kirim_laporan(date)'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- ---------- jadwal otomatis (waktu server = UTC; WITA = UTC+8) --------------
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname in ('cn-cadangan','cn-laporan');
  perform cron.schedule('cn-cadangan', '0 22 * * 0', 'select cn_private.buat_cadangan()');   -- Senin 06.00 WITA
  perform cron.schedule('cn-laporan',  '0 23 * * 0', 'select public.cn_kirim_laporan()');    -- Senin 07.00 WITA
end $$;

-- cadangan pertama langsung dibuat sekarang
select cn_private.buat_cadangan() as baris_dicadangkan;
