/*
  # Fix PAR values for holes 10-18 in Golf Costa Azahar - Verde
  
  1. Changes
    - Corrects PAR values for holes 14, 15, 16, and 17 to match their corresponding holes 5, 6, 7, and 8
    - Hole 14: PAR 4 → PAR 5 (to match hole 5)
    - Hole 15: PAR 5 → PAR 4 (to match hole 6)
    - Hole 16: PAR 4 → PAR 3 (to match hole 7)
    - Hole 17: PAR 3 → PAR 4 (to match hole 8)
  
  2. Notes
    - Ensures holes 10-18 have the exact same PAR values as holes 1-9
    - These corrections align with the course being the same 9 holes played twice
*/

UPDATE golf_holes
SET par = 5
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Golf Costa Azahar - Verde')
  AND hole_number = 14;

UPDATE golf_holes
SET par = 4
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Golf Costa Azahar - Verde')
  AND hole_number = 15;

UPDATE golf_holes
SET par = 3
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Golf Costa Azahar - Verde')
  AND hole_number = 16;

UPDATE golf_holes
SET par = 4
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Golf Costa Azahar - Verde')
  AND hole_number = 17;