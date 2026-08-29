/*
  # Add Groups Table

  1. New Tables
    - `groups`
      - `id` (uuid, primary key)
      - `name` (text) - Optional friendly name for the group
      - `group_code` (text, unique) - 6-digit code to join the group
      - `created_at` (timestamptz)
      - `created_by` (text) - user_id of creator
  
  2. Changes
    - Add `group_id` (uuid) to `golf_rounds` table
    - Add foreign key constraint from `golf_rounds.group_id` to `groups.id`
  
  3. Security
    - Enable RLS on `groups` table
    - Allow anyone to read groups if they know the group_code
    - Allow anyone to create groups
*/

-- Create groups table
CREATE TABLE IF NOT EXISTS groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text,
  group_code text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now(),
  created_by text
);

-- Add group_id to golf_rounds
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'group_id'
  ) THEN
    ALTER TABLE golf_rounds ADD COLUMN group_id uuid REFERENCES groups(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Enable RLS on groups
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;

-- Allow anyone to create groups
CREATE POLICY "Anyone can create groups"
  ON groups FOR INSERT
  WITH CHECK (true);

-- Allow anyone to read groups (they need to know the group_code to find it)
CREATE POLICY "Anyone can read groups"
  ON groups FOR SELECT
  USING (true);

-- Create index on group_code for faster lookups
CREATE INDEX IF NOT EXISTS idx_groups_group_code ON groups(group_code);

-- Create index on golf_rounds.group_id
CREATE INDEX IF NOT EXISTS idx_golf_rounds_group_id ON golf_rounds(group_id);