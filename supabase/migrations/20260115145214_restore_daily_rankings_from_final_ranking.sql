/*
  # Restore Daily Rankings from Final Ranking

  1. Changes
    - Regenerates daily_rankings from archived_rounds.final_ranking
    - Applies correct beer logic (mejores pagan, peores reciben)
  
  2. Details
    - Uses final_ranking JSON data
    - Recalculates positions globally per day
    - Assigns beer status correctly
*/

-- Limpiar daily_rankings
TRUNCATE TABLE daily_rankings;

-- Regenerar desde final_ranking en archived_rounds
INSERT INTO daily_rankings (
  group_id,
  ranking_date,
  player_name,
  total_points,
  position,
  receives_beer,
  pays_beer,
  hcp_juego,
  handicap_play,
  round_id
)
WITH archived_data AS (
  SELECT
    ar.id as round_id,
    ar.group_id,
    ar.played_at::date as ranking_date,
    fr->>'player_name' as player_name,
    (fr->>'points')::numeric as total_points,
    (fr->>'hcp_juego')::integer as hcp_juego
  FROM archived_rounds ar,
  jsonb_array_elements(ar.final_ranking) fr
  WHERE ar.final_ranking IS NOT NULL
),
player_daily_totals AS (
  SELECT
    group_id,
    ranking_date,
    player_name,
    SUM(total_points) as total_points,
    MAX(hcp_juego) as hcp_juego
  FROM archived_data
  GROUP BY group_id, ranking_date, player_name
),
ranked_players AS (
  SELECT
    group_id,
    ranking_date,
    player_name,
    total_points,
    hcp_juego,
    ROW_NUMBER() OVER (
      PARTITION BY group_id, ranking_date
      ORDER BY
        total_points DESC,
        hcp_juego ASC,
        player_name ASC
    ) as position
  FROM player_daily_totals
),
player_counts AS (
  SELECT 
    group_id,
    ranking_date,
    COUNT(*) as total_players
  FROM ranked_players
  GROUP BY group_id, ranking_date
)
SELECT
  rp.group_id,
  rp.ranking_date,
  rp.player_name,
  rp.total_points,
  rp.position,
  -- MITAD INFERIOR (posiciones altas, peores) RECIBE cerveza
  rp.position > FLOOR(pc.total_players / 2.0) as receives_beer,
  -- MITAD SUPERIOR (posiciones bajas, mejores) PAGA cerveza
  CASE
    WHEN pc.total_players % 2 = 0 THEN rp.position <= (pc.total_players / 2)
    ELSE rp.position <= FLOOR(pc.total_players / 2.0)
  END as pays_beer,
  rp.hcp_juego,
  rp.hcp_juego::numeric,
  NULL::uuid
FROM ranked_players rp
INNER JOIN player_counts pc ON rp.group_id = pc.group_id AND rp.ranking_date = pc.ranking_date;
