/*
  # Create DIVEND Rankings Functions
  
  1. New Functions
    - `get_patrocinador_ranking()` - Returns ranking of players who paid most beers
    - `get_barra_libre_ranking()` - Returns ranking of players who received most beers
    - `get_corto_ranking()` - Returns ranking of players with most "no pasó de rojas"
    - `get_driver_oro_ranking()` - Returns ranking of players with fewest "no pasó de rojas" (0 preferred), ordered by handicap
  
  2. Returns
    Each function returns a table with columns: player_name, player_id, value, handicap, rounds_played
    
  3. Notes
    - All functions use the DIVEND group ID
    - Rankings are ordered appropriately for each award type
*/

-- Function to get "El Patrocinador" ranking (most beers paid)
CREATE OR REPLACE FUNCTION get_patrocinador_ranking()
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
  WHERE ar.group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  GROUP BY player_stat->>'player_name', player_stat->>'player_id'
  ORDER BY beers_paid DESC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Barra Libre" ranking (most beers received)
CREATE OR REPLACE FUNCTION get_barra_libre_ranking()
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
  WHERE ar.group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  GROUP BY player_stat->>'player_name', player_stat->>'player_id'
  ORDER BY beers_won DESC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Corto" ranking (most "no pasó de rojas")
CREATE OR REPLACE FUNCTION get_corto_ranking()
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
  WHERE ar.group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  GROUP BY player_stat->>'player_name', player_stat->>'player_id'
  ORDER BY no_paso_count DESC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get "El Driver de Oro" ranking (fewest "no pasó de rojas", preferably 0)
CREATE OR REPLACE FUNCTION get_driver_oro_ranking()
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
  WHERE ar.group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  GROUP BY player_stat->>'player_name', player_stat->>'player_id'
  ORDER BY no_paso_count ASC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;