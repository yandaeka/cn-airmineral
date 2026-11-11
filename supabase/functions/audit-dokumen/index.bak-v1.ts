import { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, AlignmentType, ImageRun, PageBreak, BorderStyle, ShadingType } from 'npm:docx@9.5.1';

const LKS_LOGO_B64 = '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';
const LOGO = Uint8Array.from(atob(LKS_LOGO_B64), c => c.charCodeAt(0));

const BULAN = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
const HARI = ['Minggu','Senin','Selasa','Rabu','Kamis','Jumat','Sabtu'];
const parseTgl = (s) => { const [y, m, d] = String(s).slice(0, 10).split('-').map(Number); return { y, m, d, wd: new Date(Date.UTC(y, m - 1, d)).getUTCDay() }; };
const tglPanjang = (s) => { if (!s) return '…'; const { y, m, d } = parseTgl(s); return `${d} ${BULAN[m - 1]} ${y}`; };
const tglPendek = (s) => { if (!s) return ''; const { y, m, d } = parseTgl(s); return `${d}-${m}-${y}`; };
const hariSaja = (s) => { if (!s) return '…'; return HARI[parseTgl(s).wd]; };

const BD = { style: BorderStyle.SINGLE, size: 6, color: '000000' };
const BRD = { top: BD, bottom: BD, left: BD, right: BD };
const NOB1 = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };
const NOB = { top: NOB1, bottom: NOB1, left: NOB1, right: NOB1 };
const CTR = AlignmentType.CENTER, RGT = AlignmentType.RIGHT;

const cp = (text, o = {}) => new Paragraph({ alignment: o.align, indent: o.indent, spacing: { after: o.after ?? 40, before: o.before ?? 0 },
  children: [new TextRun({ text: String(text ?? ''), font: 'Calibri', size: o.size ?? 20, bold: o.bold, italics: o.italics, color: o.color })] });
const tc = (children, o = {}) => new TableCell({ borders: o.nob ? NOB : BRD, columnSpan: o.span, rowSpan: o.rowSpan,
  shading: o.fill ? { fill: o.fill, type: ShadingType.CLEAR, color: 'auto' } : undefined,
  width: o.w ? { size: o.w, type: WidthType.DXA } : undefined, margins: { top: 60, bottom: 60, left: 100, right: 100 },
  children: Array.isArray(children) ? children : [children] });
const sp = (n = 120) => new Paragraph({ spacing: { after: n }, children: [] });
const pb = () => new Paragraph({ children: [new PageBreak()] });

// Kop resmi CN (sama seperti formulir asli)
const kopFormulir = (docNo, tglEf, judul) => {
  const W = [2000, 4238, 3400];
  return new Table({ width: { size: 9638, type: WidthType.DXA }, columnWidths: W, rows: [
    new TableRow({ children: [
      tc([new Paragraph({ alignment: CTR, spacing: { after: 0 }, children: [new ImageRun({ type: 'png', data: LOGO, transformation: { width: 80, height: 80 } })] })], { w: W[0], rowSpan: 4 }),
      tc([cp('FORMULIR', { bold: true, size: 30, color: '0A6CB0', align: CTR, after: 0 }),
          cp('CV. QQ EKA PUTRA', { bold: true, size: 26, color: 'D2561A', align: CTR, after: 0 }),
          cp('Jl. Sukun No. 1 Palu', { bold: true, size: 18, color: 'D2561A', align: CTR, after: 0 })], { w: W[1], rowSpan: 4 }),
      tc(cp(`No.Dokumen : ${docNo}`, { size: 18, after: 0 }), { w: W[2] }) ] }),
    new TableRow({ children: [tc(cp('No. Revisi : 0', { size: 18, after: 0 }), { w: W[2] })] }),
    new TableRow({ children: [tc(cp('Halaman : 1 dari 1', { size: 18, after: 0 }), { w: W[2] })] }),
    new TableRow({ children: [tc(cp(`Tgl Efektif : ${tglEf}`, { size: 18, after: 0 }), { w: W[2] })] }),
    new TableRow({ children: [tc(cp(judul, { bold: true, size: 24, align: CTR, after: 0 }), { w: 9638, span: 3 })] }),
  ] });
};

