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

## Segunda fase: gestión de usuarios

Se añade Usuarios al panel: listado de 25 cuentas por página, búsqueda por correo/nombre/nick/UUID, filtros por plan efectivo y restricción, ficha y edición de nombre/nick/avatar/hándicap/tee. Los administradores (incluidas identidades administrativas incompletas) quedan excluidos. Los perfiles pendientes pueden consultarse y bloquearse, pero deben completar el registro antes de editar su perfil.

Las operaciones requieren motivo y confirmación. La ficha incluye un control de concurrencia: si otro administrador o el jugador cambió sus datos, se rechaza el guardado y hay que actualizar la ficha. Cambio y auditoría se confirman en una transacción.

Bloquear significa SOLO LECTURA de datos de negocio. Se permite consultar y recuperar/cambiar la contraseña. No se utiliza el bloqueo de Supabase Auth. Un trigger por sentencia protege las tablas públicas actuales contra INSERT, UPDATE, DELETE y TRUNCATE, incluso a través de RPC SECURITY DEFINER. Mantiene las políticas de lectura existentes. Las tablas nuevas que se incorporen en migraciones futuras también deberán instalar `app_user_write_guard`. La restricción comprueba el UUID de la sesión Auth, no identificadores locales de partidas; Express sin login mantiene su comportamiento.

La interfaz comprueba restricciones antes de montar las pantallas, al recuperar foco y cada 30 segundos. Un fallo de verificación pasa a solo lectura. Las operaciones que ya habían comenzado antes de confirmar el bloqueo pueden terminar; solicitudes posteriores se rechazan en la base de datos. Los controles de escritura se deshabilitan y las puntuaciones usan el modo de consulta existente. No se elimina ni pausa una partida o grupo.

Los planes pueden tener fecha/hora de fin (el formulario utiliza la zona horaria del navegador) o ser indefinidos. Al vencer, el plan efectivo es Express sin borrar grupos/resultados. La asignación propone un mes por defecto. El simulador conserva expresamente la capacidad de sustituir un plan administrativo cuando el usuario no está restringido; sus cambios mantienen el comportamiento anterior de un mes.

### Publicación de la segunda fase

1. Aplicar **solo** `supabase/migrations/20260911190000_app_user_management.sql` en SQL Editor del proyecto de pruebas/publicación correcto. No repetir la migración `20260910190000_create_app_administration.sql`, que ya está aplicada. No utilizar reset.
2. Esta fase añade RPC de base de datos; **no requiere volver a desplegar las Edge Functions** admin-auth/admin-management ni recrear AdminF.
3. Publicar frontend mediante el script habitual `local-deploy.ps1`, conservando las comprobaciones.
4. Entrar como AdminF y abrir Usuarios. Utilizar una cuenta de jugador de pruebas separada en otro navegador: editar perfil, asignar plan con fecha e indefinido, bloquear durante consulta/partida, comprobar consulta y contraseña, desbloquear y comprobar conservación de datos.
5. Revisar Actividad. Probar también que Express sin login, Player y Team sin bloqueo mantienen creación de partidas y navegación. No bloquear cuentas reales hasta completar estas comprobaciones.

Pruebas locales: `npm run test:admin`, `npm run typecheck`, `npm run build`. Incluyen permisos, auditoría, restricciones de escritura mediante RPC elevada, lectura conservada, contraseña, cambios de planes, conflictos de ficha/nick y controles de formulario deshabilitados. No se han ejecutado escrituras ni bloqueos sobre cuentas remotas desde las pruebas.

## Tercera fase: partidas

La sección Partidas permite consultar todas las partidas con búsqueda por referencia, UUID, identificador de origen, campo o jugador; filtros por estado y tipo; y paginación de 25 resultados. La ficha muestra puntuaciones almacenadas por jugador y hoyo. No vincula identificadores de dispositivo a cuentas Auth ni modifica puntuaciones.

Solo las partidas sin grupo admiten acciones: finalizar una activa (con los hoyos registrados, aunque esté incompleta), reabrir una finalizada/archivada, retirar y restaurar. Las partidas con grupo son exclusivamente de consulta, también en servidor. Finalizar utiliza el mismo cambio de estado/completed_at del flujo rápido existente; no genera los históricos de archivado de grupos ni recalcula resultados. Reabrir limpia completed_at y conserva todas las puntuaciones.

