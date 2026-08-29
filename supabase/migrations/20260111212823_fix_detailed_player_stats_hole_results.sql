/*
  # Fix Detailed Player Statistics Hole Results Calculation

  1. Changes
    - Update get_detailed_player_statistics to calculate hole results from net_strokes - par
    - Stop using the incorrect 'result' field
    - Calculate eagles, birdies, pars, bogeys, double_bogeys, and triple_bogeys_plus correctly
  
  2. Impact
    - Player individual statistics will now show correct distribution of results
    - Matches the calculation used in player_stats aggregation
*/

CREATE OR REPLACE FUNCTION get_detailed_player_statistics(
  p_player_name text,
  p_group_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_player_id uuid;
  v_current_handicap numeric;
  v_result jsonb := '{}'::jsonb;
  v_handicap_history jsonb;
  v_recent_rounds jsonb;
  v_best_round jsonb;
  v_hole_results jsonb;
  v_total_holes integer;
  v_avg_last_3 numeric;
  v_avg_last_5 numeric;
  v_avg_last_10 numeric;
BEGIN
  -- Get player ID and current handicap
  SELECT id, exact_handicap_18 INTO v_player_id, v_current_handicap
  FROM players
  WHERE name = p_player_name
    AND group_id = p_group_id
  LIMIT 1;

  IF v_player_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Get handicap history (last 10 changes)
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'date', changed_at,
      'old_handicap', old_handicap,
      'new_handicap', new_handicap
    ) ORDER BY changed_at DESC
  ), '[]'::jsonb)
  INTO v_handicap_history
  FROM (
    SELECT changed_at, old_handicap, new_handicap
    FROM handicap_history
    WHERE player_id = v_player_id
      AND group_id = p_group_id
    ORDER BY changed_at DESC
    LIMIT 10
  ) AS recent;

  -- Get best round
  SELECT jsonb_build_object(
    'points', (elem->>'points')::integer,
    'date', played_at,
    'course', course_name
  )
  INTO v_best_round
  FROM (
    SELECT 
      elem,
      ar.played_at,
      ar.course_name,
      (elem->>'points')::integer as points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    WHERE ar.group_id = p_group_id
      AND (elem->>'player_name')::text = p_player_name
    ORDER BY (elem->>'points')::integer DESC
    LIMIT 1
  ) sub;

  -- Count total holes played
  SELECT COALESCE(COUNT(*), 0)
  INTO v_total_holes
  FROM (
    SELECT elem
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.hole_scores) AS elem
    WHERE ar.group_id = p_group_id
      AND (elem->>'player_name')::text = p_player_name
      AND ar.hole_scores IS NOT NULL
      AND ar.hole_scores != '[]'::jsonb
  ) sub;

  -- Get hole results aggregation (calculate from net_strokes - par)
  SELECT jsonb_build_object(
    'eagles', COALESCE(SUM(CASE WHEN (elem->>'net_strokes')::int - (elem->>'par')::int <= -2 THEN 1 ELSE 0 END), 0),
    'birdies', COALESCE(SUM(CASE WHEN (elem->>'net_strokes')::int - (elem->>'par')::int = -1 THEN 1 ELSE 0 END), 0),
    'pars', COALESCE(SUM(CASE WHEN (elem->>'net_strokes')::int - (elem->>'par')::int = 0 THEN 1 ELSE 0 END), 0),
    'bogeys', COALESCE(SUM(CASE WHEN (elem->>'net_strokes')::int - (elem->>'par')::int = 1 THEN 1 ELSE 0 END), 0),
    'double_bogeys', COALESCE(SUM(CASE WHEN (elem->>'net_strokes')::int - (elem->>'par')::int = 2 THEN 1 ELSE 0 END), 0),
    'triple_bogeys_plus', COALESCE(SUM(CASE WHEN (elem->>'net_strokes')::int - (elem->>'par')::int >= 3 THEN 1 ELSE 0 END), 0)
  )
  INTO v_hole_results
  FROM (
    SELECT elem
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.hole_scores) AS elem
    WHERE ar.group_id = p_group_id
      AND (elem->>'player_name')::text = p_player_name
      AND ar.hole_scores IS NOT NULL
      AND ar.hole_scores != '[]'::jsonb
  ) sub;

  -- Calculate average of last 3 rounds
  SELECT COALESCE(AVG(points), 0)
  INTO v_avg_last_3
  FROM (
    SELECT (elem->>'points')::integer as points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    WHERE ar.group_id = p_group_id
      AND (elem->>'player_name')::text = p_player_name
    ORDER BY ar.played_at DESC
    LIMIT 3
  ) sub;

  -- Calculate average of last 5 rounds
  SELECT COALESCE(AVG(points), 0)
  INTO v_avg_last_5
  FROM (
    SELECT (elem->>'points')::integer as points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    WHERE ar.group_id = p_group_id
      AND (elem->>'player_name')::text = p_player_name
    ORDER BY ar.played_at DESC
    LIMIT 5
  ) sub;

  -- Calculate average of last 10 rounds
  SELECT COALESCE(AVG(points), 0)
  INTO v_avg_last_10
  FROM (
    SELECT (elem->>'points')::integer as points
    FROM archived_rounds ar
    CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
    WHERE ar.group_id = p_group_id
      AND (elem->>'player_name')::text = p_player_name
    ORDER BY ar.played_at DESC
    LIMIT 10
  ) sub;

  -- Build final result
  v_result := jsonb_build_object(
    'current_handicap', v_current_handicap,
    'handicap_history', v_handicap_history,
    'average_last_3', v_avg_last_3,
    'average_last_5', v_avg_last_5,
    'average_last_10', v_avg_last_10,
    'best_round', COALESCE(v_best_round, '{}'::jsonb),
    'total_holes_played', v_total_holes,
    'hole_results', COALESCE(v_hole_results, jsonb_build_object(
      'eagles', 0, 'birdies', 0, 'pars', 0,
      'bogeys', 0, 'double_bogeys', 0, 'triple_bogeys_plus', 0
    ))
  );

  RETURN v_result;
END;
$$;
