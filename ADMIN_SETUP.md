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

## Ajustes del panel (14/09/2026)

La búsqueda de Partidas utiliza palabras en cualquier orden, ignorando acentos, mayúsculas y signos como guiones. Todas las palabras deben coincidir; se admiten coincidencias parciales y una inserción, omisión o sustitución en palabras de cuatro o más caracteres. Ejemplos comprobados: `Costa Rojo`, `Cosa Azahar Rojo` y `ROJO costa` encuentran `Cosg Costa Ázahar - Rojo`.

Al seleccionar Rápidas aparece el filtro Stableford/Match/Sindicato/Parejas; al seleccionar Grupo aparece búsqueda por nombre, código o UUID del grupo, que también se identifica en los resultados. Cambiar Tipo limpia los filtros dependientes y vuelve a la primera página. Todos los filtros se aplican en servidor antes de contar y paginar; no cambian el carácter de solo consulta de las partidas de grupo.

La ficha de Usuarios presenta etiqueta y valor en una fila, y separa los datos de perfil. Los formularios de edición siguen la misma alineación. Mi contraseña incorpora Cancelar para volver al panel con la sesión abierta; las cuentas pendientes de activación siguen teniendo que establecer su contraseña antes de entrar.

Publicación: aplicar únicamente `supabase/migrations/20260914190000_admin_round_search.sql` en SQL Editor, después publicar la web con el script habitual. No se necesitan Edge Functions ni cambios de secretos. La firma anterior del listado se conserva para la transición. Las pruebas de partidas verifican los ejemplos de búsqueda, acentos, modalidades, grupos, filtros inactivos y permisos.

## Mensajes in-app (15/09/2026)

Administración → Mensajes permite buscar cuentas por correo, nick o UUID, y buzones Express por UUID exacto; seleccionar hasta 100 destinatarios; guardar borradores; revisar y confirmar el envío. El contenido se muestra como texto plano, conservando saltos de línea. Cada entrega guarda su fecha de lectura. Los mensajes enviados no se pueden editar. El historial y Actividad identifican al administrador que envió el mensaje; el receptor solo ve «Administración».

La nueva migración separa mensajes, entregas y buzones Express. Las tablas no admiten acceso directo de clientes: los RPC validan permisos y propiedad. `admin_send_message` publica y registra la auditoría en una transacción, bloquea el borrador y valida su revisión y todos los destinatarios antes de entregar. Repetir el envío del mismo UUID no duplica entregas ni auditoría. Si falla un destinatario, el borrador se conserva entero para corregirlo. `scheduled_at` queda reservado y sin interfaz ni proceso ejecutor: no hay envíos automáticos.

Notificaciones conserva las invitaciones y añade mensajes; el contador suma ambos. Refresca al entrar, recuperar foco y cada 30 segundos. Cada cuenta utiliza su sesión de pestaña y UUID Auth; no se importan mensajes anónimos al iniciar sesión. Las cuentas bloqueadas pueden consultar y marcar sus propios mensajes como leídos mediante RPC específicos. Las protecciones sobre partidas, perfiles y grupos siguen vigentes.

Express crea un buzón independiente al abrir la aplicación sin login. Genera una clave aleatoria de 256 bits, persistida antes de registrar el buzón, y usa un bloqueo del navegador para coordinar pestañas cuando está disponible. La clave se guarda en almacenamiento local (respaldo temporal en memoria si no está disponible); perder ese almacenamiento supone perder el acceso. Notificaciones muestra solo el UUID copiable, nunca la clave. La Edge Function recibe la clave en el cuerpo HTTPS, calcula SHA-256 y verifica el hash en servidor. No usa identificadores públicos de partidas, URLs ni auditorías para guardar credenciales.

La función aplica límites en servidor: 100 solicitudes/minuto por credencial y 1.000/minuto globales; altas, además, 100/minuto y 1.000/hora globales. Reutiliza el limitador protegido existente. Los límites globales también acotan intentos con claves aleatorias y pueden ajustarse si crece el tráfico. El origen permitido sigue siendo `APP_ORIGIN`; con el valor de producción, las llamadas Express desde localhost no estarán permitidas.

### Publicación paso a paso

