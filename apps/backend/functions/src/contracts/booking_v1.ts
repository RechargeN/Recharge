import { createHash } from 'node:crypto';

export type JsonObject = Record<string, unknown>;

export type BookingCommand = CreateBookingCommand | CancelBookingCommand;

export interface CreateBookingCommand {
  readonly schemaVersion: 1;
  readonly commandType: 'createBooking';
  readonly requestId: string;
  readonly idempotencyKey: string;
  readonly occurredAgainstEventRevision?: number;
  readonly payload: Readonly<{
    occurrenceId: string;
    inventoryPoolId?: string;
    channel?: 'onsite' | 'online' | 'any';
    participantUnits: number;
    namedGuests?: readonly Readonly<{ displayName: string }>[];
    auxiliaryTrackId?: string;
    applicationFields?: JsonObject;
  }>;
}

export interface CancelBookingCommand {
  readonly schemaVersion: 1;
  readonly commandType: 'cancelBooking';
  readonly requestId: string;
  readonly idempotencyKey: string;
  readonly expectedBookingRevision: number;
  readonly occurredAgainstEventRevision?: number;
  readonly payload: Readonly<{ bookingId: string; reasonCode?: string }>;
}

export type BookingQuery = GetMyBookingQuery | ListMyBookingsQuery | GetEventAvailabilityQuery;

export interface GetMyBookingQuery {
  readonly schemaVersion: 1;
  readonly queryType: 'getMyBooking';
  readonly requestId: string;
  readonly payload: Readonly<{ bookingId: string }>;
}

export interface ListMyBookingsQuery {
  readonly schemaVersion: 1;
  readonly queryType: 'listMyBookings';
  readonly requestId: string;
  readonly payload: Readonly<{
    pageSize?: number;
    cursor?: string;
    stateFilter?: 'pending' | 'confirmed' | 'cancelled' | 'expired' | 'waitlisted';
  }>;
}

export interface GetEventAvailabilityQuery {
  readonly schemaVersion: 1;
  readonly queryType: 'getEventAvailability';
  readonly requestId: string;
  readonly payload: Readonly<{
    eventId: string;
    occurrenceId: string;
    channel?: 'onsite' | 'online' | 'any';
  }>;
}

export type RawBookingInput<T> =
  Readonly<{ ok: true; value: T }> | Readonly<{ ok: false; reason: RawBookingFailureReason }>;

export type RawBookingFailureReason =
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
  | 'invalid_contract'
  | 'unsupported_flow';

const maxCallableBodyBytes = 64 * 1024;

export function inspectBookingCommand(
  rawBody: Buffer,
  decodedData: unknown,
): RawBookingInput<BookingCommand> {
  return inspectRawInput(rawBody, decodedData, parseBookingCommand);
}

export function inspectBookingQuery(
  rawBody: Buffer,
  decodedData: unknown,
): RawBookingInput<BookingQuery> {
  return inspectRawInput(rawBody, decodedData, parseBookingQuery);
}

export function computeBookingSemanticHash(command: BookingCommand, actorId: string): string {
  const projection: JsonObject = {
    algorithmVersion: 'booking_semantic_hash_v1',
    commandType: command.commandType,
    commandSchemaVersion: command.schemaVersion,
    resolvedActorScope: { kind: 'user', id: actorId },
    ...(!('expectedBookingRevision' in command)
      ? {}
      : { expectedBookingRevision: command.expectedBookingRevision }),
    ...(command.occurredAgainstEventRevision === undefined
      ? {}
      : { occurredAgainstEventRevision: command.occurredAgainstEventRevision }),
    payload: command.payload,
  };
  return createHash('sha256')
    .update(Buffer.from(canonicalJson(projection), 'utf8'))
    .digest('hex');
}

