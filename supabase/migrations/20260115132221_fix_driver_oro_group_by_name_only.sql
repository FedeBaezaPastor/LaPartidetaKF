/*
  # Fix Driver de Oro ranking to group by name only

  1. Changes
    - Updates get_driver_oro_ranking() to group only by player_name
    - This consolidates statistics for players with multiple player_ids
    - Increases limit to 20 to show more players
    - Fixes issue where duplicated player_ids were splitting statistics

  2. Notes
    - Now properly aggregates all rounds for each player regardless of player_id changes
    - Shows all players in the ranking, not just top 10
*/

-- Drop the previous version
DROP FUNCTION IF EXISTS get_driver_oro_ranking(uuid);

-- Create the corrected version
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
  LIMIT 20;
END;
$$;
