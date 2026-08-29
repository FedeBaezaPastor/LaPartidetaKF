/*
  # Make created_by field nullable

  1. Changes
    - Alter golf_rounds table to make created_by nullable
    - This allows creating rounds without authentication

  2. Notes
    - The foreign key constraint remains but the field can now be NULL
    - Existing data is not affected
*/

-- Make created_by nullable
ALTER TABLE golf_rounds 
ALTER COLUMN created_by DROP NOT NULL;
