/*
  # Remove Duplicate Beer Ranking Functions

  1. Changes
    - Drops all versions of get_patrocinador_ranking and get_barra_libre_ranking
    - Recreates them with correct signature and logic
    - Ensures they return ALL players with beer stats (not limited to top 10)
  
  2. Details
    - Uses daily_rankings table (correct logic already in place)
    - Returns complete ranking for modal display
*/

-- Drop ALL versions of these functions
DROP FUNCTION IF EXISTS get_patrocinador_ranking();
DROP FUNCTION IF EXISTS get_patrocinador_ranking(uuid);
DROP FUNCTION IF EXISTS get_barra_libre_ranking();
DROP FUNCTION IF EXISTS get_barra_libre_ranking(uuid);

-- Recreate with correct signature (with group_id parameter)
CREATE OR REPLACE FUNCTION get_patrocinador_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_beers_paid bigint,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dr.player_name,
    NULL::uuid as player_id,
    COUNT(*) FILTER (WHERE dr.pays_beer = true)::bigint as total_beers_paid,
    COUNT(DISTINCT dr.ranking_date)::bigint as total_rounds,
    AVG(dr.hcp_juego)::numeric as avg_handicap
  FROM daily_rankings dr
  WHERE dr.group_id = p_group_id
  GROUP BY dr.player_name
  HAVING COUNT(*) FILTER (WHERE dr.pays_beer = true) > 0
  ORDER BY total_beers_paid DESC, avg_handicap ASC;
END;
$$;

CREATE OR REPLACE FUNCTION get_barra_libre_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_beers_won bigint,
  total_rounds bigint,
  handicap numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dr.player_name,
    NULL::uuid as player_id,
    COUNT(*) FILTER (WHERE dr.receives_beer = true)::bigint as total_beers_won,
    COUNT(DISTINCT dr.ranking_date)::bigint as total_rounds,
    AVG(dr.hcp_juego)::numeric as avg_handicap
  FROM daily_rankings dr
  WHERE dr.group_id = p_group_id
  GROUP BY dr.player_name
  HAVING COUNT(*) FILTER (WHERE dr.receives_beer = true) > 0
  ORDER BY total_beers_won DESC, avg_handicap ASC;
END;
$$;
