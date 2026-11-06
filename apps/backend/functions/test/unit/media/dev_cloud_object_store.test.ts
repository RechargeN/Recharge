import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { Readable } from 'node:stream';
import { test } from 'node:test';

import type {
  ObjectBytesPort,
  ObjectStorePort,
} from '../../../src/modules/media/application/ports/object_store_port.js';
import {
  DevCloudObjectStore,
  DevCloudStorageContextError,
  assertDevCloudStorageContext,
  devCloudMediaBucketName,
  type DevCloudBucketLike,
  type DevCloudFileLike,
  type DevCloudFileMetadata,
} from '../../../src/modules/media/infrastructure/dev_cloud_object_store.js';
import {
  StorageEmulatorObjectStore,
  type StorageBucketLike,
  type StorageFileLike,
} from '../../../src/modules/media/infrastructure/storage_emulator_object_store.js';

// N3a: the dev Cloud Storage adapter keeps the Media port contract of the
// Storage Emulator adapter and only hardens it (bounded, generation-pinned,
// create-only, generation-safe deletion). No cloud call in this test.

const handle = 'objk:0123456789abcdefABCDEF-xyz';
const variantId = '01JD0000000000000000000000';
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.from('synthetic-n3a-png-body'),
]);
const cloudEnv = { RECHARGE_MEDIA_STORAGE: 'dev-cloud', GCLOUD_PROJECT: 'recharge-dev-n2a01' };
const emulatorEnv = {
  FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199',
  GCLOUD_PROJECT: 'demo-recharge',
};

interface Stored {
  bytes: Buffer;
  generation: number;
  contentType?: string;
}

class ApiError extends Error {
  constructor(readonly code: number) {
    super(`api-${code}`);
  }
}

/** In-memory GCS with real generation, precondition and range semantics. */
class FakeGcs {
  readonly objects = new Map<string, Stored>();
  readonly name = devCloudMediaBucketName;
  private nextGeneration = 1_700_000_000_000_001;
  downloads = 0;
  failMetadataWith: number | undefined;
  failDeleteWith: number | undefined;
  /** Simulates a concurrent replacement between metadata and delete. */
  replaceBeforeDelete = false;
  /** Serves more bytes than the metadata announced (truncated metadata / race). */
  inflateDownloads = 0;

  put(name: string, bytes: Buffer, contentType?: string): number {
    const generation = this.nextGeneration++;
    this.objects.set(name, { bytes, generation, ...(contentType ? { contentType } : {}) });
    return generation;
  }

  private metadataOf(stored: Stored): DevCloudFileMetadata {
    return {
      generation: String(stored.generation),
      size: String(stored.bytes.length),
      md5Hash: createHash('md5').update(stored.bytes).digest('base64'),
    };
  }

  cloudFile(name: string, options?: { generation?: string | number }): DevCloudFileLike {
    const pinned = options?.generation === undefined ? undefined : Number(options.generation);
    const current = (): Stored => {
      const stored = this.objects.get(name);
      if (stored === undefined || (pinned !== undefined && stored.generation !== pinned))
        throw new ApiError(404);
      return stored;
    };
    return {
      // eslint-disable-next-line @typescript-eslint/require-await -- async keeps throws as rejections
      getMetadata: async () => {
        if (this.failMetadataWith !== undefined) throw new ApiError(this.failMetadataWith);
        return [this.metadataOf(current())];
      },
      createReadStream: (range) => {
        this.downloads++;
        const stored = current();
        const body = Buffer.concat([stored.bytes, Buffer.alloc(this.inflateDownloads, 0x41)]);
        const end = range?.end === undefined ? body.length : range.end + 1;
        return Readable.from([body.subarray(range?.start ?? 0, end)]);
      },
      save: (data, saveOptions) => {
        if (saveOptions.preconditionOpts.ifGenerationMatch === 0 && this.objects.has(name))
          return Promise.reject(new ApiError(412));
        this.put(name, data, saveOptions.contentType);
        return Promise.resolve();
      },
      delete: (deleteOptions) => {
        if (this.failDeleteWith !== undefined)
          return Promise.reject(new ApiError(this.failDeleteWith));
        const stored = this.objects.get(name);
        if (stored === undefined) return Promise.reject(new ApiError(404));
        if (this.replaceBeforeDelete) this.put(name, Buffer.from('replacement'));
        const now = this.objects.get(name)!;
        if (String(now.generation) !== String(deleteOptions.ifGenerationMatch))
          return Promise.reject(new ApiError(412));
        this.objects.delete(name);
        return Promise.resolve([]);
      },
    };
  }

