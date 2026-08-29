/*
  # Fix All DIVEND Rankings to Group by Name Only

  1. Changes
    - Updates get_patrocinador_ranking() to group only by player_name
    - Updates get_barra_libre_ranking() to group only by player_name
    - Updates get_corto_ranking() to group only by player_name
    - This consolidates statistics for players with multiple player_ids

  2. Notes
    - Fixes issue where duplicated player_ids were splitting statistics
    - Uses DISTINCT ON to select one player_id per player name
    - All functions now properly aggregate data across all rounds
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
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      SUM((player_stat->>'beers_paid')::integer)::bigint as beers_paid,
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
    psg.beers_paid,
    psg.avg_handicap,
    psg.rounds
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.beers_paid DESC, psg.avg_handicap ASC;
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
  WITH player_stats_grouped AS (
    SELECT 
      (player_stat->>'player_name')::text as pname,
      SUM((player_stat->>'beers_won')::integer)::bigint as beers_won,
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
    psg.beers_won,
    psg.avg_handicap,
    psg.rounds
  FROM player_stats_grouped psg
  LEFT JOIN player_ids pi ON psg.pname = pi.pname
  ORDER BY psg.beers_won DESC, psg.avg_handicap ASC;
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
  ORDER BY psg.no_paso_count DESC, psg.avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;
