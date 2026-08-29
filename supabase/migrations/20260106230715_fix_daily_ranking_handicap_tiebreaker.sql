/*
  # Fix daily ranking to use handicap for tiebreaking

  1. Changes
    - Update calculate_daily_ranking function to extract hcp_juego from final_ranking
    - Use hcp_juego as tiebreaker (lower handicap wins)
    - Add hcp_juego column to daily_rankings table
    - Sort by: points DESC, hcp_juego ASC, player_name ASC

  2. Notes
    - This matches the frontend logic in GamePoints.tsx sortStandings()
    - Lower handicap wins in case of tie (better player wins)
*/

-- Add hcp_juego column to daily_rankings if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'daily_rankings' AND column_name = 'hcp_juego'
  ) THEN
    ALTER TABLE daily_rankings ADD COLUMN hcp_juego integer;
  END IF;
END $$;

-- Recreate function with handicap tiebreaker
DROP FUNCTION IF EXISTS calculate_daily_ranking(uuid, date);

CREATE OR REPLACE FUNCTION calculate_daily_ranking(p_group_id uuid, p_date date)
RETURNS void AS $$
BEGIN
  -- Delete existing rankings for this date to recalculate
  DELETE FROM daily_rankings 
  WHERE group_id = p_group_id 
  AND ranking_date = p_date;

  -- Calculate total points per player with handicap for tiebreaking
  WITH player_totals AS (
    SELECT 
      p_group_id as group_id,
      p_date as ranking_date,
      (elem->>'player_name')::text as player_name,
      SUM((elem->>'points')::numeric) as total_points,
      -- Use MIN hcp_juego (in case player played multiple rounds, use their best/first handicap)
      MIN((elem->>'hcp_juego')::integer) as hcp_juego
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
      hcp_juego,
      ROW_NUMBER() OVER (
        ORDER BY 
          total_points DESC, 
          hcp_juego ASC, 
          player_name ASC
      ) as position
    FROM player_totals
  ),
  player_count AS (
    SELECT COUNT(*) as total FROM ranked_players
  )
  INSERT INTO daily_rankings (group_id, ranking_date, player_name, total_points, hcp_juego, position, receives_beer, pays_beer)
  SELECT 
    rp.group_id,
    rp.ranking_date,
    rp.player_name,
    rp.total_points,
    rp.hcp_juego,
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
