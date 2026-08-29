/*
  # Add user_id to golf_rounds table for user-specific filtering

  1. Changes
    - Add `user_id` column to `golf_rounds` table (text, required)
    - Add index on `user_id` for better query performance
    - Update existing rows with a placeholder user_id
  
  2. Purpose
    - Enable each user to have their own set of rounds
    - Filter rounds by user to prevent mixing between different users
    - Each device/browser will have a unique user_id stored locally
    - This is separate from the auth.users system (created_by field)
  
  3. Notes
    - Existing rounds will be assigned a default user_id
    - New rounds must include a user_id when created
*/

-- Add user_id column to golf_rounds table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'golf_rounds' AND column_name = 'user_id'
  ) THEN
    ALTER TABLE golf_rounds ADD COLUMN user_id text;
  END IF;
END $$;

-- Update existing rows with a default user_id (for any existing data)
UPDATE golf_rounds
SET user_id = 'legacy_user'
WHERE user_id IS NULL;

-- Make user_id NOT NULL after setting default values
ALTER TABLE golf_rounds ALTER COLUMN user_id SET NOT NULL;

-- Add index for better query performance when filtering by user_id
CREATE INDEX IF NOT EXISTS idx_golf_rounds_user_id ON golf_rounds(user_id);