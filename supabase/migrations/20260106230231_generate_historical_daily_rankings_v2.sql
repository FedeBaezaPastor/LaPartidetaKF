/*
  # Generate daily rankings for historical data (v2)

  1. Purpose
    - Process all existing archived_rounds to generate daily_rankings
    - Ensures historical beer statistics are correctly calculated
    - Fixed to work with JSONB structure

  2. Process
    - Find all unique (group_id, date) combinations in archived_rounds
    - Call calculate_daily_ranking for each combination
    - This populates the daily_rankings table with historical data
*/

DO $$
DECLARE
  rec RECORD;
BEGIN
  -- Loop through all unique group_id and date combinations in archived_rounds
  FOR rec IN 
    SELECT DISTINCT 
      group_id, 
      DATE(archived_at) as ranking_date
    FROM archived_rounds
    ORDER BY group_id, ranking_date
  LOOP
    -- Calculate daily ranking for each group/date combination
    PERFORM calculate_daily_ranking(rec.group_id, rec.ranking_date);
    RAISE NOTICE 'Processed ranking for group % on date %', rec.group_id, rec.ranking_date;
  END LOOP;
  
  RAISE NOTICE 'Historical daily rankings generated successfully';
END $$;