function inspectRawInput<T>(
  rawBody: Buffer,
  decodedData: unknown,
  parse: (value: unknown) => RawBookingInput<T>,
): RawBookingInput<T> {
  if (rawBody.byteLength > maxCallableBodyBytes) return failure('body_too_large');
  if (rawBody.length >= 3 && rawBody[0] === 0xef && rawBody[1] === 0xbb && rawBody[2] === 0xbf) {
    return failure('utf8_bom');
  }

  let source: string;
  try {
    source = new TextDecoder('utf-8', { fatal: true }).decode(rawBody);
  } catch {
    return failure('invalid_utf8');
  }

  let envelope: unknown;
  try {
    envelope = new StrictJsonReader(source).read();
  } catch (error) {
    return failure(classifyJsonFailure(error));
  }
  if (!isObject(envelope) || !hasExactKeys(envelope, ['data'])) return failure('invalid_envelope');
  const rawValue = envelope.data;
  if (!isObject(rawValue)) return failure('invalid_envelope');
  if (containsProtocolWrapper(rawValue)) return failure('unsupported_protocol_value');
  try {
    validateSafeJson(decodedData);
  } catch {
    return failure('callable_decode_mismatch');
  }
  if (!equalJson(rawValue, decodedData)) return failure('callable_decode_mismatch');
  return parse(rawValue);
}

function parseBookingCommand(value: unknown): RawBookingInput<BookingCommand> {
  if (!isObject(value) || value.schemaVersion !== 1 || !isBoundedId(value.requestId)) {
    return failure('invalid_contract');
  }
  if (!isBoundedId(value.idempotencyKey) || !isObject(value.payload)) {
    return failure('invalid_contract');
  }
  if (value.commandType === 'createBooking') {
    const allowed = [
      'schemaVersion',
      'commandType',
      'requestId',
      'idempotencyKey',
      'occurredAgainstEventRevision',
      'payload',
    ];
    if (!hasOnlyKeys(value, allowed) || !optionalRevision(value.occurredAgainstEventRevision)) {
      return failure('invalid_contract');
    }
    const payload = value.payload;
    if (
      !hasOnlyKeys(payload, [
        'occurrenceId',
        'inventoryPoolId',
        'channel',
        'participantUnits',
        'namedGuests',
        'auxiliaryTrackId',
        'applicationFields',
      ]) ||
      !isBoundedId(payload.occurrenceId) ||
      !isPositiveUnits(payload.participantUnits) ||
      !optionalId(payload.inventoryPoolId) ||
      !optionalId(payload.auxiliaryTrackId) ||
      !optionalChannel(payload.channel) ||
      (payload.inventoryPoolId === undefined) !== (payload.channel === undefined) ||
      !optionalGuests(payload.namedGuests) ||
      !optionalApplicationFields(payload.applicationFields)
    ) {
      return failure('invalid_contract');
    }
    return { ok: true, value: value as unknown as CreateBookingCommand };
  }
  if (value.commandType === 'cancelBooking') {
    const allowed = [
      'schemaVersion',
      'commandType',
      'requestId',
      'idempotencyKey',
      'expectedBookingRevision',
      'occurredAgainstEventRevision',
      'payload',
    ];
    const payload = value.payload;
    if (
      !hasOnlyKeys(value, allowed) ||
      !isRevision(value.expectedBookingRevision) ||
      !optionalRevision(value.occurredAgainstEventRevision) ||
      !hasOnlyKeys(payload, ['bookingId', 'reasonCode']) ||
      !isBoundedId(payload.bookingId) ||
      !optionalReason(payload.reasonCode)
    ) {
      return failure('invalid_contract');
    }
    return { ok: true, value: value as unknown as CancelBookingCommand };
  }
  if (typeof value.commandType === 'string') return failure('unsupported_flow');
  return failure('invalid_contract');
}