  cloudBucket(): DevCloudBucketLike {
    return { name: this.name, file: (name, options) => this.cloudFile(name, options) };
  }

  emulatorBucket(): StorageBucketLike {
    return {
      file: (name): StorageFileLike => ({
        exists: () => Promise.resolve([this.objects.has(name)]),
        getMetadata: () => {
          const stored = this.objects.get(name)!;
          return Promise.resolve([
            { generation: String(stored.generation), size: String(stored.bytes.length) },
          ]);
        },
        download: () => {
          this.downloads++;
          return Promise.resolve([this.objects.get(name)!.bytes]);
        },
        save: (data, options) => {
          this.put(name, data, options?.contentType);
          return Promise.resolve();
        },
        delete: () => {
          this.objects.delete(name);
          return Promise.resolve([]);
        },
      }),
    };
  }
}

type Store = ObjectStorePort & ObjectBytesPort;
const adapters: Record<string, (gcs: FakeGcs) => Store> = {
  emulator: (gcs) => new StorageEmulatorObjectStore(gcs.emulatorBucket(), emulatorEnv),
  devCloud: (gcs) => new DevCloudObjectStore(gcs.cloudBucket(), 1_048_576, cloudEnv),
};

for (const [label, make] of Object.entries(adapters)) {
  void test(`port parity (${label}): stat, bounded read, variants and removal`, async () => {
    const gcs = new FakeGcs();
    const store = make(gcs);
    assert.deepEqual(await store.stat(handle), { kind: 'absent' });
    assert.deepEqual(await store.read(handle, 1024), { kind: 'absent' });
    const generation = gcs.put('media-source/0123456789abcdefABCDEF-xyz', png);
    assert.deepEqual(await store.stat(handle), {
      kind: 'complete',
      providerGeneration: String(generation),
      byteLength: png.length,
      sha256: createHash('sha256').update(png).digest('hex'),
      detectedMediaType: 'image/png',
    });
    assert.deepEqual(await store.read(handle, 4), { kind: 'too_large' });
    const read = await store.read(handle, 1024);
    assert.equal(read.kind, 'complete');
    assert.ok(read.kind === 'complete' && read.bytes.equals(png));
    const { providerGeneration } = await store.writeVariant(variantId, png, 'image/png');
    const variant = await store.readVariant(variantId, providerGeneration, 1024);
    assert.ok(variant.kind === 'complete' && variant.bytes.equals(png));
    assert.deepEqual(await store.readVariant(variantId, '999', 1024), { kind: 'absent' });
    assert.deepEqual(await store.readVariant(variantId, providerGeneration, 4), {
      kind: 'too_large',
    });
    assert.equal(await store.removeVariant(variantId), 'removed');
    assert.equal(await store.removeVariant(variantId), 'absent');
    assert.equal(await store.remove(handle), 'removed');
    assert.equal(await store.remove(handle), 'absent');
    await assert.rejects(store.stat('objk:../../tfstate'));
    await assert.rejects(store.writeVariant('../escape', png, 'image/png'));
  });
}

