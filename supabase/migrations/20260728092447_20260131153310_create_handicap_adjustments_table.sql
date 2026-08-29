/*
# Create handicap_adjustments table

Tracks per-round handicap adjustments applied to players based on daily rankings.

1. New Tables
- `handicap_adjustments`
  - `id` (uuid, primary key)
  - `group_id` (uuid, references groups)
  - `player_id` (uuid, references players)
  - `player_name` (text)
  - `adjustment_date` (date)
  - `ranking_position` (integer)
  - `hcp_before` (numeric)
  - `hcp_after` (numeric)
  - `adjustment` (numeric)
  - `playing_handicap_before` (numeric, nullable)
  - `archived_round_id` (uuid, references archived_rounds, ON DELETE SET NULL)
  - `created_at` (timestamptz, default now())

2. Constraints
- Unique: (group_id, player_id, adjustment_date) - initial constraint
- FK: group_id -> groups, player_id -> players, archived_round_id -> archived_rounds

3. Security
- RLS enabled
- Public CRUD policies (no-auth app, shared data)
*/

CREATE TABLE IF NOT EXISTS handicap_adjustments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid REFERENCES groups(id) ON DELETE CASCADE,
  player_id uuid REFERENCES players(id) ON DELETE CASCADE,
  player_name text,
  adjustment_date date,
  ranking_position integer,
  hcp_before numeric,
  hcp_after numeric,
  adjustment numeric,
  playing_handicap_before numeric,
  archived_round_id uuid REFERENCES archived_rounds(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Initial unique constraint (will be replaced by per-round constraint later)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'handicap_adjustments_group_id_player_id_adjustment_date_key'
  ) THEN
    ALTER TABLE handicap_adjustments
    ADD CONSTRAINT handicap_adjustments_group_id_player_id_adjustment_date_key
    UNIQUE (group_id, player_id, adjustment_date);
  END IF;
END $$;

ALTER TABLE handicap_adjustments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read handicap adjustments" ON handicap_adjustments;
CREATE POLICY "Anyone can read handicap adjustments"
  ON handicap_adjustments FOR SELECT
  TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Anyone can insert handicap adjustments" ON handicap_adjustments;
CREATE POLICY "Anyone can insert handicap adjustments"
  ON handicap_adjustments FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can update handicap adjustments" ON handicap_adjustments;
CREATE POLICY "Anyone can update handicap adjustments"
  ON handicap_adjustments FOR UPDATE
  TO anon, authenticated
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anyone can delete handicap adjustments" ON handicap_adjustments;
CREATE POLICY "Anyone can delete handicap adjustments"
  ON handicap_adjustments FOR DELETE
  TO anon, authenticated
  USING (true);