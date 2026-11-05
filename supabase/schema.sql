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

-- Tidak ada policy update/delete → pesan tidak bisa diubah/dihapus lewat query biasa.
-- Penghapusan hanya bisa lewat fungsi delete_messages() di bagian 5 (butuh secret).


-- 3) Aktifkan Realtime untuk tabel messages
-- (Bisa juga dilakukan lewat Dashboard → Database → Replication → toggle tabel "messages")
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then
  null; -- sudah terdaftar, abaikan
end $$;


-- 4) Izinkan Anonymous Sign-In
-- Ini TIDAK bisa diaktifkan lewat SQL — lakukan manual satu kali di:
-- Dashboard → Authentication → Sign In / Providers → Anonymous Sign-Ins → Enable
-- (Lihat README.md bagian "Setup Supabase" langkah 3.)


-- 5) Hapus pesan (1 atau banyak) — dilindungi secret word / password
-- ------------------------------------------------------------
-- Cara kerja:
--  * Secret disimpan sebagai HASH (bcrypt) di tabel admin_secret. Tabel ini
--    memakai RLS tanpa policy sama sekali → tidak bisa dibaca lewat API.
--  * Klien memanggil rpc('delete_messages', { message_ids, secret }).
--    Pengecekan password dilakukan DI DATABASE, bukan di browser.
--  * Percobaan salah dibatasi: 5x salah berturut-turut → terkunci 15 menit
--    (per sesi anonim).
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.admin_secret (
  id boolean primary key default true check (id), -- memaksa hanya 1 baris
  secret_hash text not null,
  updated_at timestamptz not null default now()
);
alter table public.admin_secret enable row level security;
-- (sengaja TANPA policy → tidak ada yang bisa select/insert lewat API)
revoke all on public.admin_secret from anon, authenticated;

create table if not exists public.delete_attempts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  fail_count int not null default 0,
  locked_until timestamptz
);
alter table public.delete_attempts enable row level security;
revoke all on public.delete_attempts from anon, authenticated;

-- Dipakai SEKALI oleh Anda (di SQL Editor) untuk mengatur / mengganti secret.
-- Tidak bisa dipanggil dari aplikasi (hak akses dicabut di bawah).
create or replace function public.set_delete_secret(new_secret text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if new_secret is null or char_length(new_secret) < 6 then
    raise exception 'Secret minimal 6 karakter';
  end if;
  insert into public.admin_secret (id, secret_hash, updated_at)
  values (true, crypt(new_secret, gen_salt('bf', 10)), now())
  on conflict (id) do update
    set secret_hash = excluded.secret_hash, updated_at = now();
end;
$$;
revoke all on function public.set_delete_secret(text) from public, anon, authenticated;

create or replace function public.delete_messages(message_ids uuid[], secret text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid     uuid := auth.uid();
  v_hash    text;
  v_att     public.delete_attempts%rowtype;
  v_fails   int;
  v_deleted uuid[];
  c_max_fails constant int := 5;
  c_lock      constant interval := interval '15 minutes';
  c_max_batch constant int := 200;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;

  if message_ids is null or cardinality(message_ids) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'empty');
  end if;
  if cardinality(message_ids) > c_max_batch then
    return jsonb_build_object('ok', false, 'reason', 'too_many', 'max', c_max_batch);
  end if;

  select secret_hash into v_hash from public.admin_secret where id;
  if v_hash is null then
    return jsonb_build_object('ok', false, 'reason', 'secret_not_set');
  end if;

  select * into v_att from public.delete_attempts where user_id = v_uid;
  if found and v_att.locked_until is not null and v_att.locked_until > now() then
    return jsonb_build_object(
      'ok', false, 'reason', 'locked',
      'retry_after_seconds', ceil(extract(epoch from (v_att.locked_until - now())))::int
    );
  end if;

  if secret is null or crypt(secret, v_hash) <> v_hash then
    -- Kunci lama yang sudah kedaluwarsa → hitungan mulai dari 0 lagi.
    if found and v_att.locked_until is not null and v_att.locked_until <= now() then
      v_fails := 1;
    else
      v_fails := coalesce(v_att.fail_count, 0) + 1;
    end if;

    insert into public.delete_attempts (user_id, fail_count, locked_until)
    values (v_uid, v_fails, case when v_fails >= c_max_fails then now() + c_lock end)
    on conflict (user_id) do update
      set fail_count = excluded.fail_count,
          locked_until = excluded.locked_until;

    return jsonb_build_object(
      'ok', false, 'reason', 'wrong_secret',
      'attempts_left', greatest(c_max_fails - v_fails, 0)
    );
  end if;

  -- Secret benar: reset hitungan gagal, lalu hapus.
  delete from public.delete_attempts where user_id = v_uid;

  with d as (
    delete from public.messages where id = any (message_ids) returning id
  )
  select coalesce(array_agg(id), '{}') into v_deleted from d;

  return jsonb_build_object('ok', true, 'deleted', to_jsonb(v_deleted));
end;
$$;

revoke all on function public.delete_messages(uuid[], text) from public, anon;
grant execute on function public.delete_messages(uuid[], text) to authenticated;

-- LANGKAH WAJIB (jalankan SEKALI, ganti dengan secret pilihan Anda):
--   select public.set_delete_secret('GANTI_DENGAN_SECRET_ANDA');
-- Untuk mengganti secret di kemudian hari, jalankan perintah yang sama.
