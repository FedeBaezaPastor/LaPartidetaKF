/*
  # Seed Default Golf Course

  1. Insert Default Course
    - Creates a standard 18-hole golf course
  
  2. Insert Holes
    - Adds 18 holes with realistic par values and stroke indexes
    - Stroke indexes are varied from 1-18 for handicap calculations

  3. Notes
    - This is the default course used when creating new rounds
    - Course and holes are read-only through RLS (anon can view)
    - Stroke indexes can be modified by authenticated users later
*/

-- Insert default golf course
INSERT INTO golf_courses (name, description)
VALUES (
  'Club de Golf Campestre',
  'Campo de golf estándar de 18 hoyos con dificultad media'
)
ON CONFLICT DO NOTHING;

-- Get the course ID to use for holes
DO $$
DECLARE
  course_id uuid;
BEGIN
  -- Get the first course (our default)
  SELECT id INTO course_id FROM golf_courses LIMIT 1;
  
  IF course_id IS NOT NULL THEN
    -- Insert holes (front 9)
    INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
    (course_id, 1, 4, 5),
    (course_id, 2, 3, 17),
    (course_id, 3, 5, 1),
    (course_id, 4, 4, 7),
    (course_id, 5, 4, 11),
    (course_id, 6, 3, 15),
    (course_id, 7, 5, 3),
    (course_id, 8, 4, 9),
    (course_id, 9, 4, 13),
    -- Insert holes (back 9)
    (course_id, 10, 4, 6),
    (course_id, 11, 5, 2),
    (course_id, 12, 3, 18),
    (course_id, 13, 4, 8),
    (course_id, 14, 4, 12),
    (course_id, 15, 5, 4),
    (course_id, 16, 3, 16),
    (course_id, 17, 4, 10),
    (course_id, 18, 4, 14)
    ON CONFLICT DO NOTHING;
  END IF;
END $$;
