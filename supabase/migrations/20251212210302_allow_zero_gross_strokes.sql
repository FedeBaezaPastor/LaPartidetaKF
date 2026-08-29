/*
  # Permitir valor 0 en gross_strokes

  1. Cambios
    - Elimina la restricción CHECK que requiere gross_strokes > 0
    - Añade nueva restricción que permite gross_strokes >= 0
  
  2. Razón
    - Los usuarios deben poder reducir el contador de golpes hasta 0
    - El valor 0 es válido cuando un jugador no ha completado el hoyo o quiere resetear
*/

-- Eliminar la restricción existente que requiere gross_strokes > 0
ALTER TABLE round_scores 
DROP CONSTRAINT IF EXISTS round_scores_gross_strokes_check;

-- Añadir nueva restricción que permite gross_strokes >= 0
ALTER TABLE round_scores 
ADD CONSTRAINT round_scores_gross_strokes_check CHECK (gross_strokes >= 0);
