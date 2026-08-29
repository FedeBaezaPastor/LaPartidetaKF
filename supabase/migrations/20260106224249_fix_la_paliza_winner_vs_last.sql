/*
  # Fix La Paliza - Compare Winner vs Last Place

  1. Problem
    - Previous version compared winner (1st) vs second (2nd)
    - "La Paliza" should be the biggest victory: winner vs LAST place

  2. Solution
    - Compare position 1 (lowest points = winner) with the highest position (last place)
    - Calculate: last_place_points - winner_points

  3. Example
    - Fede: 15 (1st), Arturo: 19 (2nd), Carlos: 22 (3rd)
    - Biggest victory: Fede vs Carlos = 22 - 15 = 7 points
    - NOT Fede vs Arturo = 19 - 15 = 4 points
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
      (ranking_entry->>'points')::integer as points,
      (ranking_entry->>'position')::integer as position
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
    WHERE ar.group_id = p_group_id
  ),
  round_positions AS (
    SELECT
      round_course_name,
      round_played_at,
      MAX(position) as last_position
    FROM ranked_rounds
    GROUP BY round_course_name, round_played_at
  ),
  victory_margins AS (
    SELECT
      r1.player_name as winner,
      r1.points as winner_pts,
      r2.player_name as last_place,
      r2.points as last_pts,
      r2.points - r1.points as margin,
      r1.round_course_name as vict_course_name,
      r1.round_played_at as vict_played_at
    FROM ranked_rounds r1
    JOIN round_positions rp ON r1.round_course_name = rp.round_course_name
      AND r1.round_played_at = rp.round_played_at
    JOIN ranked_rounds r2 ON r1.round_course_name = r2.round_course_name
      AND r1.round_played_at = r2.round_played_at
      AND r1.position = 1
      AND r2.position = rp.last_position
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