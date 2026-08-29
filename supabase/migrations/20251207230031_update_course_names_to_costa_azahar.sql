/*
  # Actualizar nombres de campos a Costa Azahar

  1. Cambios
    - Actualiza el primer campo al recorrido Azul de Costa Azahar
    - Actualiza el segundo campo al recorrido Amarillo de Costa Azahar
  
  2. Notas
    - Los campos del Costa Azahar tienen diferentes recorridos (Azul y Amarillo)
    - Los hoyos y sus características permanecen sin cambios
*/

-- Actualizar el primer campo a Costa Azahar Azul
UPDATE golf_courses
SET 
  name = 'Costa Azahar - Azul',
  description = 'Recorrido Azul del Costa Azahar Golf'
WHERE name = 'Club de Golf Campestre';

-- Actualizar el segundo campo a Costa Azahar Amarillo
UPDATE golf_courses
SET 
  name = 'Costa Azahar - Amarillo',
  description = 'Recorrido Amarillo del Costa Azahar Golf'
WHERE name = 'Segundo Campo de Golf';