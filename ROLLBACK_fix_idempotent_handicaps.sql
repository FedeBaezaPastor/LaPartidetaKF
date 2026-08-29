-- ============================================================================
-- ROLLBACK: Revert idempotent handicap adjustments fix
--
-- This migration restores the original functions and trigger that existed
-- before the idempotent fix was applied.
--
-- Run this ONLY if the idempotent fix causes problems.
-- After running this, also restore player handicaps from the backup snapshot
-- (see the backup data captured before the fix was applied).
-- ============================================================================

-- Step 1: Restore original adjust_playing_handicaps_from_daily_ranking
CREATE OR REPLACE FUNCTION adjust_playing_handicaps_from_daily_ranking(p_ranking_date date)
RETURNS void AS $$
DECLARE
  v_total_players integer;
  v_half_point numeric;
  v_player record;
BEGIN
  SELECT COUNT(*) INTO v_total_players
  FROM daily_rankings
  WHERE ranking_date = p_ranking_date;

  IF v_total_players = 0 THEN
    RETURN;
  END IF;

  v_half_point := v_total_players / 2.0;

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
    IF v_player.final_position <= FLOOR(v_half_point) THEN
      UPDATE players
      SET playing_handicap = GREATEST(0, COALESCE(playing_handicap, exact_handicap) - 1)
      WHERE id = v_player.player_id;
    ELSIF v_total_players % 2 = 1 AND v_player.final_position = CEIL(v_half_point) THEN
      NULL;
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

-- Step 2: Restore the trigger on daily_rankings
CREATE OR REPLACE FUNCTION trigger_adjust_handicaps_after_daily_ranking()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM adjust_playing_handicaps_from_daily_ranking(NEW.ranking_date);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS after_daily_ranking_adjust_handicaps ON daily_rankings;
CREATE TRIGGER after_daily_ranking_adjust_handicaps
AFTER INSERT OR UPDATE ON daily_rankings
FOR EACH ROW
EXECUTE FUNCTION trigger_adjust_handicaps_after_daily_ranking();

-- IMPORTANT: After running this rollback, you must also restore the player
-- handicaps from the backup snapshot taken before the fix was applied.
-- The backup values were:
--
-- Alberto Usó: exact=0.0, playing=0
-- Alfonso Cardona: exact=7.0, playing=12
-- Ángel Arrufat: exact=12.0, playing=12
-- Antonio Alegre: exact=12.0, playing=12
-- Arturo: exact=14, playing=14
-- Carlos Pascual: exact=12.0, playing=12
-- Emilio: exact=8.0, playing=NULL
-- Fede 2: exact=2.0, playing=12
-- Fede Baeza: exact=8.0, playing=8
-- Fernando: exact=5.0, playing=0
-- Graciliano: exact=3.0, playing=12
-- Guti: exact=5.0, playing=12
-- Javier: exact=7.0, playing=7
-- Juan Bosch: exact=3.0, playing=0
-- Juanjo: exact=12.0, playing=0
-- Kike Algora: exact=12.0, playing=12
-- Martincho: exact=10.0, playing=0
-- Nacho Bernat: exact=6.0, playing=6
-- Nicolas: exact=10, playing=12
-- Pablo Espinosa: exact=11.0, playing=12
-- Pablo V: exact=8.0, playing=12
-- Quique Fabregat: exact=8.0, playing=8
-- Rafa Salcedo: exact=11.0, playing=12
-- Salva Martinez: exact=14.0, playing=0
-- Saul Viciano: exact=12.0, playing=12
-- Toni Serra: exact=9.0, playing=12
-- Victor Zeyani: exact=2.0, playing=12
-- Visus Jr: exact=0, playing=12
