/*
  # Create Detailed Player Statistics Function (Phase 1)

  1. Purpose
    - Calculate comprehensive player statistics for Phase 1
    - Includes handicap, averages, best rounds, and scoring distribution

  2. Returns
    - current_handicap: Current exact handicap
    - handicap_history: Last 10 handicap changes
    - average_last_3: Average stableford points of last 3 rounds
    - average_last_5: Average stableford points of last 5 rounds
    - average_last_10: Average stableford points of last 10 rounds
    - best_round_points: Best stableford score ever
    - best_round_date: Date of best round
    - eagles: Count of eagles
    - birdies: Count of birdies
    - pars: Count of pars
    - bogeys: Count of bogeys
    - double_bogeys: Count of double bogeys
    - triple_bogeys_plus: Count of triple bogeys and worse

  3. Notes
    - Only uses archived_rounds data
    - Returns null if player has no archived rounds
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
  SELECT jsonb_agg(
    jsonb_build_object(
      'date', changed_at,
      'old_handicap', old_handicap,
      'new_handicap', new_handicap
    ) ORDER BY changed_at DESC
  )
  INTO v_handicap_history
  FROM (
    SELECT changed_at, old_handicap, new_handicap
    FROM handicap_history
    WHERE player_id = v_player_id
      AND group_id = p_group_id
    ORDER BY changed_at DESC
    LIMIT 10
  ) AS recent;

  -- Get recent rounds with points
  SELECT jsonb_agg(
    jsonb_build_object(
      'date', played_at,
      'points', (elem->>'points')::integer
    ) ORDER BY played_at DESC
  )
  INTO v_recent_rounds
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
  WHERE ar.group_id = p_group_id
    AND (elem->>'player_name')::text = p_player_name
  ORDER BY ar.played_at DESC;

  -- Get best round
  SELECT jsonb_build_object(
    'points', (elem->>'points')::integer,
    'date', ar.played_at,
    'course', ar.course_name
  )
  INTO v_best_round
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
  WHERE ar.group_id = p_group_id
    AND (elem->>'player_name')::text = p_player_name
  ORDER BY (elem->>'points')::integer DESC
  LIMIT 1;

  -- Get hole results aggregation
  SELECT jsonb_build_object(
    'eagles', COALESCE(SUM(CASE WHEN (elem->>'result')::text = 'eagle' THEN 1 ELSE 0 END), 0),
    'birdies', COALESCE(SUM(CASE WHEN (elem->>'result')::text = 'birdie' THEN 1 ELSE 0 END), 0),
    'pars', COALESCE(SUM(CASE WHEN (elem->>'result')::text = 'par' THEN 1 ELSE 0 END), 0),
    'bogeys', COALESCE(SUM(CASE WHEN (elem->>'result')::text = 'bogey' THEN 1 ELSE 0 END), 0),
    'double_bogeys', COALESCE(SUM(CASE WHEN (elem->>'result')::text = 'double_bogey' THEN 1 ELSE 0 END), 0),
    'triple_bogeys_plus', COALESCE(SUM(CASE WHEN (elem->>'result')::text = 'triple_bogey_plus' THEN 1 ELSE 0 END), 0)
  )
  INTO v_hole_results
  FROM archived_rounds ar
  CROSS JOIN jsonb_array_elements(ar.hole_scores) AS elem
  WHERE ar.group_id = p_group_id
    AND (elem->>'player_name')::text = p_player_name
    AND ar.hole_scores IS NOT NULL
    AND ar.hole_scores != '[]'::jsonb;

  -- Calculate averages
  v_result := jsonb_build_object(
    'current_handicap', v_current_handicap,
    'handicap_history', COALESCE(v_handicap_history, '[]'::jsonb),
    'average_last_3', (
      SELECT COALESCE(AVG((elem->>'points')::integer), 0)
      FROM (
        SELECT elem
        FROM archived_rounds ar
        CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
        WHERE ar.group_id = p_group_id
          AND (elem->>'player_name')::text = p_player_name
        ORDER BY ar.played_at DESC
        LIMIT 3
      ) AS last_3
    ),
    'average_last_5', (
      SELECT COALESCE(AVG((elem->>'points')::integer), 0)
      FROM (
        SELECT elem
        FROM archived_rounds ar
        CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
        WHERE ar.group_id = p_group_id
          AND (elem->>'player_name')::text = p_player_name
        ORDER BY ar.played_at DESC
        LIMIT 5
      ) AS last_5
    ),
    'average_last_10', (
      SELECT COALESCE(AVG((elem->>'points')::integer), 0)
      FROM (
        SELECT elem
        FROM archived_rounds ar
        CROSS JOIN jsonb_array_elements(ar.final_ranking) AS elem
        WHERE ar.group_id = p_group_id
          AND (elem->>'player_name')::text = p_player_name
        ORDER BY ar.played_at DESC
        LIMIT 10
      ) AS last_10
    ),
    'best_round', COALESCE(v_best_round, '{}'::jsonb),
    'hole_results', COALESCE(v_hole_results, jsonb_build_object(
      'eagles', 0, 'birdies', 0, 'pars', 0,
      'bogeys', 0, 'double_bogeys', 0, 'triple_bogeys_plus', 0
    )),
    'recent_rounds', COALESCE(v_recent_rounds, '[]'::jsonb)
  );

  RETURN v_result;
END;
$$;