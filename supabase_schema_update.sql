-- Run this script in your Supabase SQL Editor to update the profiles table

-- Add username and avatar_url columns to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Create a function to handle new user creation (optional but recommended)
-- This ensures that when a new user signs up, a profile is created
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, avatar_url)
  values (new.id, new.raw_user_meta_data->>'username', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

-- Trigger the function every time a user is created
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Helper to backfill existing profiles from auth.users (if needed)
-- UPDATE public.profiles p
-- SET 
--   username = u.raw_user_meta_data->>'username',
--   avatar_url = u.raw_user_meta_data->>'avatar_url'
-- FROM auth.users u
-- WHERE p.id = u.id;
