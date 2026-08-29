/*
  # Create Phase 3 Course Statistics Functions
  
  1. New Functions
    - `get_hoyo_muerte(p_group_id, p_course_name)` - Returns the hole with worst average performance
    - `get_hoyo_gloria(p_group_id, p_course_name)` - Returns the hole with best average performance
    - `get_mejor_ronda_campo(p_group_id, p_course_name)` - Returns best round score on that course
    
  2. Returns
    Each function returns appropriate data for the course statistic
    
  3. Notes
    - All functions filter by group_id and course_name
    - Uses hole_scores from archived_rounds
*/

-- Function to get "Hoyo de la Muerte" (worst performing hole)
CREATE OR REPLACE FUNCTION get_hoyo_muerte(p_group_id uuid, p_course_name text)
RETURNS TABLE (
  hole_number integer,
  average_score numeric,
  average_stableford numeric,
  total_plays bigint,
  par integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (hs.value->>'hole_number')::integer as hole_num,
    ROUND(AVG((hs.value->>'net_strokes')::numeric - (hs.value->>'par')::numeric), 2) as avg_score_vs_par,
    ROUND(AVG((hs.value->>'stableford_points')::numeric), 2) as avg_stableford,
    COUNT(*)::bigint as plays,
    (hs.value->>'par')::integer as hole_par
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.hole_scores) as hs
  WHERE ar.group_id = p_group_id
    AND ar.course_name = p_course_name
  GROUP BY hole_num, hole_par
  ORDER BY avg_stableford ASC, avg_score_vs_par DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get "Hoyo de la Gloria" (best performing hole)
CREATE OR REPLACE FUNCTION get_hoyo_gloria(p_group_id uuid, p_course_name text)
RETURNS TABLE (
  hole_number integer,
  average_score numeric,
  average_stableford numeric,
  total_plays bigint,
  par integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (hs.value->>'hole_number')::integer as hole_num,
    ROUND(AVG((hs.value->>'net_strokes')::numeric - (hs.value->>'par')::numeric), 2) as avg_score_vs_par,
    ROUND(AVG((hs.value->>'stableford_points')::numeric), 2) as avg_stableford,
    COUNT(*)::bigint as plays,
    (hs.value->>'par')::integer as hole_par
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.hole_scores) as hs
  WHERE ar.group_id = p_group_id
    AND ar.course_name = p_course_name
  GROUP BY hole_num, hole_par
  ORDER BY avg_stableford DESC, avg_score_vs_par ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get "Mejor Ronda en ese Campo" (best round score on course)
CREATE OR REPLACE FUNCTION get_mejor_ronda_campo(p_group_id uuid, p_course_name text)
RETURNS TABLE (
  player_name text,
  player_id uuid,
  best_score integer,
  played_at timestamptz,
  handicap numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (ranking_entry->>'player_name')::text,
    (ranking_entry->>'player_id')::uuid,
    (ranking_entry->>'points')::integer as score,
    ar.played_at,
    (ranking_entry->>'handicap')::numeric
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS ranking_entry
  WHERE ar.group_id = p_group_id
    AND ar.course_name = p_course_name
  ORDER BY score DESC, ar.played_at ASC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;
