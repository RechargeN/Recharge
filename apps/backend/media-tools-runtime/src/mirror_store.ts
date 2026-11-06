// N3b private mirror of the official ClamAV databases (D-02), written only by
// the mirror job and read only by the scanner at start. Content-addressed and
// append-only (D-07: nothing is overwritten or deleted):
//   cvd/<sha256>.cvd          one object per distinct database file
//   sets/<UTC stamp>.json     one manifest per job run, naming main/daily/bytecode
// Google Cloud Storage JSON API with the instance's metadata-server token; no
// SDK and no key file.
import { createHash } from 'node:crypto';

export const mirrorBucket = 'recharge-dev-n2a01-clamav-mirror';
export const databaseNames = Object.freeze(['main.cvd', 'daily.cvd', 'bytecode.cvd'] as const);
export type DatabaseName = (typeof databaseNames)[number];
/** Sum of the three official files is ~0.3 GB; anything far above is refused. */
export const maxDatabaseBytes = 400_000_000;
const maxManifestBytes = 16_384;

export type Fetch = (url: string, init?: RequestInit) => Promise<Response>;

export interface MirrorFile {
  readonly name: DatabaseName;
  readonly object: string;
  readonly sha256: string;
  readonly size: number;
  readonly version: number;
  readonly builtAtUtc: string;
}

export interface MirrorSet {
  readonly schemaVersion: 1;
  readonly createdAtUtc: string;
  readonly files: readonly MirrorFile[];
}

const sha256Pattern = /^[0-9a-f]{64}$/u;
const stampPattern = /^sets\/\d{8}T\d{6}Z\.json$/u;

export const sha256 = (bytes: Uint8Array) => createHash('sha256').update(bytes).digest('hex');
const md5Base64 = (bytes: Uint8Array) => createHash('md5').update(bytes).digest('base64');

/** `20261107T040000Z` for a set name; lexical order is time order. */
export function setStamp(at: Date): string {
  return at
    .toISOString()
    .replace(/[-:]/gu, '')
    .replace(/\.\d{3}Z$/u, 'Z');
}

/**
 * The 512-byte CVD header: `ClamAV-VDB:<time>:<version>:<sigs>:<flevel>:<md5>:<dsig>:<builder>:<stime>`.
 * Only version and build time are taken; clamd verifies the signature itself.
 */
