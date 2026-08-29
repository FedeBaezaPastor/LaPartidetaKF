/*
  # Update Costa Azahar Course Descriptions

  1. Changes
    - Update Golf Costa Azahar - Verde description from "Recorrido Amarillo del Costa Azahar Golf" to "Campo de golf de 9 hoyos"
    - Update Golf Costa Azahar - Rojo description from "Recorrido Azul del Costa Azahar Golf" to "Campo de golf de 9 hoyos"
*/

UPDATE golf_courses
SET description = 'Campo de golf de 9 hoyos'
WHERE name = 'Golf Costa Azahar - Verde';

UPDATE golf_courses
SET description = 'Campo de golf de 9 hoyos'
WHERE name = 'Golf Costa Azahar - Rojo';
