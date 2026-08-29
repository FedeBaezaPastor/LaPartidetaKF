-- Make the auto_calculate_daily_ranking trigger resilient.
-- If calculate_daily_ranking or apply_handicap_adjustments_for_round errors,
-- the archived_rounds INSERT should still succeed — we log the error and continue.
-- This prevents "Failed to fetch" errors when the trigger's internal logic fails.

CREATE OR REPLACE FUNCTION auto_calculate_daily_ranking()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  played_date DATE;
  v_err text;
BEGIN
  played_date := COALESCE(DATE(NEW.played_at), DATE(NEW.archived_at));

  -- Recalculate daily ranking (for beers, still aggregated by date)
  BEGIN
    PERFORM calculate_daily_ranking(NEW.group_id, played_date);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    RAISE LOG 'calculate_daily_ranking failed for round %: %', NEW.id, v_err;
  END;

  -- Apply handicap adjustments for THIS specific round (not aggregated)
  BEGIN
    PERFORM apply_handicap_adjustments_for_round(NEW.id);
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    RAISE LOG 'apply_handicap_adjustments_for_round failed for round %: %', NEW.id, v_err;
  END;

  RETURN NEW;
END;
$$;
