import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseHistory, pendingFiles, validateSelection, prepareWorkspace } from '../scripts/supabase-migrate.mjs';

test('historical SQL is never treated as new work', () => {
  const files = ['20251129032653_initial.sql', '20260917100000_group_members.sql', '20260918100000_new.sql'];
  assert.deepEqual(pendingFiles(files, []), ['20260918100000_new.sql']);
  assert.throws(() => validateSelection(files[0], files, []), /Historical/);
  assert.throws(() => validateSelection(files[1], files, []), /Historical/);
});

test('rejects repeated, ambiguous and out-of-order versions', () => {
  const a = '20260918100000_first.sql', b = '20260919100000_second.sql';
  assert.throws(() => validateSelection(a, [a], ['20260918100000']), /already/);
  assert.throws(() => validateSelection(a, [a], ['20260919100000']), /newer/);
  assert.throws(() => validateSelection(a, [a, '20260918100000_duplicate.sql'], []), /duplicate/);
  assert.throws(() => validateSelection(b, [a, b], []), /earlier/);
  assert.doesNotThrow(() => validateSelection(a, [a, b], []));
});

test('fails closed on invalid history and keeps remote-only versions', () => {
  assert.throws(() => parseHistory('{}'), /Unexpected/);
  assert.throws(() => parseHistory('{"migrations":[{"remote":"../oops"}]}'), /Invalid/);
  assert.deepEqual(parseHistory('{"migrations":[{"local":"x","remote":""},{"remote":"20260729182230"}]}'), ['20260729182230']);
});

test('temporary workspace contains only placeholders and the selected SQL', () => {
  const directory = mkdtempSync(join(tmpdir(), 'migration-workflow-test-'));
  try {
    const name = '20260918100000_new.sql';
    prepareWorkspace(directory, ['20260729182230'], name, 'SELECT 1;');
    const folder = join(directory, 'supabase', 'migrations');
    assert.deepEqual(readdirSync(folder).sort(), ['20260729182230_remote_history.sql', name]);
    assert.match(readFileSync(join(folder, '20260729182230_remote_history.sql'), 'utf8'), /^--/);
    assert.equal(readFileSync(join(folder, name), 'utf8'), 'SELECT 1;');
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
