/*
  # Fix exact_handicap_18 for Guti and Juan Bosch

  1. Problem
    - exact_handicap_18 still shows old values
    - Guti: exact_handicap_18 = 2.0, should be 3.0
    - Juan Bosch: exact_handicap_18 = 4.0, should be 5.0
    - Frontend uses exact_handicap_18 when available

  2. Changes
    - Update exact_handicap_18 for Guti to 3.0
    - Update exact_handicap_18 for Juan Bosch to 5.0
*/

UPDATE players
SET exact_handicap_18 = 3.0
WHERE name = 'Guti';

UPDATE players
SET exact_handicap_18 = 5.0
WHERE name = 'Juan Bosch';