// Baris label : nilai tanpa garis (seperti formulir asli)
const kvTbl = (rows, w1 = 2200, w2 = 7438) => new Table({ width: { size: 9638, type: WidthType.DXA }, columnWidths: [w1, w2],
  rows: rows.map(([a, b]) => new TableRow({ children: [tc(cp(a, { size: 22, after: 20 }), { w: w1, nob: true }), tc(cp(b, { size: 22, after: 20 }), { w: w2, nob: true })] })) });

// Tabel bergaris dengan header abu-abu
const pad = (rows, n, cols) => { const out = [...rows]; while (out.length < n) out.push([String(out.length + 1), ...Array(cols - 1).fill('')]); return out; };
const dataTbl = (head, rows, widths, tall = false) => {
  const mk = (vals, isHead) => new TableRow({ tableHeader: isHead, children: vals.map((v, j) =>
    tc(cp(v, { size: 20, bold: isHead, align: isHead ? CTR : undefined, after: tall && !isHead ? 280 : 40 }), { w: widths[j], fill: isHead ? 'D9D9D9' : undefined })) });
  return new Table({ width: { size: 9638, type: WidthType.DXA }, columnWidths: widths, rows: [mk(head, true), ...rows.map(r => mk(r, false))] });
};

const blokTtd = (tgl, jabatan, nama, gap = 900) => [
  cp(`Palu, ${tgl}`, { align: RGT, size: 22, after: 0 }),
  cp(jabatan, { align: RGT, size: 22, after: gap }),
  cp(nama, { align: RGT, size: 22, bold: true, after: 200 }) ];

