/*
  # Fix Costa Azahar Verde HCP values for holes 1 and 2

  1. Changes
    - Hole 1: Change HCP from 7 to 1 (PAR 4 remains)
    - Hole 2: Change HCP from 1 to 7 (PAR 5 remains)
  
  2. Impact
    - Affects active rounds immediately
    - Affects new rounds created after this change
    - Does NOT affect archived rounds (they keep their original data)
*/

UPDATE golf_holes
SET stroke_index = 1
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Golf Costa Azahar - Verde')
  AND hole_number = 1;

UPDATE golf_holes
SET stroke_index = 7
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Golf Costa Azahar - Verde')
  AND hole_number = 2;
