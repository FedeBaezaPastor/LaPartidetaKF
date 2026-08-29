-- ============================================================================
-- Per-round handicap adjustments system
-- Each archived round is processed independently.
-- ============================================================================

-- Step 1: Add handicap_adjusted flag to archived_rounds
ALTER TABLE archived_rounds
ADD COLUMN IF NOT EXISTS handicap_adjusted boolean DEFAULT false;

-- Step 2: Add archived_round_id to handicap_adjustments
ALTER TABLE handicap_adjustments
ADD COLUMN IF NOT EXISTS archived_round_id uuid;

-- Step 3: Add FK (SET NULL on delete)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'handicap_adjustments_archived_round_id_fkey'
  ) THEN
    ALTER TABLE handicap_adjustments
    ADD CONSTRAINT handicap_adjustments_archived_round_id_fkey
    FOREIGN KEY (archived_round_id) REFERENCES archived_rounds(id)
    ON DELETE SET NULL;
  END IF;
END $$;

-- Step 4: Replace unique constraint to key by round instead of date
ALTER TABLE handicap_adjustments
DROP CONSTRAINT IF EXISTS handicap_adjustments_group_id_player_id_adjustment_date_key;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'handicap_adjustments_group_id_player_id_archived_round_id_key'
  ) THEN
    ALTER TABLE handicap_adjustments
    ADD CONSTRAINT handicap_adjustments_group_id_player_id_archived_round_id_key
    UNIQUE (group_id, player_id, archived_round_id);
  END IF;
END $$;

-- Step 5: Mark ALL existing rounds as already adjusted
UPDATE archived_rounds SET handicap_adjusted = true WHERE handicap_adjusted = false;

-- Step 6: Create per-round handicap adjustment function
CREATE OR REPLACE FUNCTION apply_handicap_adjustments_for_round(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_round RECORD;
  v_total_players integer;
  v_top_positions integer;
  v_bottom_start integer;
  v_player RECORD;
  v_old_exact numeric;
  v_old_playing numeric;
  v_new_exact numeric;
  v_new_playing numeric;
  v_adjustment numeric;
  v_playing_adj integer;
BEGIN
  SELECT id, group_id, played_at, final_ranking, handicap_adjusted
  INTO v_round
  FROM archived_rounds
  WHERE id = p_round_id;

  IF NOT FOUND OR v_round.handicap_adjusted THEN
    RETURN;
  END IF;

  v_total_players := jsonb_array_length(v_round.final_ranking);

  IF v_total_players = 0 THEN
    RETURN;
  END IF;

  v_top_positions := FLOOR(v_total_players / 2.0);

  IF v_total_players % 2 = 0 THEN
    v_bottom_start := v_top_positions + 1;
  ELSE
    v_bottom_start := v_top_positions + 2;
  END IF;

  FOR v_player IN
    SELECT
      (fr->>'position')::integer as position,
      fr->>'player_name' as player_name,
      p.id as player_id,
      p.exact_handicap_18,
      p.playing_handicap
    FROM jsonb_array_elements(v_round.final_ranking) as fr
    JOIN players p ON p.name = fr->>'player_name' AND p.group_id = v_round.group_id
    ORDER BY (fr->>'position')::integer
  LOOP
    v_old_exact := v_player.exact_handicap_18;
    v_old_playing := COALESCE(v_player.playing_handicap, v_old_exact);
    v_adjustment := 0;
    v_playing_adj := 0;

    IF v_player.position <= v_top_positions THEN
      IF v_old_exact > 0 THEN
        v_adjustment := -1.0;
      END IF;
      v_playing_adj := -1;

    ELSIF v_total_players % 2 = 1 AND v_player.position = v_top_positions + 1 THEN
      v_adjustment := 0;
      v_playing_adj := 0;

    ELSE
      IF v_old_exact < 12 THEN
        v_adjustment := 1.0;
      END IF;
      v_playing_adj := 1;
    END IF;

    v_new_exact := GREATEST(0, v_old_exact + v_adjustment);
    v_new_playing := GREATEST(0, v_old_playing + v_playing_adj);

    IF v_playing_adj = 1 AND v_old_playing > 11 THEN
      v_new_playing := v_old_playing;
      v_playing_adj := 0;
    END IF;

    IF v_adjustment != 0 OR v_playing_adj != 0 THEN
      UPDATE players
      SET
        exact_handicap = CASE WHEN v_adjustment != 0 THEN v_new_exact ELSE exact_handicap END,
        exact_handicap_18 = CASE WHEN v_adjustment != 0 THEN v_new_exact ELSE exact_handicap_18 END,
        playing_handicap = CASE WHEN v_playing_adj != 0 THEN v_new_playing ELSE playing_handicap END,
        updated_at = now()
      WHERE id = v_player.player_id;

      INSERT INTO handicap_adjustments (
        group_id, player_id, player_name, adjustment_date,
        ranking_position, hcp_before, hcp_after, adjustment,
        playing_handicap_before, archived_round_id
      ) VALUES (
        v_round.group_id, v_player.player_id, v_player.player_name,
        DATE(v_round.played_at), v_player.position,
        v_old_exact, v_new_exact, v_adjustment,
        v_old_playing, p_round_id
      )
      ON CONFLICT (group_id, player_id, archived_round_id)
      DO UPDATE SET
        ranking_position = EXCLUDED.ranking_position,
        hcp_before = EXCLUDED.hcp_before,
        hcp_after = EXCLUDED.hcp_after,
        adjustment = EXCLUDED.adjustment,
        playing_handicap_before = EXCLUDED.playing_handicap_before,
        created_at = now();
    END IF;
  END LOOP;

  UPDATE archived_rounds
  SET handicap_adjusted = true
  WHERE id = p_round_id;
END;
$$;

-- Step 7: Modify the trigger to call per-round function instead
CREATE OR REPLACE FUNCTION auto_calculate_daily_ranking()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  played_date DATE;
BEGIN
  played_date := COALESCE(DATE(NEW.played_at), DATE(NEW.archived_at));

  PERFORM calculate_daily_ranking(NEW.group_id, played_date);

  PERFORM apply_handicap_adjustments_for_round(NEW.id);

  RETURN NEW;
END;
$$;