export function buildDocument(d) {
  const a = d.audit, temuan = d.temuan || [], peserta = d.peserta || [], foto = d.foto || [];
  const nama = (x) => x.nama || '';
  const anggota = (a.anggota || []).join(', ');
  const rt = a.rapat_tutup, rb = a.rapat_buka;
  const sec = [];

  // 1. UNDANGAN RAPAT (FM.7.4-01) + lampiran daftar nama
  sec.push(kopFormulir('FM.7.4-01', '03-03-2025', 'UNDANGAN RAPAT'));
  sec.push(sp(240));
  sec.push(kvTbl([['No.', `: ${a.nomor_undangan || '…'}`], ['Lamp', ': 1 (Satu) Lembar'], ['Hal', ': Rapat Penutupan Audit Internal']]));
  sec.push(sp(240));
  sec.push(cp('Kepada Yth. (Nama Terlampir)', { size: 22, after: 0 }));
  sec.push(cp('di-', { size: 22, after: 0 }));
  sec.push(cp('Tempat', { size: 22, after: 300 }));
  sec.push(cp('Mengharap kehadiran Bapak/Ibu pada pertemuan dalam rangka rapat penutupan audit internal yang akan dilaksanakan pada:', { size: 22, after: 200 }));
  sec.push(kvTbl([['Hari', `: ${hariSaja(rt?.tanggal)}`], ['Tanggal', `: ${tglPanjang(rt?.tanggal)}`], ['Jam', `: ${rt?.jam || '…'}`], ['Tempat', `: ${rt?.tempat || 'Ruang Rapat'}`], ['Agenda', `: ${a.agenda || 'Penutupan audit internal'}`]]));
  sec.push(sp(240));
  sec.push(cp('Atas perkenan dan perhatiannya kami ucapkan terima kasih.', { size: 22, after: 300 }));
  sec.push(...blokTtd(tglPanjang(a.tgl_undangan || a.tanggal), 'Direktur,', a.direktur || 'Eka Putra Idris', 900));
  sec.push(pb());
  sec.push(cp('Lampiran Undangan Rapat:', { size: 22, after: 200 }));
  sec.push(cp('Daftar Nama Yang Diundang', { size: 22, bold: true, align: CTR, after: 200 }));
  sec.push(dataTbl(['No.', 'Nama', 'Jabatan'], pad(peserta.map((x, i) => [String(i + 1), nama(x), x.jabatan || '']), 8, 3), [800, 4300, 4538]));
  sec.push(pb());

  // 2. DAFTAR HADIR (FM.7.4-02): pembukaan & penutupan, lalu notulen
  const daftar = (r, agenda) => [
    kopFormulir('FM.7.4-02', '03-03-2025', 'DAFTAR HADIR'), sp(240),
    kvTbl([['Hari / Tanggal', `: ${r?.tanggal ? hariSaja(r.tanggal) + '/ ' + tglPanjang(r.tanggal) : '…'}`], ['Jam', `: ${r?.jam || '…'}`],
           ['Tempat', `: ${r?.tempat || 'Ruang Rapat'}`], ['Agenda Rapat', `: ${agenda}`]]), sp(240),
    dataTbl(['No.', 'Nama', 'Jabatan', 'Tanda Tangan'], pad(peserta.map((x, i) => [String(i + 1), nama(x), x.jabatan || '', '']), 10, 4), [700, 3300, 2800, 2838], true),
  ];
  sec.push(...daftar(rb, 'Pembukaan dan koordinasi pelaksanaan Audit Internal'));
  sec.push(pb());
  sec.push(...daftar(rt, a.agenda || 'Penutupan Audit Internal'));
  sec.push(pb());
  sec.push(cp('NOTULEN RAPAT', { size: 24, bold: true, align: CTR, after: 200 }));
  (a.notulen || '…').split('\n').forEach(line => sec.push(cp(line || ' ', { size: 22, after: 80 })));
  sec.push(pb());

  // 3. LAPORAN HASIL AUDIT INTERNAL (FM.9.2-04)
  sec.push(kopFormulir('FM.9.2-04', '03-03-2025', 'LAPORAN HASIL AUDIT INTERNAL'));
  sec.push(sp(240));
  sec.push(kvTbl([['Tanggal Audit Internal', `: ${tglPanjang(a.tanggal)}`], ['Ketua Tim', `: ${a.ketua || '…'}`], ['Anggota Tim', `: ${anggota || '…'}`]], 2800, 6838));
  sec.push(sp(240));
  sec.push(dataTbl(['No. LKS', 'Ketidaksesuaian', 'Tindak Perbaikan', 'Bagian / Auditi', 'Tanggal Perbaikan', 'Tanggal Verifikasi'],
    temuan.map((x, i) => [`${i + 1} dari ${temuan.length}`, x.uraian || '', x.tindakan || '', x.bagian || '', tglPendek(x.tgl_perbaikan), tglPendek(x.tgl_verifikasi)]),
    [900, 2938, 2200, 1500, 1050, 1050], true));
  sec.push(sp(240));
  if (a.kesimpulan) sec.push(cp(`Kesimpulan: ${a.kesimpulan}`, { size: 22, after: 200 }));
  sec.push(...blokTtd(tglPanjang(a.tanggal), 'Ketua Tim Audit Internal', a.ketua || '…', 900));
  sec.push(pb());

  // 3b. LAPORAN KETIDAKSESUAIAN (FM.9.2-03), satu halaman per temuan
  const H = 4819, F = 9638;
  const cat = (k, x) => `${k === x ? '[X]' : '[  ]'} ${x}`;
  const lksList = temuan.length ? temuan : [{}];
  lksList.forEach((x, i) => {
    if (i > 0) sec.push(pb());
    sec.push(kopFormulir('FM.9.2-03', '03-03-2025', 'LAPORAN KETIDAKSESUAIAN'));
    sec.push(sp(200));
    sec.push(new Table({ width: { size: 9638, type: WidthType.DXA }, columnWidths: [H, H], rows: [
      new TableRow({ children: [tc(cp(`No. LKS : ${x.no ?? i + 1}`), { w: H }), tc(cp(`Tanggal Audit : ${tglPanjang(a.tanggal)}`), { w: H })] }),
      new TableRow({ children: [tc(cp(`Bagian yang diaudit : ${x.bagian || '…'}`), { w: H }), tc(cp('Dokumen Acuan : SNI ISO 9001:2015'), { w: H })] }),
      new TableRow({ children: [tc([cp('Uraian ketidaksesuaian :'), ...(x.uraian ? [cp(x.uraian, { after: 200 })] : [cp(' '), cp(' '), cp(' ')])], { w: F, span: 2 })] }),
      new TableRow({ children: [tc(cp(`Kategori :   ${cat(x.kategori, 'Mayor')}     ${cat(x.kategori, 'Minor')}     ${cat(x.kategori, 'Observasi')}`), { w: F, span: 2 })] }),
      new TableRow({ children: [tc(cp(`Nama Auditor : ${a.ketua || '…'}`), { w: H }), tc(cp(`Nama Auditi : ${x.auditi || '…'}`), { w: H })] }),
      new TableRow({ children: [tc([cp('Tanda Tangan :'), cp(' '), cp(' ')], { w: H }), tc([cp('Tanda Tangan :'), cp(' '), cp(' ')], { w: H })] }),
      new TableRow({ children: [tc([cp('Tindakan Koreksi / Tindakan Lanjut :'), ...(x.tindakan ? [cp(x.tindakan, { after: 200 })] : [cp(' '), cp(' ')])], { w: F, span: 2 })] }),
      new TableRow({ children: [tc([cp('Verifikasi Tindakan Perbaikan :'), cp(' '), cp(' '), cp(' ')], { w: F, span: 2 })] }),
      new TableRow({ children: [tc(cp('Nama Auditor :'), { w: F, span: 2 })] }),
      new TableRow({ children: [tc([cp('Tanda Tangan:'), cp(' '), cp(' ')], { w: F, span: 2 })] }),
      new TableRow({ children: [tc(cp(`Tanggal verifikasi: ${x.tgl_verifikasi ? tglPanjang(x.tgl_verifikasi) : ''}`), { w: F, span: 2 })] }),
    ] }));
  });
  sec.push(pb());

  // 4. DOKUMENTASI FOTO
  sec.push(cp('DOKUMENTASI KEGIATAN AUDIT INTERNAL', { size: 26, bold: true, align: CTR, after: 240 }));
  const fotoCells = foto.filter(f => f.bytes).map(f => new TableCell({ borders: NOB, width: { size: 50, type: WidthType.PERCENTAGE },
    children: [new Paragraph({ children: [new ImageRun({ type: 'jpg', data: f.bytes, transformation: { width: 300, height: 225 } })] }),
      new Paragraph({ children: [new TextRun({ text: f.keterangan || '', font: 'Calibri', size: 20, italics: true })], spacing: { after: 240 } })] }));
  const pasang = [];
  for (let i = 0; i < fotoCells.length; i += 2) pasang.push(new TableRow({ children: [fotoCells[i], fotoCells[i + 1] || new TableCell({ children: [new Paragraph('')] })] }));
  if (pasang.length) sec.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: pasang }));
  else sec.push(cp('Belum ada foto dokumentasi.', { italics: true }));

  return new Document({
    styles: { default: { document: { run: { font: 'Calibri', size: 22 } } } },
    sections: [{ properties: { page: { margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 } } }, children: sec }],
  });
}
// ===== RAPAT TINJAUAN MANAJEMEN (PK.9.3): FM.7.4-01, FM.7.4-02, FM.7.4-03 =====
const tcLines = (text, w, o = {}) => tc(String(text ?? '').split('\n').map(l => cp(l, { size: 20, after: 40, bold: o.bold })), { w, fill: o.fill });

