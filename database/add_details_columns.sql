-- Add new columns to game_stats table
ALTER TABLE public.game_stats 
ADD COLUMN IF NOT EXISTS players_range TEXT,
ADD COLUMN IF NOT EXISTS category TEXT;
