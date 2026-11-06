import { createHash } from 'node:crypto';

import type { App } from 'firebase-admin/app';
import { getStorage } from 'firebase-admin/storage';

import { isEntityId } from '../../../shared/ids.js';

import type {
  ObjectBytesPort,
  ObjectRead,
  ObjectStat,
  ObjectStorePort,
  RemovalResult,
} from '../application/ports/object_store_port.js';
import { detectMediaType } from './storage_emulator_object_store.js';

/** N3a: the only cloud target. No default-bucket inference, no other project. */
export const devCloudMediaProjectId = 'recharge-dev-n2a01';
export const devCloudMediaBucketName = 'recharge-dev-n2a01-media';
/** Explicit opt-in; Local/Emulator stays the default everywhere else. */
export const devCloudMediaStorageMode = 'dev-cloud';

/** The slice of a Cloud Storage bucket this adapter needs (`@google-cloud/storage` `Bucket` fits). */
export interface DevCloudBucketLike {
  readonly name: string;
  file(name: string, options?: { generation?: string | number }): DevCloudFileLike;
}

export interface DevCloudFileMetadata {
  readonly generation?: string | number;
  readonly size?: string | number;
  readonly md5Hash?: string;
}

export interface DevCloudFileLike {
  getMetadata(): Promise<[DevCloudFileMetadata, ...unknown[]]>;
  createReadStream(options?: { start?: number; end?: number }): NodeJS.ReadableStream;
  save(
    data: Buffer,
    options: {
      resumable: false;
      contentType?: string;
      preconditionOpts: { ifGenerationMatch: number };
    },
  ): Promise<void>;
  delete(options: { ifGenerationMatch: string | number }): Promise<unknown>;
}

export class DevCloudStorageContextError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'DevCloudStorageContextError';
  }
}

const emulatorVariables = [
  'FIREBASE_STORAGE_EMULATOR_HOST',
  'STORAGE_EMULATOR_HOST',
  'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_AUTH_EMULATOR_HOST',
] as const;

/**
 * Fail closed unless this is exactly the dev project, the dev-cloud mode was
 * chosen explicitly, no Emulator is configured at the same time and the bucket
 * is exactly the dev Media bucket.
 */
export function assertDevCloudStorageContext(
  bucketName: string,
  environment: NodeJS.ProcessEnv = process.env,
): void {
  if (environment.RECHARGE_MEDIA_STORAGE !== devCloudMediaStorageMode)
    throw new DevCloudStorageContextError('dev_cloud_mode_not_selected');
  if (environment.GCLOUD_PROJECT !== devCloudMediaProjectId)
    throw new DevCloudStorageContextError('project_not_dev');
  for (const name of emulatorVariables)
    if ((environment[name] ?? '') !== '')
      throw new DevCloudStorageContextError('emulator_and_cloud_both_configured');
  if (bucketName !== devCloudMediaBucketName)
    throw new DevCloudStorageContextError('bucket_not_dev_media');
}

function statusOf(error: unknown): number | undefined {
  const code = (error as { code?: unknown } | null)?.code;
  return typeof code === 'number' ? code : undefined;
}

function generationOf(metadata: DevCloudFileMetadata): string {
  const generation = String(metadata.generation ?? '');
  if (!/^[1-9][0-9]*$/u.test(generation))
    throw new DevCloudStorageContextError('provider_generation_missing');
  return generation;
}

function sizeOf(metadata: DevCloudFileMetadata): number {
  const size = Number(metadata.size);
  if (!Number.isSafeInteger(size) || size < 0)
    throw new DevCloudStorageContextError('provider_size_missing');
  return size;
}