function parseBookingQuery(value: unknown): RawBookingInput<BookingQuery> {
  if (
    !isObject(value) ||
    value.schemaVersion !== 1 ||
    !isBoundedId(value.requestId) ||
    !isObject(value.payload) ||
    !hasOnlyKeys(value, ['schemaVersion', 'queryType', 'requestId', 'payload'])
  ) {
    return failure('invalid_contract');
  }
  if (value.queryType === 'getMyBooking') {
    if (!hasExactKeys(value.payload, ['bookingId']) || !isBoundedId(value.payload.bookingId)) {
      return failure('invalid_contract');
    }
    return { ok: true, value: value as unknown as GetMyBookingQuery };
  }
  if (value.queryType === 'listMyBookings') {
    const payload = value.payload;
    const state = payload.stateFilter;
    if (
      !hasOnlyKeys(payload, ['pageSize', 'cursor', 'stateFilter']) ||
      (payload.pageSize !== undefined &&
        (!Number.isSafeInteger(payload.pageSize) ||
          Number(payload.pageSize) < 1 ||
          Number(payload.pageSize) > 50)) ||
      (payload.cursor !== undefined &&
        (typeof payload.cursor !== 'string' ||
          payload.cursor.length < 1 ||
          payload.cursor.length > 2048 ||
          !/^[\x20-\x7e]+$/u.test(payload.cursor))) ||
      (state !== undefined &&
        (typeof state !== 'string' ||
          !['pending', 'confirmed', 'cancelled', 'expired', 'waitlisted'].includes(state)))
    ) {
      return failure('invalid_contract');
    }
    return { ok: true, value: value as unknown as ListMyBookingsQuery };
  }
  if (value.queryType === 'getEventAvailability') {
    const payload = value.payload;
    if (
      !hasOnlyKeys(payload, ['eventId', 'occurrenceId', 'channel']) ||
      !isBoundedId(payload.eventId) ||
      !isBoundedId(payload.occurrenceId) ||
      !optionalChannel(payload.channel)
    ) {
      return failure('invalid_contract');
    }
    return { ok: true, value: value as unknown as GetEventAvailabilityQuery };
  }
  return failure(typeof value.queryType === 'string' ? 'unsupported_flow' : 'invalid_contract');
}

function failure<T>(reason: RawBookingFailureReason): RawBookingInput<T> {
  return { ok: false, reason };
}

function isObject(value: unknown): value is JsonObject {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const prototype = Object.getPrototypeOf(value) as unknown;
  return prototype === null || prototype === Object.prototype;
}

function hasOnlyKeys(value: JsonObject, allowed: readonly string[]): boolean {
  const accepted = new Set(allowed);
  return Object.keys(value).every((key) => accepted.has(key));
}

function hasExactKeys(value: JsonObject, keys: readonly string[]): boolean {
  return (
    Object.keys(value).length === keys.length && keys.every((key) => Object.hasOwn(value, key))
  );
}

function isBoundedId(value: unknown): value is string {
  if (typeof value !== 'string' || [...value].length < 1 || [...value].length > 128) return false;
  try {
    validateUnicode(value);
  } catch {
    return false;
  }
  return /[^\s\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]/u.test(value);
}

function optionalId(value: unknown): boolean {
  return value === undefined || isBoundedId(value);
}

function isRevision(value: unknown): value is number {
  return Number.isSafeInteger(value) && Number(value) >= 0;
}

function optionalRevision(value: unknown): boolean {
  return value === undefined || isRevision(value);
}

function isPositiveUnits(value: unknown): value is number {
  return Number.isSafeInteger(value) && Number(value) >= 1 && Number(value) <= 21;
}

function optionalChannel(value: unknown): boolean {
  return value === undefined || value === 'onsite' || value === 'online' || value === 'any';
}

function optionalReason(value: unknown): boolean {
  return (
    value === undefined || (typeof value === 'string' && value.length >= 1 && value.length <= 64)
  );
}

function optionalGuests(value: unknown): boolean {
  if (value === undefined) return true;
  if (!Array.isArray(value) || value.length > 20) return false;
  return value.every(
    (guest) =>
      isObject(guest) &&
      hasExactKeys(guest, ['displayName']) &&
      typeof guest.displayName === 'string' &&
      [...guest.displayName].length >= 1 &&
      [...guest.displayName].length <= 120,
  );
}

function optionalApplicationFields(value: unknown): boolean {
  return value === undefined || isObject(value);
}

function containsProtocolWrapper(value: unknown): boolean {
  if (Array.isArray(value)) return value.some(containsProtocolWrapper);
  if (!isObject(value)) return false;
  if (Object.hasOwn(value, '@type')) return true;
  return Object.values(value).some(containsProtocolWrapper);
}

