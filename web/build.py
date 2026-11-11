#!/usr/bin/env python3
"""Bangun versi web (Supabase + PWA) dari sumber artifact si-cn-air-mineral.html."""
import shutil, os, sys, json
os.chdir(os.path.dirname(os.path.abspath(__file__)))
SRC = 'si-cn-air-mineral.html'
OUT = 'dist'
os.makedirs(OUT, exist_ok=True)
s = open(SRC, encoding='utf-8').read()
layer = open('sb-layer.js', encoding='utf-8').read()

def R(a, b, n=1):
    global s
    c = s.count(a)
    if c != n:
        sys.exit(f'PATCH GAGAL ({c}x): {a[:90]!r}')
    s = s.replace(a, b)

# --- dokumen lengkap + PWA head
R('<title>SI CN Air Mineral</title>\n<meta name="claude:viewport-fit-sides" content="cover">',
  '''<!doctype html>
<html lang="id"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>CN Air Mineral</title>
<meta name="description" content="Sistem Informasi CV QQ Eka Putra — penjualan, piutang, stok, produksi, kas.">
<meta name="theme-color" content="#0d2f38">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" href="icon-192.png" type="image/png">
<link rel="apple-touch-icon" href="icon-192.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="CN Air">''')
R('<div id="app">', '</head><body>\n<div id="app">')
R('<script>\n/* =========================================================\n   SI CN AIR MINERAL',
  '<script>/*SUPABASE_INLINE*/</script>\n<script>\n/* =========================================================\n   SI CN AIR MINERAL')

# --- inti penyimpanan
R('async function init(){\n  render();\n  let db=null;', 'async function initArtifact(){\n  render();\n  let db=null;')
R('const ready=()=>MODE!==\'loading\'&&COLS.every(c=>loaded.has(c));',
  "const ready=()=>MODE!=='loading'&&MODE!=='login'&&COLS.every(c=>loaded.has(c));\n" + layer)
R("  const id=rec.id||genId(); const data={...rec}; delete data.id;\n  if(DB){",
  """  const id=rec.id||genId(); const data={...rec}; delete data.id;
  if(SB){ const op={t:'put',col,id,data:clean(data)}; applyLocal(op); bump(); saveCache();
    if(Q.length||!navigator.onLine){Q.push(op);saveQ();flushQ();return id}
    try{await sendOp(op)}catch(e){ if(isNetErr(e)){Q.push(op);saveQ();bump();return id} reloadCol(col); throw e }
    return id; }
  if(DB){""")
R("async function del(col,id){ if(DB)",
  """async function del(col,id){ if(SB){ const op={t:'del',col,id}; applyLocal(op); bump(); saveCache();
    if(Q.length||!navigator.onLine){Q.push(op);saveQ();flushQ();return}
    try{await sendOp(op)}catch(e){ if(isNetErr(e)){Q.push(op);saveQ();bump();return} reloadCol(col); throw e } return; }
  if(DB)""")
R("function errMsg(e){const c=e?.code;", "function errMsg(e){if(SB)return 'Gagal menyimpan: '+sbErr(e);const c=e?.code;")
R("const no=edit?rec.no:nextInvoice(v.tanggal);", "const no=edit?rec.no:await nomorNota(v.tanggal);")
R("async function nomorNota(t){\n", "async function nomorNota(t){ if(!SB)return nextInvoice(t);\n")

# --- login, keluar, status
R("function loginView(){\n", "function loginView(){ if(SB)return loginViewSB();\n")
R("  if(ME&&ME.role==='owner'&&ready()){const od=ownerDoc();", "  if(!SB&&ME&&ME.role==='owner'&&ready()){const od=ownerDoc();")
R("  if(!ME||!NAV[ME.role]){app.innerHTML=loginView();return}",
  "  if(SB&&MODE==='loading'){app.innerHTML='<div class=\"loading\">Memuat…</div>';return}\n  if(!ME||!NAV[ME.role]){app.innerHTML=loginView();return}")
R("document.addEventListener('submit',e=>{if(e.target.id==='oform')",
  "document.addEventListener('submit',e=>{if(e.target.id==='lform'){e.preventDefault();sbLogin(e.target);return}if(e.target.id==='oform')")
