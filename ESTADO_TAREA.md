# Estado para continuar — 16/09/2026

## Decisiones y alcance recuperado

El usuario pidió terminar y desplegar los jugadores invitados, y después volver al ordenador local. Se recuperó el chat original desde el historial del Codespace; su título antiguo es «Corrige controles de locución VR», identificador `01a0aaf7-7d05-7be0-a18b-417d97b9e2d8`.

La casilla «Invitado: solo juega esta partida» debe empezar desmarcada. Sin marcar crea una ficha habitual sin cuenta; marcada crea una ficha reutilizable de invitado. Solo un administrador puede elegir «Incorporar al grupo» para convertir un invitado existente. La incorporación afecta a participaciones futuras, no al historial. Las fichas no crean cuentas ni conceden acceso.

## Jugadores invitados

- Implementados alta y selección mediante RPC atómico, etiquetas de invitados y archivo completo de las partidas.
- Los invitados juegan y aparecen en la clasificación de la partida y en el historial. Se excluyen de estadísticas, premios, cervezas y ajustes automáticos de hándicap del grupo.
- Los resultados archivados conservan identidad y condición de invitado; la vista estadística recalcula posiciones entre los habituales. Se soportan partidas y días con solo invitados.
- Migraciones `20260918100000_group_guest_players.sql` y `20260919100000_guest_creation_choices.sql` aplicadas y registradas. La segunda conserva el permiso habitual de alta para usuarios que pueden registrar resultados; incorporar una ficha existente sigue requiriendo administrador. El historial remoto tiene 46 versiones. No se ha reproducido ni modificado el historial SQL antiguo.
- Validación: TypeScript, 22 pruebas administrativas con PGlite, 5 pruebas del flujo e historial, compilación y `git diff --check`. No se escribieron datos de prueba en Supabase.
- Primera publicación verificada: commit `7fa0144`, contenedor activo, HTML y JavaScript HTTP 200. Corrección de la casilla e incorporación explícita validada y lista para publicar.
- Detalles en `GUEST_PLAYERS_SETUP.md`.

## Entorno y vuelta a local

Este Codespace tiene timeout de 30 minutos. GitHub permite hasta cuatro horas para entornos nuevos, pero seguirá pudiendo suspenderlos. El usuario eligió volver a local al acabar. No se ha reiniciado ni reconstruido este entorno durante la recuperación.

Se localizaron cinco conversaciones guardadas en `~/.codex`; el chat anterior no se había borrado del disco. No se reprodujo el fallo por el que la interfaz abrió otra conversación.

Se inició una copia privada del historial cada 60 segundos en `/workspaces/.lapartideta-codex-history`, fuera del repositorio. Se conservan dos copias, con backup consistente de SQLite, conversaciones e índices. No se copian archivos de autenticación ni claves SSH. Descargar la copia antes de eliminar el Codespace: reside en su mismo disco.

La configuración del entorno, scripts de migración y despliegue, dependencias fijadas y documentación recuperados se conservaron. Los secretos siguen fuera de Git. Pasos para continuar en el ordenador en `LOCAL_SETUP.md`; funcionamiento remoto en `CODESPACE_SETUP.md`.

## Siguiente paso

Completar la publicación de la corrección y abrir la carpeta local en VS Code. Antes de actualizar la copia local, comprobar sus cambios y preservar cualquier trabajo pendiente. Configurar `.env.local` y accesos privados por separado; las migraciones ya aplicadas no se repiten.
