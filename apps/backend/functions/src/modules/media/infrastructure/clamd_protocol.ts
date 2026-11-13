import type { ScanOutcome } from '../application/ports/scanner_port.js';
import { databaseMaxAgeMs, standDatabaseRevision } from './media_tool_limits.js';

/**
 * Pure clamd protocol helpers for the D1 local tools service: INSTREAM
 * framing, reply parsing, the signature database state (§7) and the scan
 * verdict. No sockets here; the service does the I/O.
 */

/** `zINSTREAM\0`, then length-prefixed chunks, then a zero-length chunk. */
export function instreamFrames(bytes: Buffer, chunkBytes: number): Buffer[] {
  if (!Number.isSafeInteger(chunkBytes) || chunkBytes < 1) throw new RangeError('chunkBytes');
  const frames: Buffer[] = [Buffer.from('zINSTREAM\0', 'ascii')];
  for (let offset = 0; offset < bytes.length; offset += chunkBytes) {
    const chunk = bytes.subarray(offset, Math.min(bytes.length, offset + chunkBytes));
    const length = Buffer.alloc(4);
    length.writeUInt32BE(chunk.length, 0);
    frames.push(length, chunk);
  }
  frames.push(Buffer.alloc(4));
  return frames;
}

export type ScanReply =
  | { readonly kind: 'ok' }
  | { readonly kind: 'found'; readonly signature: string }
  | { readonly kind: 'error'; readonly reason: string };

/** One reply of a `z`-command, NUL-terminated or not. */
export function parseScanReply(raw: string): ScanReply {
  const text = raw.replace(/\0+$/u, '').trim();
  if (text === 'stream: OK') return { kind: 'ok' };
  const found = /^stream: (\S+) FOUND$/u.exec(text);
  if (found?.[1] !== undefined) return { kind: 'found', signature: found[1] };
  if (/size limit exceeded/iu.test(text)) return { kind: 'error', reason: 'size_limit' };
  return { kind: 'error', reason: text.endsWith('ERROR') ? 'clamd_error' : 'unparsed_reply' };
}

const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export interface ClamdVersion {
  readonly engine: string;
  readonly daily?: number;
  /** Build time of `daily`, from clamd's local-time `ctime` text. */
  readonly builtAt?: Date;
}

/** `ClamAV 1.5.4/27800/Wed Oct  8 09:21:02 2026` or `ClamAV 1.5.4`; null if unparsed. */
export function parseVersion(raw: string): ClamdVersion | null {
  const text = raw.replace(/\0+$/u, '').trim();
  const engineOnly = /^ClamAV (\d+\.\d+\.\d+)$/u.exec(text);
  if (engineOnly?.[1] !== undefined) return { engine: engineOnly[1] };
  const full =
    /^ClamAV (\d+\.\d+\.\d+)\/(\d+)\/\w{3} (\w{3}) +(\d{1,2}) (\d{2}):(\d{2}):(\d{2}) (\d{4})$/u.exec(
      text,
    );
  if (full === null) return null;
  const [, engine, daily, month, day, hour, minute, second, year] = full;
  const monthIndex = months.indexOf(month ?? '');
  if (engine === undefined || daily === undefined || monthIndex < 0) return null;
  const builtAt = new Date(
    Number(year),
    monthIndex,
    Number(day),
    Number(hour),
    Number(minute),
    Number(second),
  );
  if (Number.isNaN(builtAt.getTime())) return null;
  return { engine, daily: Number(daily), builtAt };
}

export type DatabaseState =
  | { readonly state: 'fresh'; readonly daily: number; readonly builtAt: string }
  | { readonly state: 'stale'; readonly daily: number; readonly builtAt: string }
  | { readonly state: 'absent'; readonly reason: 'no_official_daily' | 'unparsed' | 'future' };

/**
 * §7: fresh only when an official `daily` exists and is at most seven days
 * old by the server clock. A missing daily, an unreadable reply or a build
 * time in the future is `absent` — never a passed check.
 */
export function databaseState(
  version: ClamdVersion | null,
  now: Date,
  maxAgeMs = databaseMaxAgeMs,
): DatabaseState {
  if (version === null) return { state: 'absent', reason: 'unparsed' };
  if (version.daily === undefined || version.builtAt === undefined)
    return { state: 'absent', reason: 'no_official_daily' };
  const age = now.getTime() - version.builtAt.getTime();
  if (age < 0) return { state: 'absent', reason: 'future' };
  const facts = { daily: version.daily, builtAt: version.builtAt.toISOString() };
  return age <= maxAgeMs ? { state: 'fresh', ...facts } : { state: 'stale', ...facts };
}

export interface ScanVerdict {
  readonly result: ScanOutcome['result'];
  readonly toolRevision: string;
  readonly signature?: string;
  readonly reason?: string;
}

/**
 * Maps one clamd reply to the port result. `FOUND` blocks regardless of the
 * database; the limit heuristics are never a pass; `OK` is `clean` only on a
 * fresh official database, or on an absent one when the local stand exemption
 * (`standSignaturesOnly`, L1 test mode) is explicitly on.
 */
export function scanVerdict(input: {
  readonly reply: ScanReply;
  readonly database: DatabaseState;
  readonly engine: string;
  readonly standSignaturesOnly: boolean;
}): ScanVerdict {
  const { reply, database, engine } = input;
  const base = `clamav-${engine}`;
  const toolRevision =
    database.state === 'absent'
      ? `${base}/${input.standSignaturesOnly ? standDatabaseRevision : 'no-database'}/official-db-absent`
      : `${base}/daily-${database.daily}${database.state === 'stale' ? '/stale' : ''}`;
  if (reply.kind === 'error') return { result: 'inconclusive', toolRevision, reason: reply.reason };
  if (reply.kind === 'found') {
    if (reply.signature.startsWith('Heuristics.Limits.Exceeded'))
      return {
        result: 'inconclusive',
        toolRevision,
        signature: reply.signature,
        reason: 'scan_limit',
      };
    return { result: 'rejected', toolRevision, signature: reply.signature };
  }
  if (database.state === 'fresh') return { result: 'clean', toolRevision };
  if (database.state === 'stale')
    return { result: 'inconclusive', toolRevision, reason: 'database_stale' };
  return input.standSignaturesOnly
    ? { result: 'clean', toolRevision, reason: 'official_db_absent_stand_exemption' }
    : { result: 'inconclusive', toolRevision, reason: 'database_absent' };
}
