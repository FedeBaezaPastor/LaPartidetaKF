/*
  # Agregar política de eliminación para jugadores

  1. Cambios
    - Agregar política DELETE para la tabla `players`
    - Permite que usuarios anónimos y autenticados eliminen jugadores
  
  2. Seguridad
    - Política pública para permitir la eliminación de jugadores
    - Consistente con las demás políticas de la tabla
*/

CREATE POLICY "Public can delete players"
  ON players FOR DELETE
  TO anon, authenticated
  USING (true);
