/*
  # Fix exact_handicap_18 values in round_players

  1. Changes
    - Update exact_handicap_18 in round_players table to be double the exact_handicap (9-hole handicap)
    - This fixes existing rounds that may have incorrect handicap values
*/

UPDATE round_players
SET exact_handicap_18 = exact_handicap * 2
WHERE exact_handicap_18 = exact_handicap;
