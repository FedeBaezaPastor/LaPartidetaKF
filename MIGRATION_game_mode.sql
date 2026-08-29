/*
# Add game_mode column to golf_rounds

## Summary
Adds a `game_mode` column to the `golf_rounds` table to support multiple game modes:
- stableford (default): existing behavior, points-based scoring
- match: 2 players only, hole-by-hole match play (win/lose/halve)
- sindicato: 3 players only, 6 points distributed per hole (4/2/0, 3/3/0, or 4/1/1)
- parejas: 2 pairs of 2 players (4 total), team-based scoring

Also adds a `mode_points` column to `round_scores` to store mode-specific results.

## New Columns
1. `golf_rounds.game_mode` (text, NOT NULL, DEFAULT 'stableford')
2. `round_scores.mode_points` (numeric, nullable, default 0)

## How to apply
Run this SQL in the Supabase SQL Editor (Dashboard > SQL Editor > New query)
or via psql using the SUPABASE_DB_URL connection string.

## ROLLBACK
See ROLLBACK_game_mode.sql to revert these changes.
*/

-- Add game_mode to golf_rounds
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'game_mode'
  ) THEN
    ALTER TABLE golf_rounds ADD COLUMN game_mode text NOT NULL DEFAULT 'stableford';
  END IF;
END $$;

-- Add mode_points to round_scores
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'round_scores' AND column_name = 'mode_points'
  ) THEN
    ALTER TABLE round_scores ADD COLUMN mode_points numeric DEFAULT 0;
  END IF;
END $$;