export function buildRtm(d) {
  const r = d.rtm, peserta = d.peserta || [], foto = d.foto || [], items = r.items || [];
  const nama = (x) => x.nama || '';
  const sec = [];

  // 1. UNDANGAN RAPAT TINJAUAN MANAJEMEN (FM.7.4-01)
  sec.push(kopFormulir('FM.7.4-01', '03-03-2025', 'UNDANGAN RAPAT'));
  sec.push(sp(240));
  sec.push(kvTbl([['No.', `: ${r.nomor_undangan || '…'}`], ['Lamp', ': 1 (Satu) Lembar'], ['Hal', ': Rapat Tinjauan Manajemen SNI ISO 9001:2015']]));
  sec.push(sp(240));
  sec.push(cp('Kepada Yth. (Nama Terlampir)', { size: 22, after: 0 }));
  sec.push(cp('di-', { size: 22, after: 0 }));
  sec.push(cp('Tempat', { size: 22, after: 300 }));
  sec.push(cp('Mengharap kehadiran Bapak/Ibu pada pertemuan dalam rangka Rapat Tinjauan Manajemen SNI ISO 9001:2015 yang akan dilaksanakan pada:', { size: 22, after: 200 }));
  sec.push(kvTbl([['Hari', `: ${hariSaja(r.tanggal)}`], ['Tanggal', `: ${tglPanjang(r.tanggal)}`], ['Jam', `: ${r.jam || '…'}`], ['Tempat', `: ${r.tempat || 'Ruang Rapat'}`], ['Agenda', `: ${r.agenda || 'Rapat Tinjauan Manajemen SNI ISO 9001:2015'}`]]));
  sec.push(sp(240));
  sec.push(cp('Atas perkenan dan perhatiannya kami ucapkan terima kasih.', { size: 22, after: 300 }));
  sec.push(...blokTtd(tglPanjang(r.tgl_undangan || r.tanggal), 'Direktur,', r.direktur || 'Eka Putra Idris', 900));
  sec.push(pb());
  sec.push(cp('Lampiran Undangan Rapat:', { size: 22, after: 200 }));
  sec.push(cp('Daftar Nama Yang Diundang', { size: 22, bold: true, align: CTR, after: 200 }));
  sec.push(dataTbl(['No.', 'Nama', 'Jabatan'], pad(peserta.map((x, i) => [String(i + 1), nama(x), x.jabatan || '']), 8, 3), [800, 4300, 4538]));
  sec.push(pb());

  // 2. DAFTAR HADIR (FM.7.4-02)
  sec.push(kopFormulir('FM.7.4-02', '03-03-2025', 'DAFTAR HADIR'));
  sec.push(sp(240));
  sec.push(kvTbl([['Hari / Tanggal', `: ${r.tanggal ? hariSaja(r.tanggal) + ' / ' + tglPanjang(r.tanggal) : '…'}`], ['Jam', `: ${r.jam || '…'}`], ['Tempat', `: ${r.tempat || 'Ruang Rapat'}`], ['Agenda Rapat', `: ${r.agenda || '…'}`]]));
  sec.push(sp(240));
  sec.push(dataTbl(['No.', 'Nama', 'Jabatan', 'Tanda Tangan'], pad(peserta.map((x, i) => [String(i + 1), nama(x), x.jabatan || '', '']), 12, 4), [700, 3300, 2800, 2838], true));
  sec.push(pb());

  // 3. NOTULEN RAPAT (FM.7.4-03)
  sec.push(kopFormulir('FM.7.4-03', '03-03-2025', 'NOTULEN RAPAT'));
  sec.push(sp(240));
  sec.push(kvTbl([['Hari / Tanggal', `: ${r.tanggal ? hariSaja(r.tanggal) + ' / ' + tglPanjang(r.tanggal) : '…'}`], ['Jam', `: ${r.jam || '…'}`], ['Tempat', `: ${r.tempat || 'Ruang Rapat'}`], ['Agenda Rapat', `: ${r.agenda || '…'}`]]));
  sec.push(sp(200));
  sec.push(cp('Notulen Rapat sebagai berikut:', { size: 22, after: 200 }));
  const W = [700, 3700, 2600, 1500, 1138];
  sec.push(new Table({ width: { size: 9638, type: WidthType.DXA }, columnWidths: W, rows: [
    new TableRow({ tableHeader: true, children: ['No.', 'Agenda (Input) Tinjauan Manajemen', 'Tindak Lanjut', 'Penanggung Jawab', 'Target'].map((h, j) => tc(cp(h, { size: 20, bold: true, align: CTR, after: 0 }), { w: W[j], fill: 'D9D9D9' })) }),
    ...(items.length ? items : [{ agenda: '', tindak: '', pj: '', target: '' }]).map((it, i) => new TableRow({ children: [
      tc(cp(String(i + 1), { size: 20, after: 0, align: CTR }), { w: W[0] }),
      tcLines(it.agenda, W[1]), tcLines(it.tindak, W[2]), tcLines(it.pj, W[3]), tcLines(it.target, W[4]) ] })),
  ] }));
  sec.push(sp(400));
  sec.push(new Table({ width: { size: 9638, type: WidthType.DXA }, columnWidths: [4819, 4819], rows: [
    new TableRow({ children: [
      tc([cp('Disetujui Oleh :', { size: 22, after: 0 }), cp(' ', { after: 700 }), cp(r.direktur || 'Eka Putra Idris', { size: 22, bold: true, after: 0 }), cp('Direktur', { size: 22, after: 0 })], { w: 4819, nob: true }),
      tc([cp(`Palu, ${tglPanjang(r.tanggal)}`, { size: 22, after: 0 }), cp('Dibuat Oleh :', { size: 22, after: 0 }), cp(' ', { after: 700 }), cp(r.notulis || '…', { size: 22, bold: true, after: 0 }), cp('Notulis', { size: 22, after: 0 })], { w: 4819, nob: true }) ] }) ] }));
  sec.push(pb());

  // 4. DOKUMENTASI FOTO
  sec.push(cp('Foto Dokumentasi Kegiatan :', { size: 24, bold: true, align: CTR, after: 240 }));
  const fotoCells = foto.filter(f => f.bytes).map(f => new TableCell({ borders: NOB, width: { size: 50, type: WidthType.PERCENTAGE },
    children: [new Paragraph({ children: [new ImageRun({ type: 'jpg', data: f.bytes, transformation: { width: 300, height: 225 } })] }),
      new Paragraph({ children: [new TextRun({ text: f.keterangan || '', font: 'Calibri', size: 20, italics: true })], spacing: { after: 240 } })] }));
  const pasang = [];
  for (let i = 0; i < fotoCells.length; i += 2) pasang.push(new TableRow({ children: [fotoCells[i], fotoCells[i + 1] || new TableCell({ children: [new Paragraph('')] })] }));
  if (pasang.length) sec.push(new Table({ width: { size: 100, type: WidthType.PERCENTAGE }, rows: pasang }));
  else sec.push(cp('Belum ada foto dokumentasi.', { italics: true }));

  return new Document({
    styles: { default: { document: { run: { font: 'Calibri', size: 22 } } } },
    sections: [{ properties: { page: { margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 } } }, children: sec }],
  });
}


