import type { ContentTypeId } from '../../../../contracts/content_v1.js';
import type { PublisherRefV1 } from '../../../../contracts/identity_v1.js';
import type { MarketId } from '../../../reference_data/domain/identifiers.js';

/**
 * Reference lookups needed by typed rules. `undefined` means the authority
 * (BCK-20 registry) could not answer; rules then fail closed with an explicit
 * `*_unavailable` issue instead of assuming validity.
 */
export interface ReferenceLookups {
  supportsLocale(locale: string): boolean | undefined;
  subcategoryApplies(
    typeId: ContentTypeId,
    categoryId: string,
    subcategoryId: string,
  ): boolean | undefined;
  /** Required dynamic criteria field ids for the subcategory profile. */
  requiredCriteria(
    typeId: ContentTypeId,
    categoryId: string,
    subcategoryId: string,
  ): readonly string[] | undefined;
  pointInServiceArea(latitude: number, longitude: number): boolean | undefined;
}

/** Object types a Collection may reference (CLG-CRT-01 §3.12). */
export type CollectionObjectType =
  'place' | 'route' | 'bookableSession' | 'classWorkshop' | 'rental';

/**
 * Live status of a referenced published object, answered by the owning
 * Content/Catalog authority. `undefined` means it could not be resolved and the
 * rule fails closed; a client-supplied snapshot is never authority.
 */
export interface PublishedObjectLookup {
  statusOf(objectType: CollectionObjectType, objectId: string): 'ready' | 'unavailable' | undefined;
}

export interface ContentValidationContext {
  readonly typeId: ContentTypeId;
  readonly marketId: MarketId;
  readonly publisherRef: PublisherRefV1;
  readonly createdByUserId: string;
  readonly nowUtc: string;
  /** Revision of the draft being validated (post-update, i.e. current). */
  readonly draftRevision: number;
  readonly publishedObjects?: PublishedObjectLookup;
  readonly market: { readonly currencyCode: string; readonly timezoneId: string };
  readonly lookups: ReferenceLookups;
}

export type ContentRuleIssues = readonly string[];

const maxIssues = 50;

/** Collects stable, bounded, de-duplicated issue codes. */
export class IssueCollector {
  readonly #issues = new Set<string>();

  add(code: string): void {
    if (this.#issues.size < maxIssues) this.#issues.add(code);
  }

  /** Adds `code` when `ok` is false and returns `ok` for chaining. */
  require(ok: boolean, code: string): boolean {
    if (!ok) this.add(code);
    return ok;
  }

  result(): ContentRuleIssues {
    return Object.freeze([...this.#issues]);
  }
}

export type Json = Readonly<Record<string, unknown>>;

export function isRecord(value: unknown): value is Json {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/** Unicode code point count after trim and whitespace collapsing (§10.4). */
export function normalizedLength(value: string): number {
  return [...normalizeText(value)].length;
}

export function normalizeText(value: string): string {
  return value.trim().replace(/\s+/gu, ' ');
}

export function isText(value: unknown, min: number, max: number): value is string {
  if (typeof value !== 'string') return false;
  const length = normalizedLength(value);
  return length >= min && length <= max;
}

export function isInt(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isInteger(value) && value >= min && value <= max;
}

export function isNumberIn(value: unknown, min: number, max: number): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;
}

export function isStringList(
  value: unknown,
  maxItems: number,
  maxLength: number,
): value is string[] {
  return (
    Array.isArray(value) &&
    value.length <= maxItems &&
    value.every((item) => typeof item === 'string' && item.length >= 1 && item.length <= maxLength)
  );
}

export function isEnumValue<T extends string>(value: unknown, allowed: readonly T[]): value is T {
  return typeof value === 'string' && (allowed as readonly string[]).includes(value);
}

export function hasOnlyKeys(
  value: Json,
  allowed: ReadonlySet<string>,
  issues: IssueCollector,
  prefix: string,
): void {
  for (const key of Object.keys(value))
    if (!allowed.has(key)) issues.add(`${prefix}.unknown_field:${key}`);
}

/** Calendar-valid `YYYY-MM-DD`. */
export function isLocalDate(value: unknown): value is string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/u.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().startsWith(value);
}

export function isCountryCode(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Z]{2}$/u.test(value);
}

export function isIanaZone(value: unknown): value is string {
  if (typeof value !== 'string' || value.length < 1 || value.length > 64) return false;
  if (value !== 'UTC' && !value.includes('/')) return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value }).format(0);
    return true;
  } catch {
    return false;
  }
}

