/*
  # Create Players Table

  1. New Tables
    - `players`
      - `id` (uuid, primary key)
      - `name` (text, unique) - Player's name
      - `exact_handicap` (numeric) - Player's exact handicap
      - `created_at` (timestamptz) - When player was created
      - `updated_at` (timestamptz) - When player was last updated

  2. Security
    - Enable RLS on `players` table
    - Add policy for public read access
    - Add policy for public insert access
    - Add policy for public update access

  3. Indexes
    - Add index on name for faster searches
*/

-- Create players table
CREATE TABLE IF NOT EXISTS players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL,
  exact_handicap numeric NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE players ENABLE ROW LEVEL SECURITY;

-- Create policies for public access
CREATE POLICY "Public can view players"
  ON players FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Public can create players"
  ON players FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Public can update players"
  ON players FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Create index for faster name searches
CREATE INDEX IF NOT EXISTS idx_players_name ON players(name);

-- Add player_id reference to round_players table
ALTER TABLE round_players 
ADD COLUMN IF NOT EXISTS player_id uuid REFERENCES players(id);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_round_players_player_id ON round_players(player_id);
