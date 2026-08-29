/*
  # Fix Beer Logic - Invert Pays and Receives

  1. Changes
    - Corrects the calculate_daily_ranking function
    - Mitad superior (posiciones 1-5 en 10 jugadores) = MEJORES = PAGAN cerveza
    - Mitad inferior (posiciones 6-10 en 10 jugadores) = PEORES = RECIBEN cerveza
  
  2. Details
    - receives_beer: position > mitad (posiciones altas, peores jugadores)
    - pays_beer: position <= mitad (posiciones bajas, mejores jugadores)
*/

DROP FUNCTION IF EXISTS calculate_daily_ranking(uuid, date);

CREATE OR REPLACE FUNCTION calculate_daily_ranking(
  p_group_id uuid,
  p_ranking_date date
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM daily_rankings
  WHERE group_id = p_group_id AND ranking_date = p_ranking_date;

  WITH player_totals AS (
    SELECT
      rp.round_id,
      p.group_id,
      ar.played_at::date as ranking_date,
      rp.name as player_name,
      rp.playing_handicap as hcp_juego,
      SUM(rs.stableford_points) as total_points,
      SUM(rs.gross_strokes) as total_strokes,
      SUM(rs.net_strokes) as total_stableford_net
    FROM round_players rp
    INNER JOIN golf_rounds gr ON rp.round_id = gr.id
    INNER JOIN archived_rounds ar ON ar.id = (
      SELECT ar2.id
      FROM archived_rounds ar2
      WHERE ar2.played_at::date = p_ranking_date
        AND ar2.group_id = p_group_id
      LIMIT 1
    )
    INNER JOIN round_scores rs ON rs.player_id = rp.id
    LEFT JOIN players p ON rp.player_id = p.id
    WHERE gr.group_id = p_group_id
      AND gr.completed_at IS NOT NULL
      AND gr.completed_at::date = p_ranking_date
    GROUP BY rp.round_id, p.group_id, ar.played_at::date, rp.name, rp.playing_handicap
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
      ) as position
    FROM player_totals
  ),
  player_count AS (
    SELECT COUNT(*) as total FROM ranked_players
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
    -- MITAD INFERIOR (posiciones altas) RECIBE cerveza
    rp.position > FLOOR(pc.total / 2.0) as receives_beer,
    -- MITAD SUPERIOR (posiciones bajas) PAGA cerveza
    CASE
      WHEN pc.total % 2 = 0 THEN rp.position <= (pc.total / 2)
      ELSE rp.position <= FLOOR(pc.total / 2.0)
    END as pays_beer,
    rp.total_strokes,
    rp.total_stableford_net,
    rp.hcp_juego::numeric
  FROM ranked_players rp
  CROSS JOIN player_count pc;
END;
$$;

-- Recalcular todos los rankings históricos con la lógica correcta
DO $$
DECLARE
  ranking_record RECORD;
BEGIN
  FOR ranking_record IN 
    SELECT DISTINCT group_id, ranking_date 
    FROM daily_rankings 
    ORDER BY ranking_date
  LOOP
    PERFORM calculate_daily_ranking(ranking_record.group_id, ranking_record.ranking_date);
  END LOOP;
END $$;
