-- =====================================================================
-- DHARMA MUSIK DIGITAL — SETUP DATABASE & STORAGE (Supabase)
-- Aman: hanya membuat objek baru berprefix dharma_. TIDAK menyentuh
-- tabel aplikasi lain di proyek ini (tahfidz_*, rab_*).
-- Jalankan SEKALI di Supabase Dashboard -> SQL Editor -> paste -> Run.
-- =====================================================================

create extension if not exists "pgcrypto";

-- ============================ TABEL LAGU ============================
create table if not exists public.dharma_songs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  artist text not null default '',
  album text not null default '',
  genre text not null default '',
  release_year int,
  description text not null default '',
  lyrics text not null default '',
  audio_path text,            -- path objek di bucket dharma-audio (privat)
  cover_path text,            -- path objek di bucket dharma-covers (publik, nama UUID)
  duration_seconds numeric not null default 0,
  visibility text not null default 'private' check (visibility in ('private','public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists dharma_songs_owner_idx on public.dharma_songs(owner_id);
create index if not exists dharma_songs_title_idx on public.dharma_songs(title);
create index if not exists dharma_songs_artist_idx on public.dharma_songs(artist);

-- ========================== TABEL PLAYLIST ==========================
create table if not exists public.dharma_playlists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text not null default '',
  cover_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists dharma_playlists_owner_idx on public.dharma_playlists(owner_id);

-- ======================= TABEL ISI PLAYLIST =========================
create table if not exists public.dharma_playlist_tracks (
  id uuid primary key default gen_random_uuid(),
  playlist_id uuid not null references public.dharma_playlists(id) on delete cascade,
  song_id uuid not null references public.dharma_songs(id) on delete cascade,
  position int not null default 0,
  added_at timestamptz not null default now(),
  unique (playlist_id, song_id)
);
create index if not exists dharma_pt_playlist_idx on public.dharma_playlist_tracks(playlist_id, position);

-- ================== TRIGGER updated_at OTOMATIS =====================
create or replace function public.dharma_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists dharma_songs_touch on public.dharma_songs;
create trigger dharma_songs_touch before update on public.dharma_songs
  for each row execute function public.dharma_touch_updated_at();

drop trigger if exists dharma_playlists_touch on public.dharma_playlists;
create trigger dharma_playlists_touch before update on public.dharma_playlists
  for each row execute function public.dharma_touch_updated_at();

-- ==================== ROW LEVEL SECURITY (RLS) =====================
-- Hanya pemilik (auth.uid() = owner_id) yang boleh CRUD. Anonim: TOLAK SEMUA.
alter table public.dharma_songs enable row level security;
alter table public.dharma_playlists enable row level security;
alter table public.dharma_playlist_tracks enable row level security;

drop policy if exists dharma_songs_owner_all on public.dharma_songs;
create policy dharma_songs_owner_all on public.dharma_songs
  for all to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists dharma_playlists_owner_all on public.dharma_playlists;
create policy dharma_playlists_owner_all on public.dharma_playlists
  for all to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists dharma_pt_owner_all on public.dharma_playlist_tracks;
create policy dharma_pt_owner_all on public.dharma_playlist_tracks
  for all to authenticated
  using (exists (
    select 1 from public.dharma_playlists p
    where p.id = playlist_id and p.owner_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.dharma_playlists p
    where p.id = playlist_id and p.owner_id = (select auth.uid())
  ));

-- ========================= STORAGE BUCKETS =========================
-- dharma-audio  : PRIVAT  (RLS ketat, streaming via akses terautentikasi)
-- dharma-covers : PUBLIK  (nama file UUID tak terduga, metadata tetap privat di DB)
-- dharma-site   : PUBLIK  (hosting file situs)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dharma-audio', 'dharma-audio', false, 52428800,
        'audio/mpeg','audio/mp3','audio/wav','audio/x-wav','audio/wave','audio/ogg','audio/webm','audio/flac','audio/x-flac','audio/aac','audio/mp4','audio/x-m4a','audio/m4a')
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dharma-covers', 'dharma-covers', true, 10485760,
        'image/jpeg','image/png','image/webp')
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('dharma-site', 'dharma-site', true)
on conflict (id) do nothing;

-- =================== KEBIJAKAN STORAGE (RLS) ======================
-- File disimpan di folder {uid}/... -> hanya pemilik folder yang boleh tulis/baca/hapus.
drop policy if exists dharma_audio_owner_write on storage.objects;
create policy dharma_audio_owner_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'dharma-audio'
    and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists dharma_audio_owner_read on storage.objects;
create policy dharma_audio_owner_read on storage.objects
  for select to authenticated
  using (bucket_id = 'dharma-audio'
    and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists dharma_audio_owner_delete on storage.objects;
create policy dharma_audio_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'dharma-audio'
    and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists dharma_covers_owner_write on storage.objects;
create policy dharma_covers_owner_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'dharma-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists dharma_covers_owner_delete on storage.objects;
create policy dharma_covers_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'dharma-covers'
    and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists dharma_site_public_read on storage.objects;
create policy dharma_site_public_read on storage.objects
  for select using (bucket_id = 'dharma-site');

-- SELESAI. Cek: harusnya muncul 3 tabel dharma_* dan 3 bucket dharma-*.