// ===== DOKUMEN SJPH TAHAP 1: surat pernyataan bebas babi & SK tim halal =====
const kopSurat = () => new Table({ width: { size: 9638, type: WidthType.DXA }, columnWidths: [2000, 7638], rows: [
  new TableRow({ children: [
    tc([new Paragraph({ alignment: CTR, spacing: { after: 0 }, children: [new ImageRun({ type: 'png', data: LOGO, transformation: { width: 90, height: 90 } })] })], { w: 2000, nob: true }),
    tc([cp('CV. QQ EKA PUTRA', { bold: true, size: 32, color: 'D2561A', align: CTR, after: 0 }),
        cp('Jl. Sukun No. 1 Palu', { size: 20, align: CTR, after: 0 }),
        cp('Telp. 0821 9229 6123 · CVqqekaputraa@gmail.com', { size: 18, align: CTR, after: 0 })], { w: 7638, nob: true }) ] }) ] });

export function buildHalal(docName, data) {
  const sec = [];
  const tgl = data.tanggal ? tglPanjang(data.tanggal) : '…';
  if (docName === 'sk-tim') {
    sec.push(kopSurat(), sp(240));
    sec.push(cp('SURAT KEPUTUSAN', { size: 26, bold: true, align: CTR, after: 0 }));
    sec.push(cp('PENETAPAN TIM MANAJEMEN HALAL DAN/ATAU PENYELIA HALAL', { size: 24, bold: true, align: CTR, after: 300 }));
    sec.push(cp('Untuk menerapkan Sistem Jaminan Produk Halal dan dalam rangka menjaga konsistensi kehalalan produk, dengan ini ditunjuk Tim Manajemen Halal dan/atau Penyelia Halal sebagai berikut:', { size: 22, after: 200 }));
    const tim = data.tim || [];
    const n = Math.max(tim.length, 4);
    const rows = tim.map((x, i) => [String(i + 1), x.nama || '', x.jabatan || '', x.posisi || '', '']);
    sec.push(dataTbl(['No.', 'Nama', 'Jabatan', 'Posisi di Tim', 'Tanda Tangan'], pad(rows, n, 5), [700, 2800, 2300, 1800, 2038], true));
    sec.push(sp(240));
    sec.push(cp('Tim Manajemen Halal dan/atau Penyelia Halal telah membaca dan memahami Manual SJPH serta akan melaksanakan dengan sungguh-sungguh seluruh kriteria SJPH sebagaimana tertulis dalam manual SJPH ini.', { size: 22, after: 200 }));
    sec.push(cp('Demikian surat penetapan ini dibuat untuk dilaksanakan sebagaimana mestinya.', { size: 22, after: 300 }));
    sec.push(...blokTtd(tgl, 'Direktur,', data.direktur || 'Eka Putra Idris', 900));
  } else {
    sec.push(kopSurat(), sp(360));
    sec.push(cp('SURAT PERNYATAAN', { size: 26, bold: true, align: CTR, after: 360 }));
    sec.push(cp('Yang bertanda tangan di bawah ini:', { size: 22, after: 200 }));
    sec.push(kvTbl([['Nama', `: ${data.direktur || '…'}`], ['Jabatan', ': Pemilik Usaha / Direktur'], ['Perusahaan', ': CV. QQ Eka Putra']]));
    sec.push(sp(240));
    sec.push(cp('Menyatakan bahwa perusahaan kami tidak menggunakan bahan, alat, fasilitas, dan memproduksi produk berupa barang yang mengandung/terkontaminasi babi dan turunannya, najis, dan bahan berbahaya.', { size: 22, bold: true, after: 300 }));
    sec.push(cp('Demikian surat pernyataan ini dibuat dengan sebenar-benarnya untuk dapat digunakan sebagaimana mestinya.', { size: 22, after: 300 }));
    sec.push(...blokTtd(tgl, 'Pemilik Usaha,', data.direktur || 'Eka Putra Idris', 900));
  }
  return new Document({
    styles: { default: { document: { run: { font: 'Calibri', size: 22 } } } },
    sections: [{ properties: { page: { margin: { top: 1134, bottom: 1134, left: 1134, right: 1134 } } }, children: sec }],
  });
}

