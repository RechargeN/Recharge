// N3b mirror job, after freshclam (verified .deb, CVD signatures checked by
// freshclam) filled <dir>: publishes main/daily/bytecode.cvd create-only by
// content hash and then one new set manifest. Nothing is overwritten or
// deleted (D-07). A .cld, a missing file or anything oversized stops the job.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  MirrorStore,
  databaseNames,
  maxDatabaseBytes,
  parseCvdHeader,
  parseMirrorSet,
  setStamp,
  sha256,
  type MirrorFile,
  type MirrorSet,
} from './mirror_store.js';

export function readDatabaseDir(dir: string): { file: MirrorFile; bytes: Buffer }[] {
  const names = readdirSync(dir);
  const incremental = names.filter((name) => name.endsWith('.cld'));
  if (incremental.length > 0)
    throw new Error(`incremental databases refused: ${incremental.join(',')}`);
  let total = 0;
  return databaseNames.map((name) => {
    if (!names.includes(name)) throw new Error(`${name} missing`);
    const full = path.join(dir, name);
    const info = statSync(full);
    if (!info.isFile()) throw new Error(`${name} is not a file`);
    total += info.size;
    if (total > maxDatabaseBytes) throw new Error('databases too large');
    const bytes = readFileSync(full);
    const digest = sha256(bytes);
    const header = parseCvdHeader(bytes);
    return {
      bytes,
      file: {
        name,
        object: `cvd/${digest}.cvd`,
        sha256: digest,
        size: bytes.length,
        ...header,
      },
    };
  });
}

export async function publish(
  store: MirrorStore,
  dir: string,
  now: Date,
): Promise<{ set: string; created: string[]; existing: string[] }> {
  const entries = readDatabaseDir(dir);
  const created: string[] = [];
  const existing: string[] = [];
  for (const { file, bytes } of entries) {
    const outcome = await store.createOnly(file.object, bytes, 'application/octet-stream');
    (outcome === 'created' ? created : existing).push(file.name);
  }
  const manifest: MirrorSet = parseMirrorSet({
    schemaVersion: 1,
    createdAtUtc: now.toISOString(),
    files: entries.map((entry) => entry.file),
  });
  const set = `sets/${setStamp(now)}.json`;
  const outcome = await store.createOnly(
    set,
    Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`),
    'application/json',
  );
  if (outcome !== 'created') throw new Error(`set already exists: ${set}`);
  return { set, created, existing };
}

if (
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const dir = process.argv[2];
  const started = Date.now();
  try {
    if (dir === undefined) throw new Error('usage: publish_databases <dir>');
    const result = await publish(new MirrorStore(), dir, new Date());
    process.stdout.write(
      `${JSON.stringify({ kind: 'clamav-mirror-published', ...result, durationMs: Date.now() - started })}\n`,
    );
  } catch (error) {
    process.stdout.write(
      `${JSON.stringify({
        kind: 'clamav-mirror-failed',
        reason: error instanceof Error ? error.message.slice(0, 200) : 'unknown',
        durationMs: Date.now() - started,
      })}\n`,
    );
    process.exit(1);
  }
}
