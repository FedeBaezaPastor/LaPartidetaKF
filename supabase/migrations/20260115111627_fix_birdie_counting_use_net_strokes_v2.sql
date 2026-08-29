/*
  # Fix Birdie Counting to Use Net Strokes

  1. Changes
    - Update get_detailed_player_statistics function to count birdies based on net_strokes = par - 1
    - Previously only counted when result field was marked as 'birdie'
    - Now correctly identifies all net birdies regardless of result field value
  
  2. Details
    - Birdies should be counted when net_strokes = par - 1
    - This reflects the actual scoring system used in the app
    - Drop and recreate function to ensure clean update
*/

DROP FUNCTION IF EXISTS get_detailed_player_statistics(uuid);

CREATE FUNCTION get_detailed_player_statistics(target_group_id uuid)
RETURNS TABLE (
  player_id uuid,
  player_name text,
  total_rounds bigint,
  total_holes bigint,
  birdies_or_better bigint,
  pars bigint,
  bogeys bigint,
  double_bogeys bigint,
  triple_bogeys_or_worse bigint
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH all_hole_scores AS (
    SELECT 
      (ps->>'player_id')::uuid as pid,
      ps->>'player_name' as pname,
      (hs->>'par')::int as par,
      (hs->>'net_strokes')::int as net
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS ps
    CROSS JOIN jsonb_array_elements(ar.hole_scores) AS hs
    WHERE ar.group_id = target_group_id
      AND ps->>'player_name' = hs->>'player_name'
      AND (hs->>'gross_strokes')::int > 0
      AND (hs->>'abandoned')::boolean IS DISTINCT FROM true
  )
  SELECT 
    ahs.pid,
    ahs.pname,
    (SELECT COUNT(DISTINCT ar.id) 
     FROM archived_rounds ar 
     CROSS JOIN jsonb_array_elements(ar.player_stats) AS ps
     WHERE ar.group_id = target_group_id 
       AND (ps->>'player_id')::uuid = ahs.pid)::bigint as total_rounds,
    COUNT(*)::bigint as total_holes,
    COUNT(*) FILTER (WHERE ahs.net <= ahs.par - 1)::bigint as birdies_or_better,
    COUNT(*) FILTER (WHERE ahs.net = ahs.par)::bigint as pars,
    COUNT(*) FILTER (WHERE ahs.net = ahs.par + 1)::bigint as bogeys,
    COUNT(*) FILTER (WHERE ahs.net = ahs.par + 2)::bigint as double_bogeys,
    COUNT(*) FILTER (WHERE ahs.net >= ahs.par + 3)::bigint as triple_bogeys_or_worse
  FROM all_hole_scores ahs
  GROUP BY ahs.pid, ahs.pname
  ORDER BY ahs.pname;
END;
$$;