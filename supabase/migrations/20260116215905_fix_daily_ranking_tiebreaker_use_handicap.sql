/*
  # Fix tiebreaker in daily ranking to use handicap

  1. Problem
    - When players have equal points, ranking uses alphabetical order
    - Should use handicap (lower handicap wins tiebreaker)

  2. Changes
    - Update calculate_daily_ranking to order by hcp_juego ASC in case of tie
    - Lower handicap = better player = wins tiebreaker

  3. Example
    - Alfonso (HCP 9, 13 pts) vs Guti (HCP 5, 13 pts)
    - Guti should be ranked higher (position 5) because lower handicap
    - Alfonso should be position 6
*/

DROP FUNCTION IF EXISTS calculate_daily_ranking(uuid, date);

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
      SUM((player->>'points')::numeric) as total_points,
      MAX((player->>'hcp_juego')::integer) as hcp_juego
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
      hcp_juego,
      -- Order by points DESC, then by handicap ASC (lower handicap wins)
      ROW_NUMBER() OVER (ORDER BY total_points DESC, hcp_juego ASC) as position
    FROM player_totals
  ),
  player_count AS (
    SELECT COUNT(*) as total FROM ranked_players
  )
  INSERT INTO daily_rankings (group_id, ranking_date, player_name, total_points, position, hcp_juego, receives_beer, pays_beer)
  SELECT 
    rp.group_id,
    rp.ranking_date,
    rp.player_name,
    rp.total_points,
    rp.position,
    rp.hcp_juego,
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

-- Recalculate rankings for both dates
SELECT calculate_daily_ranking('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'::uuid, '2026-01-09'::date);
SELECT calculate_daily_ranking('355d0af9-0a96-4d6d-ab5a-ef1c2b203c76'::uuid, '2026-01-16'::date);
