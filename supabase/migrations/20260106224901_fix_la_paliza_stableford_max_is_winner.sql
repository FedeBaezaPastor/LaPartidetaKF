/*
  # Fix La Paliza - Stableford: Max Points = Winner

  1. Problem
    - In Stableford: MORE points = WINNER (better)
    - Previous version had it backwards (min = winner)

  2. Correct Logic for Stableford
    - MAX(points) = winner (best player)
    - MIN(points) = last place (worst player)
    - La Paliza = MAX - MIN

  3. Example
    - Partida: Fede 15, Arturo 19, Carlos 22
    - MAX = 22 (Carlos, winner) ✅
    - MIN = 15 (Fede, last place)
    - Margin = 22 - 15 = 7 points ✅
*/

CREATE OR REPLACE FUNCTION get_la_paliza(p_group_id uuid)
RETURNS TABLE (
  winner_name text,
  winner_points integer,
  second_place_name text,
  second_place_points integer,
  point_difference integer,
  course_name text,
  played_at timestamptz
) AS $$
BEGIN
  RETURN QUERY
  WITH ranked_rounds AS (
    SELECT
      ar.course_name as round_course_name,
      ar.played_at as round_played_at,
      (ranking_entry->>'player_name')::text as player_name,
      (ranking_entry->>'points')::integer as points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
    WHERE ar.group_id = p_group_id
  ),
  round_extremes AS (
    SELECT
      round_course_name,
      round_played_at,
      MAX(points) as max_points,  -- Winner in Stableford
      MIN(points) as min_points   -- Last place in Stableford
    FROM ranked_rounds
    GROUP BY round_course_name, round_played_at
  ),
  victory_margins AS (
    SELECT
      winner.player_name as winner,
      winner.points as winner_pts,
      last.player_name as last_place,
      last.points as last_pts,
      winner.points - last.points as margin,  -- Winner - Last
      winner.round_course_name as vict_course_name,
      winner.round_played_at as vict_played_at
    FROM round_extremes re
    JOIN ranked_rounds winner 
      ON winner.round_course_name = re.round_course_name
      AND winner.round_played_at = re.round_played_at
      AND winner.points = re.max_points  -- Winner has MAX points
    JOIN ranked_rounds last
      ON last.round_course_name = re.round_course_name
      AND last.round_played_at = re.round_played_at
      AND last.points = re.min_points  -- Last has MIN points
  )
  SELECT
    winner,
    winner_pts,
    last_place,
    last_pts,
    margin,
    vict_course_name,
    vict_played_at
  FROM victory_margins
  ORDER BY margin DESC, vict_played_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;