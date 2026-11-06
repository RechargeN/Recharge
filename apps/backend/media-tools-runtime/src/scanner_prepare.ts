// N3b scanner start, before the host listens (start.sh):
//   fetch <dir>          newest mirror set → main/daily/bytecode.cvd in <dir>
//   await-clamd <port> <seconds>   until clamd answers VERSION
// Any failure exits non-zero; start.sh then starts the host without clamd and
// every scan is `inconclusive` (fail-closed). Freshness (≤ 7 days) is decided
// later from clamd's own VERSION answer, not from the manifest.
import { writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { clamdVersion } from './cloud_tools_host.js';
import {
  MirrorStore,
  maxDatabaseBytes,
  newestSet,
  parseMirrorSet,
  sha256,
  type MirrorSet,
} from './mirror_store.js';

export async function fetchNewestSet(
  store: MirrorStore,
  dir: string,
): Promise<{ name: string; files: MirrorSet['files'] }> {
  const name = newestSet(await store.list('sets/'));
  if (name === null) throw new Error('mirror has no database set');
  const set = parseMirrorSet(JSON.parse((await store.download(name, 16_384)).toString('utf8')));
  mkdirSync(dir, { recursive: true });
  if (readdirSync(dir).length > 0) throw new Error('database directory is not empty');
  for (const file of set.files) {
    const bytes = await store.download(file.object, Math.min(file.size, maxDatabaseBytes));
    if (bytes.length !== file.size || sha256(bytes) !== file.sha256)
      throw new Error(`mirror object differs from its set: ${file.name}`);
    writeFileSync(path.join(dir, file.name), bytes, { flag: 'wx' });
  }
  return { name, files: set.files };
}

export async function awaitClamd(port: number, seconds: number): Promise<string> {
  const deadline = Date.now() + seconds * 1000;
  for (;;) {
    try {
      const version = await clamdVersion(port);
      if (version !== null) return version.engine;
    } catch {
      // not listening yet
    }
    if (Date.now() > deadline) throw new Error(`clamd did not answer within ${seconds} s`);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
}

if (
  process.argv[1] !== undefined &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  const [command, first, second] = process.argv.slice(2);
  const started = Date.now();
  try {
    if (command === 'fetch' && first !== undefined) {
      const { name, files } = await fetchNewestSet(new MirrorStore(), first);
      const daily = files.find((file) => file.name === 'daily.cvd');
      process.stdout.write(
        `${JSON.stringify({
          kind: 'media-tools-databases',
          set: name.slice('sets/'.length, -'.json'.length),
          dailyVersion: daily?.version ?? null,
          dailyBuiltAtUtc: daily?.builtAtUtc ?? null,
          durationMs: Date.now() - started,
        })}\n`,
      );
    } else if (command === 'await-clamd') {
      const engine = await awaitClamd(Number(first), Number(second));
      process.stdout.write(
        `${JSON.stringify({ kind: 'media-tools-clamd', engine, durationMs: Date.now() - started })}\n`,
      );
    } else throw new Error('usage: fetch <dir> | await-clamd <port> <seconds>');
  } catch (error) {
    process.stdout.write(
      `${JSON.stringify({
        kind: 'media-tools-prepare-failed',
        command,
        reason: error instanceof Error ? error.message.slice(0, 200) : 'unknown',
        durationMs: Date.now() - started,
      })}\n`,
    );
    process.exit(1);
  }
}
