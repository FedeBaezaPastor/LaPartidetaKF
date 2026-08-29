/*
  # Change reference_number to be per group

  1. Changes
    - Drop the existing unique constraint on reference_number
    - Add a new unique constraint on (group_id, reference_number)
    - Update the trigger function to assign reference_number within each group
    - Update the reset function to work per group

  2. Security
    - No changes to RLS policies
*/

-- Drop the existing unique constraint
ALTER TABLE golf_rounds DROP CONSTRAINT IF EXISTS golf_rounds_reference_number_key;

-- Add a new unique constraint for (group_id, reference_number)
ALTER TABLE golf_rounds ADD CONSTRAINT golf_rounds_group_reference_unique 
  UNIQUE (group_id, reference_number);

-- Update the trigger function to assign reference_number per group
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
    AND is_active = true;
  
  NEW.reference_number := next_ref_number;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update the reset function to work per group
CREATE OR REPLACE FUNCTION reset_reference_sequence(p_group_id UUID)
RETURNS void AS $$
BEGIN
  -- Reset reference numbers for archived rounds in the specified group
  UPDATE golf_rounds
  SET reference_number = NULL
  WHERE group_id = p_group_id
    AND is_active = false;
  
  -- Reassign reference numbers to active rounds in the specified group
  WITH numbered_rounds AS (
    SELECT 
      id,
      ROW_NUMBER() OVER (ORDER BY created_at) as new_ref_number
    FROM golf_rounds
    WHERE group_id = p_group_id
      AND is_active = true
  )
  UPDATE golf_rounds gr
  SET reference_number = nr.new_ref_number
  FROM numbered_rounds nr
  WHERE gr.id = nr.id;
END;
$$ LANGUAGE plpgsql;
