# CN Air Mineral

- `web/` — aplikasi web (satu file HTML + layer Supabase). Dibangun dengan `python3 build.py` (lihat `netlify.toml`).
- `supabase/functions/` — Edge Functions (audit-dokumen, laporan-harian, midtrans-link, midtrans-notif).
- `supabase/sql/` — skrip SQL. Dijalankan manual di SQL Editor Supabase (tidak otomatis).

## Alur deploy
1. Edit kode, lalu `git push` ke `main`.
2. Netlify membangun dan mendeploy aplikasi web otomatis.
3. GitHub Actions mendeploy Edge Functions otomatis (jika folder `supabase/functions` berubah).

## Secret yang harus dibuat di GitHub (Settings → Secrets and variables → Actions)
- `SUPABASE_ACCESS_TOKEN` — token akses Supabase (dibuat di dashboard Supabase → Account → Access Tokens).
- `SUPABASE_PROJECT_REF` — `sybpqbtptschsszpmenv`.

Secret Midtrans dan lainnya tetap di Supabase → Edge Functions → Secrets, bukan di GitHub.
