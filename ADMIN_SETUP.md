# Administradores de la aplicación — primera entrega

## Alcance

Acceso desde el formulario habitual mediante correo o alias (AdminF, AdminK), panel exclusivo de administración, alta y reenvío de acceso, desactivación/reactivación, cambio/recuperación de contraseña e historial de acciones. Todos los administradores activos tienen los mismos permisos. El último activo no puede desactivarse, ni siquiera mediante llamadas directas a la base de datos.

Las cuentas son identidades distintas en Supabase Auth, con UUID y contraseña independientes. Ejemplo: jugador `fede.baeza@gmail.com`, administrador `fede.baeza+admin@gmail.com`. El alias de correo es opcional y debe recibir mensajes. El sufijo `+admin` no concede permisos. El registro público sigue creando jugadores y no ofrece roles administrativos.

No incluye administración de jugadores, partidas, grupos ni preferencias generales. No cambia sus tablas, datos o políticas. Las políticas históricas de esas tablas requieren una revisión aparte antes de ampliar el panel. La separación de pantallas no sustituye esa revisión.

## Cambios y comprobaciones locales

- Gateway anterior al montaje de App: las identidades administrativas activas, pendientes o desactivadas no montan las pantallas ni los efectos de juego.
- Corrección puntual del trigger de altas existente: si Auth crea una cuenta sin metadatos de plan, no intenta insertar una suscripción con plan nulo. Las altas Player/Team conservan su creación de suscripción y se comprueban en pruebas.
- Nueva membresía protegida por RLS y funciones con comprobación de identidad; el cliente no puede escribir directamente roles ni auditoría.
- Alta mediante Edge Function con service role exclusivamente en servidor. Un correo ya existente no se convierte en administrador.
- Auditoría por UUID, alias, fecha, acción y motivo. No almacena contraseñas ni hashes. Los cambios de contraseña se registran como eventos de Supabase Auth sobre el UUID afectado; no se atribuyen falsamente a otro administrador.
- Desactivación efectiva para operaciones administrativas incluso con un JWT todavía vigente. La interfaz vuelve a comprobar permisos al recuperar foco y cada 30 segundos.
- Límites de intentos por alias y globales, respuestas genéricas en recuperación.
- Retirada del acceso administrativo compartido por correo/PIN y revocación de permisos sobre `admin_config`. Los PIN de grupos/pruebas no se modifican.

Validación: `npm run test:admin`, `npm run typecheck`, `npm run build`. Las pruebas ejecutan la migración sobre PostgreSQL embebido aislado (PGlite), con roles de jugador/administrador, y prueban clasificación de cuentas y llamadas de acceso. No envían correos ni acceden a los datos reales. No sustituyen la comprobación de SMTP y enlaces en un proyecto Supabase de pruebas.

## Puesta en marcha en Supabase

Esta entrega prepara código y migración; no crea cuentas reales ni aplica cambios remotos automáticamente.

1. Guardar una copia de seguridad del proyecto y verificar el proyecto de destino. Aplicar **solo** `supabase/migrations/20260910190000_create_app_administration.sql` desde SQL Editor o el flujo habitual de migraciones revisado. No ejecutar un reset ni reproducir todas las migraciones antiguas. La nueva migración es transaccional y se aplica una sola vez.
2. Configurar Site URL y la lista de Redirect URLs de Auth para el dominio de esta instalación, incluyendo:
   - `https://TU-DOMINIO/?admin-action=setup`
   - `https://TU-DOMINIO/?admin-action=recovery`
   - `https://TU-DOMINIO/?auth-action=recovery`
   Mantener los destinos existentes de confirmación de jugadores. Configurar SMTP y comprobar entrega. Los enlaces administrativos usan el correo de recuperación de Supabase para establecer una contraseña propia; no contienen una contraseña provisional visible.
3. Configurar el secreto de Edge Functions `APP_ORIGIN=https://TU-DOMINIO` (solo origen, sin barra final). Las variables SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY las proporciona el entorno Supabase. Nunca poner service role en variables VITE ni en el navegador.
4. Desplegar `admin-auth` y `admin-management` desde `supabase/functions`. El archivo `supabase/config.toml` desactiva la verificación JWT del gateway: `admin-auth` necesita aceptar solicitudes previas al login; `admin-management` valida explícitamente el JWT mediante Auth y la membresía activa en cada petición. No retirar esas comprobaciones.
5. Publicar el frontend con la configuración pública existente. Si se publica antes de la migración, los jugadores ordinarios conservan el acceso cuando el RPC todavía no existe; una identidad marcada como administrativa falla de forma cerrada.

Ejemplo de comandos, con Supabase CLI ya instalado y autenticado en el proyecto correcto:

```powershell
supabase secrets set APP_ORIGIN=https://TU-DOMINIO --project-ref TU_PROJECT_REF
supabase functions deploy admin-auth --project-ref TU_PROJECT_REF
supabase functions deploy admin-management --project-ref TU_PROJECT_REF
```

## Crear AdminF por primera y única vez

1. En Authentication → Users, crear/invitar una **cuenta nueva** con el correo administrativo. No reutilizar el UUID del jugador ni dar de alta esta cuenta desde el registro público. No insertar manualmente filas en `auth.users`.
2. Copiar el UUID de esa cuenta nueva y ejecutar en SQL Editor:

```sql
select public.bootstrap_app_administrator('UUID-NUEVO-DE-AUTH'::uuid, 'AdminF');
```

La función rechaza usuarios con perfil/suscripción de jugador y solo funciona si todavía no existe ningún administrador. La cuenta queda pendiente hasta establecer su contraseña. Si el enlace original se abrió antes de completar este paso, salir y solicitar uno nuevo.

3. En la aplicación, usar «¿Olvidaste tu contraseña?» e introducir `AdminF`. Abrir el correo y establecer la contraseña administrativa (la interfaz solicita al menos 12 caracteres; la política global de Auth debe configurarse en Supabase según se requiera). Tras guardar, entrar al panel.
4. Desde Administradores, crear `AdminK` con el correo administrativo del socio. Recibirá un enlace para fijar su propia contraseña. Comprobar el historial de creación y envío. Si SMTP falla, la cuenta permanece pendiente y permite reenviar acceso sin recrearla.

Las cuentas se desactivan en lugar de borrarse para conservar trazabilidad. Una pendiente reactivada vuelve a pendiente; una que ya tenía contraseña vuelve a activa. No es posible eliminar el último administrador a través del panel. Recuperaciones fallidas o alias desconocidos no revelan la existencia de una cuenta.

## Verificación antes de usarlo

- Login de jugador y Express: navegación, perfil, planes y partidas conservan su comportamiento.
- Login AdminF por alias y por correo: solo panel; no aparecen pantallas de juego.
- Recuperación de jugador y de AdminF: cambiar una contraseña no cambia la otra.
- AdminK: recibe enlace, fija contraseña y puede gestionar administradores con los mismos permisos.
- Desactivar AdminK mientras mantiene una sesión: sus operaciones se deniegan; al refrescar/foco aparece acceso desactivado.
- Intentar desactivar al único activo: operación rechazada.
- Revisar eventos de alta, envío, entrada, cambio de contraseña y cambios de estado.

No revertir borrando tablas de Auth ni datos de jugadores. Si una comprobación remota falla, conservar la cuenta inicial y revisar la configuración/migración antes de continuar. El antiguo acceso por PIN no se rehabilita automáticamente al volver a una versión anterior del frontend.
