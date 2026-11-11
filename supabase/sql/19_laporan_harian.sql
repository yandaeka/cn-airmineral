-- =====================================================================
-- CN Air Mineral — Laporan harian otomatis ke Telegram (jam 20.00 WITA)
-- Jalankan di Supabase → SQL Editor SETELAH Edge Function "laporan-harian" dibuat
-- dan secret TELEGRAM_BOT_TOKEN serta TELEGRAM_CHAT_ID sudah diisi.
-- Ganti <ANON_KEY> dengan anon key dari Project Settings → API.
-- =====================================================================
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- jam 20.00 WITA = 12.00 UTC
select cron.unschedule('laporan-harian-wita')
 where exists (select 1 from cron.job where jobname = 'laporan-harian-wita');

select cron.schedule('laporan-harian-wita', '0 12 * * *', $$
  select net.http_post(
    url := 'https://sybpqbtptschsszpmenv.supabase.co/functions/v1/laporan-harian',
    headers := jsonb_build_object('Authorization', 'Bearer <ANON_KEY>', 'Content-Type', 'application/json'),
    body := '{}'::jsonb);
$$);

select 'Laporan harian terjadwal jam 20.00 WITA' as hasil;