void test('binding fails closed: mode, project, Emulator alongside cloud, bucket', () => {
  const ok = { ...cloudEnv };
  assert.doesNotThrow(() => assertDevCloudStorageContext(devCloudMediaBucketName, ok));
  for (const [environment, bucket, reason] of [
    [
      { GCLOUD_PROJECT: 'recharge-dev-n2a01' },
      devCloudMediaBucketName,
      'dev_cloud_mode_not_selected',
    ],
    [{ ...ok, GCLOUD_PROJECT: 'recharge-prod-x' }, devCloudMediaBucketName, 'project_not_dev'],
    [
      { ...ok, FIREBASE_STORAGE_EMULATOR_HOST: '127.0.0.1:9199' },
      devCloudMediaBucketName,
      'emulator_and_cloud_both_configured',
    ],
    [
      { ...ok, FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' },
      devCloudMediaBucketName,
      'emulator_and_cloud_both_configured',
    ],
    [ok, 'recharge-dev-n2a01-tfstate', 'bucket_not_dev_media'],
    [ok, 'recharge-dev-n2a01.appspot.com', 'bucket_not_dev_media'],
  ] as const) {
    assert.throws(
      () => assertDevCloudStorageContext(bucket, environment),
      (error: unknown) => error instanceof DevCloudStorageContextError && error.message === reason,
    );
  }
  const gcs = new FakeGcs();
  assert.throws(() => new DevCloudObjectStore({ ...gcs.cloudBucket(), name: 'other' }, 10, ok));
  assert.throws(() => new DevCloudObjectStore(gcs.cloudBucket(), 0, ok));
});

void test('oversized source: stat reports size without downloading; read never downloads', async () => {
  const gcs = new FakeGcs();
  const store = new DevCloudObjectStore(gcs.cloudBucket(), 16, cloudEnv);
  gcs.put('media-source/0123456789abcdefABCDEF-xyz', Buffer.alloc(64, 1));
  const stat = await store.stat(handle);
  assert.equal(stat.kind, 'complete');
  assert.ok(stat.kind === 'complete' && stat.byteLength === 64 && stat.sha256 === '');
  assert.deepEqual(await store.read(handle, 16), { kind: 'too_large' });
  assert.equal(gcs.downloads, 0);
});

void test('a download larger than announced is cut off at the bound', async () => {
  const gcs = new FakeGcs();
  const store = new DevCloudObjectStore(gcs.cloudBucket(), 1_048_576, cloudEnv);
  gcs.put('media-source/0123456789abcdefABCDEF-xyz', png);
  gcs.inflateDownloads = 4096;
  assert.deepEqual(await store.read(handle, png.length + 10), { kind: 'too_large' });
  assert.deepEqual(await store.stat(handle), { kind: 'partial' });
});

void test('writeVariant is create-only: identical retry returns the stored generation, other bytes refuse', async () => {
  const gcs = new FakeGcs();
  const store = new DevCloudObjectStore(gcs.cloudBucket(), 1_048_576, cloudEnv);
  const first = await store.writeVariant(variantId, png, 'image/png');
  const retry = await store.writeVariant(variantId, png, 'image/png');
  assert.equal(retry.providerGeneration, first.providerGeneration);
  await assert.rejects(
    store.writeVariant(variantId, Buffer.from('other'), 'image/png'),
    /variant_content_conflict/,
  );
  assert.equal(
    String(gcs.objects.get(`media-variant/${variantId}`)!.generation),
    first.providerGeneration,
  );
});

void test('removal never claims success it did not get', async () => {
  const gcs = new FakeGcs();
  const store = new DevCloudObjectStore(gcs.cloudBucket(), 1_048_576, cloudEnv);
  gcs.put('media-source/0123456789abcdefABCDEF-xyz', png);
  gcs.replaceBeforeDelete = true;
  assert.equal(await store.remove(handle), 'failed');
  assert.ok(gcs.objects.has('media-source/0123456789abcdefABCDEF-xyz'), 'replacement survives');
  gcs.replaceBeforeDelete = false;
  gcs.failDeleteWith = 403;
  assert.equal(await store.remove(handle), 'failed');
  gcs.failDeleteWith = undefined;
  gcs.failMetadataWith = 503;
  assert.equal(await store.remove(handle), 'failed');
  await assert.rejects(store.stat(handle), 'permission/timeout is not "absent"');
  gcs.failMetadataWith = 403;
  await assert.rejects(store.read(handle, 1024));
});
