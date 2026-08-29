/*
  # Add No Paso Rojas Stats to Archived Rounds

  1. Changes
    - Add `player_stats` column to archived_rounds to store detailed player statistics
    - This includes no_paso_rojas counts for "El Corto" and "El Driver de Oro" awards

  2. Structure
    - player_stats: JSONB array with objects containing:
      - player_name: text
      - no_paso_rojas_count: integer
      - total_holes_played: integer

  3. Notes
    - This is for future rounds - existing rounds won't have this data
    - The get_divend_statistics function will handle cases where this data is missing
*/

-- Add player_stats column to archived_rounds
ALTER TABLE archived_rounds
ADD COLUMN IF NOT EXISTS player_stats jsonb DEFAULT '[]'::jsonb;