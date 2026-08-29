/*
  # Add holes 10-18 to Golf Costa Azahar - Verde
  
  1. Changes
    - Adds holes 10-18 to the "Golf Costa Azahar - Verde" course
    - These holes have the same PAR values as holes 1-9 (since they are the same holes)
    - Hole configuration:
      * Hole 10: PAR 4, HCP 2
      * Hole 11: PAR 5, HCP 8
      * Hole 12: PAR 4, HCP 16
      * Hole 13: PAR 4, HCP 4
      * Hole 14: PAR 4, HCP 6
      * Hole 15: PAR 5, HCP 10
      * Hole 16: PAR 4, HCP 14
      * Hole 17: PAR 3, HCP 12
      * Hole 18: PAR 3, HCP 18
  
  2. Notes
    - Uses IF NOT EXISTS to prevent errors if holes already exist
    - Only adds holes if they don't already exist for this course
*/

DO $$
DECLARE
  v_course_id uuid;
BEGIN
  -- Get the course ID for Golf Costa Azahar - Verde
  SELECT id INTO v_course_id 
  FROM golf_courses 
  WHERE name = 'Golf Costa Azahar - Verde';

  -- Add holes 10-18 only if they don't already exist
  IF NOT EXISTS (
    SELECT 1 FROM golf_holes 
    WHERE course_id = v_course_id AND hole_number = 10
  ) THEN
    INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
      (v_course_id, 10, 4, 2),
      (v_course_id, 11, 5, 8),
      (v_course_id, 12, 4, 16),
      (v_course_id, 13, 4, 4),
      (v_course_id, 14, 4, 6),
      (v_course_id, 15, 5, 10),
      (v_course_id, 16, 4, 14),
      (v_course_id, 17, 3, 12),
      (v_course_id, 18, 3, 18);
  END IF;
END $$;