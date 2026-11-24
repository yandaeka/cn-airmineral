create table public.transfer_bri (id text primary key, data jsonb not null, pengaju uuid not null);
alter table public.transfer_bri enable row level security;
revoke all on public.transfer_bri from anon, authenticated;
grant select on public.transfer_bri to authenticated;
create policy transfer_bri_baca on public.transfer_bri for select to authenticated
using (pengaju=auth.uid() or public.my_role() in ('owner','manager'));
alter publication supabase_realtime add table public.transfer_bri;
create index transfer_bri_invoice on public.transfer_bri ((data->>'ref'));
create unique index transfer_bri_unik_mutasi on public.transfer_bri ((data->>'mutasi')) where data->>'status'='Disetujui';

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('bukti-bri','bukti-bri',false,10485760,array['application/pdf','image/jpeg']);
create policy bukti_bri_upload on storage.objects for insert to authenticated with check (
bucket_id='bukti-bri' and public.my_role() in ('sales','owner','manager') and (storage.foldername(name))[1]=auth.uid()::text);
create policy bukti_bri_baca on storage.objects for select to authenticated using (
bucket_id='bukti-bri' and (public.my_role() in ('owner','manager') or (storage.foldername(name))[1]=auth.uid()::text));

create function public.cn_ajukan_bri(p_id text,p_ref text,p_tanggal date,p_nominal bigint,p_bukti text)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); nama text; inv jsonb;
begin
  if u is null or coalesce(public.my_role(),'') not in ('sales','owner','manager') then
    raise exception 'Akun tidak berhak mengajukan transfer BRI.';
  end if;
  if p_id is null or p_ref is null or p_nominal is null or p_nominal<=0 or p_tanggal is null or p_tanggal>(now() at time zone 'Asia/Makassar')::date then
    raise exception 'Lengkapi invoice, tanggal dan nominal transfer yang valid.';
  end if;
  if p_bukti is null or split_part(p_bukti,'/',1)<>u::text or not exists(select 1 from storage.objects where bucket_id='bukti-bri' and name=p_bukti) then
    raise exception 'Bukti transfer wajib diunggah.';
  end if;
  select data into inv from public.penjualan where data->>'no'=p_ref;
  if not found then raise exception 'Invoice belum tersimpan. Sinkronkan lalu coba kembali.'; end if;
  select p.nama into nama from public.profiles p where p.id=u;
  insert into public.transfer_bri(id,pengaju,data) values(p_id,u,jsonb_build_object(
    'ref',p_ref,'tanggal',p_tanggal,'nominal',p_nominal,'bukti_foto',p_bukti,
    'sales_invoice',inv->>'sales','penginput',nama,'pembayar',coalesce(nullif(inv->>'pelanggan_nama',''),'Tunai umum'),
    'status','Menunggu verifikasi','diajukan_pada',now()))
  on conflict(id) do nothing;
end $$;

create function public.cn_verifikasi_bri(p_id text,p_setuju boolean,p_catatan text)
returns void language plpgsql security definer set search_path='' as $$
declare a jsonb; inv jsonb; nama text; mutasi text; sisa numeric; n numeric;
begin
  if coalesce(public.my_role(),'') not in ('owner','manager') then raise exception 'Akun tidak berhak memverifikasi.'; end if;
  if p_setuju is null or nullif(btrim(p_catatan),'') is null then raise exception 'Isi referensi mutasi atau alasan penolakan.'; end if;
  select data into a from public.transfer_bri where id=p_id for update;
  if not found or a->>'status'<>'Menunggu verifikasi' then raise exception 'Pengajuan sudah diproses atau tidak ditemukan.'; end if;
  select p.nama into nama from public.profiles p where p.id=auth.uid();
  if p_setuju then
    mutasi:=upper(regexp_replace(p_catatan,'[^a-zA-Z0-9]','','g'));
    if mutasi='' then raise exception 'Isi referensi mutasi BRI yang valid.'; end if;
    select data into inv from public.penjualan where data->>'no'=a->>'ref' for update;
    if not found then raise exception 'Invoice sudah tidak tersedia.'; end if;
    select coalesce(sum((data->>'nominal')::numeric),0) into n from public.pembayaran where data->>'ref'=a->>'ref';
    sisa:=(coalesce(nullif(inv->>'dus','')::numeric,0)-coalesce(nullif(inv->>'retur','')::numeric,0))*coalesce(nullif(inv->>'harga','')::numeric,0)-coalesce(nullif(inv->>'diskon','')::numeric,0)-n;
    if (a->>'nominal')::numeric>sisa then raise exception 'Nominal melebihi sisa tagihan (%).',greatest(sisa,0); end if;
    update public.transfer_bri set data=a||jsonb_build_object('status','Disetujui','mutasi',mutasi,'catatan_verifikasi',btrim(p_catatan),'verifikator',nama,'diproses_pada',now()) where id=p_id;
    insert into public.pembayaran(id,data) values('bri-'||p_id,jsonb_build_object(
      'tanggal',a->>'tanggal','jenis',case when inv->>'jenis'='Tunai' then 'Penjualan tunai' else 'Penagihan piutang' end,
      'pembayar',a->>'pembayar','metode','Transfer','akun','Bank BRI','nominal',a->'nominal',
      'ref',a->>'ref','catatan','Mutasi BRI '||btrim(p_catatan),'dibuat_oleh',a->>'penginput',
      'sales_invoice',inv->>'sales','verifikator',nama,'bri_id',p_id));
  else
    update public.transfer_bri set data=a||jsonb_build_object('status','Ditolak','catatan_verifikasi',btrim(p_catatan),'verifikator',nama,'diproses_pada',now()) where id=p_id;
  end if;
exception when unique_violation then raise exception 'Referensi mutasi BRI sudah pernah dikonfirmasi.';
end $$;

revoke all on function public.cn_ajukan_bri(text,text,date,bigint,text) from public,anon,authenticated;
revoke all on function public.cn_verifikasi_bri(text,boolean,text) from public,anon,authenticated;
grant execute on function public.cn_ajukan_bri(text,text,date,bigint,text) to authenticated;
grant execute on function public.cn_verifikasi_bri(text,boolean,text) to authenticated;

create policy pembayaran_bri_insert on public.pembayaran as restrictive for insert to authenticated with check (
  not (coalesce(data->>'akun','')='Bank BRI' and coalesce(data->>'metode','')='Transfer') and not (data ? 'bri_id'));
create policy pembayaran_bri_update on public.pembayaran as restrictive for update to authenticated using (not (data ? 'bri_id')) with check (
  not (coalesce(data->>'akun','')='Bank BRI' and coalesce(data->>'metode','')='Transfer') and not (data ? 'bri_id'));
create policy pembayaran_bri_delete on public.pembayaran as restrictive for delete to authenticated using (not (data ? 'bri_id'));
