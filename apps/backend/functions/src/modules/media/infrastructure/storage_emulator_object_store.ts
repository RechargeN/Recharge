import { createHash } from 'node:crypto';

import type {
  ObjectStat,
  ObjectStorePort,
  RemovalResult,
} from '../application/ports/object_store_port.js';

/** The slice of a Storage bucket this adapter needs (the Admin SDK `Bucket` fits). */
export interface StorageBucketLike {
  file(name: string): StorageFileLike;
}

export interface StorageFileLike {
  exists(): Promise<[boolean]>;
  getMetadata(): Promise<
    [{ readonly generation?: string | number; readonly size?: string | number }]
  >;
  download(): Promise<[Buffer]>;
  save(data: Buffer, options?: { resumable?: boolean }): Promise<void>;
  delete(options?: { ignoreNotFound?: boolean }): Promise<unknown>;
}

export class StorageEmulatorContextError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = 'StorageEmulatorContextError';
  }
}

const loopbackStorageHost = /^(127\.0\.0\.1|localhost):\d+$/u;

/** The adapter only ever talks to the local Storage Emulator, never to a cloud bucket. */
export function assertStorageEmulatorContext(environment: NodeJS.ProcessEnv = process.env): void {
  const host = environment.FIREBASE_STORAGE_EMULATOR_HOST ?? environment.STORAGE_EMULATOR_HOST;
  if (host === undefined || host === '')
    throw new StorageEmulatorContextError('storage_emulator_host_missing');
  if (!loopbackStorageHost.test(host.replace(/^https?:\/\//u, '')))
    throw new StorageEmulatorContextError('storage_emulator_host_not_loopback');
  if ((environment.GCLOUD_PROJECT ?? 'demo-recharge') !== 'demo-recharge')
    throw new StorageEmulatorContextError('project_not_demo');
  if ((environment.GOOGLE_APPLICATION_CREDENTIALS ?? '') !== '')
    throw new StorageEmulatorContextError('cloud_credentials_present');
}

/** Media type detected from the bytes, never from what the client declared. */
export function detectMediaType(bytes: Buffer): string {
  if (
    bytes.length >= 8 &&
    bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  )
    return 'image/png';
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff)
    return 'image/jpeg';
  if (
    bytes.length >= 12 &&
    bytes.subarray(0, 4).toString('ascii') === 'RIFF' &&
    bytes.subarray(8, 12).toString('ascii') === 'WEBP'
  )
    return 'image/webp';
  return 'application/octet-stream';
}

/**
 * `ObjectStorePort` over the Firebase Storage Emulator. Provider facts are
 * measured from the stored object (generation, length, SHA-256, signature),
 * never taken from the caller. EMULATOR-ONLY: it proves how the service reacts
 * to real bytes in a local Storage, not production Storage, IAM or generations.
 */
export class StorageEmulatorObjectStore implements ObjectStorePort {
  constructor(
    private readonly bucket: StorageBucketLike,
    environment: NodeJS.ProcessEnv = process.env,
    private readonly prefix = 'media-source/',
  ) {
    assertStorageEmulatorContext(environment);
  }

  private file(objectKeyHandle: string): StorageFileLike {
    if (!/^objk:[0-9A-Za-z-]{20,64}$/u.test(objectKeyHandle))
      throw new StorageEmulatorContextError('object_key_handle_invalid');
    return this.bucket.file(`${this.prefix}${objectKeyHandle.slice('objk:'.length)}`);
  }

  /** Emulator-only byte transfer channel; bounded and checked by the caller. */
  async put(objectKeyHandle: string, bytes: Buffer): Promise<void> {
    await this.file(objectKeyHandle).save(bytes, { resumable: false });
  }

  async stat(objectKeyHandle: string): Promise<ObjectStat> {
    const file = this.file(objectKeyHandle);
    const [exists] = await file.exists();
    if (!exists) return { kind: 'absent' };
    const [metadata] = await file.getMetadata();
    const [bytes] = await file.download();
    return {
      kind: 'complete',
      providerGeneration: String(metadata.generation ?? ''),
      byteLength: bytes.length,
      sha256: createHash('sha256').update(bytes).digest('hex'),
      detectedMediaType: detectMediaType(bytes),
    };
  }

  async remove(objectKeyHandle: string): Promise<RemovalResult> {
    try {
      const file = this.file(objectKeyHandle);
      const [exists] = await file.exists();
      if (!exists) return 'absent';
      await file.delete({ ignoreNotFound: true });
      return 'removed';
    } catch {
      return 'failed';
    }
  }

  removeVariant(): Promise<RemovalResult> {
    // The fake processor stores no variant objects; nothing is left to remove.
    return Promise.resolve('absent');
  }
}