R("  logout:()=>{", "  logout:()=>{if(SB){sbLogout();return}")
R("gantiPw:()=>formGantiPw(),", "gantiPw:()=>SB?formGantiPwSB():formGantiPw(), backup:()=>backupXlsx(), syncNow:()=>{flushQ();loadAll()},")
R("""<button class="linkbtn" data-act="logout">Ganti</button></div><div class="mode"><span class="dot ${MODE==='cloud'?'':'loc'}"></span>${MODE==='cloud'?'Data bersama (cloud)':MODE==='local'?'Mode lokal — hanya di perangkat ini':'Menghubungkan…'}</div>""",
  """${SB?'<button class="linkbtn" data-act="gantiPwSaya" style="margin-right:10px">Kata sandi</button>':''}<button class="linkbtn" data-act="logout">${SB?'Keluar':'Ganti'}</button></div><div class="mode">${SB?`<span class="dot ${SBSTATE==='online'&&navigator.onLine?'':'loc'}"></span>${SBSTATE==='online'&&navigator.onLine?'Online · tersinkron':'Offline · data di HP ini'}${Q.length?` · <button class="linkbtn" data-act="syncNow">${Q.length} menunggu kirim</button>`:''}`:`<span class="dot ${MODE==='cloud'?'':'loc'}"></span>${MODE==='cloud'?'Data bersama (cloud)':MODE==='local'?'Mode lokal — hanya di perangkat ini':'Menghubungkan…'}`}</div>""")
R('data-act="gantiPw">Ganti password owner</button>', 'data-act="gantiPw">${SB?\'Ganti password saya\':\'Ganti password owner\'}</button>')

R("</div></div></aside>`;", '</div>${SB?`<div class="mode" style="opacity:.65">Versi ${APP_VER}</div>`:\'\'}</div></aside>`;')
# --- unduhan & halaman data
R("const dl=window.claude&&window.claude.use?await window.claude.use('downloads'):null;",
  "const dl=SB?{save:({filename,data})=>saveFile(filename,data)}:(window.claude&&window.claude.use?await window.claude.use('downloads'):null);")
R("'Data tersimpan di cloud dan dipakai bersama oleh semua orang yang membuka aplikasi ini dengan akses Contributor.'",
  "(SB?'Data tersimpan di database Supabase milik CV QQ Eka Putra. Setiap pengguna masuk dengan akunnya sendiri; hak akses dijaga di server.':'Data tersimpan di cloud dan dipakai bersama oleh semua orang yang membuka aplikasi ini dengan akses Contributor.')")
R('<div class="acts" style="margin-top:14px"><button class="btn danger" data-act="hapusSemua">',
  '<div class="acts" style="margin-top:14px">${SB?\'<button class="btn pri" data-act="backup">Unduh cadangan (Excel)</button>\':\'\'}<button class="btn danger" data-act="hapusSemua">')

# --- service worker
R("init();\n</script>", open('sb-late.js',encoding='utf-8').read()+"""
init();
if('serviceWorker' in navigator&&location.protocol==='https:'){window.addEventListener('load',()=>navigator.serviceWorker.register('sw.js').catch(()=>{}))}
</script>
</body></html>""")

lib = open('build/node_modules/@supabase/supabase-js/dist/umd/supabase.js', encoding='utf-8').read()
s = s.replace('/*SUPABASE_INLINE*/', lib, 1)
open(f'{OUT}/index.html', 'w', encoding='utf-8').write(s)
if os.path.exists(f'{OUT}/supabase.js'): os.remove(f'{OUT}/supabase.js')
for f in ['sw.js', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', '_headers', 'qr.js', 'jsqr.js']:
    p = f'static/{f}'
    if os.path.exists(p): shutil.copy(p, f'{OUT}/{f}')
FD = f'{OUT}/face'
os.makedirs(f'{FD}/model', exist_ok=True)
shutil.copy('vendor/face-api-1.7.15/dist/face-api.js', f'{FD}/face-api.js')
for m in ['tiny_face_detector_model','face_landmark_68_model','face_recognition_model']:
    for ext in ['-weights_manifest.json','.bin']:
        shutil.copy(f'vendor/face-api-1.7.15/model/{m}{ext}', f'{FD}/model/{m}{ext}')
print('OK', len(s))
