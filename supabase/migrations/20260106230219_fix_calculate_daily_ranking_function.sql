/*
  # Fix calculate_daily_ranking function to work with JSONB structure

  1. Changes
    - Update function to extract player data from final_ranking JSONB field
    - Group by player_name and sum points across all rounds for the date
    - Apply correct beer logic based on daily classification

  2. Notes
    - archived_rounds.final_ranking is JSONB: [{ position, player_name, points, hcp_juego }]
    - Need to extract player_name and points from this structure
    - Sum points for each player across all rounds on the same date
*/

DROP FUNCTION IF EXISTS calculate_daily_ranking(uuid, date);

CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_group_id uuid, p_date date)
RETURNS void AS $$
DECLARE
  total_players integer;
BEGIN
  -- Delete existing rankings for this date to recalculate
  DELETE FROM daily_rankings 
  WHERE group_id = p_group_id 
  AND ranking_date = p_date;

  -- Calculate total points per player and insert with position
  WITH player_totals AS (
    SELECT 
      p_group_id as group_id,
      p_date as ranking_date,
      (elem->>'player_name')::text as player_name,
      SUM((elem->>'points')::numeric) as total_points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    WHERE ar.group_id = p_group_id
    AND DATE(ar.archived_at) = p_date
    GROUP BY (elem->>'player_name')::text
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
