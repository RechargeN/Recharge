const ulidPattern = /^[0-9A-HJKMNP-TV-Z]{26}$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

declare const entityIdBrand: unique symbol;
declare const idempotencyKeyBrand: unique symbol;

export type EntityId = string & { readonly [entityIdBrand]: 'EntityId' };
export type IdempotencyKey = string & {
  readonly [idempotencyKeyBrand]: 'IdempotencyKey';
};

export function isEntityId(value: unknown): value is EntityId {
  return typeof value === 'string' && (ulidPattern.test(value) || uuidPattern.test(value));
}

export function parseEntityId(value: unknown): EntityId {
  if (!isEntityId(value)) {
    throw new TypeError('Expected a canonical ULID or UUID entity reference');
  }
  return value;
}

export function isIdempotencyKey(value: unknown): value is IdempotencyKey {
  return (
    typeof value === 'string' &&
    value.length >= 8 &&
    value.length <= 128 &&
    /^[A-Za-z0-9._:-]+$/.test(value)
  );
}

export function parseIdempotencyKey(value: unknown): IdempotencyKey {
  if (!isIdempotencyKey(value)) {
    throw new TypeError('Expected a bounded idempotency key');
  }
  return value;
}
