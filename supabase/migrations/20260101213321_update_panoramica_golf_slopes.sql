/*
  # Update Panorámica Golf Slope Ratings

  ## Overview
  Updates the slope ratings for all tees (barras) at Panorámica Golf based on official data.

  ## Changes
    - Barras Blancas: slope_18 = 136, slope_9_i = 136, slope_9_ii = 136
    - Barras Amarillas: slope_18 = 132, slope_9_i = 128, slope_9_ii = 137
    - Barras Azules: slope_18 = 123, slope_9_i = 123, slope_9_ii = 122
    - Barras Rojas: slope_18 = 118, slope_9_i = 118, slope_9_ii = 119

  ## Notes
    - All slopes (18-hole, front nine 1-9, and back nine 10-18) are now updated with official data
*/

-- Update Barras Blancas
UPDATE tees
SET 
  slope_18 = 136,
  slope_9_i = 136,
  slope_9_ii = 136
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Panorámica Golf')
  AND name = 'Blancas';

-- Update Barras Amarillas
UPDATE tees
SET 
  slope_18 = 132,
  slope_9_i = 128,
  slope_9_ii = 137
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Panorámica Golf')
  AND name = 'Amarillas';

-- Update Barras Azules
UPDATE tees
SET 
  slope_18 = 123,
  slope_9_i = 123,
  slope_9_ii = 122
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Panorámica Golf')
  AND name = 'Azules';

-- Update Barras Rojas
UPDATE tees
SET 
  slope_18 = 118,
  slope_9_i = 118,
  slope_9_ii = 119
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Panorámica Golf')
  AND name = 'Rojas';
