# Go-Keep: MVP Spesifikasi

Klon **Google Keep** (aplikasi catatan). Nama aplikasi: **Go-Keep**.
UI/UX dan alur navigasi harus semirip mungkin dengan Google Keep asli: Material Design, kartu catatan berwarna, grid masonry, FAB tambah catatan, navigation drawer.

## 1. Tech Stack dan Struktur Proyek (wajib, jangan diganti)

- Frontend: Flutter (Dart). Kode ada di `lib/`. Root proyek Flutter adalah `go_keep/`.
- Backend: Node.js + Express, folder `go_keep_api/`
- Database: MySQL via XAMPP (host `localhost`, port `3306`, user `root`, tanpa password, database `gokeep`)
- Paket backend: express, mysql2, bcryptjs, jsonwebtoken, cors, dotenv, express-validator, nodemon (dev)
- Paket Flutter (sudah terpasang di `pubspec.yaml`): provider, dio, flutter_secure_storage, flutter_staggered_grid_view, intl
- Base URL API dari emulator Android: `http://10.0.2.2:3000/api`
- Trafik HTTP lokal sudah diizinkan lewat `usesCleartextTraffic` di AndroidManifest. Jangan diubah.

```
go_keep/                  ← root Git
├─ lib/                   ← kode Flutter
├─ android/ ios/ test/ pubspec.yaml ...
├─ go_keep_api/           ← backend Express
├─ database/schema.sql    ← skema + seed MySQL
├─ docs/MVP.md
└─ README.md
```

## 2. Aturan untuk Agen

- Kerjakan HANYA fase yang diminta pada prompt. Jangan lompat fase.
- Fase 1–3 hanya mengubah `go_keep_api/` dan `database/`. Fase 4–6 hanya mengubah `lib/` (dan `pubspec.yaml` bila perlu). Jangan menyentuh folder di luar cakupan fase.
- Gunakan query berparameter (prepared statement). Dilarang menggabungkan string SQL dari input.
- Password di-hash dengan bcrypt. Jangan simpan password plaintext.
- Setiap endpoint notes dan labels WAJIB memfilter berdasarkan `user_id` dari JWT. Catatan milik user lain tidak boleh bisa dibaca, diubah, atau dihapus.
- Konfigurasi sensitif (kredensial DB, JWT secret) dibaca dari `.env`. Jangan di-hardcode.
- Struktur backend: `routes/`, `controllers/`, `middleware/`, `config/`.
- Struktur `lib/`: `models/`, `services/`, `providers/`, `screens/`, `widgets/`.
- State management: **Provider**. HTTP client: **dio**. Jangan tambah paket baru atau ganti pendekatan tanpa menjelaskan alasannya.
- Beri komentar singkat di bagian penting (alur auth, query utama, provider) agar mudah dijelaskan di video presentasi.
- Setelah tiap fase selesai, tulis cara menjalankan dan cara mengujinya.

## 3. Skema Database (`database/schema.sql`)

Charset `utf8mb4`, engine InnoDB, semua foreign key dengan `ON DELETE CASCADE` kecuali dinyatakan lain.

- `users`: id (PK, AI), name, email (UNIQUE), password_hash, created_at
- `notes`: id (PK, AI), user_id (FK), title, content (TEXT), type ENUM('text','checklist') default 'text', color VARCHAR(20) default 'default', is_pinned BOOL default 0, is_archived BOOL default 0, deleted_at DATETIME NULL, created_at, updated_at
- `checklist_items`: id (PK, AI), note_id (FK), text, is_checked BOOL default 0, position INT
- `labels`: id (PK, AI), user_id (FK), name, UNIQUE (user_id, name)
- `note_labels`: note_id (FK), label_id (FK), PRIMARY KEY (note_id, label_id)

Sertakan `CREATE DATABASE IF NOT EXISTS gokeep` di awal dan data seed contoh (satu user demo, beberapa catatan berbagai warna, satu checklist, dua label).

Status catatan ditentukan dari kolom: **aktif** = `is_archived = 0` dan `deleted_at IS NULL`; **arsip** = `is_archived = 1` dan `deleted_at IS NULL`; **sampah** = `deleted_at IS NOT NULL`.

## 4. Endpoint API (prefix `/api`)

