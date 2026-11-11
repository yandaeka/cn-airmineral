-- =====================================================================
-- CN Air Mineral — status laporan harian (log pengiriman)
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- =====================================================================

create table if not exists public.laporan_harian_log (
  id bigserial primary key,
  waktu timestamptz not null default now(),
  tanggal text,
  status text not null,
  pesan text
);
alter table public.laporan_harian_log enable row level security;
-- tanpa policy: hanya service role (Edge Function) yang bisa menulis; baca lewat fungsi di bawah

create or replace function public.cn_status_harian()
returns jsonb language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if public.my_role() is distinct from 'owner' then
    raise exception 'Hanya owner yang dapat melihat status laporan';
  end if;
  select * into r from public.laporan_harian_log order by waktu desc limit 1;
  return jsonb_build_object(
    'jadwal', '20.00 WITA setiap hari',
    'terakhir', case when r.id is null then null
                     else jsonb_build_object('waktu', r.waktu, 'status', r.status, 'pesan', r.pesan, 'tanggal', r.tanggal) end
  );
end $$;

revoke all on function public.cn_status_harian() from public, anon;
grant execute on function public.cn_status_harian() to authenticated;

select 'Status laporan harian siap' as hasil;
