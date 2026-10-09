export type ObjectStat =
  | { readonly kind: 'absent' }
  | { readonly kind: 'partial' }
  | {
      readonly kind: 'complete';
      readonly providerGeneration: string;
      readonly byteLength: number;
      readonly sha256: string;
      /** Media type detected from the bytes, never the client-declared type. */
      readonly detectedMediaType: string;
    };

/**
 * Object storage behind a port. Product code holds only the opaque handle the
 * backend selected; providers, buckets and public prefixes are not visible here.
 * The only adapter in this slice is `fake_object_store` (no production authority).
 */
export interface ObjectStorePort {
  stat(objectKeyHandle: string): Promise<ObjectStat>;
  /** `removed` and `absent` both confirm that nothing is left; `failed` confirms nothing. */
  remove(objectKeyHandle: string): Promise<RemovalResult>;
  removeVariant(variantId: string): Promise<RemovalResult>;
}

export type RemovalResult = 'removed' | 'absent' | 'failed';

export type ObjectRead =
  | { readonly kind: 'absent' }
  | { readonly kind: 'too_large' }
  | { readonly kind: 'complete'; readonly providerGeneration: string; readonly bytes: Buffer };

/**
 * D1: bounded byte access for the local tools adapters. A source larger than
 * `maxBytes` is never read; a variant is stored under its own id and returns
 * the generation the store assigned.
 */
export interface ObjectBytesPort {
  read(objectKeyHandle: string, maxBytes: number): Promise<ObjectRead>;
  writeVariant(
    variantId: string,
    bytes: Buffer,
    contentType: string,
  ): Promise<{ readonly providerGeneration: string }>;
}
