/*
  # Fix reset_reference_sequence function to use status column

  1. Changes
    - Update reset_reference_sequence function to use status column instead of is_active
    - Update assign_reference_number trigger function to use status = 'active'

  2. Security
    - No changes to RLS policies
*/

-- Update the trigger function to use status column
CREATE OR REPLACE FUNCTION assign_reference_number()
RETURNS TRIGGER AS $$
DECLARE
  next_ref_number INTEGER;
BEGIN
  -- Get the next reference number for this specific group
  SELECT COALESCE(MAX(reference_number), 0) + 1
  INTO next_ref_number
  FROM golf_rounds
  WHERE group_id = NEW.group_id
    AND status = 'active';
  
  NEW.reference_number := next_ref_number;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update the reset function to use status column
CREATE OR REPLACE FUNCTION reset_reference_sequence(p_group_id UUID)
RETURNS void AS $$
BEGIN
  -- Reset reference numbers for non-active rounds in the specified group
  UPDATE golf_rounds
  SET reference_number = NULL
  WHERE group_id = p_group_id
    AND status != 'active';
  
  -- Reassign reference numbers to active rounds in the specified group
  WITH numbered_rounds AS (
    SELECT 
      id,
      ROW_NUMBER() OVER (ORDER BY created_at) as new_ref_number
    FROM golf_rounds
    WHERE group_id = p_group_id
      AND status = 'active'
  )
  UPDATE golf_rounds gr
  SET reference_number = nr.new_ref_number
  FROM numbered_rounds nr
  WHERE gr.id = nr.id;
END;
$$ LANGUAGE plpgsql;
