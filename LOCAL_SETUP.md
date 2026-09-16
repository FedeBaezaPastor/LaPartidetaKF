# Volver a trabajar en local

Alternativa preparada el 16/09/2026 porque la suspensión automática de Codespaces interrumpe el trabajo. La preferencia posterior del usuario es mantener Codespaces por ahora y ampliar el timeout a cuatro horas. La aplicación publicada y Supabase siguen siendo los mismos.

## Abrir la copia local

Abrir la carpeta local de `LaPartidetaKF` en una ventana normal de VS Code, sin conexión remota a Codespaces. Antes de actualizar una copia existente:

```bash
git status
git fetch origin
```

Conservar cualquier cambio local. Si la copia está limpia y no hay commits divergentes, actualizar con `git merge --ff-only origin/main`. Si no existe copia, clonar `https://github.com/FedeBaezaPastor/LaPartidetaKF.git`.

Instalar Node.js 24 y ejecutar:

```bash
npm ci
npm run dev
```

Abrir la dirección que muestra Vite, normalmente `http://localhost:5173`. En local no se necesita `dev:codespace` ni abrir puertos remotos.

## Configuración y accesos

- Recuperar `.env.local` mediante la descarga privada del archivo desde el explorador de VS Code del Codespace. Guardarlo en la carpeta local y comprobar que Git lo excluye. No pegar su contenido en el chat ni subirlo al repositorio.
- Supabase sigue siendo `sjzivdhzlptxveygmpys`. Para consultas de migraciones desde el ordenador: `npx supabase login` y `npx supabase link --project-ref sjzivdhzlptxveygmpys`, después `npm run db:status`. Las migraciones de invitados ya aplicadas no se repiten.
- Mantener la clave SSH propia del ordenador y configurar el alias `lapartideta-vps` para `root@169.58.89.28`. No copiar la clave privada del Codespace al repositorio. La publicación desde terminal usa `npm run deploy -- --apply`, con el commit validado y subido a `main`.
- La web de desarrollo utiliza la base real compartida; las pruebas de escritura deben usar PGlite o datos de prueba adecuados.

## Continuidad de la tarea y del chat

Abrir la extensión Codex en la ventana local. El historial del Codespace permanece en ese entorno: no se presume que aparezca automáticamente en el ordenador. Para retomar el trabajo, leer `AGENTS.md`, `ESTADO_TAREA.md` y `GUEST_PLAYERS_SETUP.md`; contienen el alcance y el estado verificable de la tarea.

La copia privada del historial remoto está en `/workspaces/.lapartideta-codex-history`, fuera del repositorio. Conserva conversaciones e índices, sin copiar los archivos de autenticación o las claves SSH. Permanece en el disco de ese Codespace; no sustituye una descarga antes de eliminarlo.

El chat original de invitados tiene el identificador `01a0aaf7-7d05-7be0-a18b-417d97b9e2d8` y el título antiguo «Corrige controles de locución VR». Desde una terminal del Codespace se puede abrir con:

```bash
codex resume 01a0aaf7-7d05-7be0-a18b-417d97b9e2d8
```

La sesión local guarda su propio historial. Mantener el estado importante de cada tarea en el repositorio permite continuar aunque se cambie de ordenador o de conversación.
