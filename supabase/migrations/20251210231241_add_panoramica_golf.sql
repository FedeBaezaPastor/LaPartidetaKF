/*
  # Agregar Campo Panorámica Golf

  1. Nuevo Curso
    - Inserta el campo Panorámica Golf de 18 hoyos

  2. Hoyos
    - Agrega los 18 hoyos con valores específicos de par y stroke index
    - Datos proporcionados del campo real

  3. Notas
    - Par total: 72 (Front 9: 36, Back 9: 36)
    - Campo configurado según scorecard oficial
*/

-- Insertar Panorámica Golf
INSERT INTO golf_courses (name, description)
VALUES (
  'Panorámica Golf',
  'Campo de golf de 18 hoyos'
)
ON CONFLICT DO NOTHING;

-- Obtener el ID del nuevo curso e insertar los hoyos
DO $$
DECLARE
  new_course_id uuid;
BEGIN
  SELECT id INTO new_course_id
  FROM golf_courses
  WHERE name = 'Panorámica Golf'
  LIMIT 1;

  IF new_course_id IS NOT NULL THEN
    INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
    -- Front 9 (hoyos 1-9)
    (new_course_id, 1, 4, 10),
    (new_course_id, 2, 5, 14),
    (new_course_id, 3, 3, 18),
    (new_course_id, 4, 5, 4),
    (new_course_id, 5, 3, 16),
    (new_course_id, 6, 4, 6),
    (new_course_id, 7, 3, 12),
    (new_course_id, 8, 4, 8),
    (new_course_id, 9, 5, 2),
    -- Back 9 (hoyos 10-18)
    (new_course_id, 10, 4, 1),
    (new_course_id, 11, 5, 5),
    (new_course_id, 12, 3, 11),
    (new_course_id, 13, 4, 17),
    (new_course_id, 14, 4, 7),
    (new_course_id, 15, 4, 3),
    (new_course_id, 16, 3, 15),
    (new_course_id, 17, 4, 13),
    (new_course_id, 18, 5, 9)
    ON CONFLICT (course_id, hole_number) DO NOTHING;
  END IF;
END $$;
