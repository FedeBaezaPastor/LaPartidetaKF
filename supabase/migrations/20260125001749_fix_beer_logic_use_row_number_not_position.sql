/*
  # Corregir lógica de cervezas para usar fila física en lugar de posición

  1. Problema
    - Cuando hay empates, varios jugadores comparten la misma posición
    - La lógica actual usa position para determinar quién paga/recibe
    - Esto causa que jugadores empatados en posición 4 (pero físicamente 6º) reciban cuando deberían pagar

  2. Solución
    - Usar ROW_NUMBER (fila física) en lugar de position para calcular quién paga/recibe
    - La position se mantiene para mostrar empates correctamente en la UI
    - Pero receives_beer y pays_beer se calculan basados en la fila física real

  3. Ejemplo con 10 jugadores
    - Físicamente 1-5: reciben cerveza
    - Físicamente 6-10: pagan cerveza
    - Aunque estén empatados en posición 4, el 6º jugador paga
*/

CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_group_id uuid, p_date date)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_players integer;
  v_middle_index integer;
  v_is_odd boolean;
  v_current_position integer := 0;
  v_previous_points numeric := NULL;
  v_previous_handicap numeric := NULL;
  v_position_counter integer := 0;
  v_row_number integer := 0;
  v_player record;
BEGIN
  DELETE FROM daily_rankings 
  WHERE group_id = p_group_id 
    AND ranking_date = p_date;

  FOR v_player IN
    SELECT 
      ar.group_id,
      p_date as ranking_date,
      ps.player_name,
      SUM((ps.hole_results->>'pars')::integer * 2 +
          (ps.hole_results->>'birdies')::integer * 3 +
          (ps.hole_results->>'eagles')::integer * 4 +
          (ps.hole_results->>'bogeys')::integer * 1) as total_points,
      MAX(ps.playing_handicap) as handicap_play,
      MAX(ps.handicap) as hcp_juego,
      SUM(ps.no_paso_rojas_count) as no_paso_rojas_count,
      ar.id as round_id
    FROM archived_rounds ar
    CROSS JOIN LATERAL jsonb_to_recordset(ar.player_stats) AS ps(
      player_name text,
      playing_handicap numeric,
      handicap integer,
      hole_results jsonb,
      no_paso_rojas_count integer
    )
    WHERE ar.group_id = p_group_id
      AND DATE(ar.played_at) = p_date
    GROUP BY ar.group_id, ps.player_name, ar.id
    ORDER BY total_points DESC, handicap_play ASC
  LOOP
    v_position_counter := v_position_counter + 1;
    v_row_number := v_row_number + 1;
    
    IF v_previous_points IS NULL OR v_player.total_points != v_previous_points THEN
      v_current_position := v_position_counter;
    ELSIF v_player.handicap_play != v_previous_handicap THEN
      v_current_position := v_position_counter;
    END IF;
    
    v_previous_points := v_player.total_points;
    v_previous_handicap := v_player.handicap_play;

    INSERT INTO daily_rankings (
      group_id,
      ranking_date,
      player_name,
      total_points,
      position,
      hcp_juego,
      handicap_play,
      no_paso_rojas_count,
      round_id
    ) VALUES (
      v_player.group_id,
      v_player.ranking_date,
      v_player.player_name,
      v_player.total_points,
      v_current_position,
      v_player.hcp_juego,
      v_player.handicap_play,
      v_player.no_paso_rojas_count,
      v_player.round_id
    );
  END LOOP;

  SELECT COUNT(*) INTO v_total_players
  FROM daily_rankings
  WHERE group_id = p_group_id AND ranking_date = p_date;

  v_is_odd := (v_total_players % 2) != 0;
  v_middle_index := FLOOR(v_total_players::numeric / 2);

  -- Usar ROW_NUMBER en lugar de position para determinar quién paga/recibe
  WITH ranked_players AS (
    SELECT 
      id,
      ROW_NUMBER() OVER (ORDER BY total_points DESC, handicap_play ASC) - 1 as row_index
    FROM daily_rankings
    WHERE group_id = p_group_id AND ranking_date = p_date
  )
  UPDATE daily_rankings dr
  SET 
    receives_beer = CASE 
      WHEN v_is_odd AND rp.row_index = v_middle_index THEN false
      WHEN rp.row_index < v_middle_index THEN true
      ELSE false
    END,
    pays_beer = CASE 
      WHEN v_is_odd AND rp.row_index = v_middle_index THEN false
      WHEN rp.row_index >= v_middle_index + (CASE WHEN v_is_odd THEN 1 ELSE 0 END) THEN true
      ELSE false
    END
  FROM ranked_players rp
  WHERE dr.id = rp.id
    AND dr.group_id = p_group_id 
    AND dr.ranking_date = p_date;
END;
$$;

-- Recalcular todos los rankings existentes
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
    RAISE NOTICE 'Recalculated ranking for % on %', ranking_record.group_id, ranking_record.ranking_date;
  END LOOP;
END $$;
