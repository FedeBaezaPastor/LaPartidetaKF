import { DatabaseSync, backup } from 'node:sqlite';
import { mkdir, readdir, readFile, writeFile, copyFile, chmod, rename, rm, open } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(import.meta.url);
const source = resolve(process.env.CODEX_HOME || join(homedir(), '.codex'));
const destination = resolve(process.env.CODEX_HISTORY_BACKUP_ROOT || (process.env.CODESPACES === 'true'
  ? '/workspaces/.lapartideta-codex-history'
  : join(homedir(), '.local/share/lapartideta/codex-history')));
const pidFile = join(destination, 'watch.pid');

async function entries(path) {
  try { return await readdir(path, { withFileTypes: true }); }
  catch (error) { if (error.code === 'ENOENT') return []; throw error; }
}
async function copySessions(from, to) {
  for (const entry of await entries(from)) {
    if (entry.isDirectory()) await copySessions(join(from, entry.name), join(to, entry.name));
    else if (entry.isFile() && entry.name.endsWith('.jsonl')) {
      await mkdir(to, { recursive: true, mode: 0o700 });
      await copyFile(join(from, entry.name), join(to, entry.name));
      await chmod(join(to, entry.name), 0o600);
    }
  }
}
async function snapshot() {
  const databases = (await entries(source)).filter(entry => entry.isFile() && /^(state|thread_history)_\d+\.sqlite$/.test(entry.name));
  if (!(await entries(join(source, 'sessions'))).length && !(await entries(join(source, 'archived_sessions'))).length) return;
  await mkdir(destination, { recursive: true, mode: 0o700 });
  await chmod(destination, 0o700);
  const staging = join(destination, '.snapshot-tmp');
  await rm(staging, { recursive: true, force: true });
  await mkdir(staging, { mode: 0o700 });
  for (const entry of databases) {
    const db = new DatabaseSync(join(source, entry.name), { readOnly: true });
    try { await backup(db, join(staging, entry.name)); }
    finally { db.close(); }
    await chmod(join(staging, entry.name), 0o600);
  }
  // Copy rollouts after the SQLite snapshot so indexed conversations have files.
  for (const directory of ['sessions', 'archived_sessions']) await copySessions(join(source, directory), join(staging, directory));
  try {
    await copyFile(join(source, 'session_index.jsonl'), join(staging, 'session_index.jsonl'));
    await chmod(join(staging, 'session_index.jsonl'), 0o600);
  } catch (error) { if (error.code !== 'ENOENT') throw error; }
  await writeFile(join(staging, 'snapshot.json'), JSON.stringify({ createdAt: new Date().toISOString(), source }, null, 2), { mode: 0o600 });
  await rm(join(destination, 'previous'), { recursive: true, force: true });
  try { await rename(join(destination, 'latest'), join(destination, 'previous')); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  await rename(staging, join(destination, 'latest'));
}
async function watcherRunning() {
  try {
    const pid = Number(await readFile(pidFile, 'utf8'));
    if (!Number.isInteger(pid) || pid <= 0) return false;
    const command = await readFile(`/proc/${pid}/cmdline`, 'utf8');
    return command.split('\0').includes(script) && command.split('\0').includes('--watch');
  } catch (error) { if (error.code === 'ENOENT' || error.code === 'ESRCH') return false; throw error; }
}
async function restore() {
  if ((await entries(source)).some(entry => /^(state|thread_history)_\d+\.sqlite/.test(entry.name)) || (await entries(join(source, 'sessions'))).length) {
    throw new Error('No se restaura sobre un historial existente. Cierra Codex y recupera en una carpeta vacía.');
  }
  const from = join(destination, 'latest');
  const metadata = JSON.parse(await readFile(join(from, 'snapshot.json'), 'utf8'));
  if (metadata.source !== source) throw new Error('La ruta de CODEX_HOME difiere de la original; no se reescriben las rutas del índice automáticamente.');
  await mkdir(source, { recursive: true, mode: 0o700 });
  for (const directory of ['sessions', 'archived_sessions']) await copySessions(join(from, directory), join(source, directory));
  for (const entry of await entries(from)) {
    if (entry.isFile() && (/^(state|thread_history)_\d+\.sqlite$/.test(entry.name) || entry.name === 'session_index.jsonl')) {
      await copyFile(join(from, entry.name), join(source, entry.name));
      await chmod(join(source, entry.name), 0o600);
    }
  }
}
try {
  const mode = process.argv[2] || '--once';
  if (!['--once', '--start', '--watch', '--restore'].includes(mode) || process.argv.length > 3) throw new Error('Uso: node scripts/codex-history.mjs [--once|--start|--restore]');
  if (mode === '--restore') {
    await restore();
    console.log('Historial restaurado. Abre Codex y selecciona la conversación guardada.');
  } else if (mode === '--start') {
    await mkdir(destination, { recursive: true, mode: 0o700 });
    if (!(await entries(source)).some(entry => /^(state|thread_history)_\d+\.sqlite/.test(entry.name)) && !(await entries(join(source, 'sessions'))).length) {
      try { await restore(); }
      catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
    if (!(await watcherRunning())) {
      await snapshot();
      const child = spawn(process.execPath, [script, '--watch'], { detached: true, stdio: 'ignore' });
      child.unref();
    }
    console.log(`Copia del historial iniciada en ${destination}; intervalo de 60 segundos.`);
  } else if (mode === '--watch') {
    await mkdir(destination, { recursive: true, mode: 0o700 });
    if (await watcherRunning()) process.exit(0);
    await rm(pidFile, { force: true });
    const lock = await open(pidFile, 'wx', 0o600);
    await lock.writeFile(String(process.pid));
    await lock.close();
    while (true) {
      try { await snapshot(); }
      catch (error) { await writeFile(join(destination, 'last-error.txt'), `${new Date().toISOString()} ${error.message}\n`, { mode: 0o600 }); }
      await new Promise(done => setTimeout(done, 60_000));
    }
  } else {
    await snapshot();
    console.log(`Copia del historial guardada en ${destination}/latest.`);
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