export function parseCvdHeader(bytes: Uint8Array): {
  version: number;
  builtAtUtc: string;
} {
  const header = Buffer.from(bytes.subarray(0, 512))
    .toString('latin1')
    .replace(/[\0 ]+$/u, '');
  const fields = header.split(':');
  if (fields[0] !== 'ClamAV-VDB' || fields.length < 9) throw new Error('not a CVD header');
  const version = Number(fields[2]);
  const stime = Number(fields[fields.length - 1]);
  if (!Number.isSafeInteger(version) || version < 1) throw new Error('CVD version invalid');
  if (!Number.isSafeInteger(stime) || stime < 1_000_000_000) throw new Error('CVD time invalid');
  return { version, builtAtUtc: new Date(stime * 1000).toISOString() };
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/** Strict manifest check: exactly the three files, content-addressed, bounded. */
export function parseMirrorSet(value: unknown): MirrorSet {
  if (!isRecord(value) || value.schemaVersion !== 1) throw new Error('set: schema');
  if (typeof value.createdAtUtc !== 'string' || Number.isNaN(Date.parse(value.createdAtUtc)))
    throw new Error('set: createdAtUtc');
  if (!Array.isArray(value.files) || value.files.length !== databaseNames.length)
    throw new Error('set: files');
  let total = 0;
  const files = databaseNames.map((name): MirrorFile => {
    const raw: unknown = (value.files as unknown[]).find(
      (file) => isRecord(file) && file.name === name,
    );
    if (!isRecord(raw)) throw new Error(`set: ${name} missing`);
    const digest = raw.sha256;
    if (typeof digest !== 'string' || !sha256Pattern.test(digest))
      throw new Error(`set: ${name} sha256`);
    if (raw.object !== `cvd/${digest}.cvd`) throw new Error(`set: ${name} object`);
    const size = raw.size;
    if (!Number.isSafeInteger(size) || (size as number) < 512) throw new Error(`set: ${name} size`);
    total += size as number;
    const version = raw.version;
    if (!Number.isSafeInteger(version) || (version as number) < 1)
      throw new Error(`set: ${name} version`);
    if (typeof raw.builtAtUtc !== 'string' || Number.isNaN(Date.parse(raw.builtAtUtc)))
      throw new Error(`set: ${name} builtAtUtc`);
    return {
      name,
      object: raw.object,
      sha256: digest,
      size: size as number,
      version: version as number,
      builtAtUtc: raw.builtAtUtc,
    };
  });
  if (total > maxDatabaseBytes) throw new Error('set: too large');
  return { schemaVersion: 1, createdAtUtc: value.createdAtUtc, files };
}

/** Newest set name among object names; foreign names are ignored. */
export function newestSet(names: readonly string[]): string | null {
  const sets = names.filter((name) => stampPattern.test(name)).sort();
  return sets.at(-1) ?? null;
}

export class MirrorStore {
  #token: { value: string; expiresAt: number } | null = null;

  constructor(
    private readonly fetchImpl: Fetch = fetch,
    private readonly bucket: string = mirrorBucket,
    private readonly api: string = 'https://storage.googleapis.com',
    private readonly metadata: string = 'http://metadata.google.internal',
  ) {}

  async #authorization(): Promise<string> {
    if (this.#token === null || Date.now() > this.#token.expiresAt) {
      const response = await this.fetchImpl(
        `${this.metadata}/computeMetadata/v1/instance/service-accounts/default/token`,
        {
          headers: { 'metadata-flavor': 'Google' },
          signal: AbortSignal.timeout(5_000),
        },
      );
      if (response.status !== 200) throw new Error(`metadata token ${response.status}`);
      const body = (await response.json()) as {
        access_token?: unknown;
        expires_in?: unknown;
      };
      if (typeof body.access_token !== 'string' || typeof body.expires_in !== 'number')
        throw new Error('metadata token shape');
      this.#token = {
        value: body.access_token,
        expiresAt: Date.now() + Math.max(0, body.expires_in - 60) * 1000,
      };
    }
    return `Bearer ${this.#token.value}`;
  }

  async #json(url: string): Promise<unknown> {
    const response = await this.fetchImpl(url, {
      headers: { authorization: await this.#authorization() },
      signal: AbortSignal.timeout(30_000),
    });
    if (response.status !== 200) throw new Error(`GET ${response.status}`);
    return response.json();
  }

  #object(name: string): string {
    return `${this.api}/storage/v1/b/${this.bucket}/o/${encodeURIComponent(name)}`;
  }

  async list(prefix: string): Promise<string[]> {
    const names: string[] = [];
    let pageToken: string | undefined;
    do {
      const query = new URLSearchParams({
        prefix,
        fields: 'items(name),nextPageToken',
      });
      if (pageToken !== undefined) query.set('pageToken', pageToken);
      const page = (await this.#json(`${this.api}/storage/v1/b/${this.bucket}/o?${query}`)) as {
        items?: { name?: unknown }[];
        nextPageToken?: unknown;
      };
      for (const item of page.items ?? []) if (typeof item.name === 'string') names.push(item.name);
      pageToken = typeof page.nextPageToken === 'string' ? page.nextPageToken : undefined;
      if (names.length > 10_000) throw new Error('list: too many objects');
    } while (pageToken !== undefined);
    return names;
  }

  /** Bounded download; the caller checks the content. */
  async download(name: string, maxBytes: number): Promise<Buffer> {
    const response = await this.fetchImpl(`${this.#object(name)}?alt=media`, {
      headers: { authorization: await this.#authorization() },
      signal: AbortSignal.timeout(120_000),
    });
    if (response.status !== 200 || response.body === null)
      throw new Error(`download ${response.status}`);
    const declared = Number(response.headers.get('content-length') ?? 'NaN');
    if (Number.isFinite(declared) && declared > maxBytes) throw new Error('download: too large');
    const chunks: Buffer[] = [];
    let size = 0;
    for await (const chunk of response.body as AsyncIterable<Uint8Array>) {
      size += chunk.length;
      if (size > maxBytes) throw new Error('download: too large');
      chunks.push(Buffer.from(chunk));
    }
    return Buffer.concat(chunks);
  }

  /**
   * Create-only upload (`ifGenerationMatch=0`). An existing object of the same
   * name counts only when its size and MD5 match these bytes.
   */
  async createOnly(
    name: string,
    bytes: Buffer,
    contentType: string,
  ): Promise<'created' | 'existing'> {
    const query = new URLSearchParams({
      uploadType: 'media',
      name,
      ifGenerationMatch: '0',
    });
    const response = await this.fetchImpl(
      `${this.api}/upload/storage/v1/b/${this.bucket}/o?${query}`,
      {
        method: 'POST',
        headers: {
          authorization: await this.#authorization(),
          'content-type': contentType,
        },
        body: bytes,
        signal: AbortSignal.timeout(300_000),
      },
    );
    if (response.status === 200) return 'created';
    if (response.status !== 412) throw new Error(`upload ${response.status}`);
    const existing = (await this.#json(`${this.#object(name)}?fields=size,md5Hash`)) as {
      size?: unknown;
      md5Hash?: unknown;
    };
    if (existing.size !== String(bytes.length) || existing.md5Hash !== md5Base64(bytes))
      throw new Error(`existing object differs: ${name}`);
    return 'existing';
  }
}
