/*
  # Crear tabla de configuración de administrador

  1. Nueva Tabla
    - `admin_config`
      - `id` (uuid, primary key) - ID único
      - `admin_email` (text) - Email del administrador
      - `admin_pin` (text) - PIN de acceso (4 dígitos)
      - `created_at` (timestamptz) - Fecha de creación
      - `updated_at` (timestamptz) - Fecha de última actualización

  2. Seguridad
    - Habilitar RLS en la tabla
    - Solo usuarios autenticados pueden leer
    - Solo usuarios autenticados pueden actualizar (para cambiar PIN)

  3. Datos Iniciales
    - Insertar configuración por defecto con el PIN actual
*/

CREATE TABLE IF NOT EXISTS admin_config (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_email text NOT NULL,
  admin_pin text NOT NULL CHECK (length(admin_pin) = 4),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE admin_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Usuarios autenticados pueden leer configuración admin"
  ON admin_config
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios autenticados pueden actualizar configuración admin"
  ON admin_config
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Insertar configuración inicial solo si no existe
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM admin_config LIMIT 1) THEN
    INSERT INTO admin_config (admin_email, admin_pin)
    VALUES ('kike@kikealgora.com', '2248');
  END IF;
END $$;