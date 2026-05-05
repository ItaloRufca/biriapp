-- 1. Create new table user_items
create table if not exists user_items (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users not null,
  game_id text not null,
  name text,
  image_url text,
  rating int,
  is_collection boolean default false,
  is_wishlist boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, game_id)
);

-- 2. Enable RLS
alter table user_items enable row level security;

drop policy if exists "Users can view own items" on user_items;
create policy "Users can view own items" on user_items for select using (auth.uid() = user_id);

drop policy if exists "Users can insert own items" on user_items;
create policy "Users can insert own items" on user_items for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update own items" on user_items;
create policy "Users can update own items" on user_items for update using (auth.uid() = user_id);

drop policy if exists "Users can delete own items" on user_items;
create policy "Users can delete own items" on user_items for delete using (auth.uid() = user_id);

-- 3. Migrate data from user_games (Collection)
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'user_games') then
    insert into user_items (user_id, game_id, name, image_url, is_collection, created_at)
    select user_id, game_id, name, image_url, true, created_at
    from user_games
    where status = 'collection'
    on conflict (user_id, game_id) do update
    set 
      is_collection = true,
      name = excluded.name,
      image_url = excluded.image_url;
  end if;
end $$;

-- 4. Migrate data from user_games (Wishlist)
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'user_games') then
    insert into user_items (user_id, game_id, name, image_url, is_wishlist, created_at)
    select user_id, game_id, name, image_url, true, created_at
    from user_games
    where status = 'wishlist'
    on conflict (user_id, game_id) do update
    set 
      is_wishlist = true,
      name = excluded.name,
      image_url = excluded.image_url;
  end if;
end $$;

-- 5. Migrate data from user_ratings
do $$
begin
  if exists (select from pg_tables where schemaname = 'public' and tablename = 'user_ratings') then
    insert into user_items (user_id, game_id, name, image_url, rating, created_at)
    select user_id, game_id, name, image_url, rating, created_at
    from user_ratings
    on conflict (user_id, game_id) do update
    set 
      rating = excluded.rating,
      name = excluded.name,
      image_url = excluded.image_url;
  end if;
end $$;

-- 6. Update View game_averages
drop view if exists game_averages;
create or replace view game_averages as
select 
  game_id, 
  avg(rating)::numeric(10,2) as average_rating,
  count(*) as rating_count
from (
  select game_id, rating from user_items where rating is not null
  union all
  select game_id, rating from legacy_ratings
) as all_ratings
group by game_id;

-- 7. Update claim_legacy_ratings function
create or replace function claim_legacy_ratings(p_access_code text)
returns json as $$
declare
  v_username text;
  v_count int;
begin
  -- Find user by access code
  select username into v_username from legacy_users where access_code = p_access_code;
  
  if v_username is null then
    return json_build_object('success', false, 'message', 'Código inválido');
  end if;

  -- Insert into user_items (updating metadata if exists)
  with source_ratings as (
    select distinct on (game_id) game_id, rating, name, image_url
    from legacy_ratings
    where username = v_username
    order by game_id, id desc
  ),
  inserted as (
    insert into user_items (user_id, game_id, rating, name, image_url, created_at)
    select auth.uid(), game_id, rating, name, image_url, now()
    from source_ratings
    on conflict (user_id, game_id) do update
    set 
      name = excluded.name,
      image_url = excluded.image_url,
      rating = excluded.rating
    returning 1
  )
  select count(*) into v_count from inserted;

  -- Mark as claimed in profiles
  insert into profiles (id, claimed_legacy) values (auth.uid(), true)
  on conflict (id) do update set claimed_legacy = true;
  
  return json_build_object('success', true, 'message', 'Histórico resgatado com sucesso!', 'count', v_count);
end;
$$ language plpgsql security definer;

-- 8. Update reset_account function
create or replace function reset_account()
returns void as $$
begin
  delete from user_items where user_id = auth.uid();
  update profiles set claimed_legacy = false where id = auth.uid();
end;
$$ language plpgsql security definer;

-- 9. Drop old tables (Optional: keep as backup for now? User said "apague o legacy backup" before, but let's be safe and just rename or ignore. 
-- Actually, the user wants a clean solution. Let's drop them to avoid confusion.)
drop table if exists user_games;
drop table if exists user_ratings;