function equalJson(left: unknown, right: unknown, depth = 0): boolean {
  if (depth > 64) return false;
  if (left === null || right === null) return left === right;
  if (typeof left !== typeof right) return false;
  if (typeof left === 'boolean' || typeof left === 'string') return left === right;
  if (typeof left === 'number')
    return typeof right === 'number' && Number.isSafeInteger(left) && Object.is(left, right);
  if (Array.isArray(left)) {
    return (
      Array.isArray(right) &&
      left.length === right.length &&
      left.every((item, index) => equalJson(item, right[index], depth + 1))
    );
  }
  if (!isObject(left) || !isObject(right)) return false;
  const leftKeys = Object.keys(left).sort();
  const rightKeys = Object.keys(right).sort();
  return (
    leftKeys.length === rightKeys.length &&
    leftKeys.every(
      (key, index) => key === rightKeys[index] && equalJson(left[key], right[key], depth + 1),
    )
  );
}

function classifyJsonFailure(error: unknown): RawBookingFailureReason {
  const message = error instanceof Error ? error.message : '';
  if (message.startsWith('duplicate_key:')) return 'duplicate_key';
  if (message === 'unpaired_surrogate') return 'unpaired_surrogate';
  if (message === 'unsafe_integer' || message === 'fractional_number') return 'unsafe_number';
  return 'invalid_json';
}

function canonicalJson(value: unknown): string {
  if (value === null) return 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return Object.is(value, -0) ? '0' : String(value);
  if (typeof value === 'string') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (isObject(value)) {
    const keys = Object.keys(value).sort(compareUtf16);
    return `{${keys.map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(',')}}`;
  }
  throw new TypeError('unsupported_canonical_value');
}

function compareUtf16(left: string, right: string): number {
  const length = Math.min(left.length, right.length);
  for (let index = 0; index < length; index += 1) {
    const difference = left.charCodeAt(index) - right.charCodeAt(index);
    if (difference !== 0) return difference;
  }
  return left.length - right.length;
}

function validateUnicode(value: string): void {
  for (let index = 0; index < value.length; index += 1) {
    const unit = value.charCodeAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      const low = value.charCodeAt(index + 1);
      if (!(low >= 0xdc00 && low <= 0xdfff)) throw new TypeError('unpaired_surrogate');
      index += 1;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw new TypeError('unpaired_surrogate');
    }
  }
}

function validateSafeJson(value: unknown, depth = 0): void {
  if (depth > 64) throw new TypeError('json_depth_exceeded');
  if (value === null || typeof value === 'boolean') return;
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) throw new TypeError('unsafe_number');
    return;
  }
  if (typeof value === 'string') {
    validateUnicode(value);
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) validateSafeJson(item, depth + 1);
    return;
  }
  if (isObject(value)) {
    for (const [key, item] of Object.entries(value)) {
      validateUnicode(key);
      validateSafeJson(item, depth + 1);
    }
    return;
  }
  throw new TypeError('unsupported_json_type');
}

