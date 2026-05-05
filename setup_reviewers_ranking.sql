-- Function to get top reviewers combining Legacy and Active users
CREATE OR REPLACE FUNCTION get_top_reviewers()
RETURNS TABLE (
  username TEXT,
  avatar_url TEXT,
  count BIGINT,
  is_legacy BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  WITH legacy_counts AS (
    SELECT 
      lr.username,
      NULL::text as avatar_url,
      COUNT(*) as count,
      true as is_legacy
    FROM legacy_ratings lr
    GROUP BY lr.username
  ),
  active_counts AS (
    SELECT 
      p.username,
      p.avatar_url,
      COUNT(*) as count,
      false as is_legacy
    FROM user_items ui
    JOIN profiles p ON ui.user_id = p.id
    WHERE ui.rating IS NOT NULL
    GROUP BY p.username, p.avatar_url
  )
  SELECT * FROM legacy_counts
  UNION ALL
  SELECT * FROM active_counts
  ORDER BY count DESC
  LIMIT 50;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
