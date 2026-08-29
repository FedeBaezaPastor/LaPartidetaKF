/*
  # Fix: doble ajuste de playing_handicap al archivar varias partidas el mismo día

  ## Problema
  El trigger `after_daily_ranking_adjust_handicaps` se disparaba
  `AFTER INSERT OR UPDATE ... FOR EACH ROW` sobre `daily_rankings`.
  Como `calculate_daily_ranking()` borra y reinserta TODAS las filas del día
  cada vez que se archiva cualquier partida de esa fecha, el ajuste de ±1
  (que además era relativo, no idempotente) se aplicaba varias veces:
  una vez por cada fila insertada, y de nuevo cada vez que se reconstruía
  el ranking del día al archivar partidas adicionales.

  ## Solución
  1. Se elimina el trigger a nivel de fila sobre `daily_rankings`.
  2. El ajuste se invoca una única vez, explícitamente, al final de
     `calculate_daily_ranking()`.
  3. El ajuste pasa a ser idempotente: se apoya en una foto
     (`daily_handicap_snapshots`) del `playing_handicap` de cada jugador
     tomada la primera vez que se procesa ese día. El nuevo valor siempre
     se calcula como `foto ± 1` (asignación absoluta), nunca como un
     incremento sobre el valor ya modificado. Repetir el cálculo para el
     mismo día (p.ej. al archivar una 2ª o 3ª partida) da siempre el mismo
     resultado correcto.
  4. Se añade el filtro por `group_id` que faltaba (antes se cruzaba solo
     por nombre de jugador, lo que podía mezclar jugadores homónimos de
     distintos grupos).

  ## Tablas nuevas
  - `daily_handicap_snapshots`: almacena el `playing_handicap` (o
    `exact_handicap` si aquél es nulo) de cada jugador la primera vez que
    se procesa un día concreto. Clave única `(group_id, ranking_date,
    player_id)` para que el snapshot no se sobrescriba en llamadas
    posteriores para la misma fecha.

  ## Funciones modificadas
  - `adjust_playing_handicaps_from_daily_ranking(group_id, date)`: nueva
    versión idempotente. Toma el snapshot si no existe, y siempre calcula
    el nuevo valor a partir de `handicap_before`, no del valor actual.
  - `calculate_daily_ranking(group_id, date)`: reconstruida para llamar
    al ajuste una sola vez al final, en vez de depender de un trigger.

  ## Seguridad
  - RLS habilitada en `daily_handicap_snapshots`.
  - Políticas SELECT e INSERT públicas (la app usa anon key, no hay login).
*/

-- 1. Eliminar el trigger problemático (se disparaba una vez por fila insertada)
DROP TRIGGER IF EXISTS after_daily_ranking_adjust_handicaps ON daily_rankings;
DROP FUNCTION IF EXISTS trigger_adjust_handicaps_after_daily_ranking();

-- 2. Tabla de snapshot: handicap de cada jugador ANTES de que se le aplique
--    el ajuste correspondiente a un día concreto.
CREATE TABLE IF NOT EXISTS daily_handicap_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  ranking_date date NOT NULL,
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  handicap_before numeric NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(group_id, ranking_date, player_id)
);

ALTER TABLE daily_handicap_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view handicap snapshots" ON daily_handicap_snapshots;
CREATE POLICY "Public can view handicap snapshots" ON daily_handicap_snapshots
  FOR SELECT TO public USING (true);
DROP POLICY IF EXISTS "Public can insert handicap snapshots" ON daily_handicap_snapshots;
CREATE POLICY "Public can insert handicap snapshots" ON daily_handicap_snapshots
  FOR INSERT TO public WITH CHECK (true);

-- 3. Nueva versión idempotente y filtrada por group_id
CREATE OR REPLACE FUNCTION adjust_playing_handicaps_from_daily_ranking(
  p_group_id uuid,
  p_ranking_date date
)
RETURNS void AS $$
DECLARE
  v_total_players integer;
  v_half_point numeric;
  v_player record;
BEGIN
  -- Tomar snapshot del handicap actual SOLO si aún no existe uno para
  -- este jugador/grupo/fecha (primera vez que se procesa este día).
  INSERT INTO daily_handicap_snapshots (group_id, ranking_date, player_id, handicap_before)
  SELECT p_group_id, p_ranking_date, p.id, COALESCE(p.playing_handicap, p.exact_handicap)
  FROM daily_rankings dr
  JOIN players p ON p.name = dr.player_name AND p.group_id = p_group_id
  WHERE dr.group_id = p_group_id AND dr.ranking_date = p_ranking_date
  ON CONFLICT (group_id, ranking_date, player_id) DO NOTHING;

  SELECT COUNT(*) INTO v_total_players
  FROM daily_rankings
  WHERE group_id = p_group_id AND ranking_date = p_ranking_date;

  IF v_total_players = 0 THEN
    RETURN;
  END IF;

  v_half_point := v_total_players / 2.0;

  FOR v_player IN
    SELECT
      dr.position AS final_position,
      p.id AS player_id,
      s.handicap_before
    FROM daily_rankings dr
    JOIN players p ON p.name = dr.player_name AND p.group_id = p_group_id
    JOIN daily_handicap_snapshots s
      ON s.player_id = p.id
     AND s.group_id = p_group_id
     AND s.ranking_date = p_ranking_date
    WHERE dr.group_id = p_group_id AND dr.ranking_date = p_ranking_date
    ORDER BY dr.position
  LOOP
    -- Todo se calcula SIEMPRE a partir de la foto (handicap_before),
    -- nunca del valor actual, para que sea idempotente.
    IF v_player.final_position <= FLOOR(v_half_point) THEN
      -- Mitad superior: resta 1 (excepto si ya es 0)
      UPDATE players
      SET playing_handicap = GREATEST(0, v_player.handicap_before - 1)
      WHERE id = v_player.player_id;

    ELSIF v_total_players % 2 = 1 AND v_player.final_position = CEIL(v_half_point) THEN
      -- Jugador central (si número impar de jugadores): no cambia
      UPDATE players
      SET playing_handicap = v_player.handicap_before
      WHERE id = v_player.player_id;

    ELSE
      -- Mitad inferior: suma 1 (solo si handicap <= 11)
      UPDATE players
      SET playing_handicap = CASE
        WHEN v_player.handicap_before <= 11 THEN v_player.handicap_before + 1
        ELSE v_player.handicap_before
      END
      WHERE id = v_player.player_id;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 4. Invocar el ajuste UNA SOLA VEZ, al final de calculate_daily_ranking,
--    en vez de dejar que se dispare por cada fila insertada en daily_rankings.
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

  -- Ajuste de playing_handicap: una sola vez por llamada, idempotente
  -- (aunque se llame varias veces para la misma fecha al archivar mas
  -- partidas de ese dia, el resultado final es siempre el correcto).
  PERFORM adjust_playing_handicaps_from_daily_ranking(p_group_id, p_date);
END;
$$;