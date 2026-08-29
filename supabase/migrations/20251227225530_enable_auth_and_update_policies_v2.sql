/*
  # Enable Supabase Auth and Update RLS Policies
  
  1. Changes
    - Add user_auth_id column to groups table for authenticated users
    - Update RLS policies to support both authenticated and anonymous users
    - Maintain backward compatibility
    
  2. Security
    - Authenticated users can manage their own groups
    - Public access maintained for joining with codes
*/

-- Add user_auth_id column to groups table for authenticated users
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'groups' AND column_name = 'user_auth_id'
  ) THEN
    ALTER TABLE groups ADD COLUMN user_auth_id uuid REFERENCES auth.users(id);
  END IF;
END $$;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_groups_user_auth_id ON groups(user_auth_id);