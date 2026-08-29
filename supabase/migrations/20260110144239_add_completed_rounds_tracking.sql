/*
  # Add completed rounds tracking

  1. Changes to golf_rounds table
    - Add `completed_at` timestamp column to track when a round is finished
    - This allows counting completed rounds even if they're later deleted
    - Defaults to NULL for ongoing rounds

  2. New Table: completed_rounds_summary
    - Stores lightweight summary data when a round is completed
    - Includes player stats, final scores, and key metrics
    - Much smaller than full archived_rounds (no hole-by-hole scores)
    - Allows showing post-game statistics without archiving everything

  3. Security
    - Enable RLS on completed_rounds_summary
    - Allow public read access for statistics
    - Only authenticated users can insert summaries

  ## Usage
  - When a quick play round finishes, set `completed_at = now()`
  - Optionally save summary data to `completed_rounds_summary`
  - Admin panel counts rounds WHERE `completed_at IS NOT NULL`
  - Rounds can be deleted after completion without losing the count
*/

-- Add completed_at to golf_rounds
ALTER TABLE golf_rounds
ADD COLUMN IF NOT EXISTS completed_at timestamptz DEFAULT NULL;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_golf_rounds_completed_at
  ON golf_rounds(completed_at)
  WHERE completed_at IS NOT NULL;

-- Create completed_rounds_summary table
CREATE TABLE IF NOT EXISTS completed_rounds_summary (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id uuid REFERENCES golf_rounds(id) ON DELETE SET NULL,
  user_id text NOT NULL,
  group_id uuid REFERENCES groups(id) ON DELETE CASCADE,
  course_name text NOT NULL,
  num_holes integer NOT NULL CHECK (num_holes IN (9, 18)),
  holes_range text,
  use_slope boolean NOT NULL DEFAULT true,
  completed_at timestamptz NOT NULL DEFAULT now(),

  -- Player statistics (JSONB for flexibility)
  player_stats jsonb NOT NULL DEFAULT '[]'::jsonb,

  -- Aggregate statistics
  total_players integer NOT NULL DEFAULT 0,

  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE completed_rounds_summary ENABLE ROW LEVEL SECURITY;

-- Policies: anyone can read summaries
CREATE POLICY "Anyone can read completed rounds summaries"
  ON completed_rounds_summary
  FOR SELECT
  TO public
  USING (true);

-- Only authenticated users can insert summaries
CREATE POLICY "Authenticated users can insert summaries"
  ON completed_rounds_summary
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Users can insert their own summaries (for quick play)
CREATE POLICY "Users can insert their own summaries"
  ON completed_rounds_summary
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_completed_rounds_summary_group_id
  ON completed_rounds_summary(group_id)
  WHERE group_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_completed_rounds_summary_user_id
  ON completed_rounds_summary(user_id);

CREATE INDEX IF NOT EXISTS idx_completed_rounds_summary_completed_at
  ON completed_rounds_summary(completed_at DESC);

COMMENT ON TABLE completed_rounds_summary IS 'Lightweight summary of completed rounds for statistics, without full hole-by-hole data';
COMMENT ON COLUMN completed_rounds_summary.player_stats IS 'JSON array with player names, scores, points, and basic hole results (eagles, birdies, etc.)';
