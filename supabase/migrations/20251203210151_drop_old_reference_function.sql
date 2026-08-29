/*
  # Drop old reference number function

  1. Changes
    - Remove the old generate_reference_number function that still references the deleted sequence
  
  2. Notes
    - This function was replaced by set_reference_number but wasn't properly cleaned up
*/

DROP FUNCTION IF EXISTS generate_reference_number() CASCADE;