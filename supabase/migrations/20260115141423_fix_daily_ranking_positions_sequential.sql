/*
  # Fix Daily Ranking Position Calculation
  
  1. Problem
    - Positions are not sequential (multiple players have position 1, 2, 3...)
    - This breaks the beer calculation logic
  
  2. Solution
    - Use ROW_NUMBER() to generate sequential positions (1, 2, 3, 4...)
    - Order by: total_points DESC, hcp_juego ASC, player_name ASC
    - Beer logic: top half receives, bottom half pays
*/

CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_group_id uuid, p_date date)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM daily_rankings
  WHERE group_id = p_group_id
    AND ranking_date = p_date;

  WITH player_totals AS (
    SELECT
      p_group_id as group_id,
      p_date as ranking_date,
      (elem->>'player_name')::text as player_name,
      SUM((elem->>'points')::numeric) as total_points,
      MIN((elem->>'hcp_juego')::integer) as hcp_juego,
      SUM(
        COALESCE(
          (SELECT SUM((score->>'gross_strokes')::integer)
           FROM jsonb_array_elements(ar.hole_scores) AS score
           WHERE score->>'player_name' = elem->>'player_name'
          ), 0)
      ) as total_strokes,
      SUM((elem->>'points')::numeric) as total_stableford_net
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    WHERE ar.group_id = p_group_id
      AND DATE(ar.archived_at) = p_date
    GROUP BY (elem->>'player_name')::text
  ),
  ranked_players AS (
    SELECT
      group_id,
      ranking_date,
      player_name,
      total_points,
      hcp_juego,
      total_strokes,
      total_stableford_net,
      ROW_NUMBER() OVER (
        ORDER BY
          total_points DESC,
          hcp_juego ASC,
          player_name ASC
      )::integer as position
    FROM player_totals
  ),
  player_count AS (
    SELECT COUNT(*)::integer as total FROM ranked_players
  )
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
  SELECT
    rp.group_id,
    rp.ranking_date,
    rp.player_name,
    rp.total_points,
    rp.hcp_juego,
    rp.position,
    rp.position <= CEIL(pc.total / 2.0) as receives_beer,
    rp.position > CEIL(pc.total / 2.0) as pays_beer,
    rp.total_strokes,
    rp.total_stableford_net,
    rp.hcp_juego::numeric
  FROM ranked_players rp
  CROSS JOIN player_count pc;
END;
$$;
