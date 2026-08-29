/*
  # Fix Costa Azahar Historical Course Names

  1. Changes
    - Update all archived rounds with old name "Costa Azahar - Verde" to "Golf Costa Azahar - Verde"
    - Update all archived rounds with old name "Costa Azahar - Rojo" to "Golf Costa Azahar - Rojo"
    - Update all archived rounds with old name "Costa Azahar - Azul" to "Golf Costa Azahar - Rojo" (if exists)
    - Update all archived rounds with old name "Costa Azahar - Amarillo" to "Golf Costa Azahar - Verde" (if exists)
  
  2. Purpose
    - Consolidate historical data to use current course names
    - Eliminate duplicate entries in statistics dropdowns
*/

-- Update Costa Azahar - Verde to Golf Costa Azahar - Verde
UPDATE archived_rounds
SET course_name = 'Golf Costa Azahar - Verde'
WHERE course_name = 'Costa Azahar - Verde';

-- Update Costa Azahar - Rojo to Golf Costa Azahar - Rojo
UPDATE archived_rounds
SET course_name = 'Golf Costa Azahar - Rojo'
WHERE course_name = 'Costa Azahar - Rojo';

-- Update Costa Azahar - Azul to Golf Costa Azahar - Rojo (if exists)
UPDATE archived_rounds
SET course_name = 'Golf Costa Azahar - Rojo'
WHERE course_name = 'Costa Azahar - Azul';

-- Update Costa Azahar - Amarillo to Golf Costa Azahar - Verde (if exists)
UPDATE archived_rounds
SET course_name = 'Golf Costa Azahar - Verde'
WHERE course_name = 'Costa Azahar - Amarillo';
