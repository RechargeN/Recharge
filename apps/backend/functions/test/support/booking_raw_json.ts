const maxSafeInteger = 9_007_199_254_740_991;

export class StrictJsonReader {
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

  private readObject(depth: number): Record<string, unknown> {
    this.offset += 1;
    const result: Record<string, unknown> = Object.create(null) as Record<string, unknown>;
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
        else if (![0x22, 0x5c, 0x2f, 0x62, 0x66, 0x6e, 0x72, 0x74].includes(escaped)) {
          throw new TypeError('bad_escape');
        }
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
    const integerDigits = match[1];
    const fractionalDigits = match[2] ?? '';
    const coefficient = `${integerDigits}${fractionalDigits}`;
    const isZero = !/[1-9]/u.test(coefficient);
    const exponent = Number(match[3] ?? '0');
    if (!Number.isSafeInteger(exponent)) {
      if (!isZero) throw new TypeError(exponent < 0 ? 'fractional_number' : 'unsafe_integer');
    } else {
      const decimalScale = exponent - fractionalDigits.length;
      if (decimalScale < 0 && !isZero) {
        const requiredTrailingZeros = -decimalScale;
        if (
          requiredTrailingZeros > coefficient.length ||
          /[1-9]/u.test(coefficient.slice(-requiredTrailingZeros))
        ) {
          throw new TypeError('fractional_number');
        }
      }
    }
    const value = Number(match[0]);
    if (!Number.isSafeInteger(value) || Math.abs(value) > maxSafeInteger) {
      throw new TypeError(Number.isInteger(value) ? 'unsafe_integer' : 'fractional_number');
    }
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

export function validateUnicode(value: string): void {
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

export function validateSafeJson(value: unknown, depth = 0): void {
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
  if (typeof value === 'object') {
    for (const [key, item] of Object.entries(value)) {
      validateUnicode(key);
      validateSafeJson(item, depth + 1);
    }
    return;
  }
  throw new TypeError('unsupported_json_type');
}
