/*
  # Restore Correct Player Handicaps (Jan 15, 2026)

  1. Purpose
    - Restore player handicaps to their correct values before test rounds
    - Test rounds modified several player handicaps incorrectly
    
  2. Changes
    - Alfonso Cardona: 10 → 9
    - Guti: 4 → 5
    - Kike Algora: 10 → 11
    - Victor Zeyani: 3 → 4
    - Ángel Arrufat: 12 → 11
    
  3. Notes
    - Other players remain unchanged
    - This ensures historical accuracy after test round deletion
*/

-- Update Alfonso Cardona
UPDATE players
SET exact_handicap_18 = '9'
WHERE name = 'Alfonso Cardona'
AND group_id = (SELECT id FROM groups WHERE name = 'Divend Beer Golf');

-- Update Guti
UPDATE players
SET exact_handicap_18 = '5'
WHERE name = 'Guti'
AND group_id = (SELECT id FROM groups WHERE name = 'Divend Beer Golf');

-- Update Kike Algora
UPDATE players
SET exact_handicap_18 = '11'
WHERE name = 'Kike Algora'
AND group_id = (SELECT id FROM groups WHERE name = 'Divend Beer Golf');

-- Update Victor Zeyani
UPDATE players
SET exact_handicap_18 = '4'
WHERE name = 'Victor Zeyani'
AND group_id = (SELECT id FROM groups WHERE name = 'Divend Beer Golf');

-- Update Ángel Arrufat
UPDATE players
SET exact_handicap_18 = '11'
WHERE name = 'Ángel Arrufat'
AND group_id = (SELECT id FROM groups WHERE name = 'Divend Beer Golf');
