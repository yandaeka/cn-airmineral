import { createClient } from 'npm:@supabase/supabase-js@2';

// Dipanggil Midtrans (HTTP Notification). Deploy dengan --no-verify-jwt.
// Verifikasi dilakukan dengan bertanya langsung ke Midtrans (Status API), bukan lewat tanda tangan.

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('ok');
  const b: any = await req.json();
  const orderId = String(b.order_id ?? '');
  if (!orderId) return new Response('ok');

  const key = Deno.env.get('MIDTRANS_SERVER_KEY')!;
  const env = Deno.env.get('MIDTRANS_ENV') ?? 'sandbox';
  const base = env === 'production' ? 'https://api.midtrans.com' : 'https://api.sandbox.midtrans.com';

  // tanya status ke Midtrans memakai kunci server kita
  const r = await fetch(`${base}/v2/${encodeURIComponent(orderId)}/status`, {
    headers: { 'Accept': 'application/json', 'Authorization': 'Basic ' + btoa(key + ':') },
  });
  const st: any = await r.json().catch(() => ({}));
  console.log('STATUS_API', 'http=' + r.status, 'order_id=' + orderId, 'transaction_status=' + st.transaction_status);
  if (r.status !== 200) {
    // 401 = kunci salah; 404 = order belum ada. Balas 500 supaya Midtrans mencoba lagi nanti.
    return new Response(JSON.stringify({ pesan: 'status api gagal', http: r.status, order_id: orderId }), { status: 500, headers: { 'Content-Type': 'application/json' } });
  }

  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  let { data: ord } = await sb.from('midtrans_order').select('*').eq('order_id', orderId).single();
  if (!ord) {
    // cadangan: cari invoice dari bagian depan order_id (nomor invoice tanpa tanda '-')
    const pref = orderId.split('-')[0];
    const { data: pj0 } = await sb.from('penjualan').select('data');
    const cocok: any = (pj0 ?? []).map((x: any) => x.data ?? {}).find((d: any) => String(d.no ?? '').replace(/[^a-zA-Z0-9]/g, '').slice(0, 30) === pref);
    if (cocok) ord = { order_id: orderId, no: cocok.no, status: 'pending' } as any;
  }
  console.log('LOG_ORD', 'ditemukan=' + (ord ? 'ya' : 'tidak'), 'status=' + (ord?.status ?? '-'), 'orderId=' + orderId);
  if (!ord) return new Response('ok');

  const ts = st.transaction_status;
  const lunas = ts === 'settlement' || (ts === 'capture' && st.fraud_status === 'accept');
  if (!lunas) {
    if (['expire', 'cancel', 'deny'].includes(ts)) {
      await sb.from('midtrans_order').update({ status: ts }).eq('order_id', orderId);
    }
    return new Response('ok');
  }
  if (ord.status === 'paid') return new Response('ok'); // sudah dicatat

  const tanggal = new Date(Date.now() + 7 * 3600e3).toISOString().slice(0, 10); // tanggal WIB
  const gross = Math.round(Number(st.gross_amount));

  // biaya Midtrans (atur lewat secret)
  const tipe = String(st.payment_type || '');
  const persen = Number(Deno.env.get('FEE_QRIS_PERSEN') ?? '0.7');
  const tetap = Number(Deno.env.get('FEE_TRANSFER_TETAP') ?? '4000');
  let fee = 0;
  if (tipe === 'qris') fee = Math.round(gross * persen / 100);
  else if (tipe === 'bank_transfer' || tipe === 'echannel') fee = tetap;

  // jenis penerimaan mengikuti invoice: penjualan tunai atau penagihan piutang
  const { data: pj } = await sb.from('penjualan').select('data');
  const inv: any = (pj ?? []).map((x: any) => x.data ?? {}).find((d: any) => d.no === ord.no);
  const jenis = inv?.jenis === 'Tunai' ? 'Penjualan tunai' : 'Penagihan piutang';

  // penerimaan utuh sesuai tagihan
  const r1: any = await sb.from('pembayaran').upsert({ id: 'mt-' + orderId, data: {
    tanggal, jenis, pembayar: 'Midtrans · ' + ord.no,
    metode: 'Midtrans', akun: 'Midtrans', nominal: gross, ref: ord.no,
    catatan: `Midtrans ${tipe} · ${orderId}`,
  } });
  console.log('LOG_BAYAR', 'error=' + (r1?.error?.message ?? 'tidak ada'), 'nominal=' + gross, 'ref=' + ord.no);
  // biaya Midtrans dicatat otomatis sebagai pengeluaran dari akun Midtrans
  if (fee > 0) {
    await sb.from('pengeluaran').upsert({ id: 'mtfee-' + orderId, data: {
      tanggal, kategori: 'Biaya bank', keterangan: 'Biaya Midtrans ' + ord.no,
      nominal: fee, metode: 'Midtrans', akun: 'Midtrans', bukti: orderId,
      dibuat_oleh: 'Midtrans', dibuat_pada: new Date().toISOString(),
    } });
  }
  const r2: any = await sb.from('midtrans_order').update({ status: 'paid', dibayar: new Date().toISOString() }).eq('order_id', orderId);
  console.log('LOG_UPDATE', 'error=' + (r2?.error?.message ?? 'tidak ada'));
  return new Response('ok');
});
