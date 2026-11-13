import type {
  ObjectBytesPort,
  ObjectRead,
  ObjectStat,
  ObjectStorePort,
  RemovalResult,
} from '../application/ports/object_store_port.js';

export interface FakeObject {
  readonly providerGeneration: string;
  readonly byteLength: number;
  readonly sha256: string;
  readonly detectedMediaType: string;
}

/**
 * FAKE object store for local tests. It records nothing about real Storage,
 * IAM, generations or signatures and is never evidence of production behaviour.
 */
export class FakeObjectStore implements ObjectStorePort, ObjectBytesPort {
  readonly #objects = new Map<string, FakeObject>();
  readonly #partial = new Set<string>();
  readonly #bytes = new Map<string, { providerGeneration: string; bytes: Buffer }>();
  readonly variantBytes = new Map<string, Buffer>();
  #variantGeneration = 0;

  /** D1 tests: source bytes for the local tools adapters. */
  putBytes(objectKeyHandle: string, providerGeneration: string, bytes: Buffer): void {
    this.#bytes.set(objectKeyHandle, { providerGeneration, bytes });
  }

  read(objectKeyHandle: string, maxBytes: number): Promise<ObjectRead> {
    const stored = this.#bytes.get(objectKeyHandle);
    if (stored === undefined) return Promise.resolve({ kind: 'absent' });
    if (stored.bytes.length > maxBytes) return Promise.resolve({ kind: 'too_large' });
    return Promise.resolve({ kind: 'complete', ...stored });
  }

  writeVariant(variantId: string, bytes: Buffer): Promise<{ readonly providerGeneration: string }> {
    this.#variantGeneration += 1;
    const providerGeneration = `fake-variant-generation-${this.#variantGeneration}`;
    this.putVariantBytes(variantId, providerGeneration, bytes);
    return Promise.resolve({ providerGeneration });
  }

  readonly #variantGenerations = new Map<string, string>();

  /** D2 tests: variant bytes at a given generation (the FAKE processor writes none). */
  putVariantBytes(variantId: string, providerGeneration: string, bytes: Buffer): void {
    this.variants.add(variantId);
    this.variantBytes.set(variantId, bytes);
    this.#variantGenerations.set(variantId, providerGeneration);
  }

  /** Called whenever a variant is read; lets a test change the world mid-delivery. */
  onReadVariant: ((variantId: string) => Promise<void>) | undefined;

  async readVariant(
    variantId: string,
    providerGeneration: string,
    maxBytes: number,
  ): Promise<ObjectRead> {
    await this.onReadVariant?.(variantId);
    const bytes = this.variantBytes.get(variantId);
    if (
      bytes === undefined ||
      !this.variants.has(variantId) ||
      this.#variantGenerations.get(variantId) !== providerGeneration
    )
      return { kind: 'absent' };
    if (bytes.length > maxBytes) return { kind: 'too_large' };
    return { kind: 'complete', providerGeneration, bytes };
  }

  put(objectKeyHandle: string, object: FakeObject): void {
    this.#partial.delete(objectKeyHandle);
    this.#objects.set(objectKeyHandle, object);
  }

  /** When set, every removal reports `failed` (cleanup cannot be confirmed). */
  failRemovals = false;
  readonly removedHandles: string[] = [];
  readonly removedVariants: string[] = [];
  readonly variants = new Set<string>();

  remove(objectKeyHandle: string): Promise<RemovalResult> {
    if (this.failRemovals) return Promise.resolve('failed');
    const existed = this.#objects.delete(objectKeyHandle) || this.#partial.delete(objectKeyHandle);
    this.removedHandles.push(objectKeyHandle);
    return Promise.resolve(existed ? 'removed' : 'absent');
  }

  removeVariant(variantId: string): Promise<RemovalResult> {
    if (this.failRemovals) return Promise.resolve('failed');
    const existed = this.variants.delete(variantId);
    this.removedVariants.push(variantId);
    return Promise.resolve(existed ? 'removed' : 'absent');
  }

  putPartial(objectKeyHandle: string): void {
    this.#partial.add(objectKeyHandle);
  }

  stat(objectKeyHandle: string): Promise<ObjectStat> {
    const object = this.#objects.get(objectKeyHandle);
    if (object !== undefined) return Promise.resolve({ kind: 'complete', ...object });
    if (this.#partial.has(objectKeyHandle)) return Promise.resolve({ kind: 'partial' });
    return Promise.resolve({ kind: 'absent' });
  }
}
