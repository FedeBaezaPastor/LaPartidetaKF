-- ROLLBACK: Remove game_mode column from golf_rounds
-- Run this ONLY if you need to revert the game_mode migration
-- Date: 2026-08-17

ALTER TABLE golf_rounds DROP COLUMN IF EXISTS game_mode;
ALTER TABLE round_scores DROP COLUMN IF EXISTS mode_points;

-- Note: This will NOT affect any existing data since game_mode has a default
-- and mode_points is nullable. All existing rounds will continue to work
-- as stableford (the default).
