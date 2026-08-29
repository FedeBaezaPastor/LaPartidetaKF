/*
  # Agregar campo no_paso_rojas_count a daily_rankings

  1. Cambios
    - Agregar columna no_paso_rojas_count a la tabla daily_rankings
    - Actualizar la función calculate_daily_ranking para incluir este campo
    - Recalcular rankings existentes con los valores correctos
*/

-- Agregar columna si no existe
ALTER TABLE daily_rankings 
ADD COLUMN IF NOT EXISTS no_paso_rojas_count integer DEFAULT 0;

-- Actualizar función para incluir no_paso_rojas_count
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

  UPDATE daily_rankings dr
  SET 
    receives_beer = CASE 
      WHEN v_is_odd AND dr.position - 1 = v_middle_index THEN false
      WHEN dr.position - 1 < v_middle_index THEN true
      ELSE false
    END,
    pays_beer = CASE 
      WHEN v_is_odd AND dr.position - 1 = v_middle_index THEN false
      WHEN dr.position - 1 >= v_middle_index + (CASE WHEN v_is_odd THEN 1 ELSE 0 END) THEN true
      ELSE false
    END
  WHERE dr.group_id = p_group_id 
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
  LOOP
    PERFORM calculate_daily_ranking(ranking_record.group_id, ranking_record.ranking_date);
  END LOOP;
END $$;