class StrictJsonReader {
  private offset = 0;
  public constructor(private readonly source: string) {}
  public read(): unknown {
    this.skipWhitespace();
    const value = this.readValue(0);
    this.skipWhitespace();
    if (this.offset !== this.source.length) throw new TypeError('trailing_json');
    return value;
  }
  private readValue(depth: number): unknown {
    if (depth > 64) throw new TypeError('json_depth_exceeded');
    const unit = this.peek();
    if (unit === 0x7b) return this.readObject(depth + 1);
    if (unit === 0x5b) return this.readArray(depth + 1);
    if (unit === 0x22) return this.readString();
    if (this.source.startsWith('true', this.offset)) return this.readLiteral('true', true);
    if (this.source.startsWith('false', this.offset)) return this.readLiteral('false', false);
    if (this.source.startsWith('null', this.offset)) return this.readLiteral('null', null);
    return this.readNumber();
  }
  private readObject(depth: number): JsonObject {
    this.offset += 1;
    const result: JsonObject = Object.create(null) as JsonObject;
    this.skipWhitespace();
    if (this.consume(0x7d)) return result;
    while (true) {
      if (this.peek() !== 0x22) throw new TypeError('object_key_expected');
      const key = this.readString();
      if (Object.hasOwn(result, key)) throw new TypeError(`duplicate_key:${key}`);
      this.skipWhitespace();
      this.expect(0x3a);
      this.skipWhitespace();
      result[key] = this.readValue(depth);
      this.skipWhitespace();
      if (this.consume(0x7d)) return result;
      this.expect(0x2c);
      this.skipWhitespace();
    }
  }
  private readArray(depth: number): unknown[] {
    this.offset += 1;
    const result: unknown[] = [];
    this.skipWhitespace();
    if (this.consume(0x5d)) return result;
    while (true) {
      result.push(this.readValue(depth));
      this.skipWhitespace();
      if (this.consume(0x5d)) return result;
      this.expect(0x2c);
      this.skipWhitespace();
    }
  }
  private readString(): string {
    const start = this.offset;
    this.offset += 1;
    while (this.offset < this.source.length) {
      const unit = this.source.charCodeAt(this.offset);
      this.offset += 1;
      if (unit === 0x22) {
        const value = JSON.parse(this.source.slice(start, this.offset)) as unknown;
        if (typeof value !== 'string') throw new TypeError('invalid_string');
        validateUnicode(value);
        return value;
      }
      if (unit < 0x20) throw new TypeError('string_control');
      if (unit === 0x5c) {
        if (this.offset >= this.source.length) throw new TypeError('bad_escape');
        const escaped = this.source.charCodeAt(this.offset);
        this.offset += 1;
        if (escaped === 0x75) this.readHexEscape();
        else if (![0x22, 0x5c, 0x2f, 0x62, 0x66, 0x6e, 0x72, 0x74].includes(escaped))
          throw new TypeError('bad_escape');
      }
    }
    throw new TypeError('unterminated_string');
  }
  private readHexEscape(): void {
    const hex = this.source.slice(this.offset, this.offset + 4);
    if (!/^[0-9A-Fa-f]{4}$/u.test(hex)) throw new TypeError('bad_unicode_escape');
    this.offset += 4;
  }
  private readLiteral<T>(literal: string, value: T): T {
    this.offset += literal.length;
    return value;
  }
  private readNumber(): number {
    const match = /^-?(0|[1-9]\d*)(?:\.(\d+))?(?:[eE]([+-]?\d+))?/u.exec(
      this.source.slice(this.offset),
    );
    if (match === null) throw new TypeError('value_expected');
    this.offset += match[0].length;
    const integerDigits = match[1] ?? '';
    const fractionalDigits = match[2] ?? '';
    const coefficient = `${integerDigits}${fractionalDigits}`;
    const isZero = !/[1-9]/u.test(coefficient);
    const exponent = Number(match[3] ?? '0');
    if (!Number.isSafeInteger(exponent)) {
      if (!isZero) throw new TypeError(exponent < 0 ? 'fractional_number' : 'unsafe_integer');
    } else {
      const decimalScale = exponent - fractionalDigits.length;
      if (decimalScale < 0 && !isZero) {
        const requiredZeros = -decimalScale;
        if (requiredZeros > coefficient.length || /[1-9]/u.test(coefficient.slice(-requiredZeros)))
          throw new TypeError('fractional_number');
      }
    }
    const value = Number(match[0]);
    if (!Number.isSafeInteger(value))
      throw new TypeError(Number.isInteger(value) ? 'unsafe_integer' : 'fractional_number');
    return Object.is(value, -0) ? 0 : value;
  }
  private skipWhitespace(): void {
    while ([0x20, 0x09, 0x0a, 0x0d].includes(this.peek())) this.offset += 1;
  }
  private peek(): number {
    return this.offset < this.source.length ? this.source.charCodeAt(this.offset) : -1;
  }
  private consume(unit: number): boolean {
    if (this.peek() !== unit) return false;
    this.offset += 1;
    return true;
  }
  private expect(unit: number): void {
    if (!this.consume(unit)) throw new TypeError('unexpected_token');
  }
}
