/*
  # Fix Driver de Oro Using DISTINCT ON for Player ID

  1. Changes
    - Fixes get_driver_oro_ranking() to use subquery instead of aggregate functions on UUID
    - Selects first player_id found for each player name
    - Groups statistics by player name only

  2. Notes
    - PostgreSQL doesn't support MIN/MAX on UUID type
    - Uses subquery to get one player_id per player name
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
      SUM((player_stat->>'no_paso_rojas_count')::integer)::bigint as no_paso_count,
      AVG((player_stat->>'handicap')::numeric) as avg_handicap,
      COUNT(*)::bigint as rounds
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
    GROUP BY player_stat->>'player_name'
  ),
  player_ids AS (
    SELECT DISTINCT ON ((player_stat->>'player_name')::text)
      (player_stat->>'player_name')::text as pname,
      (player_stat->>'player_id')::uuid as pid
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
    WHERE ar.group_id = p_group_id
  )
  SELECT 
    psg.pname,
    pi.pid,
    psg.no_paso_count,
    psg.avg_handicap,
    psg.rounds
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.no_paso_count ASC, psg.avg_handicap ASC
  LIMIT 20;
END;
$$;
