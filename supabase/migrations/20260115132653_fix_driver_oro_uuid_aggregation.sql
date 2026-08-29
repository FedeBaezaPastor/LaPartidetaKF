/*
  # Fix Driver de Oro UUID Aggregation

  1. Changes
    - Fixes get_driver_oro_ranking() to use MAX() instead of MIN() for UUID
    - PostgreSQL doesn't support MIN() on UUID type

  2. Notes
    - Uses MAX() to select one player_id when grouping by name
*/

DROP FUNCTION IF EXISTS get_driver_oro_ranking(uuid);
CREATE OR REPLACE FUNCTION get_driver_oro_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  value bigint,
  handicap numeric,
  rounds_played bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      MAX((player_stat->>'player_id')::uuid) as pid,
      SUM((player_stat->>'no_paso_rojas_count')::integer)::bigint as no_paso_count,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap,
      COUNT(*)::bigint as rounds
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
  )
  SELECT 
    pname,
    pid,
    no_paso_count,
    avg_handicap,
    rounds
  FROM player_stats_grouped
  ORDER BY no_paso_count ASC, avg_handicap ASC
  LIMIT 20;
END;
$$;
