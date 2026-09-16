# Jugadores invitados

En una partida de grupo, la casilla **Invitado: solo juega esta partida** empieza desmarcada. Una ficha nueva sin cuenta cuenta como habitual; al marcar la casilla se crea como invitado. Los usuarios con permiso para registrar resultados pueden crear cualquiera de las dos fichas.

Los invitados juegan con su hándicap y slope, aparecen identificados en tarjetas y clasificaciones de la partida, y se conservan en el historial completo. No cuentan en estadísticas del grupo o del campo, premios, cervezas ni ajustes de hándicap. Una partida con solo invitados también se puede archivar y consultar.

Las fichas se reutilizan dentro del mismo grupo. Al seleccionar un invitado en la configuración de una nueva partida, un administrador puede elegir **Incorporar al grupo** para convertir su ficha en miembro sin cuenta. Las participaciones anteriores conservan su condición de invitado. Esta conversión no crea una cuenta ni concede acceso al grupo.

## Base de datos

Migración inicial: `supabase/migrations/20260918100000_group_guest_players.sql`. La corrección del alta habitual está en `supabase/migrations/20260919100000_guest_creation_choices.sql`. Requieren el esquema de miembros y hándicaps por grupo ya existente. No volver a ejecutar el historial antiguo.

```bash
npm run db:status
npm run db:migrate -- supabase/migrations/20260918100000_group_guest_players.sql
npm run db:migrate -- supabase/migrations/20260918100000_group_guest_players.sql --apply
```

Consultar el historial remoto y revisar la simulación antes de aplicar. El frontend actualizado requiere esta migración. La migración se aplicó y registró el 16/09/2026. La corrección `20260919100000` también se aplicó y registró el 16/09/2026. El historial remoto tiene 46 versiones; no se deben repetir esas migraciones. El frontend del commit `7fa0144` se publicó el 16/09/2026 en https://golf.arinsaldev.com. Se verificaron el contenedor activo y las respuestas HTTP 200 del HTML y del JavaScript actualizado.

`players.is_guest` describe la ficha reutilizable y `round_players.is_guest` guarda la condición de cada participación. Al archivar, el servidor obtiene el ranking de los resultados de la partida y guarda la condición en ranking, estadísticas y golpes. La vista `group_statistics_rounds` excluye invitados y recalcula posiciones y cervezas entre los miembros; el historial lee `archived_rounds` completo.

## Validación

`npm run typecheck`, `npm run test:admin`, `npm run test:workflow` y `npm run build`.

Las pruebas con PGlite comprueban nombres coincidentes, exclusión de estadísticas y premios, cervezas, hándicaps, fichas reutilizadas, conversión sin cambiar históricos, grupos separados, cuentas de solo lectura, límites de modalidad, duplicados, snapshots de antiguos clientes y políticas de lectura de la vista. No escriben en Supabase.

Después de aplicar la migración, revisar visualmente con cuentas y datos de prueba: añadir un invitado, seleccionar uno existente, finalizar y archivar una partida mixta y otra con solo invitados, consultar el historial y convertir una ficha para una partida posterior.
