-- ============================================================================
-- Revert handicap adjustments when an archived round is deleted
--
-- When a round is deleted, reverse the handicap changes that were applied
-- for that specific round, using the hcp_before and playing_handicap_before
-- stored in handicap_adjustments.
-- ============================================================================

CREATE OR REPLACE FUNCTION revert_handicap_adjustments_for_round()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_adj RECORD;
BEGIN
  -- Reverse each adjustment made for this round
  FOR v_adj IN
    SELECT 
      ha.player_id,
      ha.hcp_before,
      ha.playing_handicap_before,
      ha.adjustment
    FROM handicap_adjustments ha
    WHERE ha.archived_round_id = OLD.id
  LOOP
    -- Restore exact_handicap to hcp_before
    IF v_adj.adjustment != 0 THEN
      UPDATE players
      SET 
        exact_handicap = v_adj.hcp_before,
        exact_handicap_18 = v_adj.hcp_before,
        updated_at = now()
      WHERE id = v_adj.player_id;
    END IF;

    -- Restore playing_handicap to playing_handicap_before
    IF v_adj.playing_handicap_before IS NOT NULL THEN
      UPDATE players
      SET playing_handicap = v_adj.playing_handicap_before
      WHERE id = v_adj.player_id;
    END IF;
  END LOOP;

  -- The handicap_adjustments rows will be auto-deleted by ON DELETE SET NULL
  -- on the FK. But we want them fully deleted, so do it explicitly.
  DELETE FROM handicap_adjustments WHERE archived_round_id = OLD.id;

  RETURN OLD;
END;
$$;

-- Create the trigger
DROP TRIGGER IF EXISTS trigger_revert_handicaps_on_delete ON archived_rounds;
CREATE TRIGGER trigger_revert_handicaps_on_delete
BEFORE DELETE ON archived_rounds
FOR EACH ROW
EXECUTE FUNCTION revert_handicap_adjustments_for_round();
