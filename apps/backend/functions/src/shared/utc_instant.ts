declare const utcInstantBrand: unique symbol;
declare const ianaTimezoneBrand: unique symbol;

export type UtcInstant = string & { readonly [utcInstantBrand]: 'UtcInstant' };
export type IanaTimezone = string & {
  readonly [ianaTimezoneBrand]: 'IanaTimezone';
};

const utcInstantPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/;

export function isUtcInstant(value: unknown): value is UtcInstant {
  if (typeof value !== 'string' || !utcInstantPattern.test(value)) return false;
  const epoch = Date.parse(value);
  if (!Number.isFinite(epoch)) return false;

  const normalizedInput = value.includes('.')
    ? value.replace(/\.(\d{1,2})Z$/, (_, digits: string) => `.${digits.padEnd(3, '0')}Z`)
    : value.replace(/Z$/, '.000Z');
  return new Date(epoch).toISOString() === normalizedInput;
}

export function parseUtcInstant(value: unknown): UtcInstant {
  if (!isUtcInstant(value)) {
    throw new TypeError('Expected a valid RFC 3339 UTC instant ending in Z');
  }
  return new Date(value).toISOString() as UtcInstant;
}

export function isIanaTimezone(value: unknown): value is IanaTimezone {
  if (typeof value !== 'string' || value.length < 1 || value.length > 64) return false;
  if (value !== 'UTC' && !value.includes('/')) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value }).format(0);
    return true;
  } catch {
    return false;
  }
}

export function parseIanaTimezone(value: unknown): IanaTimezone {
  if (!isIanaTimezone(value)) {
    throw new TypeError('Expected a supported IANA timezone name');
  }
  return value;
}
