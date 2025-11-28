-- 1. Create game_stats table
CREATE TABLE IF NOT EXISTS public.game_stats (
    game_id TEXT PRIMARY KEY,
    name TEXT,
    image_url TEXT,
    average NUMERIC DEFAULT 0,
    count INTEGER DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 2. Populate from legacy_ratings (Plural)
-- We aggregate legacy ratings first
-- We use ON CONFLICT to merge if we run this multiple times
INSERT INTO public.game_stats (game_id, name, image_url, average, count)
SELECT
    game_id,
    MAX(name) as name,
    MAX(image_url) as image_url,
    AVG(rating) as average,
    COUNT(rating) as count
FROM public.legacy_ratings -- Corrected from legacy_rating
WHERE rating IS NOT NULL
GROUP BY game_id
ON CONFLICT (game_id) DO UPDATE
SET
    average = EXCLUDED.average,
    count = EXCLUDED.count;

-- 3. Merge/Update with user_items (Active app ratings)
-- We create a view to combine both for easier calculation
CREATE OR REPLACE VIEW all_ratings_view AS
SELECT game_id, name, image_url, rating FROM public.legacy_ratings WHERE rating IS NOT NULL
UNION ALL
SELECT game_id, name, image_url, rating FROM public.user_items WHERE rating IS NOT NULL;

-- Now populate/update game_stats from this combined view
-- This ensures we have the global average of everything
INSERT INTO public.game_stats (game_id, name, image_url, average, count)
SELECT
    game_id,
    MAX(name),
    MAX(image_url),
    AVG(rating),
    COUNT(rating)
FROM all_ratings_view
GROUP BY game_id
ON CONFLICT (game_id) DO UPDATE
SET
    average = EXCLUDED.average,
    count = EXCLUDED.count,
    name = COALESCE(EXCLUDED.name, public.game_stats.name),
    image_url = COALESCE(EXCLUDED.image_url, public.game_stats.image_url),
    updated_at = now();

-- 4. Create Trigger Function to keep it updated
CREATE OR REPLACE FUNCTION public.update_game_stats_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- Recalculate stats for the specific game_id involved
    -- We use the all_ratings_view to include legacy data in the average
    WITH stats AS (
        SELECT
            AVG(rating) as new_avg,
            COUNT(rating) as new_count,
            MAX(name) as name,
            MAX(image_url) as image_url
        FROM all_ratings_view
        WHERE game_id = COALESCE(NEW.game_id, OLD.game_id)
    )
    INSERT INTO public.game_stats (game_id, name, image_url, average, count)
    SELECT
        COALESCE(NEW.game_id, OLD.game_id),
        stats.name,
        stats.image_url,
        COALESCE(stats.new_avg, 0),
        COALESCE(stats.new_count, 0)
    FROM stats
    WHERE stats.new_count > 0
    ON CONFLICT (game_id) DO UPDATE
    SET
        average = EXCLUDED.average,
        count = EXCLUDED.count,
        name = COALESCE(EXCLUDED.name, public.game_stats.name),
        image_url = COALESCE(EXCLUDED.image_url, public.game_stats.image_url),
        updated_at = now();
        
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Attach Trigger
DROP TRIGGER IF EXISTS on_rating_change ON public.user_items;
CREATE TRIGGER on_rating_change
    AFTER INSERT OR UPDATE OF rating OR DELETE ON public.user_items
    FOR EACH ROW EXECUTE PROCEDURE public.update_game_stats_trigger();
