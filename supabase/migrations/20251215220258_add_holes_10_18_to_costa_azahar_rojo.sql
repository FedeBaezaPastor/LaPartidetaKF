/*
  # Add holes 10-18 to Golf Costa Azahar - Rojo
  
  1. Changes
    - Adds holes 10-18 to Golf Costa Azahar - Rojo course
    - Holes 1-9 already exist with correct values
  
  2. New Holes (10-18)
    - Hole 10: PAR 4, HCP 2
    - Hole 11: PAR 5, HCP 8
    - Hole 12: PAR 4, HCP 14
    - Hole 13: PAR 3, HCP 18
    - Hole 14: PAR 4, HCP 4
    - Hole 15: PAR 5, HCP 6
    - Hole 16: PAR 4, HCP 10
    - Hole 17: PAR 3, HCP 12
    - Hole 18: PAR 3, HCP 16
  
  3. Notes
    - Total PAR: 35 (holes 1-9) + 34 (holes 10-18) = 69
    - Course rating and slope remain unchanged
*/

INSERT INTO golf_holes (course_id, hole_number, par, stroke_index)
SELECT 
  id,
  unnest(ARRAY[10, 11, 12, 13, 14, 15, 16, 17, 18]),
  unnest(ARRAY[4, 5, 4, 3, 4, 5, 4, 3, 3]),
  unnest(ARRAY[2, 8, 14, 18, 4, 6, 10, 12, 16])
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Rojo'
ON CONFLICT (course_id, hole_number) DO NOTHING;