/*
  # Allow Public Access to Golf Tables

  1. Changes
    - Drop existing restrictive RLS policies
    - Add permissive policies to allow anyone to read and write data
    - This is for development/testing purposes

  2. Security
    - All tables remain with RLS enabled
    - New policies allow public access for INSERT, SELECT, UPDATE, DELETE
*/

-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can view courses" ON golf_courses;
DROP POLICY IF EXISTS "Anyone can view holes" ON golf_holes;
DROP POLICY IF EXISTS "Users can create rounds" ON golf_rounds;
DROP POLICY IF EXISTS "Anyone can view active rounds" ON golf_rounds;
DROP POLICY IF EXISTS "Round creator can update status" ON golf_rounds;
DROP POLICY IF EXISTS "Anyone can view round players" ON round_players;
DROP POLICY IF EXISTS "Anyone can add players to rounds" ON round_players;
DROP POLICY IF EXISTS "Anyone can remove players from rounds" ON round_players;
DROP POLICY IF EXISTS "Anyone can view round scores" ON round_scores;
DROP POLICY IF EXISTS "Anyone can record scores" ON round_scores;

-- Golf Courses - Public access
CREATE POLICY "Public can view courses"
  ON golf_courses FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Public can insert courses"
  ON golf_courses FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Golf Holes - Public access
CREATE POLICY "Public can view holes"
  ON golf_holes FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Public can update holes"
  ON golf_holes FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Public can insert holes"
  ON golf_holes FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Golf Rounds - Public access
CREATE POLICY "Public can view rounds"
  ON golf_rounds FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Public can create rounds"
  ON golf_rounds FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Public can update rounds"
  ON golf_rounds FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Round Players - Public access
CREATE POLICY "Public can view players"
  ON round_players FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Public can add players"
  ON round_players FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Public can remove players"
  ON round_players FOR DELETE
  TO anon, authenticated
  USING (true);

-- Round Scores - Public access
CREATE POLICY "Public can view scores"
  ON round_scores FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Public can insert scores"
  ON round_scores FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Public can update scores"
  ON round_scores FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);
