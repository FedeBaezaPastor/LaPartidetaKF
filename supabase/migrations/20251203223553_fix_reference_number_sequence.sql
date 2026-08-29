/*
  # Fix reference number sequence initialization
  
  1. Problem
    - Previous migration only looked at active rounds when setting sequence
    - If all rounds are completed, sequence starts from 1 again
    - This causes duplicate key violations
  
  2. Solution
    - Reset sequence based on ALL rounds (active or completed)
    - This ensures new rounds get unique reference numbers
  
  3. Changes
    - Update sequence to continue from highest existing reference number
*/

-- Reset the sequence to the next available number based on ALL existing rounds
SELECT setval('golf_rounds_reference_seq', COALESCE((SELECT MAX(reference_number) FROM golf_rounds), 0) + 1, false);
