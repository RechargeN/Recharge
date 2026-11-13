import { StrictJsonReader, validateSafeJson } from './booking_raw_json.js';

const maxCallableBodyBytes = 64 * 1024;

export type BookingCallableRawBodyFailureReason =
  | 'body_too_large'
  | 'invalid_utf8'
  | 'utf8_bom'
  | 'invalid_json'
  | 'duplicate_key'
  | 'unsafe_number'
  | 'unpaired_surrogate'
  | 'invalid_envelope'
  | 'unsupported_protocol_value'
  | 'callable_decode_mismatch'
  | 'invalid_contract';

export type BookingCallableRawBodyResult =
  | { readonly ok: true; readonly command: Readonly<Record<string, unknown>> }
  | { readonly ok: false; readonly reason: BookingCallableRawBodyFailureReason };

export function inspectBookingCallableRawBody(
  rawBody: Buffer,
  decodedData: unknown,
  validateCommand: (value: unknown) => boolean,
): BookingCallableRawBodyResult {
  if (rawBody.byteLength > maxCallableBodyBytes) {
    return failure('body_too_large');
  }
  if (rawBody.length >= 3 && rawBody[0] === 0xef && rawBody[1] === 0xbb && rawBody[2] === 0xbf) {
    return failure('utf8_bom');
  }

  let source: string;
  try {
    source = new TextDecoder('utf-8', { fatal: true }).decode(rawBody);
  } catch {
    return failure('invalid_utf8');
  }
  let decodedEnvelope: unknown;
  try {
    decodedEnvelope = new StrictJsonReader(source).read();
  } catch (error) {
    return failure(classifyStrictJsonFailure(error));
  }

  if (!isJsonObject(decodedEnvelope)) return failure('invalid_envelope');
  const envelopeKeys = Object.keys(decodedEnvelope);
  if (envelopeKeys.length !== 1 || envelopeKeys[0] !== 'data') {
    return failure('invalid_envelope');
  }

  const command = decodedEnvelope.data;
  if (!isJsonObject(command)) return failure('invalid_envelope');
  if (containsCallableProtocolWrapper(command)) {
    return failure('unsupported_protocol_value');
  }

  try {
    validateSafeJson(decodedData);
  } catch {
    return failure('callable_decode_mismatch');
  }
  if (!equalJson(command, decodedData)) return failure('callable_decode_mismatch');

  try {
    if (!validateCommand(command)) return failure('invalid_contract');
  } catch {
    return failure('invalid_contract');
  }
  return { ok: true, command };
}

function failure(reason: BookingCallableRawBodyFailureReason): BookingCallableRawBodyResult {
  return { ok: false, reason };
}

function classifyStrictJsonFailure(error: unknown): BookingCallableRawBodyFailureReason {
  const message = error instanceof Error ? error.message : '';
  if (message.startsWith('duplicate_key:')) return 'duplicate_key';
  if (message === 'unpaired_surrogate') return 'unpaired_surrogate';
  if (message === 'unsafe_integer' || message === 'fractional_number') return 'unsafe_number';
  return 'invalid_json';
}

function isJsonObject(value: unknown): value is Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const prototype = Object.getPrototypeOf(value) as unknown;
  return prototype === null || prototype === Object.prototype;
}

function containsCallableProtocolWrapper(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(containsCallableProtocolWrapper);
  if (!isJsonObject(value)) return false;
  if (Object.hasOwn(value, '@type')) return true;
  return Object.values(value).some(containsCallableProtocolWrapper);
}

function equalJson(left: unknown, right: unknown, depth = 0): boolean {
  if (depth > 64) return false;
  if (left === null || right === null) return left === right;
  if (typeof left !== typeof right) return false;
  if (typeof left === 'boolean' || typeof left === 'string') return left === right;
  if (typeof left === 'number') {
    return typeof right === 'number' && Number.isSafeInteger(left) && Object.is(left, right);
  }
  if (Array.isArray(left)) {
    if (!Array.isArray(right) || left.length !== right.length) return false;
    return left.every((item, index) => equalJson(item, right[index], depth + 1));
  }
  if (!isJsonObject(left) || !isJsonObject(right)) return false;
  const leftKeys = Object.keys(left).sort();
  const rightKeys = Object.keys(right).sort();
  if (leftKeys.length !== rightKeys.length) return false;
  return leftKeys.every(
    (key, index) => key === rightKeys[index] && equalJson(left[key], right[key], depth + 1),
  );
}
