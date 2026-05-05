begin;

-- 1) Ajustes mínimos para suportar legado sem duplicidade
alter table if exists public.legacy_ratings
  add column if not exists is_active boolean not null default true,
  add column if not exists deactivated_at timestamptz;

alter table if exists public.legacy_users
  add column if not exists claimed_by_user_id uuid references auth.users(id),
  add column if not exists claimed_at timestamptz;

create index if not exists idx_legacy_ratings_active_game on public.legacy_ratings(game_id) where is_active = true;
create index if not exists idx_legacy_ratings_active_user on public.legacy_ratings(legacy_user_id) where is_active = true;
create index if not exists idx_ratings_game_created on public.ratings(game_id, created_at);

-- remove funções antigas para evitar erro de assinatura/retorno
drop function if exists public.get_games_ranking(integer, numeric);
drop function if exists public.get_games_ranking(integer, integer);
drop function if exists public.get_games_ranking();
drop function if exists public.get_reviewers_ranking(integer);
drop function if exists public.get_reviewers_ranking();
drop function if exists public.claim_legacy_ratings(text);

-- 2) Função de ranking de jogos com média bayesiana
-- WR = (v/(v+m))*R + (m/(v+m))*C
-- v = quantidade de notas do jogo
-- R = média do jogo
-- C = média global
-- m = mínimo de confiança (default 20)
create or replace function public.get_games_ranking(
  p_days integer default null,
  p_m numeric default 20
)
returns table (
  game_id text,
  name text,
  image_url text,
  min_players integer,
  max_players integer,
  avg_rating numeric,
  rating_count integer,
  weighted_rating numeric,
  rank_position bigint
)
language sql
stable
security definer
set search_path = public
as $$
with current_ratings as (
  select
    r.game_id::text as game_id,
    r.rating::numeric as rating,
    r.created_at as rated_at
  from public.ratings r
  where r.rating between 1 and 5
    and (
      p_days is null
      or r.created_at >= now() - make_interval(days => p_days)
    )
),
legacy_active as (
  select
    lr.game_id::text as game_id,
    lr.rating::numeric as rating,
    lr.rated_at
  from public.legacy_ratings lr
  where lr.is_active = true
    and lr.rating between 1 and 5
    and (
      p_days is null
      or lr.rated_at >= now() - make_interval(days => p_days)
    )
),
all_votes as (
  select game_id, rating, rated_at from current_ratings
  union all
  select game_id, rating, rated_at from legacy_active
),
normalized_votes as (
  select
    coalesce(g.id::text, v.game_id::text) as game_id,
    v.rating
  from all_votes v
  left join public.games g
    on g.id::text = v.game_id::text
    or g.bgg_id = v.game_id::text
),
per_game as (
  select
    v.game_id,
    avg(v.rating) as r_avg,
    count(*)::int as v_count
  from normalized_votes v
  group by v.game_id
),
global_avg as (
  select coalesce(avg(v.rating), 0)::numeric as c_avg
  from normalized_votes v
),
ranked as (
  select
    g.id as game_id,
    g.name,
    g.image_url,
    g.min_players,
    g.max_players,
    coalesce(pg.r_avg, 0)::numeric as avg_rating,
    coalesce(pg.v_count, 0)::int as rating_count,
    (
      (
        coalesce(pg.v_count, 0)::numeric
        / nullif((coalesce(pg.v_count, 0)::numeric + p_m), 0)
      ) * coalesce(pg.r_avg, 0)
      +
      (
        p_m
        / nullif((coalesce(pg.v_count, 0)::numeric + p_m), 0)
      ) * ga.c_avg
    )::numeric as weighted_rating
  from public.games g
  left join per_game pg on pg.game_id = g.id::text
  cross join global_avg ga
  where g.is_active = true
)
select
  r.game_id,
  r.name,
  r.image_url,
  r.min_players,
  r.max_players,
  round(r.avg_rating, 3) as avg_rating,
  r.rating_count,
  round(r.weighted_rating, 3) as weighted_rating,
  row_number() over (
    order by r.weighted_rating desc, r.rating_count desc, r.name asc
  )::bigint as rank_position
from ranked r
order by rank_position;
$$;

-- 3) Ranking de avaliadores
-- Critério: quantidade de jogos avaliados
-- Desempate: quem avaliou primeiro
create or replace function public.get_reviewers_ranking(
  p_days integer default null
)
returns table (
  username text,
  rated_count integer,
  first_rating_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
with counts as (
  select
    r.user_id,
    count(*)::int as rated_count,
    min(r.first_rated_at) as first_rating_at
  from public.ratings r
  where r.rating between 1 and 5
    and (
      p_days is null
      or r.created_at >= now() - make_interval(days => p_days)
    )
  group by r.user_id
)
select
  coalesce(p.username, 'Jogador') as username,
  c.rated_count,
  c.first_rating_at
from counts c
left join public.profiles p on p.id = c.user_id
order by c.rated_count desc, c.first_rating_at asc, coalesce(p.username, 'Jogador') asc;
$$;

-- 4) Claim legado sem dupla contagem
-- Regra:
-- - copia notas legadas para ratings apenas onde o usuário ainda não avaliou
-- - após claim, inativa legacy_ratings do dono do código
create or replace function public.claim_legacy_ratings(
  p_access_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_legacy_user_id uuid;
  v_inserted int := 0;
  v_deactivated int := 0;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'message', 'Usuário não autenticado.');
  end if;

  if p_access_code is null or btrim(p_access_code) = '' then
    return jsonb_build_object('success', false, 'message', 'Código inválido.');
  end if;

  select lu.id
    into v_legacy_user_id
  from public.legacy_users lu
  where lu.access_code = btrim(p_access_code)
  limit 1;

  if v_legacy_user_id is null then
    return jsonb_build_object('success', false, 'message', 'Código não encontrado.');
  end if;

  -- evita claim repetido para mesmo código
  if exists (
    select 1
    from public.legacy_users lu
    where lu.id = v_legacy_user_id
      and lu.claimed_by_user_id is not null
  ) then
    return jsonb_build_object('success', false, 'message', 'Esse legado já foi resgatado.');
  end if;

  insert into public.ratings (user_id, game_id, rating)
  select
    v_uid,
    lr.game_id,
    lr.rating
  from public.legacy_ratings lr
  where lr.legacy_user_id = v_legacy_user_id
    and lr.is_active = true
    and lr.rating between 1 and 5
    and not exists (
      select 1
      from public.ratings r
      where r.user_id = v_uid
        and r.game_id = lr.game_id
    );

  get diagnostics v_inserted = row_count;

  update public.legacy_ratings
  set is_active = false,
      deactivated_at = now()
  where legacy_user_id = v_legacy_user_id
    and is_active = true;

  get diagnostics v_deactivated = row_count;

  update public.legacy_users
  set claimed_by_user_id = v_uid,
      claimed_at = now()
  where id = v_legacy_user_id;

  update public.profiles
  set claimed_legacy = true,
      updated_at = now()
  where id = v_uid;

  return jsonb_build_object(
    'success', true,
    'message', 'Legado resgatado com sucesso.',
    'inserted_ratings', v_inserted,
    'deactivated_legacy_ratings', v_deactivated
  );
end;
$$;

-- Segurança básica
revoke all on function public.claim_legacy_ratings(text) from public;
grant execute on function public.claim_legacy_ratings(text) to authenticated;
grant execute on function public.get_games_ranking(integer, numeric) to anon, authenticated;
grant execute on function public.get_reviewers_ranking(integer) to anon, authenticated;

commit;