1. En Supabase → SQL Editor, ejecutar **solo** `supabase/migrations/20260915190000_inapp_messages.sql`. Requiere las migraciones administrativas ya aplicadas. No repetirlas ni utilizar reset.
2. En PowerShell, desde la carpeta del proyecto, desplegar el servicio nuevo:

   ```powershell
   npx supabase functions deploy express-messages --project-ref sjzivdhzlptxveygmpys
   ```

   No hacen falta secretos nuevos. Se reutilizan `APP_ORIGIN=https://golf.arinsaldev.com` y las variables Supabase automáticas. El `verify_jwt=false` de esta función es intencional: Express no tiene sesión Auth y se autentica con la clave privada del buzón.
3. Publicar el frontend con el script habitual, que incluye los cambios pendientes:

   ```powershell
   .\local-deploy.ps1 -CommitMessage "Añadir mensajes in-app desde administración"
   ```

4. Recargar las pestañas. En una pestaña sin login, abrir Notificaciones y copiar el UUID del buzón Express. En otra, entrar con una **cuenta registrada de pruebas**. Desde AdminF, seleccionar esa cuenta y ese buzón, guardar un borrador, reabrirlo, revisar y confirmar un aviso de prueba. Verificar contenido, contador y lectura en ambos, y las fechas individuales en Administración → Mensajes.
5. Conservar las sesiones abiertas y comprobar otra cuenta sin acceso al mensaje, recuperación al volver al foco, invitaciones y una partida en curso sin interrupción. Probar una cuenta de pruebas bloqueada: debe leer mensajes y seguir sin poder modificar perfil, partidas ni grupos. No utilizar otros destinatarios hasta completar estas comprobaciones.

Validación local: `npm run test:admin`, `npm run typecheck`, `npm run build` y `npx deno check supabase/functions/express-messages/index.ts`. Las pruebas de mensajes utilizan una base PostgreSQL local en memoria y servicios simulados: no envían avisos ni modifican cuentas remotas. Cubren permisos, administradores desactivados, aislamiento, claves Express, límites del servicio, borradores, revisión, duplicados, reintentos, 100 destinatarios, rechazo completo de destinatarios inválidos, paginación, cambios de nick y lectura bajo bloqueo. La comprobación real en la aplicación publicada queda para los pasos 4 y 5.

## Mensajes a grupos y desde grupos (15/09/2026)

En Administración → Mensajes → Nuevo mensaje se pueden buscar grupos por nombre, código o UUID y elegir **Todo el grupo** o **Solo administradores**. Se pueden combinar grupos y cuentas individuales. El límite de 100 se aplica a las cuentas únicas resultantes, no al número de grupos seleccionados. Un grupo sin cuentas registradas no es un destinatario válido. Las invitaciones pendientes, los nombres de jugadores y los dispositivos Express no se convierten automáticamente en miembros registrados.

Los usuarios registrados que sean propietarios (`groups.user_auth_id`) o tengan el rol `admin` en `group_members` disponen de **Notificaciones → Mensajes de mis grupos**. Pueden seleccionar únicamente sus grupos, escribir a todos sus miembros, solo a sus administradores o a miembros concretos. Esta gestión no depende del PIN local ni del indicador de creador guardado en el dispositivo. No permite acceder al panel administrativo de la aplicación ni buscar usuarios ajenos al grupo. Los resultados y las entregas de esta gestión muestran nick/nombre/UUID, sin exponer correos privados.

Los receptores ven **Grupo · nombre del grupo** para los avisos de un administrador de grupo, y **Administración** para los enviados desde el panel de la aplicación. No hay respuestas. Cada administrador de grupo conserva sus propios borradores; los administradores actuales del grupo pueden consultar su historial de mensajes enviados y lecturas. El administrador de la aplicación puede consultar estos mensajes en su panel, pero no editar ni publicar los borradores ajenos del grupo. Actividad registra `group.message.sent` con el UUID y nick del autor y el grupo de origen.

La selección (cuentas/grupos/administradores de grupo) se guarda separada de la lista concreta de destinatarios. Al guardar/revisar se resuelven los miembros actuales, incluidos el propietario registrado y los miembros con rol admin. Antes del envío se resuelve de nuevo: si cambia la lista de UUID, el envío se rechaza completo y es necesario volver a editar/revisar. Una cuenta elegida individualmente por un administrador de grupo también debe seguir perteneciendo al grupo al enviar. Los reintentos del mismo mensaje enviado siguen siendo idempotentes.

Los RPC validan la autoría del borrador, el rol actual y el bloqueo en cada escritura. La interfaz vuelve a comprobar los grupos administrados al recuperar foco y cada 30 segundos. Un administrador de grupo bloqueado conserva la consulta y lectura, pero no puede crear, guardar ni enviar mensajes. Al eliminar un grupo, los mensajes entregados conservan contenido, remitente y lecturas; el vínculo de gestión queda vacío y recrear un grupo con el mismo UUID no recupera su historial.

