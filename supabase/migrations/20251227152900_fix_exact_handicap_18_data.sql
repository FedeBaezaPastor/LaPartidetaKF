/*
  # Fix exact_handicap_18 data

  1. Changes
    - Set exact_handicap_18 equal to exact_handicap for all players
    - This fixes incorrect data from previous migrations
*/

UPDATE players
SET exact_handicap_18 = exact_handicap;

UPDATE round_players
SET exact_handicap_18 = exact_handicap;
