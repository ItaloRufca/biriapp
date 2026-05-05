begin;

alter table public.games
  add column if not exists alt_name text,
  add column if not exists players_text text,
  add column if not exists best_player_count int,
  add column if not exists primary_category text,
  add column if not exists primary_category_display text,
  add column if not exists subtitle text,
  add column if not exists pagat_url text;

create table if not exists public.game_external_links (
  game_id uuid primary key references public.games(id) on delete cascade,
  bgg_url text,
  ludopedia_url text,
  rules_url text,
  pagat_url text,
  player_aid_image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.game_content (
  game_id uuid primary key references public.games(id) on delete cascade,
  birideck_markdown text,
  birideck_display text,
  bd_adaptacao text,
  bd_informacao text,
  bd_player_aid text,
  magana_notes text,
  resumo_vaza text,
  com_resumo text,
  resumo_outros text,
  resumo_climbing text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.legacy_import_raw (
  game_id uuid primary key references public.games(id) on delete cascade,
  conta_notas text,
  dummy1 text,
  dummy2 text,
  dummy3 text,
  dummy4 text,
  dummy5 text,
  dummy6 text,
  dummy7 text,
  dummy8 text,
  dummy9 text,
  dummy10 text,
  media text,
  emoji_media text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_games_primary_category on public.games(primary_category);
create index if not exists idx_games_best_player_count on public.games(best_player_count);

-- updated_at triggers
 drop trigger if exists trg_game_external_links_updated on public.game_external_links;
create trigger trg_game_external_links_updated
before update on public.game_external_links
for each row execute function public.set_updated_at();

 drop trigger if exists trg_game_content_updated on public.game_content;
create trigger trg_game_content_updated
before update on public.game_content
for each row execute function public.set_updated_at();

 drop trigger if exists trg_legacy_import_raw_updated on public.legacy_import_raw;
create trigger trg_legacy_import_raw_updated
before update on public.legacy_import_raw
for each row execute function public.set_updated_at();

-- RLS
alter table public.game_external_links enable row level security;
alter table public.game_content enable row level security;
alter table public.legacy_import_raw enable row level security;

 drop policy if exists game_external_links_select_all on public.game_external_links;
create policy game_external_links_select_all
on public.game_external_links for select using (true);

 drop policy if exists game_external_links_admin_write on public.game_external_links;
create policy game_external_links_admin_write
on public.game_external_links for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

 drop policy if exists game_content_select_all on public.game_content;
create policy game_content_select_all
on public.game_content for select using (true);

 drop policy if exists game_content_admin_write on public.game_content;
create policy game_content_admin_write
on public.game_content for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

 drop policy if exists legacy_import_raw_admin_only on public.legacy_import_raw;
create policy legacy_import_raw_admin_only
on public.legacy_import_raw for all
using (public.is_admin(auth.uid()))
with check (public.is_admin(auth.uid()));

commit;
