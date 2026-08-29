/*
  # Fix exact_handicap_18 values

  1. Changes
    - Update exact_handicap_18 in players table to be double the exact_handicap (9-hole handicap)
    - This ensures proper conversion when switching between 9 and 18 hole courses
*/

UPDATE players
SET exact_handicap_18 = exact_handicap * 2
WHERE exact_handicap_18 = exact_handicap;