La retirada administrativa guarda el estado previo y marca la partida como deleted sin borrar jugadores ni puntuaciones. El marcador solo puede cambiarse con permisos administrativos. Los usuarios no pueden reactivar ni escribir puntuaciones/jugadores de una partida retirada. La restauración vuelve al estado anterior y vuelve a consumir un hueco, incluso si el total supera cuatro. No permite reabrir/restaurar en curso mientras exista otra rápida activa para el mismo identificador. El reset Express completo existente sigue siendo una operación aparte y puede borrar físicamente los registros.

El aviso y la comprobación de creación Express usan ahora el mismo RPC de recuento: todas las rápidas del identificador de origen, excepto las retiradas por administración. Una eliminación del jugador sigue contando; una retirada administrativa libera un hueco. Player/Team siguen sin límite. El contador se refresca al recuperar foco y cada 30 segundos; las pantallas de partida rápida también refrescan el estado administrativo. Las comprobaciones históricas de una partida activa/finalizada pendiente se mantienen.

Cada acción exige motivo de 3–500 caracteres y confirmación. La auditoría guarda UUID de partida, administrador, estado anterior/nuevo y motivo en la misma transacción. La ficha usa updated_at para rechazar cambios administrativos sobre un estado desactualizado. Los triggers serializan escrituras de jugadores/puntuaciones con la retirada de la partida.

### Publicar Partidas

1. En Supabase SQL Editor aplicar **solo** `supabase/migrations/20260912190000_app_round_management.sql`. Requiere las dos fases anteriores ya aplicadas. No repetir migraciones anteriores ni usar reset.
2. No hay Edge Functions nuevas ni cambios de secretos. Publicar la web con `local-deploy.ps1` y recargar con Ctrl+F5.
3. AdminF → Partidas: comprobar consulta de una rápida y una de grupo. En una rápida de pruebas, finalizar/reabrir y comprobar las puntuaciones. Retirar, verificar hueco de Express desde el dispositivo de origen y restaurar para comprobar que vuelve a contar. Comprobar Actividad.
4. Verificar con una sesión de jugador abierta que una retirada se refleja al volver a la ventana y no admite nuevas puntuaciones. Verificar que las acciones de grupos no aparecen ni se aceptan por RPC.

Pruebas: `npm run test:admin`, `npm run typecheck`, `npm run build`. La prueba de partidas cubre permisos, transiciones, conflictos de estado, restauración con otra activa, conservación de puntuaciones, contador (incluidas eliminaciones del jugador), auditoría y compatibilidad con el reset Express. Las pruebas locales no envían correos ni modifican datos remotos.

## Sesiones independientes por pestaña

La autenticación utiliza sessionStorage con respaldo en memoria cuando el navegador no permite almacenamiento. Cada documento tiene un storageKey de Supabase distinto para aislar también su BroadcastChannel. El adaptador conserva claves estables dentro de la pestaña, incluidos los verificadores de recuperación, para mantener la sesión al recargar.

Un canal separado intercambia únicamente identificadores de pestaña para detectar copias de sessionStorage en pestañas duplicadas; nunca transmite tokens. Las pestañas nuevas no importan la sesión compartida anterior de localStorage. Todos los cierres de sesión de la interfaz utilizan scope local de Supabase para no revocar las sesiones independientes de la misma cuenta.

Publicar solo frontend; no requiere SQL, secretos ni Edge Functions. Después de actualizar, recargar todas las pestañas y volver a iniciar sesión en cada una. La sesión se mantiene al recargar la pestaña; al cerrarla, no se conserva como un acceso permanente (el navegador puede restaurar pestañas según sus propias opciones).

Comprobar con dos pestañas: AdminF en una, jugador en otra; cerrar cualquiera y confirmar que la otra sigue operativa. La prueba `tests/admin-tab-auth.test.mjs` cubre aislamiento, recarga, duplicación, limpieza y almacenamiento no disponible.
