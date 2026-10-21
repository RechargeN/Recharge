import { findPeoplePolicy, isPublicCellCentre } from '../../../shared/find_people_policy.js';
import type {
  CatalogOccurrence,
  CatalogPoint,
  ContentFact,
  ProjectionOutcome,
  SourceRevision,
} from './catalog_item.js';
import { normalizeText } from './catalog_item.js';

/**
 * D3.7 Find People Catalog projection v1: a public allowlist read only from
 * the server-built public body of an immutable revision (§3.2). The point is
 * the ~1 km cell centre; anything that is not a verified cell centre, or any
 * trace of private meeting data, excludes the object. Consent, age, K2 and
 * expiry are never decided here: every read checks them fresh (§6).
 */
export interface CatalogFindPeopleItem {
  readonly schemaRevision: 'catalog-find-people-projection-v1';
  readonly typeId: 'find_people';
  readonly contentId: string;
  readonly publishedRevisionId: string;
  readonly sourcePointerRevision: number;
  readonly marketId: string;
  readonly publisherRef: { readonly type: string; readonly id: string };
  /** The single responsible host, public by spec v3.1 §6.2. */
  readonly hostUserId: string;
  readonly title: string;
  readonly shortDescription: string;
  readonly fullDescription: string;
  readonly categoryId: string;
  readonly subcategoryId: string;
  readonly tags: readonly string[];
  readonly publicAreaLabel: string;
  /** The cell centre, never the meeting point. */
  readonly point: CatalogPoint;
  readonly publicGeoPrecisionMeters: number;
  readonly timezoneId: string;
  /** Exactly one occurrence in T3 (single schedule). */
  readonly occurrences: readonly CatalogOccurrence[];
  readonly applicationDeadlineUtc: string;
  readonly skillLevel: string;
  readonly languageCodes: readonly string[];
  readonly participationGoal: string;
  readonly targetGroupSize: number;
  readonly hostSeatCount: number;
  readonly approvalMode: string;
  readonly verificationRequirement: string;
  readonly costType: string;
  readonly expectedSpend: { readonly amountMinor: number; readonly currencyCode: string } | null;
  /** No media in T3: the card uses the category visual. */
  readonly coverMediaId: null;
  readonly referenceRevisions: Readonly<Record<string, string>>;
  readonly publishedAtUtc: string;
  readonly searchText: string;
}

function record(value: unknown): Readonly<Record<string, unknown>> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function text(value: unknown): string | null {
  return typeof value === 'string' && value.trim() !== '' ? value : null;
}

function instant(value: unknown): string | null {
  return typeof value === 'string' &&
    /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/u.test(value) &&
    Number.isFinite(Date.parse(value))
    ? value
    : null;
}

function int(value: unknown): number | null {
  return typeof value === 'number' && Number.isSafeInteger(value) ? value : null;
}

function strings(value: unknown): string[] | null {
  return Array.isArray(value) && value.every((item) => typeof item === 'string')
    ? [...value]
    : null;
}

/** Whether any key in the body could carry private meeting data. */
function hasPrivateTrace(value: unknown, depth = 0): boolean {
  if (depth > 12) return false;
  if (Array.isArray(value)) return value.some((item) => hasPrivateTrace(item, depth + 1));
  const object = record(value);
  if (object === null) return false;
  for (const [key, child] of Object.entries(object)) {
    if (
      key === 'exact' ||
      key === 'exactGeo' ||
      key === 'addressLine' ||
      key === 'instructions' ||
      key === 'placeName' ||
      key === 'confirmations'
    )
      return true;
    if (hasPrivateTrace(child, depth + 1)) return true;
  }
  return false;
}

