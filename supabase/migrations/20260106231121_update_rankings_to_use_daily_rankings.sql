/*
  # Update ranking functions to use daily_rankings table

  1. Changes
    - Update get_patrocinador_ranking to read from daily_rankings
    - Update get_barra_libre_ranking to read from daily_rankings
    - These functions now reflect the corrected daily classification logic

  2. Notes
    - Old functions read from archived_rounds.player_stats (per-round calculation)
    - New functions read from daily_rankings (daily classification)
    - This ensures consistency with the daily classification shown in GamePoints
*/

-- Drop old functions
DROP FUNCTION IF EXISTS get_patrocinador_ranking();
DROP FUNCTION IF EXISTS get_barra_libre_ranking();

-- Recreate get_patrocinador_ranking using daily_rankings
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
    dr.player_name,
    NULL::uuid as player_id,  -- We don't have player_id in daily_rankings
    COUNT(*) FILTER (WHERE dr.pays_beer = true)::bigint as beers_paid,
    AVG(dr.hcp_juego)::numeric as avg_handicap,
    COUNT(DISTINCT dr.ranking_date)::bigint as days_played
  FROM daily_rankings dr
  WHERE dr.group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  GROUP BY dr.player_name
  HAVING COUNT(*) FILTER (WHERE dr.pays_beer = true) > 0
  ORDER BY beers_paid DESC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;

-- Recreate get_barra_libre_ranking using daily_rankings
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
    dr.player_name,
    NULL::uuid as player_id,
    COUNT(*) FILTER (WHERE dr.receives_beer = true)::bigint as beers_received,
    AVG(dr.hcp_juego)::numeric as avg_handicap,
    COUNT(DISTINCT dr.ranking_date)::bigint as days_played
  FROM daily_rankings dr
  WHERE dr.group_id = '355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'
  GROUP BY dr.player_name
  HAVING COUNT(*) FILTER (WHERE dr.receives_beer = true) > 0
  ORDER BY beers_received DESC, avg_handicap ASC;
END;
$$ LANGUAGE plpgsql;
