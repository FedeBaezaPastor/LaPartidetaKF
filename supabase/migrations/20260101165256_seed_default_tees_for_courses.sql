/*
  # Seed Default Tees for All Golf Courses

  ## Overview
  This migration populates the tees table with default tee boxes for all existing golf courses.
  Each course gets 4 standard tees with default slope values.

  ## New Data
    For each golf course, the following tees are created:
    - Blancas (White) - Default slope 113 for all
    - Amarillas (Yellow) - Default slope 113 for all
    - Rojas (Red) - Default slope 113 for all
    - Azules (Blue) - Default slope 113 for all

  ## Notes
    - Default slope values (113) are placeholders
    - These values should be updated with actual course-specific slope ratings
    - Each tee has three slope values: 18 holes, holes 1-9, holes 10-18
*/

-- Insert default tees for Golf Costa Azahar - Verde
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Blancas' as name,
  '#FFFFFF' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Verde';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Amarillas' as name,
  '#FFD700' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Verde';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Rojas' as name,
  '#DC143C' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Verde';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Azules' as name,
  '#1E90FF' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Verde';

-- Insert default tees for Golf Costa Azahar - Rojo
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Blancas' as name,
  '#FFFFFF' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Rojo';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Amarillas' as name,
  '#FFD700' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Rojo';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Rojas' as name,
  '#DC143C' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Rojo';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Azules' as name,
  '#1E90FF' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Golf Costa Azahar - Rojo';

-- Insert default tees for Mediterraneo Golf
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Blancas' as name,
  '#FFFFFF' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Mediterraneo Golf';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Amarillas' as name,
  '#FFD700' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Mediterraneo Golf';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Rojas' as name,
  '#DC143C' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Mediterraneo Golf';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Azules' as name,
  '#1E90FF' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Mediterraneo Golf';

-- Insert default tees for Panorámica Golf
INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Blancas' as name,
  '#FFFFFF' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Panorámica Golf';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Amarillas' as name,
  '#FFD700' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Panorámica Golf';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Rojas' as name,
  '#DC143C' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Panorámica Golf';

INSERT INTO tees (course_id, name, color, slope_18, slope_9_i, slope_9_ii)
SELECT 
  id as course_id,
  'Azules' as name,
  '#1E90FF' as color,
  113 as slope_18,
  113 as slope_9_i,
  113 as slope_9_ii
FROM golf_courses
WHERE name = 'Panorámica Golf';