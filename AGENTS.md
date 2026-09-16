# Entorno de trabajo

- Proyecto: `/workspaces/LaPartidetaKF`, en el Codespace compartido `glowing-space-system-rpw7rr56pv3xq4q`. La terminal es Linux/Bash.
- Guía de configuración y comprobaciones: `CODESPACE_SETUP.md`.
- Instalar las dependencias fijadas con `npm ci`. Arrancar con `npm run dev:codespace`.
- Las variables públicas de la web están en `.env.local`, excluido de Git. Mantener credenciales, claves SSH y copias de seguridad fuera del repositorio.
- GitHub: `FedeBaezaPastor/LaPartidetaKF`, rama habitual `main`. Comprobar cambios locales y remotos antes de sincronizar; conservar el trabajo del usuario.

## Supabase

- Destino existente: `sjzivdhzlptxveygmpys` (La Partideta K&F_01).
- `npm run db:status` consulta las migraciones nuevas. `npm run db:migrate -- supabase/migrations/ARCHIVO.sql` muestra una simulación; añadir `--apply` aplica ese archivo y registra la versión.
- Revisar y probar el SQL antes de aplicar. Una migración nueva debe tener una versión única posterior a `20260917100000` y a las versiones remotas.
- El historial antiguo contiene ejecuciones manuales, importaciones duplicadas y versiones repetidas. Los archivos hasta `20260917100000` se conservan como referencia histórica y quedan fuera del flujo nuevo. Su exclusión no afirma que cada archivo se ejecutara literalmente.
- No ejecutar `supabase db push` directamente sobre toda la carpeta histórica, ni `db reset --linked`, ni registrar en bloque los archivos antiguos como aplicados. Si hay que corregir un comportamiento histórico, crear una migración nueva revisada.
- La simulación usa archivos temporales que representan las versiones ya registradas remotamente y copia solo la migración nueva seleccionada. No modifica el historial previo.
- La web local utiliza la base compartida real: las pruebas que escriben datos deben usar las pruebas locales con PGlite o cuentas/datos de prueba adecuados.

## VPS

- Alias SSH disponible en este Codespace: `lapartideta-vps` (`root@169.58.89.28`). Clave propia en `~/.ssh/id_ed25519_lapartideta_vps`.
- Aplicación en `/var/www/miapp`, contenedor `lapartideta-app`, web `https://golf.arinsaldev.com`.
- Consultar estado: `ssh -o BatchMode=yes lapartideta-vps 'docker ps --filter name=lapartideta-app'`.
- Para una tarea de publicación, validar el código, subir los commits destinados a producción y ejecutar por SSH `cd /var/www/miapp && ./deploy.sh`; después verificar el contenedor y la web. El script remoto descarga `main` y reinicia el contenedor.
- `local-deploy.ps1` pertenece al flujo de Windows. En el Codespace utilizar Bash y SSH.

## Validación

- Código: `npm run typecheck`, `npm run test:admin`, `npm run build`.
- Flujo de migraciones: `npm run test:workflow` y `npm run db:status`.
- Git: `git diff --check`; confirmar que `.env.local`, `.local/` y los nuevos archivos de `supabase/.temp/` están excluidos.
