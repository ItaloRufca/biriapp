-- Add metadata columns to user_ratings
alter table user_ratings 
add column if not exists name text,
add column if not exists image_url text;

-- Update existing ratings with data from user_games if available (best effort)
update user_ratings ur
set 
  name = ug.name,
  image_url = ug.image_url
from user_games ug
where ur.game_id = ug.game_id
  and ur.user_id = ug.user_id
  and ur.name is null;