/** Reads at most `maxBytes + 1` bytes and stops; the caller decides on `too_large`. */
async function boundedBytes(file: DevCloudFileLike, maxBytes: number): Promise<Buffer> {
  const chunks: Buffer[] = [];
  let length = 0;
  const stream = file.createReadStream({ start: 0, end: maxBytes });
  for await (const chunk of stream as AsyncIterable<Buffer | string>) {
    const buffer = typeof chunk === 'string' ? Buffer.from(chunk) : chunk;
    chunks.push(buffer);
    length += buffer.length;
    if (length > maxBytes) {
      (stream as { destroy?: () => void }).destroy?.();
      break;
    }
  }
  return Buffer.concat(chunks, length);
}

/**
 * N3a: `ObjectStorePort`/`ObjectBytesPort` over the dev Cloud Storage bucket.
 * Same contract as `StorageEmulatorObjectStore`: provider facts are measured
 * from the stored object, never taken from the caller. Differences are
 * hardening only: every read is bounded and pinned to one generation, writes
 * are create-only, deletion is generation-safe and a permission/timeout/412 is
 * never reported as `removed` or `absent`. No scanner, processor, push, public
 * ACL, signed URL or cleanup lives here: lifecycle, quarantine, retention and
 * deletion stay with the Media service.
 */
export class DevCloudObjectStore implements ObjectStorePort, ObjectBytesPort {
  constructor(
    private readonly bucket: DevCloudBucketLike,
    private readonly maxObjectBytes: number,
    environment: NodeJS.ProcessEnv = process.env,
    private readonly prefix = 'media-source/',
    private readonly variantPrefix = 'media-variant/',
  ) {
    assertDevCloudStorageContext(bucket.name, environment);
    if (!Number.isSafeInteger(maxObjectBytes) || maxObjectBytes <= 0)
      throw new DevCloudStorageContextError('max_object_bytes_invalid');
  }

  private sourceName(objectKeyHandle: string): string {
    if (!/^objk:[0-9A-Za-z-]{20,64}$/u.test(objectKeyHandle))
      throw new DevCloudStorageContextError('object_key_handle_invalid');
    return `${this.prefix}${objectKeyHandle.slice('objk:'.length)}`;
  }

  private variantName(variantId: string): string {
    if (!isEntityId(variantId)) throw new DevCloudStorageContextError('variant_id_invalid');
    return `${this.variantPrefix}${variantId}`;
  }

  /** `null` only for a confirmed 404; permission, timeout and other errors propagate. */
  private async metadataOrAbsent(
    name: string,
    generation?: string,
  ): Promise<DevCloudFileMetadata | null> {
    try {
      const file =
        generation === undefined ? this.bucket.file(name) : this.bucket.file(name, { generation });
      const [metadata] = await file.getMetadata();
      return metadata;
    } catch (error) {
      if (statusOf(error) === 404) return null;
      throw error;
    }
  }

  /**
   * Bounded: an object above `maxObjectBytes` is never downloaded. Its size is
   * reported so the Media service refuses it (`limit_exceeded` precedes every
   * hash/type comparison); the empty hash and generic type match nothing.
   */
  async stat(objectKeyHandle: string): Promise<ObjectStat> {
    const name = this.sourceName(objectKeyHandle);
    const metadata = await this.metadataOrAbsent(name);
    if (metadata === null) return { kind: 'absent' };
    const providerGeneration = generationOf(metadata);
    const size = sizeOf(metadata);
    if (size > this.maxObjectBytes)
      return {
        kind: 'complete',
        providerGeneration,
        byteLength: size,
        sha256: '',
        detectedMediaType: 'application/octet-stream',
      };
    const bytes = await boundedBytes(
      this.bucket.file(name, { generation: providerGeneration }),
      this.maxObjectBytes,
    );
    if (bytes.length !== size) return { kind: 'partial' };
    return {
      kind: 'complete',
      providerGeneration,
      byteLength: bytes.length,
      sha256: createHash('sha256').update(bytes).digest('hex'),
      detectedMediaType: detectMediaType(bytes),
    };
  }

