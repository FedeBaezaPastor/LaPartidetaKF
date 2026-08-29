/*
  # Fix exact_handicap for Guti and Juan Bosch

  1. Problem
    - Guti shows exact_handicap = 2.0, should be 3.0
    - Juan Bosch shows exact_handicap = 4.0, should be 5.0

  2. Changes
    - Update exact_handicap for Guti to 3.0
    - Update exact_handicap for Juan Bosch to 5.0
    - Verify all registered players have correct values
*/

-- Correct exact_handicap values
UPDATE players
SET exact_handicap = 3.0
WHERE name = 'Guti';

UPDATE players
SET exact_handicap = 5.0
WHERE name = 'Juan Bosch';

-- Verify the update
SELECT 
  name,
  exact_handicap,
  playing_handicap
FROM players
WHERE name IN ('Guti', 'Juan Bosch')
ORDER BY name;
