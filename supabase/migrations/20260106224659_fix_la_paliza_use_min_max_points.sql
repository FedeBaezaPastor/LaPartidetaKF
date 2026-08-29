/*
  # Fix La Paliza - Use Min/Max Points Instead of Positions

  1. Problem
    - Positions in final_ranking may be reversed (position 1 = highest points)
    - In golf, winner = LOWEST points, last = HIGHEST points
    - Cannot trust position numbers

  2. Solution
    - For each round, find MIN(points) = winner
    - For each round, find MAX(points) = last place
    - Calculate: max_points - min_points = biggest victory margin

  3. Example
    - Partida: Fede 15, Arturo 19, Carlos 22
    - MIN = 15 (Fede, winner), MAX = 22 (Carlos, last)
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
      MIN(points) as min_points,
      MAX(points) as max_points
    FROM ranked_rounds
    GROUP BY round_course_name, round_played_at
  ),
  victory_margins AS (
    SELECT
      winner.player_name as winner,
      winner.points as winner_pts,
      last.player_name as last_place,
      last.points as last_pts,
      last.points - winner.points as margin,
      winner.round_course_name as vict_course_name,
      winner.round_played_at as vict_played_at
    FROM round_extremes re
    JOIN ranked_rounds winner 
      ON winner.round_course_name = re.round_course_name
      AND winner.round_played_at = re.round_played_at
      AND winner.points = re.min_points
    JOIN ranked_rounds last
      ON last.round_course_name = re.round_course_name
      AND last.round_played_at = re.round_played_at
      AND last.points = re.max_points
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