/*
  # Add DELETE policy for golf_rounds

  1. Security Changes
    - Add policy to allow public users to delete rounds
    - This allows anyone to delete any round (suitable for a shared golf app)
*/

-- Drop policy if exists
DROP POLICY IF EXISTS "Public can delete rounds" ON golf_rounds;

-- Allow public users to delete rounds
CREATE POLICY "Public can delete rounds"
  ON golf_rounds
  FOR DELETE
  TO anon, authenticated
  USING (true);
