/*
  # Fix daily ranking calculation to properly expand final_ranking JSONB

  1. Problem
    - Function was trying to use `ar.total_points` which doesn't exist in archived_rounds
    - archived_rounds has `final_ranking` as JSONB array with player objects
    - Need to expand the array and sum points for players across multiple rounds

  2. Changes
    - Drop and recreate calculate_daily_ranking function
    - Use jsonb_array_elements to expand final_ranking array
    - Extract player_name and points from each element
    - Properly sum points for players who appear in multiple rounds on same day

  3. Note
    - This will fix the issue where only 3 players showed instead of all 10
    - After this migration, need to recalculate rankings for affected dates
*/

-- Drop existing function
DROP FUNCTION IF EXISTS calculate_daily_ranking(uuid, date);

-- Recreate function with correct logic
CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_group_id uuid, p_date date)
RETURNS void AS $$
DECLARE
  total_players integer;
  receive_count integer;
  pay_start_position integer;
BEGIN
  -- Delete existing rankings for this date to recalculate
  DELETE FROM daily_rankings 
  WHERE group_id = p_group_id 
  AND ranking_date = p_date;

  -- Calculate total points per player by expanding final_ranking JSONB array
  WITH player_totals AS (
    SELECT 
      p_group_id as group_id,
      p_date as ranking_date,
      player->>'player_name' as player_name,
      SUM((player->>'points')::numeric) as total_points
    FROM archived_rounds ar,
    jsonb_array_elements(ar.final_ranking) as player
    WHERE ar.group_id = p_group_id
    AND DATE(ar.played_at) = p_date
    GROUP BY player->>'player_name'
  ),
  ranked_players AS (
    SELECT 
      group_id,
      ranking_date,
      player_name,
      total_points,
      ROW_NUMBER() OVER (ORDER BY total_points DESC, player_name ASC) as position
    FROM player_totals
  ),
  player_count AS (
    SELECT COUNT(*) as total FROM ranked_players
  )
  INSERT INTO daily_rankings (group_id, ranking_date, player_name, total_points, position, receives_beer, pays_beer)
  SELECT 
    rp.group_id,
    rp.ranking_date,
    rp.player_name,
    rp.total_points,
    rp.position,
    -- Receives beer: top floor(n/2) positions
    rp.position <= FLOOR(pc.total / 2.0) as receives_beer,
    -- Pays beer: bottom floor(n/2) positions
    -- For odd numbers: starts at position (floor(n/2) + 2)
    -- For even numbers: starts at position (n/2 + 1)
    CASE 
      WHEN pc.total % 2 = 0 THEN rp.position > (pc.total / 2)
      ELSE rp.position > FLOOR(pc.total / 2.0) + 1
    END as pays_beer
  FROM ranked_players rp
  CROSS JOIN player_count pc;

END;
$$ LANGUAGE plpgsql;

-- Recalculate rankings for January 16, 2026
SELECT calculate_daily_ranking('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'::uuid, '2026-01-16'::date);
