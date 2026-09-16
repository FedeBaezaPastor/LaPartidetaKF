import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, readdirSync, cpSync, rmSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const PROJECT = 'sjzivdhzlptxveygmpys';
// Current production state was inspected on 2026-09-15. Older SQL includes
// manual executions and duplicate imports; it is retained as historical source.
export const HISTORICAL_CUTOFF = '20260917100000';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

export function parseHistory(output) {
  const value = JSON.parse(output);
  if (!Array.isArray(value.migrations)) throw new Error('Unexpected migration history response');
  const versions = value.migrations.filter(row => row.remote).map(row => row.remote);
  if (versions.some(version => !/^\d{14}$/.test(version))) throw new Error('Invalid remote migration version');
  return [...new Set(versions)].sort();
}

export function pendingFiles(files, remote) {
  return files.filter(file => /^\d{14}_[\w-]+\.sql$/.test(file))
    .filter(file => file.slice(0, 14) > HISTORICAL_CUTOFF && !remote.includes(file.slice(0, 14))).sort();
}

export function validateSelection(file, files, remote) {
  const version = file.slice(0, 14);
  if (!/^\d{14}_[\w-]+\.sql$/.test(file)) throw new Error('Use a timestamped SQL migration file');
  if (version <= HISTORICAL_CUTOFF) throw new Error('Historical migration: do not replay it. Create a new reviewed migration.');
  if (remote.includes(version)) throw new Error('This migration version is already registered in Supabase');
  if (remote.some(item => item > version)) throw new Error('Migration must be newer than the remote history');
  if (files.filter(item => item.startsWith(version + '_')).length !== 1) throw new Error('Missing or duplicate local migration version');
  if (pendingFiles(files, remote)[0] !== file) throw new Error('Apply earlier new migrations first');
}

export function prepareWorkspace(directory, remote, selectedFile, sql) {
  const migrations = join(directory, 'supabase', 'migrations');
  mkdirSync(migrations, { recursive: true });
  // Supabase compares versions, not file contents, for already-applied entries.
  // These placeholders preserve remote history without replaying historical SQL.
  for (const version of remote) {
    writeFileSync(join(migrations, `${version}_remote_history.sql`), '-- Already registered remotely. Historical SQL is not replayed.\n');
  }
  writeFileSync(join(migrations, selectedFile), sql);
}

function cli(args, capture = false) {
  const entry = join(root, 'node_modules', 'supabase', 'dist', 'supabase.js');
  const result = spawnSync(process.execPath, [entry, ...args], { cwd: root, encoding: 'utf8', stdio: capture ? ['ignore', 'pipe', 'inherit'] : 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Supabase command failed (${result.status})`);
  return result.stdout;
}

function main(args) {
  const apply = args.includes('--apply');
  const rest = args.filter(arg => arg !== '--apply');
  if (rest.length > 1 || rest.some(arg => arg.startsWith('--') && arg !== '--status') || (apply && (rest.length === 0 || rest[0] === '--status'))) {
    throw new Error('Usage: npm run db:migrate -- [--status | supabase/migrations/NEW.sql [--apply]]');
  }
  const linked = readFileSync(join(root, 'supabase', '.temp', 'project-ref'), 'utf8').trim();
  if (linked !== PROJECT) throw new Error(`Expected project ${PROJECT}; link the correct project first`);
  const files = readdirSync(join(root, 'supabase', 'migrations'));
  const historyArgs = ['migration', 'list', '--linked', '--agent', 'yes', '--output-format', 'json'];
  const remote = parseHistory(cli(historyArgs, true));
  const pending = pendingFiles(files, remote);
  console.log(`Project: ${PROJECT}. Remote history: ${remote.length} versions.`);
  console.log(`New migrations pending: ${pending.length}. Historical SQL through ${HISTORICAL_CUTOFF} is excluded.`);
  if (!rest.length || rest[0] === '--status') {
    for (const file of pending) console.log(file);
    return;
  }
  const source = realpathSync(resolve(root, rest[0]));
  if (dirname(source) !== realpathSync(join(root, 'supabase', 'migrations'))) throw new Error('Select a file inside supabase/migrations');
  const file = basename(source);
  validateSelection(file, files, remote);
  const sql = readFileSync(source, 'utf8');
  if (!sql.trim()) throw new Error('Empty migration');
  const temporary = mkdtempSync(join(tmpdir(), 'lapartideta-migration-'));
  try {
    prepareWorkspace(temporary, remote, file, sql);
    cpSync(join(root, 'supabase', 'config.toml'), join(temporary, 'supabase', 'config.toml'));
    cpSync(join(root, 'supabase', '.temp'), join(temporary, 'supabase', '.temp'), { recursive: true });
    console.log(`Selected: ${file}. ${apply ? 'Applying reviewed SQL.' : 'Preview only; no SQL will be applied.'}`);
    cli(['db', 'push', '--linked', '--workdir', temporary, ...(apply ? ['--yes'] : ['--dry-run'])]);
    if (apply) {
      const updated = parseHistory(cli(historyArgs, true));
      if (!updated.includes(file.slice(0, 14))) throw new Error('Migration was not found in remote history after applying');
      console.log('Migration recorded in Supabase history.');
    }
  } finally {
    rmSync(temporary, { recursive: true, force: true });
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
