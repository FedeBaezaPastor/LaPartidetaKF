# Recuperación tras desconexión — 16/09/2026

Este documento recoge evidencias del disco; no sustituye las instrucciones del chat anterior, que no están disponibles en la conversación actual.

## Estado recuperado

- Rama `main`, commit `4e7d393` (miembros y hándicaps por grupo). Tras `git fetch origin`, coincide con `origin/main`.
- Trabajo sin commit: configuración del Codespace, Node, dependencias del CLI Supabase, documentación, scripts de migración y despliegue, pruebas del flujo y exclusiones de archivos locales.
- Existe una migración nueva de 406 líneas: `supabase/migrations/20260918100000_group_guest_players.sql`. Añade tratamiento de invitados en grupos y participaciones. Debe tratarse como trabajo pendiente de revisión: no hay cambios de interfaz ni pruebas específicas de invitados en el árbol recuperado.
- No se puede confirmar si esa migración está aplicada: `npm run db:status` falló con `Supabase command failed (1)`.

## Comprobaciones realizadas en la recuperación

- `npm run typecheck`: correcto.
- `npm run test:admin`: 18 pruebas correctas.
- `npm run test:workflow`: 4 pruebas correctas.
- `npm run build`: correcto, con advertencias de imports estáticos/dinámicos.
- `git diff --check`: correcto.
- `.env.local`, `.local/` y archivos de `supabase/.temp/`: excluidos de Git.
- En esta recuperación no se ha aplicado SQL, publicado código ni ejecutado un despliegue.

## Para retomar

1. Recuperar o confirmar el alcance funcional original antes de completar la función de invitados.
2. Resolver la consulta del historial remoto de Supabase y comprobar la versión `20260918100000`.
3. Revisar la migración y preparar pruebas locales con PGlite antes de cualquier aplicación.
4. Completar interfaz y servicios según el alcance confirmado; validar y guardar los cambios en commits.

Actualizar este archivo cuando cambie el estado o antes de interrumpir una tarea larga.

## Avance de jugadores invitados — 16/09/2026

El usuario confirmó que la tarea interrumpida era la función de invitados y pidió terminarla antes de revisar Codespaces/local.

- Implementados alta y selección mediante RPC atómico en configuración y visor de partidas; invitados nuevos por defecto y conversión a miembro sin cuenta por administradores al añadir una ficha existente.
- Identificación de invitados en tarjetas, clasificaciones, estadísticas de la partida y Puntos de Juego.
- Estadísticas de grupo/campo, premios, cervezas y ajustes leen la proyección sin invitados; el historial conserva todos los participantes y distingue nombres coincidentes por UUID.
- Archivo de partidas de grupo desde el visor y soporte de días con solo invitados.
- Migración revisada y ejecutada en PGlite; guardas de permisos, duplicados, límites, condición inmutable y resultados calculados en servidor. Compatible con esquemas sin el RPC antiguo de cervezas.
- Validación final: TypeScript, 22 pruebas administrativas (4 nuevas de invitados), 4 del flujo y compilación. También se ejecutaron en PGlite las 12 funciones estadísticas recuperadas del esquema remoto actual; no se escribieron datos de prueba en Supabase.
- Documentación: `GUEST_PLAYERS_SETUP.md`.
- El acceso al CLI se recuperó. Historial consultado y simulación revisada: solo la migración nueva de invitados. Se aplicó y registró `20260918100000`; el historial remoto pasó de 44 a 45 versiones y quedan cero migraciones nuevas pendientes. Verificadas las dos columnas con default false, las tres guardas activas y la vista con `security_invoker=true`. No se cambió la condición de fichas históricas (cero invitados al aplicar).
- Publicación autorizada expresamente por el usuario y completada el 16/09/2026: commit `7fa0144` subido a `main`, ejecución de `/var/www/miapp/deploy.sh`, compilación remota correcta y nuevo contenedor activo sin reinicios. Verificados HTML y JavaScript actualizados con HTTP 200; el JavaScript contiene el alta de invitados y la proyección de estadísticas.
- Función de invitados implementada, migración aplicada y frontend publicado. Pendiente de conversación: revisar Codespaces y local, según pidió el usuario.
- La configuración previa del Codespace y sus scripts se han conservado para revisarlos después, según pidió el usuario.
