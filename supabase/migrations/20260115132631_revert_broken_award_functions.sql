/*
  # Revert Award Ranking Functions to Correct Implementation

  1. Changes
    - Restores get_patrocinador_ranking() to use beer_stats
    - Restores get_barra_libre_ranking() to use beer_stats
    - Restores get_corto_ranking() to use no_paso_rojas_count
    - Updates get_driver_oro_ranking() to group by name only and show all players

  2. Notes
    - These functions were broken by the 20260115104346 migration
    - Now all return player_id, value, handicap, rounds_played as expected
    - All accept p_group_id parameter for flexibility
*/

-- Function to get "El Patrocinador" ranking (most beers paid)
DROP FUNCTION IF EXISTS get_patrocinador_ranking(uuid);
CREATE OR REPLACE FUNCTION get_patrocinador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  value bigint,
  handicap numeric,
  rounds_played bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (player_stat->>'player_name')::text,
    (player_stat->>'player_id')::uuid,
    SUM((player_stat->>'beers_paid')::integer)::bigint as beers_paid,
    AVG((player_stat->>'handicap')::numeric) as avg_handicap,
    COUNT(*)::bigint as rounds
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
  WHERE ar.group_id = p_group_id
  GROUP BY player_stat->>'player_name', player_stat->>'player_id'
  ORDER BY beers_paid DESC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Barra Libre" ranking (most beers received)
DROP FUNCTION IF EXISTS get_barra_libre_ranking(uuid);
CREATE OR REPLACE FUNCTION get_barra_libre_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  value bigint,
  handicap numeric,
  rounds_played bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (player_stat->>'player_name')::text,
    (player_stat->>'player_id')::uuid,
    SUM((player_stat->>'beers_won')::integer)::bigint as beers_won,
    AVG((player_stat->>'handicap')::numeric) as avg_handicap,
    COUNT(*)::bigint as rounds
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
  WHERE ar.group_id = p_group_id
  GROUP BY player_stat->>'player_name', player_stat->>'player_id'
  ORDER BY beers_won DESC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Corto" ranking (most "no pasó de rojas")
DROP FUNCTION IF EXISTS get_corto_ranking(uuid);
CREATE OR REPLACE FUNCTION get_corto_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  value bigint,
  handicap numeric,
  rounds_played bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (player_stat->>'player_name')::text,
    (player_stat->>'player_id')::uuid,
    SUM((player_stat->>'no_paso_rojas_count')::integer)::bigint as no_paso_count,
    AVG((player_stat->>'handicap')::numeric) as avg_handicap,
    COUNT(*)::bigint as rounds
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.player_stats) AS player_stat
  WHERE ar.group_id = p_group_id
  GROUP BY player_stat->>'player_name', player_stat->>'player_id'
  ORDER BY no_paso_count DESC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Driver de Oro" ranking (fewest "no pasó de rojas", preferably 0)
-- Group by name only to handle players with multiple IDs
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
      MIN((player_stat->>'player_id')::uuid) as pid,
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