/**
 * Public links are HTTPS only, without credentials or unusual schemes
 * (`javascript:`, `data:` and app schemes are rejected).
 */
export function isSafeHttpsUrl(value: unknown): value is string {
  if (typeof value !== 'string' || value.length < 12 || value.length > 2048) return false;
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    return false;
  }
  return (
    parsed.protocol === 'https:' &&
    parsed.username === '' &&
    parsed.password === '' &&
    parsed.hostname.includes('.') &&
    !/[\s<>"']/u.test(value)
  );
}

export function isEmail(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.length <= 254 &&
    /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]{2,}$/u.test(value)
  );
}

/** International phone: optional `+`, 7–15 digits, common separators. */
export function isPhone(value: unknown): value is string {
  if (typeof value !== 'string' || value.length > 32) return false;
  if (!/^\+?[\d\s().-]+$/u.test(value)) return false;
  const digits = value.replace(/\D/gu, '');
  return digits.length >= 7 && digits.length <= 15;
}

/** True when free text embeds a phone number, e-mail or link. */
export function containsContactLike(value: string): boolean {
  return (
    /[^\s@]+@[^\s@]+\.[^\s@]+/u.test(value) ||
    /https?:\/\//iu.test(value) ||
    /www\./iu.test(value) ||
    /(?:\+?\d[\s().-]*){9,}/u.test(value)
  );
}

/** Upper-case shouting: at least 6 letters and no lower-case letter. */
export function isAllCaps(value: string): boolean {
  const letters = value.replace(/[^\p{L}]/gu, '');
  return (
    letters.length >= 6 && letters === letters.toUpperCase() && letters !== letters.toLowerCase()
  );
}

/** Non-negative integer amount in minor units (Money is never floating point). */
export function isMinorUnits(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
}

export function isLocalMinute(value: unknown): value is number {
  return isInt(value, 0, 1439);
}

/** Half-open occupied intervals on a week timeline, minutes from Monday 00:00. */
export interface WeekInterval {
  readonly start: number;
  readonly end: number;
}

const weekMinutes = 7 * 1440;

/**
 * Expands weekly periods (ISO day 1..7, minutes from local midnight) onto a
 * circular week timeline; an overnight tail is carried into the next day.
 */
export function weeklyIntervals(
  periods: readonly {
    dayOfWeek: number;
    openMinute: number;
    closeMinute: number;
    closesNextDay: boolean;
  }[],
): readonly WeekInterval[] {
  const result: WeekInterval[] = [];
  for (const period of periods) {
    const start = (period.dayOfWeek - 1) * 1440 + period.openMinute;
    const length = period.closesNextDay
      ? 1440 - period.openMinute + period.closeMinute
      : period.closeMinute - period.openMinute;
    const end = start + length;
    if (end <= weekMinutes) result.push({ start, end });
    else {
      result.push({ start, end: weekMinutes });
      result.push({ start: 0, end: end - weekMinutes });
    }
  }
  return result;
}

export function intervalsOverlap(intervals: readonly WeekInterval[]): boolean {
  const sorted = [...intervals].sort((left, right) => left.start - right.start);
  for (let index = 1; index < sorted.length; index += 1) {
    const previous = sorted[index - 1];
    const current = sorted[index];
    if (previous !== undefined && current !== undefined && current.start < previous.end)
      return true;
  }
  return false;
}

/**
 * True when any identifier-valued field still holds an unreplaced local
 * `loc_*` id. Permanent ULID/UUIDs must replace them before publication.
 */
export function hasUnreplacedLocalId(value: unknown, depth = 0): boolean {
  if (depth > 10) return false;
  if (Array.isArray(value)) return value.some((item) => hasUnreplacedLocalId(item, depth + 1));
  if (!isRecord(value)) return false;
  for (const [key, child] of Object.entries(value)) {
    const idKey = key === 'id' || key.endsWith('Id');
    const idsKey = key.endsWith('Ids');
    if (idKey && typeof child === 'string' && child.startsWith('loc_')) return true;
    if (
      idsKey &&
      Array.isArray(child) &&
      child.some((item) => typeof item === 'string' && item.startsWith('loc_'))
    )
      return true;
    if (hasUnreplacedLocalId(child, depth + 1)) return true;
  }
  return false;
}
