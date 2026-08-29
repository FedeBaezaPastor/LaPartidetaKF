/*
  # Update Mediterraneo Golf Slope Ratings

  ## Overview
  Updates the slope ratings for all tees (barras) at Mediterraneo Golf based on official data.

  ## Changes
    - Barras Blancas: slope_18 = 138, slope_9_i = 113 (no data), slope_9_ii = 113 (no data)
    - Barras Azules: slope_18 = 131, slope_9_i = 113 (no data), slope_9_ii = 113 (no data)
    - Barras Amarillas: slope_18 = 135, slope_9_i = 132, slope_9_ii = 113 (no data)
    - Barras Rojas: slope_18 = 130, slope_9_i = 131, slope_9_ii = 113 (no data)

  ## Notes
    - Only updating 18-hole slopes and 9-hole front nine (1-9) slopes where data is available
    - Back nine (10-18) slopes remain at default 113 as no data was provided
*/

-- Update Barras Blancas
UPDATE tees
SET 
  slope_18 = 138,
  slope_9_i = 113,
  slope_9_ii = 113
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Mediterraneo Golf')
  AND name = 'Blancas';

-- Update Barras Azules
UPDATE tees
SET 
  slope_18 = 131,
  slope_9_i = 113,
  slope_9_ii = 113
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Mediterraneo Golf')
  AND name = 'Azules';

-- Update Barras Amarillas
UPDATE tees
SET 
  slope_18 = 135,
  slope_9_i = 132,
  slope_9_ii = 113
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Mediterraneo Golf')
  AND name = 'Amarillas';

-- Update Barras Rojas
UPDATE tees
SET 
  slope_18 = 130,
  slope_9_i = 131,
  slope_9_ii = 113
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Mediterraneo Golf')
  AND name = 'Rojas';
