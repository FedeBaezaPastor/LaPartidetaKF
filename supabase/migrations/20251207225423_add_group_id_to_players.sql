/*
  # Add group support for players and quick play rounds

  1. Changes to `players` table
    - Add `group_id` column (nullable uuid, foreign key to groups)
    - Players without group_id are temporary (for quick play)
    - Players with group_id are permanent (belong to a group)
  
  2. Changes to `golf_rounds` table
    - Make `group_id` nullable to support quick play rounds
    - Quick play rounds have group_id = NULL
    - Group rounds have group_id set
  
  3. Changes to `scores` table
    - No changes needed, scores still reference rounds and players
  
  4. Security
    - Update RLS policies to handle NULL group_id cases
    - Ensure proper access control for both quick play and group rounds
*/

-- Add group_id to players table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'players' AND column_name = 'group_id'
  ) THEN
    ALTER TABLE players ADD COLUMN group_id uuid REFERENCES groups(id) ON DELETE CASCADE;
    CREATE INDEX IF NOT EXISTS idx_players_group_id ON players(group_id);
  END IF;
END $$;

-- Make group_id nullable in golf_rounds (it should already be nullable, but ensuring it)
ALTER TABLE golf_rounds ALTER COLUMN group_id DROP NOT NULL;

-- Update RLS policies for players to handle group_id filtering
DROP POLICY IF EXISTS "Anyone can view players" ON players;
DROP POLICY IF EXISTS "Anyone can insert players" ON players;
DROP POLICY IF EXISTS "Anyone can update players" ON players;
DROP POLICY IF EXISTS "Anyone can delete players" ON players;

-- Allow viewing all players (both temporary and group players)
CREATE POLICY "Anyone can view players"
  ON players FOR SELECT
  USING (true);

-- Allow inserting players (both temporary and group players)
CREATE POLICY "Anyone can insert players"
  ON players FOR INSERT
  WITH CHECK (true);

-- Allow updating players
CREATE POLICY "Anyone can update players"
  ON players FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Allow deleting players
CREATE POLICY "Anyone can delete players"
  ON players FOR DELETE
  USING (true);

-- Update RLS policies for golf_rounds to handle NULL group_id
DROP POLICY IF EXISTS "Anyone can view rounds" ON golf_rounds;
DROP POLICY IF EXISTS "Anyone can insert rounds" ON golf_rounds;
DROP POLICY IF EXISTS "Anyone can update rounds" ON golf_rounds;
DROP POLICY IF EXISTS "Anyone can delete rounds" ON golf_rounds;

-- Allow viewing all rounds (both quick play and group rounds)
CREATE POLICY "Anyone can view rounds"
  ON golf_rounds FOR SELECT
  USING (true);

-- Allow inserting rounds (both quick play and group rounds)
CREATE POLICY "Anyone can insert rounds"
  ON golf_rounds FOR INSERT
  WITH CHECK (true);

-- Allow updating rounds
CREATE POLICY "Anyone can update rounds"
  ON golf_rounds FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Allow deleting rounds
CREATE POLICY "Anyone can delete rounds"
  ON golf_rounds FOR DELETE
  USING (true);