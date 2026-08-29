/*
  # Agregar Segundo Campo de Golf

  1. Nuevo Curso
    - Inserta un segundo campo de golf de 18 hoyos
  
  2. Hoyos
    - Agrega los 18 hoyos con valores de par y stroke index
    - Puedes modificar estos valores según las características del campo real

  3. Notas
    - Los valores de par y stroke_index son ejemplos, modifícalos según tu campo
    - El nombre y descripción también se pueden personalizar
*/

-- Insertar el segundo campo de golf
INSERT INTO golf_courses (name, description)
VALUES (
  'Segundo Campo de Golf',
  'Campo de golf alternativo de 18 hoyos'
)
ON CONFLICT DO NOTHING;

-- Obtener el ID del nuevo curso e insertar los hoyos
DO $$
DECLARE
  new_course_id uuid;
BEGIN
  -- Obtener el curso recién creado por nombre
  SELECT id INTO new_course_id 
  FROM golf_courses 
  WHERE name = 'Segundo Campo de Golf'
  LIMIT 1;
  
  IF new_course_id IS NOT NULL THEN
    -- Insertar los 18 hoyos
    -- MODIFICA estos valores según las características de tu campo
    INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
    -- Front 9 (hoyos 1-9)
    (new_course_id, 1, 4, 7),
    (new_course_id, 2, 4, 13),
    (new_course_id, 3, 3, 15),
    (new_course_id, 4, 5, 1),
    (new_course_id, 5, 4, 9),
    (new_course_id, 6, 4, 11),
    (new_course_id, 7, 3, 17),
    (new_course_id, 8, 5, 3),
    (new_course_id, 9, 4, 5),
    -- Back 9 (hoyos 10-18)
    (new_course_id, 10, 4, 8),
    (new_course_id, 11, 5, 2),
    (new_course_id, 12, 4, 12),
    (new_course_id, 13, 3, 16),
    (new_course_id, 14, 4, 6),
    (new_course_id, 15, 4, 10),
    (new_course_id, 16, 4, 14),
    (new_course_id, 17, 3, 18),
    (new_course_id, 18, 5, 4)
    ON CONFLICT (course_id, hole_number) DO NOTHING;
  END IF;
END $$;
