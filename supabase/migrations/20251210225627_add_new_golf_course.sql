/*
  # Agregar Nuevo Campo de Golf

  1. Nuevo Curso
    - Inserta un nuevo campo de golf de 18 hoyos

  2. Hoyos
    - Agrega los 18 hoyos con valores de par y stroke index
    - Personaliza estos valores según las características del campo real

  3. Notas
    - Modifica el nombre y descripción del campo según tus necesidades
    - Ajusta los valores de par (3, 4 o 5) para cada hoyo
    - Ajusta el stroke_index (1-18) según la dificultad de cada hoyo
    - El stroke_index 1 es el hoyo más difícil, 18 es el más fácil
*/

-- Insertar el nuevo campo de golf
-- MODIFICA EL NOMBRE Y DESCRIPCIÓN AQUÍ:
INSERT INTO golf_courses (name, description)
VALUES (
  'Tercer Campo de Golf',
  'Nuevo campo agregado como ejemplo'
)
ON CONFLICT DO NOTHING;

-- Obtener el ID del nuevo curso e insertar los hoyos
DO $$
DECLARE
  new_course_id uuid;
BEGIN
  -- Obtener el curso recién creado por nombre
  -- IMPORTANTE: Usa el mismo nombre que arriba
  SELECT id INTO new_course_id
  FROM golf_courses
  WHERE name = 'Tercer Campo de Golf'
  LIMIT 1;

  IF new_course_id IS NOT NULL THEN
    -- Insertar los 18 hoyos
    -- MODIFICA los valores de par y stroke_index según tu campo
    -- Formato: (course_id, hole_number, par, stroke_index)
    INSERT INTO golf_holes (course_id, hole_number, par, stroke_index) VALUES
    -- Front 9 (hoyos 1-9)
    (new_course_id, 1, 4, 5),    -- Hoyo 1: Par 4, Dificultad 5
    (new_course_id, 2, 3, 17),   -- Hoyo 2: Par 3, Dificultad 17
    (new_course_id, 3, 5, 1),    -- Hoyo 3: Par 5, Dificultad 1 (más difícil)
    (new_course_id, 4, 4, 7),    -- Hoyo 4: Par 4, Dificultad 7
    (new_course_id, 5, 4, 11),   -- Hoyo 5: Par 4, Dificultad 11
    (new_course_id, 6, 3, 15),   -- Hoyo 6: Par 3, Dificultad 15
    (new_course_id, 7, 5, 3),    -- Hoyo 7: Par 5, Dificultad 3
    (new_course_id, 8, 4, 9),    -- Hoyo 8: Par 4, Dificultad 9
    (new_course_id, 9, 4, 13),   -- Hoyo 9: Par 4, Dificultad 13
    -- Back 9 (hoyos 10-18)
    (new_course_id, 10, 4, 6),   -- Hoyo 10: Par 4, Dificultad 6
    (new_course_id, 11, 5, 2),   -- Hoyo 11: Par 5, Dificultad 2
    (new_course_id, 12, 3, 18),  -- Hoyo 12: Par 3, Dificultad 18 (más fácil)
    (new_course_id, 13, 4, 8),   -- Hoyo 13: Par 4, Dificultad 8
    (new_course_id, 14, 4, 12),  -- Hoyo 14: Par 4, Dificultad 12
    (new_course_id, 15, 5, 4),   -- Hoyo 15: Par 5, Dificultad 4
    (new_course_id, 16, 3, 16),  -- Hoyo 16: Par 3, Dificultad 16
    (new_course_id, 17, 4, 10),  -- Hoyo 17: Par 4, Dificultad 10
    (new_course_id, 18, 4, 14)   -- Hoyo 18: Par 4, Dificultad 14
    ON CONFLICT (course_id, hole_number) DO NOTHING;
  END IF;
END $$;
