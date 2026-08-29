/*
  # Add DIVEND Beer Statistics

  1. New Tables
    - `beer_stats`
      - `round_id` (uuid, foreign key to golf_rounds)
      - `player_id` (uuid, foreign key to players)
      - `status` (text: 'payer', 'receiver', 'neutral')
      - `position` (integer: position in daily leaderboard)
      - Primary key on (round_id, player_id)

  2. Functions
    - `calculate_beer_stats_for_round(round_id uuid)`: Calculates beer stats based on leaderboard
    - `get_divend_statistics()`: Returns aggregated statistics for DIVEND group

  3. Security
    - Enable RLS on `beer_stats` table
    - Add policies for public read access (since rounds are public)

  4. Notes
    - Beer payers/receivers are determined by position in daily leaderboard
    - If even number of players: top half receives, bottom half pays
    - If odd number of players: top floor(n/2) receives, middle 1 is neutral, bottom floor(n/2) pays
    - This only applies to the DIVEND group
*/

-- Create beer_stats table
CREATE TABLE IF NOT EXISTS beer_stats (
  round_id uuid NOT NULL REFERENCES golf_rounds(id) ON DELETE CASCADE,
  player_id uuid NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('payer', 'receiver', 'neutral')),
  position integer NOT NULL,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (round_id, player_id)
);

-- Enable RLS
ALTER TABLE beer_stats ENABLE ROW LEVEL SECURITY;

-- Allow public read access
CREATE POLICY "Anyone can view beer stats"
  ON beer_stats FOR SELECT
  TO public
  USING (true);

-- Allow insert/update for the calculation function
CREATE POLICY "System can manage beer stats"
  ON beer_stats FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

-- Function to calculate beer stats for a round
CREATE OR REPLACE FUNCTION calculate_beer_stats_for_round(p_round_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_players integer;
  v_receiver_count integer;
  v_payer_start integer;
  v_record record;
  v_position integer;
BEGIN
  -- Delete existing beer stats for this round
  DELETE FROM beer_stats WHERE round_id = p_round_id;

  -- Get total number of players in the round
  SELECT COUNT(*) INTO v_total_players
  FROM scores
  WHERE round_id = p_round_id
  GROUP BY player_id;

  -- Calculate receiver count and payer start position
  v_receiver_count := v_total_players / 2;
  
  IF v_total_players % 2 = 0 THEN
    -- Even: top half receives, bottom half pays
    v_payer_start := v_receiver_count + 1;
  ELSE
    -- Odd: top floor(n/2) receives, middle is neutral, bottom floor(n/2) pays
    v_payer_start := v_receiver_count + 2;
  END IF;

  -- Calculate leaderboard positions and insert beer stats
  v_position := 0;
  
  FOR v_record IN (
    SELECT 
      p.id as player_id,
      SUM(s.points) as total_points
    FROM players p
    INNER JOIN scores s ON s.player_id = p.id
    WHERE s.round_id = p_round_id
    GROUP BY p.id
    ORDER BY SUM(s.points) DESC, p.name ASC
  )
  LOOP
    v_position := v_position + 1;
    
    IF v_position <= v_receiver_count THEN
      -- Top positions: receivers (blue)
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'receiver', v_position);
    ELSIF v_position >= v_payer_start THEN
      -- Bottom positions: payers (red)
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'payer', v_position);
    ELSE
      -- Middle position (only for odd number): neutral (yellow)
      INSERT INTO beer_stats (round_id, player_id, status, position)
      VALUES (p_round_id, v_record.player_id, 'neutral', v_position);
    END IF;
  END LOOP;
END;
$$;

-- Function to get DIVEND statistics
CREATE OR REPLACE FUNCTION get_divend_statistics()
RETURNS TABLE (
  stat_type text,
  player_name text,
  player_id uuid,
  value bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Get group_id for DIVEND
  DECLARE
    v_group_id uuid;
  BEGIN
    SELECT id INTO v_group_id
    FROM groups
    WHERE name = 'DIVEND'
    LIMIT 1;

    IF v_group_id IS NULL THEN
      RETURN;
    END IF;

    -- El Patrocinador: Most beers paid
    RETURN QUERY
    SELECT 
      'patrocinador'::text as stat_type,
      p.name as player_name,
      p.id as player_id,
      COUNT(*)::bigint as value
    FROM beer_stats bs
    INNER JOIN players p ON p.id = bs.player_id
    WHERE bs.status = 'payer'
      AND p.group_id = v_group_id
    GROUP BY p.id, p.name
    ORDER BY COUNT(*) DESC, p.name ASC
    LIMIT 1;

    -- El Barra libre: Most beers received
    RETURN QUERY
    SELECT 
      'barra_libre'::text as stat_type,
      p.name as player_name,
      p.id as player_id,
      COUNT(*)::bigint as value
    FROM beer_stats bs
    INNER JOIN players p ON p.id = bs.player_id
    WHERE bs.status = 'receiver'
      AND p.group_id = v_group_id
    GROUP BY p.id, p.name
    ORDER BY COUNT(*) DESC, p.name ASC
    LIMIT 1;

    -- El Corto: Most "No pasó de Rojas"
    RETURN QUERY
    SELECT 
      'corto'::text as stat_type,
      p.name as player_name,
      p.id as player_id,
      COUNT(*)::bigint as value
    FROM scores s
    INNER JOIN players p ON p.id = s.player_id
    INNER JOIN golf_rounds gr ON gr.id = s.round_id
    WHERE s.no_paso_rojas = true
      AND gr.status = 'completed'
      AND p.group_id = v_group_id
    GROUP BY p.id, p.name
    ORDER BY COUNT(*) DESC, p.name ASC
    LIMIT 1;

    -- El Driver de Oro: Least "No pasó de Rojas" (but must have played)
    RETURN QUERY
    SELECT 
      'driver_oro'::text as stat_type,
      p.name as player_name,
      p.id as player_id,
      COUNT(CASE WHEN s.no_paso_rojas = true THEN 1 END)::bigint as value
    FROM players p
    INNER JOIN scores s ON s.player_id = p.id
    INNER JOIN golf_rounds gr ON gr.id = s.round_id
    WHERE gr.status = 'completed'
      AND p.group_id = v_group_id
    GROUP BY p.id, p.name
    HAVING COUNT(*) > 0
    ORDER BY COUNT(CASE WHEN s.no_paso_rojas = true THEN 1 END) ASC, p.name ASC
    LIMIT 1;
  END;
END;
$$;