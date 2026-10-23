# Dharma Musik Digital — Dharma Labs Digital

Perpustakaan musik original pribadi. Frontend SPA murni (tanpa dependensi,
tanpa build step) + Supabase (Postgres, Storage, Auth, RLS).

## Isi
- site/ ................ aplikasi produksi (index.html + css/ + js/)
  - js/config.js ...... berisi URL proyek + ANON KEY (diisi saat deploy)
  - TIDAK ADA service-role key di frontend (aturan keamanan mutlak)
- preview.html ........ versi mandiri satu file dengan mode uji (?selftest=1
  memakai data simulasi untuk demonstrasi UI; bukan bagian produksi)
- dharma_musik_setup.sql  skema DB + RLS + bucket storage (jalankan di SQL Editor)
- build_preview.py .... generator preview (reproducible)

## Fitur
Upload audio+cover dengan progres & validasi, CRUD lengkap, playlist
(urut posisi, hapus playlist tidak menghapus lagu), pencarian/filter/urut,
mini-player global (play/pause, next/prev, seek, volume, shuffle, repeat
one/all, queue, bertahan saat navigasi), audio privat via akses
terautentikasi (blob) + cache, RLS ketat pemilik-saja, mobile-first.

## Deploy (setelah SQL dijalankan & anon key diisi di config.js)
Opsi A: upload isi site/ ke bucket publik dharma-site (Supabase Storage).
Opsi B: hosting statis apa pun (Netlify/Vercel/GitHub Pages).

## Keamanan
Anonim tidak bisa membaca metadata (RLS) maupun audio (bucket privat +
kebijakan folder {uid}/). Cover publik dengan nama file UUID tak terduga.
