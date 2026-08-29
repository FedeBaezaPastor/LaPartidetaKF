-- ============================================================================
-- Fix v2: Corrected idempotent handicap adjustments
--
-- Issues with v1:
-- 1. apply_handicap_adjustments_from_daily_ranking was reverting playing_handicap
--    to hcp_before when playing_handicap_before was NULL, corrupting values.
-- 2. Dropped the trigger that called adjust_playing_handicaps_from_daily_ranking
--    but never added that call into apply_handicap_adjustments_from_daily_ranking,
--    so playing_handicap adjustments were broken.
--
-- This migration fixes both issues:
-- 1. apply_handicap_adjustments_from_daily_ranking ONLY touches exact_handicap
--    and exact_handicap_18, never playing_handicap.
-- 2. It calls adjust_playing_handicaps_from_daily_ranking at the end, which
--    is now also idempotent.
-- ============================================================================

-- Step 1: Fix apply_handicap_adjustments_from_daily_ranking
-- Remove playing_handicap manipulation, add call to adjust_playing_handicaps
CREATE OR REPLACE FUNCTION apply_handicap_adjustments_from_daily_ranking(
  p_group_id uuid, 
  p_date date
) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  ranking_record RECORD;
  total_players integer;
  top_positions integer;
  bottom_start_position integer;
  adjustment numeric;
  new_exact_handicap numeric;
  old_exact_handicap numeric;
  old_playing_handicap numeric;
BEGIN
  -- Phase 1: Revert previous exact_handicap adjustments for this date
  -- Restore exact_handicap and exact_handicap_18 to hcp_before
  FOR ranking_record IN
    SELECT 
      ha.player_id,
      ha.hcp_before,
      ha.playing_handicap_before
    FROM handicap_adjustments ha
    WHERE ha.group_id = p_group_id
      AND ha.adjustment_date = p_date
  LOOP
    UPDATE players
    SET 
      exact_handicap = ranking_record.hcp_before,
      exact_handicap_18 = ranking_record.hcp_before,
      updated_at = now()
    WHERE id = ranking_record.player_id;
  END LOOP;

  -- Phase 2: Apply fresh adjustments based on current daily_rankings
  SELECT COUNT(*) INTO total_players
  FROM daily_rankings
  WHERE group_id = p_group_id
    AND ranking_date = p_date;

  top_positions := FLOOR(total_players / 2.0);

  IF total_players % 2 = 0 THEN
    bottom_start_position := top_positions + 1;
  ELSE
    bottom_start_position := top_positions + 2;
  END IF;

  FOR ranking_record IN
    SELECT 
      dr.player_name,
      dr.position,
      dr.hcp_juego,
      p.id as player_id,
      p.exact_handicap_18,
      p.playing_handicap
    FROM daily_rankings dr
    JOIN players p ON p.name = dr.player_name AND p.group_id = dr.group_id
    WHERE dr.group_id = p_group_id
      AND dr.ranking_date = p_date
    ORDER BY dr.position
  LOOP
    old_exact_handicap := ranking_record.exact_handicap_18;
    old_playing_handicap := COALESCE(ranking_record.playing_handicap, old_exact_handicap);
    adjustment := 0;

    -- Top players: subtract 1 if HCP > 0
    IF ranking_record.position <= top_positions THEN
      IF old_exact_handicap > 0 THEN
        adjustment := -1.0;
      END IF;
    -- Bottom players: add 1 if HCP < 12
    ELSIF ranking_record.position >= bottom_start_position THEN
      IF old_exact_handicap < 12 THEN
        adjustment := 1.0;
      END IF;
    -- Middle player (odd total): no change
    ELSE
      adjustment := 0;
    END IF;

    new_exact_handicap := GREATEST(0, old_exact_handicap + adjustment);

    IF adjustment != 0 THEN
      UPDATE players
      SET 
        exact_handicap = new_exact_handicap,
        exact_handicap_18 = new_exact_handicap,
        updated_at = now()
      WHERE id = ranking_record.player_id;

      INSERT INTO handicap_adjustments (
        group_id, player_id, player_name, adjustment_date,
        ranking_position, hcp_before, hcp_after, adjustment,
        playing_handicap_before
      ) VALUES (
        p_group_id, ranking_record.player_id, ranking_record.player_name,
        p_date, ranking_record.position, old_exact_handicap,
        new_exact_handicap, adjustment, old_playing_handicap
      )
      ON CONFLICT (group_id, player_id, adjustment_date)
      DO UPDATE SET
        ranking_position = EXCLUDED.ranking_position,
        hcp_before = EXCLUDED.hcp_before,
        hcp_after = EXCLUDED.hcp_after,
        adjustment = EXCLUDED.adjustment,
        playing_handicap_before = EXCLUDED.playing_handicap_before,
        created_at = now();
    END IF;
  END LOOP;

  -- Phase 3: Now adjust playing_handicap (idempotent version)
  PERFORM adjust_playing_handicaps_from_daily_ranking(p_date);
END;
$$;

-- Step 2: Fix adjust_playing_handicaps_from_daily_ranking
-- Make it idempotent: revert previous playing_handicap changes using
-- playing_handicap_before from handicap_adjustments, then apply fresh.
CREATE OR REPLACE FUNCTION adjust_playing_handicaps_from_daily_ranking(
  p_ranking_date date
) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_total_players integer;
  v_half_point numeric;
  v_player record;
  v_old_playing_handicap numeric;
  v_new_playing_handicap numeric;
BEGIN
  SELECT COUNT(*) INTO v_total_players
  FROM daily_rankings
  WHERE ranking_date = p_ranking_date;

  IF v_total_players = 0 THEN
    RETURN;
  END IF;

  -- Phase 1: Revert previous playing_handicap adjustments for this date
  -- Restore playing_handicap to playing_handicap_before
  FOR v_player IN
    SELECT 
      ha.player_id,
      ha.playing_handicap_before
    FROM handicap_adjustments ha
    WHERE ha.adjustment_date = p_ranking_date
      AND ha.playing_handicap_before IS NOT NULL
  LOOP
    UPDATE players
    SET playing_handicap = v_player.playing_handicap_before
    WHERE id = v_player.player_id;
  END LOOP;

  v_half_point := v_total_players / 2.0;

  -- Phase 2: Apply fresh adjustments
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
    v_old_playing_handicap := COALESCE(v_player.playing_handicap, v_player.exact_handicap);

    -- Top half: subtract 1 (min 0)
    IF v_player.final_position <= FLOOR(v_half_point) THEN
      v_new_playing_handicap := GREATEST(0, v_old_playing_handicap - 1);
      IF v_new_playing_handicap != v_old_playing_handicap THEN
        UPDATE players
        SET playing_handicap = v_new_playing_handicap
        WHERE id = v_player.player_id;
      END IF;

    -- Middle player (odd count): no change
    ELSIF v_total_players % 2 = 1 AND v_player.final_position = CEIL(v_half_point) THEN
      NULL;

    -- Bottom half: add 1 (only if HCP <= 11)
    ELSE
      IF v_old_playing_handicap <= 11 THEN
        v_new_playing_handicap := v_old_playing_handicap + 1;
        UPDATE players
        SET playing_handicap = v_new_playing_handicap
        WHERE id = v_player.player_id;
      END IF;
    END IF;
  END LOOP;
END;
$$;
