/*
  # Fix Beer Logic - Invert Receives/Pays

  1. Changes
    - Fixes calculate_daily_ranking so winners RECEIVE beer (not pay)
    - Fixes so losers PAY beer (not receive)
    
  2. Details
    - MITAD SUPERIOR (posiciones bajas 1-5) → RECIBEN cerveza (ganadores cobran)
    - MITAD INFERIOR (posiciones altas 6-10) → PAGAN cerveza (perdedores pagan)
*/

DROP FUNCTION IF EXISTS calculate_daily_ranking(uuid, date);

CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_group_id uuid, p_ranking_date date)
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
    -- MITAD SUPERIOR (posiciones bajas) RECIBE cerveza (GANADORES COBRAN)
    CASE
      WHEN pc.total % 2 = 0 THEN rp.position <= (pc.total / 2)
      ELSE rp.position <= FLOOR(pc.total / 2.0)
    END as receives_beer,
    -- MITAD INFERIOR (posiciones altas) PAGA cerveza (PERDEDORES PAGAN)
    rp.position > FLOOR(pc.total / 2.0) as pays_beer,
    rp.total_strokes,
    rp.total_stableford_net,
    rp.hcp_juego::numeric
  FROM ranked_players rp
  CROSS JOIN player_count pc;
END;
$$;
