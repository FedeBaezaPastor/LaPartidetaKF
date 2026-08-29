/*
  # Sistema de Handicap de Juego Dinámico

  ## Descripción
  Implementa el sistema de ajuste automático del handicap de juego basado en la 
  clasificación diaria. El handicap se ajusta después de cada día de juego según 
  la posición del jugador en el ranking diario.

  ## Cambios en Tablas
  
  ### `players`
  - Añade columna `playing_handicap` (numeric): Handicap de juego actual a 9 hoyos
    - Se inicializa con el valor de `exact_handicap`
    - Se ajusta automáticamente según la posición en daily_rankings
    - Default: NULL (se calculará en migración posterior)

  ## Nuevas Funciones

  ### `adjust_playing_handicaps_from_daily_ranking(p_ranking_date date)`
  Ajusta los handicaps de juego de todos los jugadores según su posición en el 
  ranking diario:
  
  **MITAD SUPERIOR (mejores clasificados):**
  - Se RESTA 1 al HCP de juego
  - EXCEPCIÓN: Si ya tienen HCP 0, no se resta
  
  **MITAD INFERIOR (peores clasificados):**
  - Se SUMA 1 al HCP de juego
  - EXCEPCIÓN: Solo se suma si tienen HCP ≤ 11. Los de HCP 12+ NO suman
  
  **MEDIO (jugador central si impar):**
  - No suma ni resta

  ## Triggers
  
  ### `trigger_adjust_handicaps_after_daily_ranking`
  Se ejecuta DESPUÉS de INSERT/UPDATE en `daily_rankings`
  Llama automáticamente a `adjust_playing_handicaps_from_daily_ranking()`

  ## Seguridad
  - Mantiene las políticas RLS existentes
  - No afecta datos históricos ni estadísticas
  - Solo modifica `playing_handicap` en la tabla `players`
*/

-- Añadir columna playing_handicap a players
ALTER TABLE players 
ADD COLUMN IF NOT EXISTS playing_handicap numeric;

-- Función para ajustar handicaps según daily_rankings
CREATE OR REPLACE FUNCTION adjust_playing_handicaps_from_daily_ranking(p_ranking_date date)
RETURNS void AS $$
DECLARE
  v_total_players integer;
  v_half_point numeric;
  v_player record;
BEGIN
  -- Contar jugadores en el ranking de ese día
  SELECT COUNT(*) INTO v_total_players
  FROM daily_rankings
  WHERE ranking_date = p_ranking_date;

  -- Si no hay jugadores, salir
  IF v_total_players = 0 THEN
    RETURN;
  END IF;

  -- Calcular punto medio
  v_half_point := v_total_players / 2.0;

  -- Procesar cada jugador del ranking
  FOR v_player IN
    SELECT 
      p.id as player_id,
      dr.position as final_position,
      p.exact_handicap,
      p.playing_handicap
    FROM daily_rankings dr
    JOIN players p ON p.name = dr.player_name
    WHERE dr.ranking_date = p_ranking_date
    ORDER BY dr.position
  LOOP
    -- MITAD SUPERIOR: Resta 1 (excepto si ya es 0)
    IF v_player.final_position <= FLOOR(v_half_point) THEN
      UPDATE players
      SET playing_handicap = GREATEST(0, COALESCE(playing_handicap, exact_handicap) - 1)
      WHERE id = v_player.player_id;
    
    -- JUGADOR MEDIO (si número impar): No cambia
    ELSIF v_total_players % 2 = 1 AND v_player.final_position = CEIL(v_half_point) THEN
      -- No hacer nada, mantener el valor actual
      NULL;
    
    -- MITAD INFERIOR: Suma 1 (solo si HCP ≤ 11)
    ELSE
      UPDATE players
      SET playing_handicap = CASE
        WHEN COALESCE(playing_handicap, exact_handicap) <= 11 
        THEN COALESCE(playing_handicap, exact_handicap) + 1
        ELSE COALESCE(playing_handicap, exact_handicap)
      END
      WHERE id = v_player.player_id;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Trigger para ajustar handicaps automáticamente después de daily_rankings
CREATE OR REPLACE FUNCTION trigger_adjust_handicaps_after_daily_ranking()
RETURNS TRIGGER AS $$
BEGIN
  -- Llamar a la función de ajuste para la fecha del ranking
  PERFORM adjust_playing_handicaps_from_daily_ranking(NEW.ranking_date);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger en daily_rankings
DROP TRIGGER IF EXISTS after_daily_ranking_adjust_handicaps ON daily_rankings;
CREATE TRIGGER after_daily_ranking_adjust_handicaps
AFTER INSERT OR UPDATE ON daily_rankings
FOR EACH ROW
EXECUTE FUNCTION trigger_adjust_handicaps_after_daily_ranking();

-- Inicializar playing_handicap con exact_handicap para todos los jugadores
UPDATE players
SET playing_handicap = exact_handicap
WHERE playing_handicap IS NULL;

-- Aplicar ajustes históricos desde el daily_ranking más antiguo hasta el más reciente
DO $$
DECLARE
  v_date record;
BEGIN
  FOR v_date IN
    SELECT DISTINCT ranking_date
    FROM daily_rankings
    ORDER BY ranking_date ASC
  LOOP
    PERFORM adjust_playing_handicaps_from_daily_ranking(v_date.ranking_date);
  END LOOP;
END;
$$;