**Auth**

- POST `/auth/register`: body name, email, password; validasi email dan panjang password minimal 6
- POST `/auth/login`: return `{ token, user }`
- GET `/auth/me`: butuh JWT

**Notes** (semua butuh JWT)

- GET `/notes?status=active|archived|trash&q=&label_id=`: pinned di atas, lalu urut `updated_at` desc; `q` mencari di judul dan isi; response menyertakan checklist items dan labels
- POST `/notes`: body title, content, type, color, checklist_items (opsional), label_ids (opsional)
- GET `/notes/:id`
- PUT `/notes/:id`: ubah judul, isi, warna, checklist items, dan label sekaligus
- PATCH `/notes/:id/pin`, `/notes/:id/archive`: toggle
- PATCH `/notes/:id/trash`: set `deleted_at`
- PATCH `/notes/:id/restore`: kosongkan `deleted_at`
- DELETE `/notes/:id`: hapus permanen, hanya boleh jika sudah di sampah
- DELETE `/notes/trash/empty`: hapus permanen semua catatan di sampah milik user

**Labels** (semua butuh JWT)

- GET `/labels`, POST `/labels`, PUT `/labels/:id`, DELETE `/labels/:id`
- POST `/notes/:id/labels/:labelId`, DELETE `/notes/:id/labels/:labelId`

Format error konsisten: `{ "message": "..." }` dengan status HTTP yang tepat (400 validasi, 401 tidak terautentikasi, 403 atau 404 bukan milik user, 409 duplikat, 500 server).

## 5. Fitur Flutter

1. **Splash, Login, Register.** Token disimpan di secure storage dan dipakai untuk auto-login. Interceptor dio menambahkan header Authorization; jika 401, kembali ke Login.
2. **Home.** Daftar catatan grid masonry dan list (toggle), bagian "Disematkan" dan "Lainnya", search bar di atas, FAB tambah catatan.
3. **Editor catatan.** Judul, isi, mode checklist (tambah, centang, hapus item), pilihan warna, pin, arsip, hapus, kelola label catatan. Perubahan tersimpan otomatis saat keluar dari editor.
4. **Navigation drawer.** Catatan, Arsip, Sampah, daftar Label (tap untuk filter), Kelola Label, Logout.
5. **Layar Arsip dan Sampah.** Sampah punya aksi restore, hapus permanen, dan kosongkan sampah dengan dialog konfirmasi.
6. **Pencarian** berdasarkan judul dan isi, serta filter per label.
7. **Loading, error, dan empty state** di setiap layar, dengan pesan dalam Bahasa Indonesia.
8. Kartu catatan menampilkan judul, cuplikan isi atau item checklist, chip label, dan warna latar sesuai warna catatan.

## 6. Fase Pengerjaan

- **Fase 1.** Backend fondasi: struktur folder `go_keep_api/`, koneksi MySQL (pool), `database/schema.sql`, auth (register, login, me), middleware JWT, error handler global.
- **Fase 2.** Backend notes: CRUD, pin, arsip, sampah, restore, hapus permanen, kosongkan sampah, pencarian, checklist items.
- **Fase 3.** Backend labels dan relasi `note_labels`, filter notes berdasarkan label.
- **Fase 4.** Flutter fondasi di `lib/`: struktur folder, theme (terang), API service (dio + interceptor token), model, auth provider, layar Splash, Login, Register.
- **Fase 5.** Flutter Home: grid masonry, pin, search, toggle grid/list, editor catatan lengkap termasuk checklist dan warna.
- **Fase 6.** Flutter drawer, Arsip, Sampah, Label, polishing UI agar mirip Keep, empty/error state.

## 7. Kriteria Selesai per Fase

- Fase 1–3: semua endpoint bisa diuji dengan Postman/Thunder Client; request tanpa token ditolak; user A tidak bisa mengakses data user B.
- Fase 4–6: alur lengkap berjalan di emulator Android tanpa crash: daftar, login, buat catatan teks dan checklist, pin, arsip, hapus, restore, label, cari.

## 8. Di Luar Cakupan (jangan dikerjakan)

Reminder dan notifikasi, kolaborasi, lampiran gambar atau audio, sinkronisasi offline, drag-and-drop reorder, dark mode.
