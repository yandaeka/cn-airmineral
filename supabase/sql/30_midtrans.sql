-- =====================================================================
-- CN Air Mineral — Midtrans: catatan tautan pembayaran per invoice
-- Jalankan sekali di Supabase → SQL Editor → Run. Aman dijalankan ulang.
-- Tabel ini hanya diakses Edge Function (service role), tidak lewat aplikasi.
-- =====================================================================
create table if not exists public.midtrans_order (
  order_id    text primary key,
  no          text not null,
  nominal     numeric not null,
  payment_url text,
  status      text not null default 'pending',
  dibuat      timestamptz not null default now(),
  dibayar     timestamptz
);
alter table public.midtrans_order enable row level security;
revoke all on public.midtrans_order from anon, authenticated;

select 'Midtrans siap' as hasil;
