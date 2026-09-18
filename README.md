# Dead Drop — Ruang Obrolan Anonim

Aplikasi chat anonim berbasis **Vue 3 + Supabase Realtime**:

- Pengguna masuk **tanpa akun** (memakai *anonymous auth* Supabase), lalu memilih **nama samaran** sendiri.
- Ada **satu ruang publik** ("Frekuensi Umum") yang bisa dibaca semua orang yang sedang daring.
- Ada **pesan pribadi ke ID tertentu** — dan **tidak ada daftar "siapa online" atau direktori pengguna sama sekali**. Satu-satunya cara membuka chat pribadi adalah dengan mengetahui persis ID lawan bicara (dibagikan di luar aplikasi, mis. diucapkan langsung atau ditempel di ruang publik). Ini disengaja untuk menjaga anonimitas — pengguna tidak bisa "menjelajahi" siapa saja yang sedang memakai aplikasi.
- Pesan mengalir secara realtime lewat **WebSocket Supabase Realtime** (bukan polling).

---

## 1. Arsitektur singkat

```
┌──────────────┐        WebSocket (Realtime)        ┌──────────────────┐
│   Vue app     │ <────────────────────────────────> │  Supabase project │
│  (Netlify)    │        REST (insert/select)         │  Postgres + Auth   │
└──────────────┘ <────────────────────────────────> └──────────────────┘
```

- **Auth**: `supabase.auth.signInAnonymously()` — setiap pengunjung otomatis mendapat `user.id` unik (UUID) tanpa perlu mendaftar. ID inilah yang dipakai untuk mengenali "siapa mengirim ke siapa", dan ID inilah yang harus dibagikan secara manual (di luar aplikasi) agar orang lain bisa mengajak chat pribadi.
- **Nama samaran**: disimpan di tabel `profiles`, terhubung 1‑1 dengan `auth.users.id`. Nama ini yang terlihat oleh orang lain — bukan UUID.
- **Pesan**: satu tabel `messages`. Baris dengan `receiver_id = NULL` = pesan publik. Baris dengan `receiver_id` terisi = pesan pribadi ke user tersebut.
- **Tidak ada direktori pengguna**: tabel `profiles` hanya bisa dibaca oleh pemiliknya sendiri lewat query biasa (RLS `auth.uid() = id`). Untuk membuka chat dengan ID yang sudah diketahui, aplikasi memanggil fungsi database `get_nickname_by_id(uuid)` yang hanya mengembalikan hasil untuk **satu ID persis** — tidak bisa dipakai untuk men-scan/menampilkan semua pengguna. Menebak ID secara acak secara praktis mustahil (UUID v4, 1 banding 2^122).
- **Keamanan**: **Row Level Security (RLS)** di Postgres memastikan seseorang hanya bisa *membaca* pesan publik + pesan miliknya sendiri (terkirim/diterima), dan hanya bisa *mengirim* pesan atas nama dirinya sendiri. Ini berlaku juga untuk data yang lewat WebSocket.

---

## 2. Prasyarat

