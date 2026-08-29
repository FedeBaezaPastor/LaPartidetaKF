/*
  # Fix La Paliza Function - Course Name Ambiguity
  
  1. Updates
    - Explicitly qualify all course_name and played_at references with table aliases
    - Removes ambiguity in JOIN conditions and SELECT clause
    
  2. Notes
    - This fixes the "column reference 'course_name' is ambiguous" error
*/

-- Fix "La Paliza" function to remove column ambiguity
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
  victory_margins AS (
    SELECT 
      r1.player_name as winner,
      r1.points as winner_pts,
      r2.player_name as second,
      r2.points as second_pts,
      r1.points - r2.points as margin,
      r1.round_course_name as vict_course_name,
      r1.round_played_at as vict_played_at
    FROM ranked_rounds r1
    JOIN ranked_rounds r2 ON r1.round_course_name = r2.round_course_name 
      AND r1.round_played_at = r2.round_played_at 
      AND r1.position = 1 
      AND r2.position = 2
  )
  SELECT 
    winner,
    winner_pts,
    second,
    second_pts,
    margin,
    vict_course_name,
    vict_played_at
  FROM victory_margins
  ORDER BY margin DESC, vict_played_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;