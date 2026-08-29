/*
  # Fix Handicaps for January 9, 2026 Games

  This migration corrects the playing handicaps (handicap field) for games played on January 9, 2026.
  The handicaps were incorrectly stored and need to be updated to match the actual playing handicaps.

  ## Changes
  - Alfonso Cardona: 9 → 8
  - Carlos Pascual: 13 (unchanged)
  - Fede Baeza: 11 → 10
  - Guti: 5 → 6
  - Kike Algora: 11 → 12
  - Martincho: 8 → 9
  - Nacho Bernat: 13 → 14
  - Quique Fabregat: 12 (unchanged)
  - Saul Viciano: 12 (unchanged)
  - Victor Zeyani: 4 → 5
*/

DO $$
DECLARE
  divend_group_id uuid;
  round_record record;
  updated_ranking jsonb;
  ranking_entry jsonb;
BEGIN
  -- Get DIVEND group ID
  SELECT id INTO divend_group_id FROM groups WHERE group_code = 'DIVEND' LIMIT 1;

  -- Update each round from January 9, 2026
  FOR round_record IN 
    SELECT id, final_ranking
    FROM archived_rounds
    WHERE group_id = divend_group_id
      AND DATE(played_at) = '2026-01-09'
  LOOP
    updated_ranking = '[]'::jsonb;
    
    -- Process each player in the ranking
    FOR ranking_entry IN 
      SELECT * FROM jsonb_array_elements(round_record.final_ranking)
    LOOP
      -- Update handicap based on player name
      CASE ranking_entry->>'player_name'
        WHEN 'Alfonso Cardona' THEN
          ranking_entry = jsonb_set(ranking_entry, '{handicap}', '8'::jsonb);
          ranking_entry = jsonb_set(ranking_entry, '{hcp_juego}', '8'::jsonb);
        WHEN 'Fede Baeza' THEN
          ranking_entry = jsonb_set(ranking_entry, '{handicap}', '10'::jsonb);
          ranking_entry = jsonb_set(ranking_entry, '{hcp_juego}', '10'::jsonb);
        WHEN 'Guti' THEN
          ranking_entry = jsonb_set(ranking_entry, '{handicap}', '6'::jsonb);
          ranking_entry = jsonb_set(ranking_entry, '{hcp_juego}', '6'::jsonb);
        WHEN 'Kike Algora' THEN
          ranking_entry = jsonb_set(ranking_entry, '{handicap}', '12'::jsonb);
          ranking_entry = jsonb_set(ranking_entry, '{hcp_juego}', '12'::jsonb);
        WHEN 'Martincho' THEN
          ranking_entry = jsonb_set(ranking_entry, '{handicap}', '9'::jsonb);
          ranking_entry = jsonb_set(ranking_entry, '{hcp_juego}', '9'::jsonb);
        WHEN 'Nacho Bernat' THEN
          ranking_entry = jsonb_set(ranking_entry, '{handicap}', '14'::jsonb);
          ranking_entry = jsonb_set(ranking_entry, '{hcp_juego}', '14'::jsonb);
        WHEN 'Victor Zeyani' THEN
          ranking_entry = jsonb_set(ranking_entry, '{handicap}', '5'::jsonb);
          ranking_entry = jsonb_set(ranking_entry, '{hcp_juego}', '5'::jsonb);
        ELSE
          -- Keep unchanged for Carlos, Quique, and Saul
          NULL;
      END CASE;
      
      updated_ranking = updated_ranking || jsonb_build_array(ranking_entry);
    END LOOP;
    
    -- Update the round with corrected handicaps
    UPDATE archived_rounds
    SET final_ranking = updated_ranking
    WHERE id = round_record.id;
  END LOOP;
END $$;
