/*
  # Rebuild Daily Rankings from Archived Rounds

  1. Changes
    - Deletes all existing daily_rankings
    - Rebuilds them from archived_rounds.final_ranking data
    - Uses correct beer logic (winners receive, losers pay)
    
  2. Details
    - Processes all archived rounds in the system
    - Top half receives beer (winners)
    - Bottom half pays beer (losers)
*/

-- First, delete all existing daily_rankings
DELETE FROM daily_rankings;

-- Rebuild from archived_rounds
INSERT INTO daily_rankings (
  group_id,
  ranking_date,
  player_name,
  total_points,
  hcp_juego,
  position,
  receives_beer,
  pays_beer,
  total_strokes,
  total_stableford_net,
  handicap_play
)
WITH ranked_data AS (
  SELECT 
    ar.group_id,
    ar.played_at::date as ranking_date,
    (ranking->>'player_name')::text as player_name,
    (ranking->>'points')::int as total_points,
    (ranking->>'handicap')::numeric as hcp_juego,
    (ranking->>'position')::int as position,
    0 as total_strokes,
    0 as total_stableford_net,
    COUNT(*) OVER (PARTITION BY ar.id) as player_count
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) as ranking
)
SELECT 
  group_id,
  ranking_date,
  player_name,
  total_points,
  hcp_juego,
  position,
  -- MITAD SUPERIOR (posiciones bajas 1-5) RECIBE cerveza (ganadores cobran)
  CASE
    WHEN player_count % 2 = 0 THEN position <= (player_count / 2)
    ELSE position <= FLOOR(player_count / 2.0)
  END as receives_beer,
  -- MITAD INFERIOR (posiciones altas 6-10) PAGA cerveza (perdedores pagan)
  position > FLOOR(player_count / 2.0) as pays_beer,
  total_strokes,
  total_stableford_net,
  hcp_juego::numeric as handicap_play
FROM ranked_data
ORDER BY ranking_date, position;
