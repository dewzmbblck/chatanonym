-- ============================================================
-- Dead Drop — skema database Supabase
-- Jalankan seluruh isi file ini di: Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1) Tabel profil (nama samaran per pengguna anonim)
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nickname text not null check (char_length(nickname) between 2 and 24),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- (Aman dijalankan ulang) hapus policy versi lama jika sebelumnya pernah
-- memakai skema yang mengizinkan "select semua profil".
drop policy if exists "profiles_select_all_authenticated" on public.profiles;
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_upsert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

-- PENTING: seseorang HANYA boleh membaca profilnya SENDIRI lewat query biasa.
-- Tidak ada "select semua profil" untuk siapa pun — ini yang mencegah orang
-- menarik daftar lengkap ID + nama samaran semua pengguna lewat API.
create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

create policy "profiles_upsert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Untuk membuka chat pribadi, pengguna perlu tahu apakah sebuah ID valid dan
-- nama samarannya — tapi TANPA bisa men-scan/list semua profil. Fungsi ini
-- adalah satu-satunya jalan resmi: ia hanya mengembalikan hasil kalau Anda
-- memasukkan ID PERSIS yang benar (1 baris, bukan daftar). Menebak UUID acak
-- secara praktis mustahil (peluangnya 1 : 2^122), jadi ini setara dengan
-- "hanya bisa dibuka jika sudah tahu ID-nya".
create or replace function public.get_nickname_by_id(target_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select nickname from public.profiles where id = target_id;
$$;

-- Batasi siapa yang boleh memanggil fungsi ini, lalu izinkan hanya untuk
-- pengguna yang sudah login (termasuk sesi anonim).
revoke all on function public.get_nickname_by_id(uuid) from public;
grant execute on function public.get_nickname_by_id(uuid) to authenticated;


-- 2) Tabel pesan (chat publik + chat pribadi)
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users (id) on delete cascade,
  sender_name text not null,
  receiver_id uuid references auth.users (id) on delete cascade, -- NULL = pesan publik
  content text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now()
);

create index if not exists messages_public_idx
  on public.messages (created_at)
  where receiver_id is null;

create index if not exists messages_receiver_idx
  on public.messages (receiver_id, created_at);

create index if not exists messages_sender_idx
  on public.messages (sender_id, created_at);

alter table public.messages enable row level security;

drop policy if exists "messages_select_visible" on public.messages;
drop policy if exists "messages_insert_own" on public.messages;

-- Boleh dibaca jika: pesan publik, ATAU Anda pengirimnya, ATAU Anda penerimanya.
-- Baris ini tidak bisa "di-scan" untuk menemukan siapa saja lawan bicara orang
-- lain — hanya percakapan yang melibatkan diri Anda sendiri yang cocok.
create policy "messages_select_visible"
  on public.messages for select
  to authenticated
  using (
    receiver_id is null
    or sender_id = auth.uid()
    or receiver_id = auth.uid()
  );

-- Hanya boleh mengirim pesan atas nama diri sendiri.
create policy "messages_insert_own"
  on public.messages for insert
  to authenticated
  with check (sender_id = auth.uid());

-- Tidak ada policy update/delete → pesan tidak bisa diubah/dihapus siapa pun.


-- 3) Aktifkan Realtime untuk tabel messages
-- (Bisa juga dilakukan lewat Dashboard → Database → Replication → toggle tabel "messages")
alter publication supabase_realtime add table public.messages;


-- 4) Izinkan Anonymous Sign-In
-- Ini TIDAK bisa diaktifkan lewat SQL — lakukan manual satu kali di:
-- Dashboard → Authentication → Sign In / Providers → Anonymous Sign-Ins → Enable
-- (Lihat README.md bagian "Setup Supabase" langkah 3.)
