/*
  # Create Statistics and Archive Tables

  ## New Tables
  
  1. `seasons`
     - `id` (uuid, primary key)
     - `group_id` (uuid, FK to groups) - which group this season belongs to
     - `name` (text) - season name, e.g., "2026", "Temporada Invierno 2026"
     - `start_date` (date) - when the season starts
     - `end_date` (date, nullable) - when the season ends (null if active)
     - `created_at` (timestamptz)

  2. `archived_rounds`
     - `id` (uuid, primary key)
     - `group_id` (uuid, FK to groups) - the group that played this round
     - `course_name` (text) - name of the course played
     - `played_at` (timestamptz) - when the round was played
     - `archived_at` (timestamptz) - when it was archived
     - `final_ranking` (jsonb) - array of objects: [{ position, player_name, points, hcp_juego }]
     - `season_id` (uuid, FK to seasons) - which season this round belongs to
     - `created_at` (timestamptz)

  3. `handicap_history`
     - `id` (uuid, primary key)
     - `player_id` (uuid, FK to players) - the player whose handicap changed
     - `group_id` (uuid, FK to groups) - the group context
     - `old_handicap` (numeric) - previous handicap value
     - `new_handicap` (numeric) - new handicap value
     - `changed_at` (timestamptz) - when the change occurred
     - `archived_round_id` (uuid, FK to archived_rounds) - which round caused this change
     - `created_at` (timestamptz)

  ## Security
  - Enable RLS on all tables
  - Add public access policies for all operations (no auth required)

  ## Notes
  - Only multipartidetas (group rounds) are archived
  - Quick rounds (partideta rápida) are NOT archived
  - Statistics are calculated from archived_rounds data
  - DIVEND group has special rules that are filtered by group_id
*/

-- Create seasons table
CREATE TABLE IF NOT EXISTS seasons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  name text NOT NULL,
  start_date date NOT NULL,
  end_date date,
  created_at timestamptz DEFAULT now()
);

-- Create archived_rounds table
CREATE TABLE IF NOT EXISTS archived_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  course_name text NOT NULL,
  played_at timestamptz NOT NULL,
  archived_at timestamptz DEFAULT now(),
  final_ranking jsonb NOT NULL,
  season_id uuid REFERENCES seasons(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Create handicap_history table
CREATE TABLE IF NOT EXISTS handicap_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  group_id uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  old_handicap numeric NOT NULL,
  new_handicap numeric NOT NULL,
  changed_at timestamptz DEFAULT now(),
  archived_round_id uuid REFERENCES archived_rounds(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE seasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE archived_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE handicap_history ENABLE ROW LEVEL SECURITY;

-- Public access policies for seasons
CREATE POLICY "Anyone can view seasons"
  ON seasons FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Anyone can insert seasons"
  ON seasons FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Anyone can update seasons"
  ON seasons FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Anyone can delete seasons"
  ON seasons FOR DELETE
  TO public
  USING (true);

-- Public access policies for archived_rounds
CREATE POLICY "Anyone can view archived rounds"
  ON archived_rounds FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Anyone can insert archived rounds"
  ON archived_rounds FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Anyone can update archived rounds"
  ON archived_rounds FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Anyone can delete archived rounds"
  ON archived_rounds FOR DELETE
  TO public
  USING (true);

-- Public access policies for handicap_history
CREATE POLICY "Anyone can view handicap history"
  ON handicap_history FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Anyone can insert handicap history"
  ON handicap_history FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Anyone can update handicap history"
  ON handicap_history FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Anyone can delete handicap history"
  ON handicap_history FOR DELETE
  TO public
  USING (true);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_archived_rounds_group_id ON archived_rounds(group_id);
CREATE INDEX IF NOT EXISTS idx_archived_rounds_season_id ON archived_rounds(season_id);
CREATE INDEX IF NOT EXISTS idx_archived_rounds_played_at ON archived_rounds(played_at);
CREATE INDEX IF NOT EXISTS idx_handicap_history_player_id ON handicap_history(player_id);
CREATE INDEX IF NOT EXISTS idx_handicap_history_group_id ON handicap_history(group_id);
CREATE INDEX IF NOT EXISTS idx_seasons_group_id ON seasons(group_id);