- Node.js 18+ dan npm
- Akun gratis di [supabase.com](https://supabase.com)
- Akun gratis di [netlify.com](https://netlify.com)
- (Opsional) Git + akun GitHub, jika ingin deploy otomatis dari repo

---

## 3. Setup Supabase

### 3.1 Buat project

1. Masuk ke [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**.
2. Isi nama project, buat password database (simpan baik-baik), pilih region terdekat (mis. Singapore untuk Indonesia).
3. Tunggu sampai project selesai di-provision (±2 menit).

### 3.2 Jalankan skema database

1. Di sidebar kiri, buka **SQL Editor** → **New query**.
2. Buka file [`supabase/schema.sql`](./supabase/schema.sql) dari proyek ini, salin seluruh isinya, tempel ke editor.
3. Klik **Run**. Ini akan membuat:
   - Tabel `profiles` (nama samaran) dan `messages` (pesan)
   - Semua **RLS policy** yang diperlukan
   - Mengaktifkan **Realtime** untuk tabel `messages`

### 3.3 Aktifkan Anonymous Sign-In

Langkah ini **wajib** dilakukan manual (tidak bisa lewat SQL):

1. Buka **Authentication** → **Sign In / Providers** di sidebar.
2. Cari **Anonymous Sign-Ins**, aktifkan toggle-nya.
3. Simpan.

Tanpa langkah ini, aplikasi akan gagal dengan error `Anonymous sign-ins are disabled`.

### 3.4 (Cek) Realtime aktif untuk tabel `messages`

Skrip SQL di atas sudah menjalankan `alter publication supabase_realtime add table public.messages;`. Untuk memastikan:

1. Buka **Database** → **Replication**.
2. Pastikan tabel `messages` berstatus **ON** di bawah publication `supabase_realtime`.

### 3.5 Ambil kredensial API

1. Buka **Project Settings** (ikon gear) → **API**.
2. Catat dua nilai ini:
   - **Project URL** → jadi `VITE_SUPABASE_URL`
   - **anon public** key → jadi `VITE_SUPABASE_ANON_KEY`

> `anon key` **aman ditaruh di frontend** — dia memang didesain publik. Yang benar-benar melindungi data Anda adalah RLS policy di tabel, bukan kerahasiaan key ini. Jangan pernah memakai `service_role key` di frontend.

---

## 4. Jalankan di lokal

```bash
# 1. Masuk ke folder proyek
cd anon-chat

# 2. Install dependency
npm install

# 3. Buat file .env dari contoh, lalu isi dengan kredensial dari langkah 3.5
cp .env.example .env

# 4. Jalankan dev server
npm run dev
```

Buka `http://localhost:5173`. Untuk menguji chat publik/pribadi, buka aplikasi di **dua tab browser berbeda** (atau satu tab normal + satu tab mode Incognito, supaya sesi anonimnya berbeda), pilih nama samaran berbeda di masing-masing, lalu coba kirim pesan.

---

## 5. Deploy ke Netlify

### Opsi A — lewat Git (disarankan, ada auto-deploy)

1. Push folder proyek ini ke repo GitHub/GitLab/Bitbucket.
2. Di Netlify: **Add new site** → **Import an existing project** → pilih repo Anda.
3. Build settings akan otomatis terbaca dari `netlify.toml`:
   - Build command: `npm run build`
   - Publish directory: `dist`
4. Sebelum klik deploy, buka **Add environment variables** dan tambahkan:
   - `VITE_SUPABASE_URL` = URL project Supabase Anda
   - `VITE_SUPABASE_ANON_KEY` = anon key Anda
5. Klik **Deploy site**.

### Opsi B — drag & drop (tanpa Git)

```bash
npm run build
```

Ini menghasilkan folder `dist/`. **Catatan penting**: karena env variable di-*bake* saat build, untuk metode drag & drop Anda perlu menjalankan `npm run build` di komputer lokal dengan file `.env` sudah terisi (lihat langkah 4), baru drag folder `dist/` ke [app.netlify.com/drop](https://app.netlify.com/drop).

### Setelah deploy

Jika Anda mengubah environment variables di Netlify Dashboard (**Site settings → Environment variables**) setelah deploy pertama, klik **Trigger deploy → Clear cache and deploy site** supaya nilai baru ikut ter-build (variabel `VITE_*` disuntik saat build, bukan saat runtime).

---

## 6. Struktur proyek

```
anon-chat/
├── index.html
├── package.json
├── vite.config.js
├── netlify.toml
├── .env.example
├── supabase/
│   └── schema.sql          ← jalankan ini di Supabase SQL Editor
└── src/
    ├── main.js
    ├── supabase.js          ← inisialisasi client Supabase
    ├── style.css            ← design tokens global
    ├── App.vue              ← auth, presence, subscription realtime
    └── components/
        ├── CoverSheet.vue   ← layar pilih nama samaran
        ├── Sidebar.vue      ← daftar pengguna online + tombol Frekuensi Umum
        └── ChatPanel.vue    ← daftar pesan + kolom kirim
```

---

## 7. Cara kerja fitur pesan pribadi (ketik ID untuk membuka obrolan)

1. Setiap sesi anonim otomatis mendapat `user.id` (UUID) dari Supabase Auth. ID inilah yang ditampilkan di sidebar sebagai **"ID Anda"**, lengkap dengan tombol salin — inilah yang **harus Anda bagikan sendiri secara manual** (chat lain, media sosial, disebut langsung, dll.) supaya seseorang bisa mengajak Anda chat pribadi. Aplikasi tidak pernah menampilkan ID atau nama orang lain kepada siapa pun secara otomatis.
2. Di kolom **"Buka obrolan dengan ID"**, pengguna menempelkan ID tujuan lalu klik **Buka**. Aplikasi akan:
   - Menolak jika formatnya bukan UUID, atau jika itu ID miliknya sendiri.
   - Memanggil fungsi database `get_nickname_by_id(id)` untuk memastikan ID itu benar-benar terdaftar dan mengambil nama samarannya. Fungsi ini **hanya bisa mencocokkan satu ID yang persis sama** — tidak ada cara untuk "menjelajahi" atau menebak-nebak ID pengguna lain lewat fungsi ini.
   - Jika valid, membuka thread percakapan pribadi dengan ID itu — tanpa mensyaratkan orang itu sedang online saat itu juga.
3. Begitu login, setiap klien berlangganan (subscribe) ke dua channel Realtime:
   - `public-room-changes` — dengan filter `receiver_id=is.null`, menerima semua pesan publik baru.
   - `private-inbox-{myId}` — dengan filter `receiver_id=eq.{myId}`, menerima pesan pribadi baru **yang ditujukan ke dirinya, dari ID mana pun**. Ini juga jalan masuk lain untuk memulai percakapan: kalau seseorang yang sudah tahu ID Anda mengirim pesan duluan, thread-nya otomatis muncul di sidebar Anda beserta nama samarannya — tanpa Anda perlu tahu ID mereka lebih dulu.
4. Saat mengirim pesan privat, aplikasi meng-*insert* satu baris ke tabel `messages` dengan `receiver_id` = UUID lawan bicara. Baris ini otomatis "dipancarkan" oleh Supabase Realtime hanya ke klien yang subscribe dan lolos RLS — yaitu si pengirim (lewat hasil insert langsung) dan si penerima (lewat channel inbox-nya).
5. Daftar **"Percakapan Pribadi"** di sidebar **hanya berisi thread yang benar-benar sudah pernah Anda buka atau terima** — bukan daftar semua pengguna. Tidak ada indikator "online" karena aplikasi ini sengaja tidak melacak/menyiarkan kehadiran siapa pun.

---

## 8. Troubleshooting

| Gejala | Kemungkinan penyebab |
|---|---|
| `Anonymous sign-ins are disabled` | Langkah 3.3 belum dilakukan. |
| Pesan tidak muncul realtime, harus refresh | Tabel `messages` belum di-enable di Database → Replication (langkah 3.4). |
| Error 401/permission denied saat kirim pesan | RLS policy belum terpasang — jalankan ulang `supabase/schema.sql`. |
| "ID tidak ditemukan" padahal ID-nya benar | Fungsi `get_nickname_by_id` belum ter-*grant* ke role `authenticated`, atau `supabase/schema.sql` belum dijalankan ulang setelah update. Jalankan ulang skrip SQL-nya. |
| Env var tidak terbaca di Netlify | Variabel `VITE_*` disuntik saat *build*, bukan runtime — pastikan sudah di-set sebelum deploy, atau trigger re-deploy setelah menambahkannya. |
| `VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY belum diset` di console | File `.env` belum dibuat (lokal) atau env var belum diisi (Netlify). |

---

## 9. Catatan keamanan & batasan

- **Tidak ada direktori/daftar pengguna sama sekali** — bukan cuma disembunyikan di UI, tapi juga di level database: tabel `profiles` hanya bisa di-`select` oleh pemiliknya sendiri (RLS `auth.uid() = id`), jadi memanggil API Supabase secara langsung pun tidak bisa menarik daftar semua ID/nama. Satu-satunya jalan resmi mencocokkan ID adalah fungsi `get_nickname_by_id`, yang hanya bisa menguji satu ID persis pada satu waktu — bukan pencarian/listing.
- Satu pengecualian yang perlu disadari: setiap baris pesan **publik** membawa `sender_id` mentah (UUID) selain nama samaran. Orang yang cukup teknis bisa membuka DevTools browser dan melihat UUID itu dari respons jaringan, lalu memakainya untuk membuka chat pribadi — meski Anda tidak membagikannya secara sadar. Ini adalah trade-off wajar untuk ruang publik (sama seperti forum mana pun yang menampilkan ID pengirim), tapi kalau Anda ingin benar-benar menutup celah ini, pertimbangkan mengganti alur publik agar hanya mengirim `sender_name` lewat Realtime Broadcast (bukan lewat tabel `messages` langsung) sehingga `sender_id` tidak pernah dikirim ke browser orang lain.
- Karena bersifat anonim dan terbuka, siapa pun bisa membuat sesi baru tanpa verifikasi apa pun — ini **fitur, bukan bug**, tapi berarti tidak ada mekanisme "banned user" bawaan. Jika perlu moderasi, tambahkan tabel `blocked_ids` dan filter di RLS, atau gunakan Supabase Edge Function untuk memfilter kata kasar sebelum insert.
- Panjang pesan dan nama samaran sudah dibatasi lewat `check constraint` di database (bukan cuma di frontend), supaya tidak bisa dilewati.
- Tidak ada rate limiting bawaan di skema ini. Untuk produksi dengan trafik publik, pertimbangkan menambah Supabase Edge Function / database trigger yang membatasi jumlah pesan per `sender_id` per menit.
- Riwayat pesan privat tersimpan permanen di database selama tidak dihapus manual — ini bukan "self-destructing message". Tambahkan cron job (Supabase pg_cron) jika ingin auto-hapus pesan lama.
