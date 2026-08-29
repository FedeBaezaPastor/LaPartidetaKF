/*
  # Fix La Paliza - Compare Winner vs Last Place

  1. Changes
    - Modify `get_la_paliza` function to compare 1st place vs LAST place
    - Previously compared 1st vs 2nd place
    - Now finds the player with minimum points (last place) and calculates difference
    - Column names remain the same for compatibility (second_place_name/points now refer to last place)
  
  2. Logic
    - Find winner (MAX points in each round)
    - Find last place (MIN points in each round)
    - Calculate victory margin as (winner_points - last_place_points)
    - Return the round with the biggest margin
*/

DROP FUNCTION IF EXISTS get_la_paliza(uuid);

CREATE OR REPLACE FUNCTION get_la_paliza(p_group_id uuid)
RETURNS TABLE (
  winner_name text,
  winner_id uuid,
  winner_points integer,
  second_place_name text,
  second_place_points integer,
  point_difference integer,
  course_name text,
  played_at timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH round_players AS (
    SELECT 
      ar.id,
      ar.course_name,
      ar.played_at,
      (ranking->>'player_name')::text as pname,
      (ranking->>'player_id')::uuid as pid,
      (ranking->>'points')::int as points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking
    WHERE ar.group_id = p_group_id
  ),
  round_extremes AS (
    SELECT 
      id,
      course_name,
      played_at,
      MAX(points) as max_points,
      MIN(points) as min_points
    FROM round_players
    GROUP BY id, course_name, played_at
  ),
  victory_margins AS (
    SELECT 
      winner.pname as winner_name,
      winner.pid as winner_id,
      winner.points as winner_points,
      last_place.pname as last_name,
      last_place.points as last_points,
      (winner.points - last_place.points) as margin,
      re.course_name,
      re.played_at
    FROM round_extremes re
    JOIN round_players winner ON winner.id = re.id AND winner.points = re.max_points
    JOIN round_players last_place ON last_place.id = re.id AND last_place.points = re.min_points
  )
  SELECT 
    vm.winner_name,
    vm.winner_id,
    vm.winner_points,
    vm.last_name,
    vm.last_points,
    vm.margin,
    vm.course_name,
    vm.played_at
  FROM victory_margins vm
  ORDER BY vm.margin DESC
  LIMIT 1;
END;
$$;