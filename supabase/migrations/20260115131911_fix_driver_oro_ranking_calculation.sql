/*
  # Fix Driver de Oro ranking calculation

  1. Changes
    - Corrects get_driver_oro_ranking() to calculate fewest "No pasó de Rojas"
    - Previously was incorrectly calculating average points
    - Now properly counts no_paso_rojas_count from archived_rounds.player_stats
    - Orders by fewest no_paso_rojas first, then by handicap ascending

  2. Returns
    - player_name: Player's name
    - value: Total count of "no pasó de rojas"
    - handicap: Average handicap
    - rounds_played: Total rounds played
*/

-- Drop the incorrect version
DROP FUNCTION IF EXISTS get_driver_oro_ranking(uuid);

-- Create the correct version
CREATE OR REPLACE FUNCTION get_driver_oro_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  value bigint,
  handicap numeric,
  rounds_played bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (player_stat->>'player_name')::text as player_name,
    SUM((player_stat->>'no_paso_rojas_count')::integer)::bigint as no_paso_count,
    AVG((player_stat->>'handicap')::numeric) as avg_handicap,
    COUNT(*)::bigint as rounds
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
  WHERE ar.group_id = p_group_id
  GROUP BY player_stat->>'player_name'
  ORDER BY no_paso_count ASC, avg_handicap ASC
  LIMIT 10;
END;
$$;
