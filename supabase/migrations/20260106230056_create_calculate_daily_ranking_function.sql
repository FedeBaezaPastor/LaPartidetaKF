/*
  # Create function to calculate and store daily rankings

  1. Function: calculate_daily_ranking
    - Parameters: p_group_id (uuid), p_date (date)
    - Calculates total points for each player on a specific date
    - Determines position based on total points
    - Applies beer logic:
      - Even number of players: top 50% receive, bottom 50% pay
      - Odd number of players: top floor(n/2) receive, middle 1 neutral, bottom floor(n/2) pay
    - Stores results in daily_rankings table using UPSERT

  2. Logic Examples:
    - 11 players: positions 1-5 receive, position 6 neutral, positions 7-11 pay
    - 9 players: positions 1-4 receive, position 5 neutral, positions 6-9 pay
    - 6 players: positions 1-3 receive, positions 4-6 pay
    - 16 players: positions 1-8 receive, positions 9-16 pay
*/

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

  -- Calculate total points per player and insert with position
  WITH player_totals AS (
    SELECT 
      p_group_id as group_id,
      p_date as ranking_date,
      ar.player_name,
      SUM(ar.total_points) as total_points
    FROM archived_rounds ar
    WHERE ar.group_id = p_group_id
    AND DATE(ar.archived_at) = p_date
    GROUP BY ar.player_name
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
