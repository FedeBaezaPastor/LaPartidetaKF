/*
  # Fix players unique constraint for multi-group support

  1. Problem
    - Current UNIQUE constraint on `name` prevents different groups from having players with same name
    - Need to allow same name in different groups, but prevent duplicates within same group

  2. Solution
    - Drop the existing UNIQUE constraint on `name` column
    - Create a UNIQUE partial index that combines `name` and `group_id`
    - Create a separate UNIQUE partial index for players without group (group_id IS NULL)
    - This allows same name across different groups while preventing duplicates within same group

  3. Changes
    - Remove UNIQUE constraint from `name` column
    - Add composite UNIQUE index for (name, group_id) where group_id IS NOT NULL
    - Add UNIQUE index for name where group_id IS NULL (for quick play)
*/

-- Drop the existing unique constraint on name
ALTER TABLE players DROP CONSTRAINT IF EXISTS players_name_key;

-- Create a unique index for players within groups (same name allowed across groups)
CREATE UNIQUE INDEX IF NOT EXISTS players_name_group_id_unique 
  ON players(name, group_id) 
  WHERE group_id IS NOT NULL;

-- Create a unique index for players without group (quick play)
-- This ensures no duplicate names for temporary players
CREATE UNIQUE INDEX IF NOT EXISTS players_name_no_group_unique 
  ON players(name) 
  WHERE group_id IS NULL;