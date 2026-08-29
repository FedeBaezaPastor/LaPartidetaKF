/*
  # Agregar función para reiniciar secuencia de números de referencia

  1. Nueva Función
    - `reset_reference_sequence()` reinicia la secuencia a 1
    - Se llama cuando se eliminan todas las partidas

  2. Comportamiento
    - Si no hay partidas en la base de datos, reinicia a 1
    - Si hay partidas, mantiene la secuencia desde el máximo + 1

  3. Seguridad
    - Función pública que puede ser llamada por cualquier usuario
*/

-- Create function to reset reference number sequence
CREATE OR REPLACE FUNCTION reset_reference_sequence()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if there are any rounds left
  IF NOT EXISTS (SELECT 1 FROM golf_rounds LIMIT 1) THEN
    -- No rounds exist, reset to 1
    PERFORM setval('golf_rounds_reference_seq', 1, false);
  ELSE
    -- Rounds exist, set to max + 1
    PERFORM setval('golf_rounds_reference_seq', COALESCE((SELECT MAX(reference_number) FROM golf_rounds), 0) + 1, false);
  END IF;
END;
$$;
