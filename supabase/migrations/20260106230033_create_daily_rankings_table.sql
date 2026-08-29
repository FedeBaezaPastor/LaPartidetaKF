/*
  # Create daily rankings table

  1. New Tables
    - `daily_rankings`
      - `id` (uuid, primary key)
      - `group_id` (uuid, references groups) - The group this ranking belongs to
      - `ranking_date` (date) - The date of the ranking
      - `player_name` (text) - Player name
      - `total_points` (numeric) - Total points for the day (sum of all rounds)
      - `position` (integer) - Final position (1, 2, 3...)
      - `receives_beer` (boolean) - Whether player receives beer
      - `pays_beer` (boolean) - Whether player pays beer
      - `created_at` (timestamptz) - When this ranking was created
      - Unique constraint on (group_id, ranking_date, player_name)

  2. Security
    - Enable RLS on `daily_rankings` table
    - Add policies for public read access

  3. Notes
    - This table stores the final daily classification
    - Beer calculations are based on this daily ranking, not individual rounds
    - For odd number of players: floor(n/2) receive, 1 neutral, floor(n/2) pay
    - For even number of players: n/2 receive, n/2 pay
*/

CREATE TABLE IF NOT EXISTS daily_rankings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
  ranking_date date NOT NULL,
  player_name text NOT NULL,
  total_points numeric NOT NULL DEFAULT 0,
  position integer NOT NULL,
  receives_beer boolean NOT NULL DEFAULT false,
  pays_beer boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE(group_id, ranking_date, player_name)
);

ALTER TABLE daily_rankings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to daily rankings"
  ON daily_rankings
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Allow public insert to daily rankings"
  ON daily_rankings
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Allow public update to daily rankings"
  ON daily_rankings
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow public delete from daily rankings"
  ON daily_rankings
  FOR DELETE
  TO public
  USING (true);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_daily_rankings_group_date 
  ON daily_rankings(group_id, ranking_date);