import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (obj: any, status = 200) => new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json', ...CORS } });

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const auth = req.headers.get('Authorization') ?? '';
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // hanya owner yang boleh
    const sbUser = createClient(url, anon, { global: { headers: { Authorization: auth } } });
    const { data: ud } = await sbUser.auth.getUser();
    if (!ud?.user) return json({ ok: false, error: 'Belum login' }, 401);
    const { data: prof } = await sbUser.from('profiles').select('role').eq('id', ud.user.id).single();
    if (prof?.role !== 'owner') return json({ ok: false, error: 'Hanya owner' }, 403);

    const body = await req.json();
    if (body.jenis === 'halal') {
      const hdoc = buildHalal(body.doc, body.data || {});
      const hbytes = await Packer.toBuffer(hdoc);
      const hnama = body.doc === 'sk-tim' ? 'SK-Tim-Halal' : 'Surat-Pernyataan-Bebas-Babi';
      return new Response(hbytes, { headers: {
        'Content-Type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'Content-Disposition': `attachment; filename="${hnama}.docx"`,
        ...CORS } });
    }
    const id = body.id;
    const jenis = body.jenis === 'rtm' ? 'rtm' : 'audit';
    const sb = createClient(url, service);

    if (jenis === 'rtm') {
      const { data: row, error: e1 } = await sb.from('rtm').select('data').eq('id', id).single();
      if (e1 || !row) return json({ ok: false, error: 'RTM tidak ditemukan' }, 404);
      const rtm = { ...row.data };
      const foto = [];
      for (const f of (rtm.foto || [])) {
        const { data: blob } = await sb.storage.from('foto').download(f.path);
        if (blob) foto.push({ bytes: new Uint8Array(await blob.arrayBuffer()), keterangan: f.keterangan || '' });
      }
      const doc = buildRtm({ rtm, peserta: rtm.peserta || [], foto });
      const bytes = await Packer.toBuffer(doc);
      return new Response(bytes, { headers: {
        'Content-Type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'Content-Disposition': `attachment; filename="Tinjauan-Manajemen-${rtm.tanggal || id}.docx"`,
        ...CORS } });
    }

    const { data: row, error: e1 } = await sb.from('audit').select('data').eq('id', id).single();
    if (e1 || !row) return json({ ok: false, error: 'Audit tidak ditemukan' }, 404);
    const { data: trows } = await sb.from('audit_temuan').select('id,data');
    const { data: frows } = await sb.from('audit_foto').select('id,data');

    const audit = row.data;
    const temuan = (trows ?? []).map((r: any) => ({ id: r.id, ...r.data })).filter((x: any) => x.audit_id === id)
      .sort((a: any, b: any) => (a.no ?? 0) - (b.no ?? 0));
    const fotos = (frows ?? []).map((r: any) => ({ id: r.id, ...r.data })).filter((x: any) => x.audit_id === id);
    const foto = [];
    for (const f of fotos) {
      const { data: blob } = await sb.storage.from('foto').download(f.path);
      if (blob) foto.push({ bytes: new Uint8Array(await blob.arrayBuffer()), keterangan: f.keterangan || '' });
    }

    const doc = buildDocument({ audit, temuan, peserta: audit.peserta || [], foto });
    const bytes = await Packer.toBuffer(doc);
    return new Response(bytes, { headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'Content-Disposition': `attachment; filename="Laporan-Audit-Internal-${audit.tanggal || id}.docx"`,
      ...CORS } });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