export function projectFindPeople(fact: ContentFact, source: SourceRevision): ProjectionOutcome {
  const bad = (): ProjectionOutcome => ({ state: 'excluded', reason: 'invalid_projection' });
  const body = source.body;
  const data = record(body.findPeople);
  if (data === null || data.projection !== 'public_v1' || hasPrivateTrace(body)) return bad();
  if (data.visibility !== 'public') return { state: 'excluded', reason: 'unlisted' };
  const meeting = record(data.meeting);
  const location = record(meeting?.publicLocation);
  const latitude = location?.latitude;
  const longitude = location?.longitude;
  if (
    meeting?.mode !== 'in_person' ||
    typeof latitude !== 'number' ||
    typeof longitude !== 'number' ||
    location?.precisionMeters !== findPeoplePolicy.publicGeoPrecisionMeters ||
    location.policyRevision !== findPeoplePolicy.publicGeoPolicyRevision ||
    !isPublicCellCentre(latitude, longitude, findPeoplePolicy.publicGeoPrecisionMeters)
  )
    return bad();
  const schedule = record(data.schedule);
  const slot = record(schedule?.slot);
  const start = instant(slot?.startAtUtc);
  const end = instant(slot?.endAtUtc);
  const group = record(data.group);
  const cost = record(data.cost);
  const hosts = record(data.hosts);
  const hostIds = strings(hosts?.responsibleHostUserIds);
  const spend = record(cost?.expectedSpend);
  const title = text(body.title);
  const shortDescription = text(body.shortDescription);
  const fullDescription = text(body.fullDescription);
  const categoryId = text(body.categoryId);
  const subcategoryId = text(body.subcategoryId);
  const publicAreaLabel = text(meeting.publicAreaLabel);
  const timezoneId = text(schedule?.timezoneId);
  const deadline = instant(schedule?.applicationDeadlineUtc);
  const languageCodes = strings(data.languageCodes);
  const targetGroupSize = int(group?.targetGroupSize);
  const hostSeatCount = int(group?.hostSeatCount);
  if (
    schedule?.mode !== 'single' ||
    typeof slot?.id !== 'string' ||
    start === null ||
    end === null ||
    Date.parse(start) >= Date.parse(end) ||
    hostIds === null ||
    hostIds.length !== 1 ||
    title === null ||
    shortDescription === null ||
    fullDescription === null ||
    categoryId === null ||
    subcategoryId === null ||
    publicAreaLabel === null ||
    timezoneId === null ||
    deadline === null ||
    languageCodes === null ||
    targetGroupSize === null ||
    hostSeatCount === null ||
    instant(source.publishedAtUtc) === null
  )
    return bad();
  const tags = strings(body.tags) ?? [];
  const item: CatalogFindPeopleItem = {
    schemaRevision: 'catalog-find-people-projection-v1',
    typeId: 'find_people',
    contentId: fact.contentId,
    publishedRevisionId: fact.publishedRevisionId,
    sourcePointerRevision: fact.pointerRevision,
    marketId: fact.marketId,
    publisherRef: { type: fact.publisherRef.type, id: fact.publisherRef.id },
    hostUserId: hostIds[0] as string,
    title,
    shortDescription,
    fullDescription,
    categoryId,
    subcategoryId,
    tags,
    publicAreaLabel,
    point: { latitude, longitude },
    publicGeoPrecisionMeters: findPeoplePolicy.publicGeoPrecisionMeters,
    timezoneId,
    occurrences: [{ id: slot.id, startAtUtc: start, endAtUtc: end }],
    applicationDeadlineUtc: deadline,
    skillLevel: text(data.skillLevel) ?? 'any',
    languageCodes,
    participationGoal: text(data.participationGoal) ?? 'other',
    targetGroupSize,
    hostSeatCount,
    approvalMode: text(group?.approvalMode) ?? 'manual',
    verificationRequirement: text(group?.verificationRequirement) ?? 'none',
    costType: text(cost?.costType) ?? 'unknown',
    expectedSpend:
      spend !== null && int(spend.amountMinor) !== null && typeof spend.currencyCode === 'string'
        ? { amountMinor: spend.amountMinor as number, currencyCode: spend.currencyCode }
        : null,
    coverMediaId: null,
    referenceRevisions: { ...source.referenceRevisions },
    publishedAtUtc: source.publishedAtUtc,
    searchText: normalizeText(
      [title, shortDescription, categoryId, subcategoryId, publicAreaLabel, ...tags].join(' '),
    ),
  };
  return { state: 'listed', item };
}
