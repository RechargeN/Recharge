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
}
