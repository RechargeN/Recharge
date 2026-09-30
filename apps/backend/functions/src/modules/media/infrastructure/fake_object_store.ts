import type { ObjectStat, ObjectStorePort } from '../application/ports/object_store_port.js';

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
