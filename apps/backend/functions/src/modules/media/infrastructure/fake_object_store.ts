import type {
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
export class FakeObjectStore implements ObjectStorePort {
  readonly #objects = new Map<string, FakeObject>();
  readonly #partial = new Set<string>();

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
