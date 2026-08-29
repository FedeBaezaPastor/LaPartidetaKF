-- Restore missing ranking functions

CREATE OR REPLACE FUNCTION get_killer_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  best_score integer,
  course_name text,
  played_at timestamptz,
  handicap numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    (ranking_entry->>'points')::integer as best_score,
    ar.course_name,
    ar.played_at,
    (ranking_entry->>'handicap')::numeric
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  ORDER BY best_score DESC, ar.played_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_paquete_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  worst_score integer,
  course_name text,
  played_at timestamptz,
  handicap numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    (ranking_entry->>'points')::integer as worst_score,
    ar.course_name,
    ar.played_at,
    (ranking_entry->>'handicap')::numeric
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  ORDER BY worst_score ASC, ar.played_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_shark_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_wins bigint,
  total_rounds bigint,
  win_percentage numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    COUNT(*) FILTER (WHERE (ranking_entry->>'position')::integer = 1) as total_wins,
    COUNT(*) as total_rounds,
    ROUND((COUNT(*) FILTER (WHERE (ranking_entry->>'position')::integer = 1)::numeric / COUNT(*)::numeric) * 100, 1) as win_percentage
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  GROUP BY ranking_entry->>'player_name', ranking_entry->>'player_id'
  ORDER BY total_wins DESC, win_percentage DESC, total_rounds DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_viciado_ranking(p_group_id uuid)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  total_rounds bigint,
  average_score numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    COUNT(*) as total_rounds,
    ROUND(AVG((ranking_entry->>'points')::numeric), 2) as average_score
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
  GROUP BY ranking_entry->>'player_name', ranking_entry->>'player_id'
  ORDER BY total_rounds DESC, average_score DESC;
END;
$$ LANGUAGE plpgsql;

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
      ar.id as round_id,
      ar.course_name as round_course,
      ar.played_at as round_date,
      (ranking->>'player_name')::text as pname,
      (ranking->>'player_id')::uuid as pid,
      (ranking->>'points')::int as points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking
    WHERE ar.group_id = p_group_id
  ),
  round_extremes AS (
    SELECT 
      round_id,
      round_course,
      round_date,
      MAX(points) as max_points,
      MIN(points) as min_points
    FROM round_players
    GROUP BY round_id, round_course, round_date
  ),
  victory_margins AS (
    SELECT 
      winner.pname as winner_name,
      winner.pid as winner_id,
      winner.points as winner_points,
      last_place.pname as last_name,
      last_place.points as last_points,
      (winner.points - last_place.points) as margin,
      re.round_course as course,
      re.round_date as date
    FROM round_extremes re
    JOIN round_players winner ON winner.round_id = re.round_id AND winner.points = re.max_points
    JOIN round_players last_place ON last_place.round_id = re.round_id AND last_place.points = re.min_points
  )
  SELECT 
    vm.winner_name,
    vm.winner_id,
    vm.winner_points,
    vm.last_name,
    vm.last_points,
    vm.margin,
    vm.course,
    vm.date
  FROM victory_margins vm
  ORDER BY vm.margin DESC
  LIMIT 1;
END;
$$;
