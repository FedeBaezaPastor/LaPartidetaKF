/*
  # Corregir PAR y HCP del campo Golf Costa Azahar - Rojo
  
  ## Cambios realizados
  
  Se actualizan los valores de PAR y stroke_index (HCP) para el campo "Golf Costa Azahar - Rojo"
  según la información correcta proporcionada:
  
  ### Hoyos 1-9 (PAR total: 35)
  - Hoyo 1: PAR 4, HCP 1  (antes: PAR 4, HCP 8)
  - Hoyo 2: PAR 5, HCP 7  (antes: PAR 5, HCP 2)
  - Hoyo 3: PAR 4, HCP 13 (antes: PAR 3, HCP 18)
  - Hoyo 4: PAR 3, HCP 17 (antes: PAR 4, HCP 10)
  - Hoyo 5: PAR 4, HCP 3  (antes: PAR 4, HCP 6)
  - Hoyo 6: PAR 5, HCP 5  (antes: PAR 4, HCP 12)
  - Hoyo 7: PAR 4, HCP 9  (antes: PAR 3, HCP 16)
  - Hoyo 8: PAR 3, HCP 11 (antes: PAR 5, HCP 4)
  - Hoyo 9: PAR 3, HCP 15 (antes: PAR 4, HCP 14)
  
  ### Hoyos 10-18 (PAR total: 35)
  - Se replican los mismos valores para los hoyos 10-18
  
  ## Impacto
  - ✅ No hay partidas activas con este campo
  - ✅ No hay partidas archivadas con este campo
  - ✅ Modificación segura sin impacto en datos existentes
*/

-- Actualizar hoyos 1-9 del campo Costa Azahar - Rojo
UPDATE golf_holes
SET 
  par = CASE hole_number
    WHEN 1 THEN 4
    WHEN 2 THEN 5
    WHEN 3 THEN 4
    WHEN 4 THEN 3
    WHEN 5 THEN 4
    WHEN 6 THEN 5
    WHEN 7 THEN 4
    WHEN 8 THEN 3
    WHEN 9 THEN 3
  END,
  stroke_index = CASE hole_number
    WHEN 1 THEN 1
    WHEN 2 THEN 7
    WHEN 3 THEN 13
    WHEN 4 THEN 17
    WHEN 5 THEN 3
    WHEN 6 THEN 5
    WHEN 7 THEN 9
    WHEN 8 THEN 11
    WHEN 9 THEN 15
  END
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Golf Costa Azahar - Rojo')
  AND hole_number BETWEEN 1 AND 9;

-- Actualizar hoyos 10-18 del campo Costa Azahar - Rojo (mismo recorrido)
UPDATE golf_holes
SET 
  par = CASE hole_number
    WHEN 10 THEN 4
    WHEN 11 THEN 5
    WHEN 12 THEN 4
    WHEN 13 THEN 3
    WHEN 14 THEN 4
    WHEN 15 THEN 5
    WHEN 16 THEN 4
    WHEN 17 THEN 3
    WHEN 18 THEN 3
  END,
  stroke_index = CASE hole_number
    WHEN 10 THEN 1
    WHEN 11 THEN 7
    WHEN 12 THEN 13
    WHEN 13 THEN 17
    WHEN 14 THEN 3
    WHEN 15 THEN 5
    WHEN 16 THEN 9
    WHEN 17 THEN 11
    WHEN 18 THEN 15
  END
WHERE course_id = (SELECT id FROM golf_courses WHERE name = 'Golf Costa Azahar - Rojo')
  AND hole_number BETWEEN 10 AND 18;
