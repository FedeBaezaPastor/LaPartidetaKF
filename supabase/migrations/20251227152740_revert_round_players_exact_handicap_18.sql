/*
  # Revert exact_handicap_18 values in round_players

  1. Changes
    - Revert exact_handicap_18 in round_players table to be equal to exact_handicap
    - This restores the original behavior where both values are the same (9-hole handicap)
*/

UPDATE round_players
SET exact_handicap_18 = exact_handicap / 2
WHERE exact_handicap_18 = exact_handicap * 2;
