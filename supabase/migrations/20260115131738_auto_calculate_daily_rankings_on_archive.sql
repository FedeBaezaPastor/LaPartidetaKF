/*
  # Auto-calculate daily rankings when archiving rounds

  1. Changes
    - Creates a trigger function that automatically calls calculate_daily_ranking()
      when a round is archived
    - Creates the trigger on archived_rounds table
    - Recalculates daily rankings for all existing archived rounds

  2. Purpose
    - Ensures daily rankings are always calculated immediately after archiving
    - Provides double safety (function call + trigger)
    - Fixes any missing daily rankings from previously archived rounds
*/

-- Create trigger function to auto-calculate daily ranking
CREATE OR REPLACE FUNCTION auto_calculate_daily_ranking()
RETURNS TRIGGER AS $$
DECLARE
  played_date DATE;
BEGIN
  -- Extract the date from played_at (or archived_at if played_at is not available)
  played_date := COALESCE(DATE(NEW.played_at), DATE(NEW.archived_at));

  -- Call calculate_daily_ranking for this group and date
  PERFORM calculate_daily_ranking(NEW.group_id, played_date);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on archived_rounds
DROP TRIGGER IF EXISTS trigger_auto_calculate_daily_ranking ON archived_rounds;

CREATE TRIGGER trigger_auto_calculate_daily_ranking
  AFTER INSERT ON archived_rounds
  FOR EACH ROW
  EXECUTE FUNCTION auto_calculate_daily_ranking();

-- Recalculate daily rankings for all existing archived rounds
DO $$
DECLARE
  rec RECORD;
BEGIN
  -- Get all unique group_id and date combinations from archived_rounds
  FOR rec IN
    SELECT DISTINCT
      group_id,
      DATE(COALESCE(played_at, archived_at)) as ranking_date
    FROM archived_rounds
    WHERE group_id IS NOT NULL
    ORDER BY ranking_date DESC
  LOOP
    -- Calculate daily ranking for each group/date combination
    PERFORM calculate_daily_ranking(rec.group_id, rec.ranking_date);

    RAISE NOTICE 'Recalculated daily ranking for group % on date %', rec.group_id, rec.ranking_date;
  END LOOP;
END;
$$;
