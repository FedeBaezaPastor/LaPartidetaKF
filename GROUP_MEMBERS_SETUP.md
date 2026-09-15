# Miembros y hándicaps por grupo: validación local

Estado: implementación preparada. La migración aún no se ha aplicado a la base compartida desde este trabajo. No se ha publicado el frontend en el VPS.

## Aplicación

1. En Supabase → SQL Editor → New query, ejecutar **solo** `supabase/migrations/20260917100000_group_member_players.sql`, completo y una vez. No volver a ejecutar las migraciones anteriores.
2. En la terminal del proyecto, ejecutar `npm run dev` y abrir `http://localhost:5173/`.
3. Probar con cuentas y grupos de prueba. Localhost usa la misma base que la web publicada: editar o retirar miembros sí cambia los datos compartidos.
4. No hacen falta nuevas Edge Functions ni secretos.
5. Después de validar, publicar el frontend con el procedimiento habitual del proyecto. Hasta entonces, realizar estas pruebas con el frontend local actualizado.

## Comprobaciones de interfaz pendientes

- Entrar como FedeTeam, abrir Puntos de Juego: Fede y FedeTeam muestran avatar, nick, nombre, rol y hándicap para 18 hoyos. El UUID está en Detalles. El propietario dice Administrador del Grupo.
- Incorporar a Fede a dos grupos. Asignar 18 en uno y 10 en otro; sus fichas deben tener internamente 9 y 5. Cambiar el perfil no altera ninguno. Probar 0 y 18,5.
- Seleccionar a Fede desde Miembro registrado al preparar una partida: el hándicap procede del grupo y no es editable en ese formulario. Una ficha sin hándicap aparece pendiente y no se puede seleccionar.
- Si hay una ficha antigua con el mismo nombre, aparece separada como Ficha sin cuenta vinculada. Crear otra ficha sin cuenta que coincida con un miembro exige elegir esa opción expresamente.
- Añadir a Fede a una partida y, después, cambiar su hándicap del grupo: la participación existente conserva su valor. Cerrar y archivar una partida de prueba para verificar el ajuste por resultados.
- Con un formulario abierto, modificar el mismo miembro desde otra pestaña: guardar la versión anterior debe fallar. Cancelar y abrir de nuevo el formulario muestra la versión actual. El refresco de 30 segundos no sustituye lo escrito.
- Retirar a Fede: desaparece de miembros, nuevos destinatarios de grupo y selección para nuevas partidas. Conserva la ficha y las participaciones anteriores. La invitación antigua deja de funcionar; una nueva invitación recupera su ficha y último hándicap.
- Comprobar que no hay botón para retirar al propietario ni a uno mismo. Un miembro normal, un administrador que pierde su rol y una cuenta bloqueada no pueden administrar miembros.
- Revisar Actividad en el panel de la app: operación, actor, grupo, cuenta afectada y valores anteriores/nuevos.
- Comprobar invitaciones, mensajes, una partida Express sin login y una partida Player/Team.

## Diseño y pruebas automatizadas

`players.auth_user_id` + `players.group_id` identifican una sola ficha registrada. `handicap_pending` distingue un valor pendiente del cero; ambos campos numéricos heredados guardan la base de 9 hoyos. Las fichas antiguas permanecen sin UUID de cuenta; no se han atribuido históricos de DIVEND.

La incorporación y aceptación de invitaciones crean o recuperan la ficha en una transacción. Las consultas no crean registros. Las modificaciones verifican permisos actuales, bloqueo y versiones, y guardan la auditoría en la misma transacción. Permisos internos de un solo uso protegen las fichas y el historial de ajustes frente a escrituras directas y funciones heredadas.

Los archivos nuevos guardan `source_round_id` y `player_db_id`. Para participaciones vinculadas, las posiciones y Spanish Hands usados para ajustar hándicaps se calculan desde los resultados del servidor. Se mantiene la fórmula existente y se aplica una sola vez durante el archivo. Los rankings nuevos distinguen las identidades explícitas de los nombres antiguos; la migración no recalcula históricos.

Pruebas: `npm run test:admin`, `npm run typecheck`, `npm run build`. La batería incluye PostgreSQL local mediante PGlite; no escribe en Supabase. Las pruebas SQL de esta fase cubren dos grupos, cero, decimales, perfiles pendientes, permisos y pérdida de rol, bloqueo, cambios obsoletos, retirada/reingreso, invitaciones caducadas por retirada, escrituras directas, snapshots, resultados, nombres coincidentes y rollback si falla la auditoría. La validación visual contra Supabase queda pendiente de aplicar la migración.
