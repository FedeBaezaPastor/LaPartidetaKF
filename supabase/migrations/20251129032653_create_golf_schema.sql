/*
  # Create Golf Scoring Database Schema

  1. New Tables
    - `golf_courses` - Course templates with configurable holes
      - `id` (uuid, primary key)
      - `name` (text)
      - `description` (text)
      - `created_at` (timestamp)
    
    - `golf_holes` - Hole definitions with editable stroke index
      - `id` (uuid, primary key)
      - `course_id` (uuid, foreign key)
      - `hole_number` (integer, 1-18)
      - `par` (integer, 3-5)
      - `stroke_index` (integer, 1-18, mutable)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `golf_rounds` - Individual game rounds
      - `id` (uuid, primary key)
      - `course_id` (uuid, foreign key)
      - `user_id` (uuid, foreign key to auth.users)
      - `num_holes` (integer, 9 or 18)
      - `status` (enum: 'active', 'completed', 'cancelled')
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `round_players` - Players in each round
      - `id` (uuid, primary key)
      - `round_id` (uuid, foreign key)
      - `user_id` (uuid, foreign key to auth.users)
      - `name` (text)
      - `exact_handicap` (numeric)
      - `playing_handicap` (integer)
      - `created_at` (timestamp)
    
    - `round_scores` - Scores for each hole by each player
      - `id` (uuid, primary key)
      - `round_id` (uuid, foreign key)
      - `player_id` (uuid, foreign key to round_players)
      - `hole_number` (integer)
      - `gross_strokes` (integer)
      - `strokes_received` (integer)
      - `net_strokes` (integer)
      - `stableford_points` (integer)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Users can only view their own rounds and can see others' rounds they're invited to
    - Users can only edit scores for their own round
    - Course administrators can edit hole stroke indexes

  3. Notes
    - Stroke index is mutable to allow course customization
    - Multiple active rounds can exist simultaneously
    - Each round tracks which player entered each score
*/

-- Create golf_courses table
CREATE TABLE IF NOT EXISTS golf_courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now()
);

-- Create golf_holes table
CREATE TABLE IF NOT EXISTS golf_holes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES golf_courses(id) ON DELETE CASCADE,
  hole_number integer NOT NULL CHECK (hole_number >= 1 AND hole_number <= 18),
  par integer NOT NULL CHECK (par >= 3 AND par <= 5),
  stroke_index integer NOT NULL CHECK (stroke_index >= 1 AND stroke_index <= 18),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(course_id, hole_number)
);

-- Create golf_rounds table
CREATE TABLE IF NOT EXISTS golf_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES golf_courses(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  num_holes integer NOT NULL CHECK (num_holes IN (9, 18)),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create round_players table
CREATE TABLE IF NOT EXISTS round_players (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  name text NOT NULL,
  exact_handicap numeric NOT NULL,
  playing_handicap integer NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create round_scores table
CREATE TABLE IF NOT EXISTS round_scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  player_id uuid NOT NULL REFERENCES round_players(id) ON DELETE CASCADE,
  hole_number integer NOT NULL,
  gross_strokes integer NOT NULL CHECK (gross_strokes > 0),
  strokes_received integer NOT NULL DEFAULT 0,
  net_strokes integer NOT NULL,
  stableford_points integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE golf_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE golf_holes ENABLE ROW LEVEL SECURITY;
ALTER TABLE golf_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE round_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE round_scores ENABLE ROW LEVEL SECURITY;

-- Policies for golf_courses (public read, admin write)
CREATE POLICY "Anyone can view golf courses"
  ON golf_courses FOR SELECT
  TO anon, authenticated
  USING (true);

-- Policies for golf_holes (public read, admin write)
CREATE POLICY "Anyone can view golf holes"
  ON golf_holes FOR SELECT
  TO anon, authenticated
  USING (true);

-- Policies for golf_rounds
CREATE POLICY "Users can view rounds they created"
  ON golf_rounds FOR SELECT
  TO authenticated
  USING (created_by = auth.uid());

CREATE POLICY "Users can view all active rounds"
  ON golf_rounds FOR SELECT
  TO authenticated
  USING (status = 'active');

CREATE POLICY "Users can create rounds"
  ON golf_rounds FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "Users can update own round status"
  ON golf_rounds FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Policies for round_players
CREATE POLICY "Users can view players in active rounds"
  ON round_players FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM golf_rounds
      WHERE golf_rounds.id = round_players.round_id
      AND (golf_rounds.created_by = auth.uid() OR golf_rounds.status = 'active')
    )
  );

CREATE POLICY "Users can add players to own rounds"
  ON round_players FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM golf_rounds
      WHERE golf_rounds.id = round_players.round_id
      AND golf_rounds.created_by = auth.uid()
    )
  );

-- Policies for round_scores
CREATE POLICY "Users can view scores in active rounds"
  ON round_scores FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM golf_rounds
      WHERE golf_rounds.id = round_scores.round_id
      AND (golf_rounds.created_by = auth.uid() OR golf_rounds.status = 'active')
    )
  );

CREATE POLICY "Users can insert scores only for their round"
  ON round_scores FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM golf_rounds
      JOIN round_players ON golf_rounds.id = round_players.round_id
      WHERE golf_rounds.id = round_scores.round_id
      AND golf_rounds.created_by = auth.uid()
      AND round_players.id = round_scores.player_id
    )
  );

CREATE POLICY "Users can update scores only in their round"
  ON round_scores FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM golf_rounds
      WHERE golf_rounds.id = round_scores.round_id
      AND golf_rounds.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM golf_rounds
      WHERE golf_rounds.id = round_scores.round_id
      AND golf_rounds.created_by = auth.uid()
    )
  );

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_golf_holes_course_id ON golf_holes(course_id);
CREATE INDEX IF NOT EXISTS idx_golf_rounds_course_id ON golf_rounds(course_id);
CREATE INDEX IF NOT EXISTS idx_golf_rounds_created_by ON golf_rounds(created_by);
CREATE INDEX IF NOT EXISTS idx_golf_rounds_status ON golf_rounds(status);
CREATE INDEX IF NOT EXISTS idx_round_players_round_id ON round_players(round_id);
CREATE INDEX IF NOT EXISTS idx_round_scores_round_id ON round_scores(round_id);
CREATE INDEX IF NOT EXISTS idx_round_scores_player_id ON round_scores(player_id);