  async remove(objectKeyHandle: string): Promise<RemovalResult> {
    return this.removeName(this.sourceName(objectKeyHandle));
  }

  async removeVariant(variantId: string): Promise<RemovalResult> {
    return this.removeName(this.variantName(variantId));
  }

  /** Deletes exactly the generation it saw; a replaced object is `failed`, never removed. */
  private async removeName(name: string): Promise<RemovalResult> {
    try {
      const metadata = await this.metadataOrAbsent(name);
      if (metadata === null) return 'absent';
      await this.bucket.file(name).delete({ ifGenerationMatch: generationOf(metadata) });
      return 'removed';
    } catch (error) {
      return statusOf(error) === 404 ? 'absent' : 'failed';
    }
  }

  async read(objectKeyHandle: string, maxBytes: number): Promise<ObjectRead> {
    const name = this.sourceName(objectKeyHandle);
    const metadata = await this.metadataOrAbsent(name);
    if (metadata === null) return { kind: 'absent' };
    const providerGeneration = generationOf(metadata);
    if (sizeOf(metadata) > maxBytes) return { kind: 'too_large' };
    const bytes = await boundedBytes(
      this.bucket.file(name, { generation: providerGeneration }),
      maxBytes,
    );
    if (bytes.length > maxBytes) return { kind: 'too_large' };
    return { kind: 'complete', providerGeneration, bytes };
  }

  /**
   * Create-only. A retry after a lost response finds the object (412) and
   * returns its generation only when the stored bytes are identical (MD5);
   * otherwise it refuses instead of overwriting.
   */
  async writeVariant(
    variantId: string,
    bytes: Buffer,
    contentType: string,
  ): Promise<{ readonly providerGeneration: string }> {
    const name = this.variantName(variantId);
    const md5 = createHash('md5').update(bytes).digest('base64');
    try {
      await this.bucket.file(name).save(bytes, {
        resumable: false,
        contentType,
        preconditionOpts: { ifGenerationMatch: 0 },
      });
    } catch (error) {
      if (statusOf(error) !== 412) throw error;
    }
    const metadata = await this.metadataOrAbsent(name);
    if (metadata === null) throw new DevCloudStorageContextError('variant_missing_after_write');
    if (metadata.md5Hash !== md5) throw new DevCloudStorageContextError('variant_content_conflict');
    return { providerGeneration: generationOf(metadata) };
  }

  async readVariant(
    variantId: string,
    providerGeneration: string,
    maxBytes: number,
  ): Promise<ObjectRead> {
    const name = this.variantName(variantId);
    if (!/^[1-9][0-9]*$/u.test(providerGeneration)) return { kind: 'absent' };
    const metadata = await this.metadataOrAbsent(name, providerGeneration);
    if (metadata === null) return { kind: 'absent' };
    if (String(metadata.generation ?? '') !== providerGeneration) return { kind: 'absent' };
    if (sizeOf(metadata) > maxBytes) return { kind: 'too_large' };
    const bytes = await boundedBytes(
      this.bucket.file(name, { generation: providerGeneration }),
      maxBytes,
    );
    if (bytes.length > maxBytes) return { kind: 'too_large' };
    return { kind: 'complete', providerGeneration, bytes };
  }
}

/**
 * The dev composition's object store: exact app project and bucket name, so
 * the Admin SDK never infers a default bucket or falls back to production.
 */
export function createDevCloudObjectStore(
  app: App,
  maxObjectBytes: number,
  environment: NodeJS.ProcessEnv = process.env,
): DevCloudObjectStore {
  if (app.options.projectId !== devCloudMediaProjectId)
    throw new DevCloudStorageContextError('app_project_not_dev');
  assertDevCloudStorageContext(devCloudMediaBucketName, environment);
  const bucket = getStorage(app).bucket(devCloudMediaBucketName) as unknown as DevCloudBucketLike;
  return new DevCloudObjectStore(bucket, maxObjectBytes, environment);
}
