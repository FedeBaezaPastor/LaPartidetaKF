/*
  # Recreate Hoyo de la Muerte and Hoyo de la Gloria Functions
  
  1. Changes
    - Drop existing functions
    - Recreate `get_hoyo_muerte` to count bogeys, double bogeys, triple bogeys, etc.
    - Recreate `get_hoyo_gloria` to count eagles and birdies
    
  2. Logic
    - Hoyo de la Muerte: Most holes where gross_strokes > par (bogey or worse)
    - Hoyo de la Gloria: Most holes where gross_strokes < par (birdie or eagle)
*/

-- Drop existing functions
DROP FUNCTION IF EXISTS get_hoyo_muerte(uuid, text);
DROP FUNCTION IF EXISTS get_hoyo_gloria(uuid, text);

-- Function to get "Hoyo de la Muerte" (most bogeys, double bogeys, etc.)
CREATE OR REPLACE FUNCTION get_hoyo_muerte(p_group_id uuid, p_course_name text)
RETURNS TABLE (
  hole_number integer,
  total_bad_scores bigint,
  bogeys bigint,
  double_bogeys bigint,
  triple_or_worse bigint,
  total_plays bigint,
  par integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (hs.value->>'hole_number')::integer as hole_num,
    COUNT(*) FILTER (WHERE (hs.value->>'gross_strokes')::integer > (hs.value->>'par')::integer) as bad_scores,
    COUNT(*) FILTER (WHERE (hs.value->>'gross_strokes')::integer = (hs.value->>'par')::integer + 1) as bogey_count,
    COUNT(*) FILTER (WHERE (hs.value->>'gross_strokes')::integer = (hs.value->>'par')::integer + 2) as double_bogey_count,
    COUNT(*) FILTER (WHERE (hs.value->>'gross_strokes')::integer >= (hs.value->>'par')::integer + 3) as triple_worse_count,
    COUNT(*)::bigint as plays,
    (hs.value->>'par')::integer as hole_par
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.hole_scores) as hs
  WHERE ar.group_id = p_group_id
    AND ar.course_name = p_course_name
    AND (hs.value->>'gross_strokes')::integer > 0
  GROUP BY hole_num, hole_par
  ORDER BY bad_scores DESC, triple_worse_count DESC, double_bogey_count DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to get "Hoyo de la Gloria" (most eagles and birdies)
CREATE OR REPLACE FUNCTION get_hoyo_gloria(p_group_id uuid, p_course_name text)
RETURNS TABLE (
  hole_number integer,
  total_good_scores bigint,
  eagles bigint,
  birdies bigint,
  total_plays bigint,
  par integer
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (hs.value->>'hole_number')::integer as hole_num,
    COUNT(*) FILTER (WHERE (hs.value->>'gross_strokes')::integer < (hs.value->>'par')::integer) as good_scores,
    COUNT(*) FILTER (WHERE (hs.value->>'gross_strokes')::integer <= (hs.value->>'par')::integer - 2) as eagle_count,
    COUNT(*) FILTER (WHERE (hs.value->>'gross_strokes')::integer = (hs.value->>'par')::integer - 1) as birdie_count,
    COUNT(*)::bigint as plays,
    (hs.value->>'par')::integer as hole_par
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.hole_scores) as hs
  WHERE ar.group_id = p_group_id
    AND ar.course_name = p_course_name
    AND (hs.value->>'gross_strokes')::integer > 0
  GROUP BY hole_num, hole_par
  ORDER BY good_scores DESC, eagle_count DESC, birdie_count DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql;