La migración añade dos protecciones de identidad necesarias porque las políticas heredadas de grupos permiten actualizaciones públicas: un usuario no puede cambiar el propietario de un grupo ajeno ni trasladar una membresía a otro UUID de usuario/grupo. Se conserva la vinculación automática de un grupo anónimo sin miembros registrados ni historial de mensajes. Reclamar un grupo sin propietario que ya tenga miembros registrados exige ser administrador de ese grupo; los casos históricos sin administrador deben revisarse desde servidor. No se modifican puntuaciones, partidas, planes ni las migraciones ya aplicadas.

### Publicar la ampliación de grupos

1. En Supabase → SQL Editor, ejecutar **solo** `supabase/migrations/20260915210000_group_messages.sql`, después de la migración de mensajes ya aplicada.
2. No hay Edge Functions ni secretos nuevos: `express-messages` no cambia. Publicar el frontend con el script habitual:

   ```powershell
   .\local-deploy.ps1 -CommitMessage "Añadir mensajes a grupos y gestión por administradores de grupo"
   ```

3. Recargar las pestañas. Desde AdminF, buscar un grupo de pruebas, guardar/revisar **Solo administradores** y verificar la lista antes de confirmar. Repetir **Todo el grupo**, comprobando que miembros compartidos con otras selecciones no aparecen duplicados.
4. En otra pestaña, entrar con un administrador registrado del grupo de pruebas. Abrir Notificaciones → Mensajes de mis grupos, seleccionar el grupo y guardar/revisar/enviar un aviso de prueba. El receptor debe ver «Grupo · nombre», y Administración → Actividad debe identificar al autor real. Un miembro corriente no debe ver esta entrada.
5. Verificar en pruebas la pérdida de rol y el bloqueo con el formulario abierto, además de un cambio de miembros entre revisión y envío. No utilizar grupos reales antes de esta comprobación.

Pruebas locales: `npm run test:admin`, `npm run typecheck`, `npm run build` y ESLint sobre los componentes/servicios de mensajes. La prueba de grupos ejecuta las migraciones reales de administración, restricciones y mensajes en PostgreSQL local e incluye pérdida de rol, suplantación de propietario/membresía, bloqueo, destinatarios fuera de ámbito, confidencialidad de borradores, grupos combinados, límite de 100, cambios de miembros, auditoría y conservación de entregas tras eliminar el grupo. La regresión de mensajes individuales y Express también se ejecuta con esta nueva migración.

## Invitaciones ocultas y aceptación atómica

El contador contaba correctamente las invitaciones pendientes, pero la lista intentaba incluir `user_profiles!invited_by` mediante una relación REST inexistente: `invited_by` referencia `auth.users`. La consulta fallaba y la interfaz ocultaba el error mostrando «No tienes invitaciones pendientes». Ahora el perfil del remitente se obtiene por separado; si no está disponible, la invitación se sigue mostrando. Los errores de carga se muestran como errores, con un botón para reintentar, sin afirmar que el buzón esté vacío.

Aceptar utiliza `respond_to_group_invitation`: comprueba propietario de la invitación y bloqueo, e inserta la membresía y actualiza la respuesta en una única transacción. Los reintentos no duplican miembros ni cambian un rol administrativo existente. Un fallo de inserción conserva la invitación pendiente. No se aceptan invitaciones ni se reparan membresías remotas automáticamente.

Publicación:

1. Ejecutar solo `supabase/migrations/20260916100000_atomic_group_invitation_response.sql` en Supabase → SQL Editor.
2. Publicar frontend con `.\local-deploy.ps1 -CommitMessage "Corregir invitaciones ocultas y aceptación de miembros"`. No hay cambios en Edge Functions ni secretos.
3. Recargar con Ctrl+F5 la pestaña de Fede → Notificaciones → Actualizar invitaciones. Comprobar que aparece la invitación de La Partideta y aceptarla. Al regresar a inicio debe descontarse esa invitación del badge; después comprobar Fede entre los destinatarios reales del grupo.

Pruebas: consulta sin relación REST al perfil, perfil ausente, errores de carga, aceptación y rechazo, reintentos, roles conservados, rechazo de otras cuentas, cuentas bloqueadas y rollback ante fallo de alta de miembro. DIVEND queda fuera de esta corrección.
