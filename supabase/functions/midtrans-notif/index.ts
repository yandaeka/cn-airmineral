import { createClient } from 'npm:@supabase/supabase-js@2';

// Dipanggil Midtrans (HTTP Notification). Deploy dengan --no-verify-jwt.
const hex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((x) => x.toString(16).padStart(2, '0')).join('');

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return new Response('ok');
  const b: any = await req.json();
  const key = Deno.env.get('MIDTRANS_SERVER_KEY')!;

  // verifikasi signature: SHA512(order_id + status_code + gross_amount + server_key)
  const expected = hex(await crypto.subtle.digest('SHA-512',
    new TextEncoder().encode(String(b.order_id) + String(b.status_code) + String(b.gross_amount) + key)));
  if (expected !== b.signature_key) return new Response(JSON.stringify({ pesan: 'signature salah', expected_prefix: expected.slice(0, 12), diterima_prefix: String(b.signature_key).slice(0, 12), order_id: b.order_id, status_code: b.status_code, gross_amount: b.gross_amount, panjang_key: key.length }), { status: 403, headers: { 'Content-Type': 'application/json' } });

  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: ord } = await sb.from('midtrans_order').select('*').eq('order_id', b.order_id).single();
  if (!ord) return new Response('ok');

  const lunas = b.transaction_status === 'settlement' ||
    (b.transaction_status === 'capture' && b.fraud_status === 'accept');
  if (!lunas) {
    if (['expire', 'cancel', 'deny'].includes(b.transaction_status)) {
      await sb.from('midtrans_order').update({ status: b.transaction_status }).eq('order_id', b.order_id);
    }
    return new Response('ok');
  }
  if (ord.status === 'paid') return new Response('ok'); // sudah dicatat

  const tanggal = new Date(Date.now() + 7 * 3600e3).toISOString().slice(0, 10); // tanggal WIB
  const gross = Math.round(Number(b.gross_amount));

  // biaya Midtrans (sesuaikan dengan kontrak Midtrans; atur lewat secret)
  const tipe = String(b.payment_type || '');
  const persen = Number(Deno.env.get('FEE_QRIS_PERSEN') ?? '0.7');
  const tetap = Number(Deno.env.get('FEE_TRANSFER_TETAP') ?? '4000');
  let fee = 0;
  if (tipe === 'qris') fee = Math.round(gross * persen / 100);
  else if (tipe === 'bank_transfer' || tipe === 'echannel') fee = tetap;

  // jenis penerimaan mengikuti invoice: penjualan tunai atau penagihan piutang
  const { data: pj } = await sb.from('penjualan').select('data');
  const inv: any = (pj ?? []).map((r: any) => r.data ?? {}).find((d: any) => d.no === ord.no);
  const jenis = inv?.jenis === 'Tunai' ? 'Penjualan tunai' : 'Penagihan piutang';

  // penerimaan utuh sesuai tagihan
  await sb.from('pembayaran').upsert({ id: 'mt-' + b.order_id, data: {
    tanggal, jenis, pembayar: 'Midtrans · ' + ord.no,
    metode: 'Midtrans', akun: 'Midtrans', nominal: gross, ref: ord.no,
    catatan: `Midtrans ${tipe} · ${b.order_id}`,
  } });
  // biaya Midtrans dicatat otomatis sebagai pengeluaran dari akun Midtrans
  if (fee > 0) {
    await sb.from('pengeluaran').upsert({ id: 'mtfee-' + b.order_id, data: {
      tanggal, kategori: 'Biaya bank', keterangan: 'Biaya Midtrans ' + ord.no,
      nominal: fee, metode: 'Midtrans', akun: 'Midtrans', bukti: b.order_id,
      dibuat_oleh: 'Midtrans', dibuat_pada: new Date().toISOString(),
    } });
  }
  await sb.from('midtrans_order').update({ status: 'paid', dibayar: new Date().toISOString() }).eq('order_id', b.order_id);
  return new Response('ok');
});
