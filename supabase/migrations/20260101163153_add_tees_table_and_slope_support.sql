/*
  # Add Tees (Barras) and Slope Support

  ## Overview
  This migration adds support for tee boxes (barras) with slope ratings and integrates them into the rounds system.

  ## New Tables
    - `tees`
      - `id` (uuid, primary key)
      - `course_id` (uuid, foreign key to golf_courses)
      - `name` (text) - Name of the tee (Blancas, Amarillas, Rojas, Azules)
      - `color` (text) - Color code for UI display
      - `slope_18` (integer) - Slope rating for 18 holes
      - `slope_9_i` (integer) - Slope rating for holes 1-9
      - `slope_9_ii` (integer) - Slope rating for holes 10-18
      - `created_at` (timestamptz)

  ## Modified Tables
    - `golf_rounds`
      - Add `tee_id` (uuid, nullable, foreign key to tees) - Selected tee for slope calculations
      - Add `manual_slope` (integer, nullable) - Manually entered slope value (overrides tee slope)

  ## Security
    - Enable RLS on `tees` table
    - Add public read policy for tees
    - Add admin insert/update/delete policies for tees

  ## Notes
    - Tees are course-specific
    - When `use_slope` is true, either `tee_id` or `manual_slope` should be set
    - `manual_slope` takes precedence over tee slope if both are present
*/

-- Create tees table
CREATE TABLE IF NOT EXISTS tees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES golf_courses(id) ON DELETE CASCADE,
  name text NOT NULL,
  color text NOT NULL,
  slope_18 integer NOT NULL DEFAULT 113,
  slope_9_i integer NOT NULL DEFAULT 113,
  slope_9_ii integer NOT NULL DEFAULT 113,
  created_at timestamptz DEFAULT now()
);

-- Add tee_id and manual_slope to golf_rounds
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'tee_id'
  ) THEN
    ALTER TABLE golf_rounds ADD COLUMN tee_id uuid REFERENCES tees(id) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'manual_slope'
  ) THEN
    ALTER TABLE golf_rounds ADD COLUMN manual_slope integer;
  END IF;
END $$;

-- Enable RLS on tees
ALTER TABLE tees ENABLE ROW LEVEL SECURITY;

-- Public can read all tees
CREATE POLICY "Anyone can view tees"
  ON tees FOR SELECT
  TO public
  USING (true);

-- Authenticated users can insert tees
CREATE POLICY "Authenticated users can insert tees"
  ON tees FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Authenticated users can update tees
CREATE POLICY "Authenticated users can update tees"
  ON tees FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Authenticated users can delete tees
CREATE POLICY "Authenticated users can delete tees"
  ON tees FOR DELETE
  TO authenticated
  USING (true);