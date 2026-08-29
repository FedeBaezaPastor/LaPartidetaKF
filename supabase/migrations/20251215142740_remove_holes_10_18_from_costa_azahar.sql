/*
  # Remove holes 10-18 from Costa Azahar courses

  1. Changes
    - Delete holes 10-18 from Golf Costa Azahar - Rojo
    - Delete holes 10-18 from Golf Costa Azahar - Verde
  
  2. Notes
    - Costa Azahar is a 9-hole course
    - When playing 18 holes, players go around twice on the same 9 holes
    - Other courses have 18 physical holes
*/

-- Delete holes 10-18 from Costa Azahar courses
DELETE FROM golf_holes 
WHERE hole_number BETWEEN 10 AND 18 
AND course_id IN (
  SELECT id FROM golf_courses 
  WHERE name LIKE '%Costa Azahar%'
);