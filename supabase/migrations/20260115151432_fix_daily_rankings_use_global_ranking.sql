/*
  # Fix Daily Rankings - Use Global Daily Ranking

  1. Changes
    - Deletes all existing daily_rankings
    - Rebuilds using GLOBAL ranking across ALL rounds of the same day
    - Top half receives beer, bottom half pays beer
    - If odd number of players, middle player neither pays nor receives
    
  2. Details
    - Groups all players from all rounds of the same day
    - Creates single global ranking by points DESC, handicap ASC, name ASC
    - Applies beer logic to the global ranking (not individual round positions)
*/

-- Delete all existing daily_rankings
DELETE FROM daily_rankings;

-- Rebuild from archived_rounds using GLOBAL daily ranking
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
WITH all_players_per_day AS (
  -- Get all players from all rounds of each day
  SELECT 
    ar.group_id,
    ar.played_at::date as ranking_date,
    (ranking->>'player_name')::text as player_name,
    (ranking->>'points')::int as total_points,
    (ranking->>'handicap')::numeric as hcp_juego
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) as ranking
),
global_daily_ranking AS (
  -- Create global ranking for each day
  SELECT 
    group_id,
    ranking_date,
    player_name,
    total_points,
    hcp_juego,
    ROW_NUMBER() OVER (
      PARTITION BY group_id, ranking_date
      ORDER BY total_points DESC, hcp_juego ASC, player_name ASC
    ) as position,
    COUNT(*) OVER (PARTITION BY group_id, ranking_date) as total_players
  FROM all_players_per_day
)
SELECT 
  group_id,
  ranking_date,
  player_name,
  total_points,
  hcp_juego,
  position,
  -- Receives beer: top half of global ranking
  CASE
    WHEN total_players % 2 = 0 THEN 
      -- Even number: top half receives
      position <= (total_players / 2)
    ELSE 
      -- Odd number: top half receives (excluding middle)
      position <= FLOOR(total_players / 2.0)
  END as receives_beer,
  -- Pays beer: bottom half of global ranking
  CASE
    WHEN total_players % 2 = 0 THEN 
      -- Even number: bottom half pays
      position > (total_players / 2)
    ELSE 
      -- Odd number: bottom half pays (excluding middle)
      position > CEIL(total_players / 2.0)
  END as pays_beer,
  0 as total_strokes,
  0 as total_stableford_net,
  hcp_juego::numeric as handicap_play
FROM global_daily_ranking
ORDER BY ranking_date, position;
