import {
  contentTypeIds,
  type ContentBody,
  type ContentTypeId,
} from '../../../contracts/content_v1.js';
import { activityMediaIds, validateActivityBody } from './type_rules/activity_rules.js';
import { placeMediaIds, validatePlaceBody } from './type_rules/place_rules.js';
import type { ContentValidationContext } from './type_rules/validation_context.js';

export type ContentAction = 'create' | 'update' | 'read' | 'submit' | 'publish';

/** Bump when an entry's policy or availability changes; pinned by tests. */
export const contentTypeRegistryRevision = 'content-type-registry-v3';

/** How the publication adapter obtains and pins the type's source. */
export type ContentSourceResolver =
  /** The draft body itself is the source, validated by the type validator. */
  | 'inline_body'
  /** An immutable revision owned by another BCK is pinned by reference. */
  | 'pinned_immutable_revision'
  /** Stable IDs of already published objects, order-checked. */
  | 'published_object_membership';

export type ContentTypeUnavailableReason =
  /** Approved spec exists but its backend rules are not implemented yet. */
  | 'source_contract_pending'
  /** The type's specification is not yet approved. */
  | 'spec_not_approved'
  /** Publication needs an accepted consent/legal decision first. */
  | 'consent_gate_pending'
  /** The source lives in another BCK whose contract is not implemented. */
  | 'dependency_pending';

export type ContentTypeAvailability =
  | { readonly status: 'available' }
  | {
      readonly status: 'unavailable';
      readonly reason: ContentTypeUnavailableReason;
      /** Owning authority or decision the type is waiting for. */
      readonly dependency?: string;
    };

export type ContentTypeRule = (
  body: ContentBody,
  context: ContentValidationContext,
) => readonly string[];

export interface ContentTypeRegistryEntry {
  readonly typeId: ContentTypeId;
  readonly typeSchemaMajor: 1;
  readonly validatorRevision: string;
  /** Authority that owns the source the adapter validates or pins. */
  readonly sourceAuthority: string;
  readonly sourceResolver: ContentSourceResolver;
  readonly requiredCapabilities: Readonly<Record<ContentAction, string>>;
  readonly allowedPublisherTypes: readonly ('user' | 'page')[];
  readonly moderationProfileId: string;
  readonly visibilityPolicy: 'public_catalog' | 'consent_limited';
  readonly marketPolicy: 'single_market_per_content';
  readonly localizedTextPolicy: 'per_locale_with_declared_fallback';
  readonly discoverFamily: string;
  readonly mapperRevision: string;
  readonly availability: ContentTypeAvailability;
  /**
   * Typed source rule: returns bounded issue codes (empty = valid). Present
   * exactly when the type is available; otherwise the type fails closed.
   */
  readonly validate?: ContentTypeRule;
  /** Media ids the body references; Media readiness is checked for exactly these. */
  readonly mediaIds?: (body: ContentBody) => readonly string[];
}

const capabilities: Readonly<Record<ContentAction, string>> = Object.freeze({
  create: 'content.create',
  update: 'content.create',
  read: 'content.create',
  submit: 'content.submit',
  publish: 'content.publish',
});

interface EntryInput {
  readonly discoverFamily: string;
  readonly sourceAuthority: string;
  readonly sourceResolver: ContentSourceResolver;
  readonly visibilityPolicy?: ContentTypeRegistryEntry['visibilityPolicy'];
  /** Exactly one of `rules` and `unavailable` must be given. */
  readonly rules?: {
    readonly validate: ContentTypeRule;
    readonly mediaIds: (body: ContentBody) => readonly string[];
  };
  readonly unavailable?: {
    readonly reason: ContentTypeUnavailableReason;
    readonly dependency?: string;
  };
}

function entry(typeId: ContentTypeId, input: EntryInput): ContentTypeRegistryEntry {
  if ((input.rules === undefined) === (input.unavailable === undefined))
    throw new Error(`content_type_registry_entry_invalid:${typeId}`);
  const availability: ContentTypeAvailability =
    input.rules !== undefined
      ? { status: 'available' }
      : {
          status: 'unavailable',
          reason: input.unavailable?.reason ?? 'source_contract_pending',
          ...(input.unavailable?.dependency === undefined
            ? {}
            : { dependency: input.unavailable.dependency }),
        };
  return Object.freeze({
    typeId,
    typeSchemaMajor: 1,
    validatorRevision: input.rules === undefined ? 'unavailable' : `${typeId}-source-v1`,
    sourceAuthority: input.sourceAuthority,
    sourceResolver: input.sourceResolver,
    requiredCapabilities: capabilities,
    allowedPublisherTypes: Object.freeze(['user', 'page'] as const),
    moderationProfileId: `${typeId}.default`,
    visibilityPolicy: input.visibilityPolicy ?? 'public_catalog',
    marketPolicy: 'single_market_per_content',
    localizedTextPolicy: 'per_locale_with_declared_fallback',
    discoverFamily: input.discoverFamily,
    mapperRevision: `${typeId}-mapper-v1`,
    availability: Object.freeze(availability),
    ...(input.rules === undefined
      ? {}
      : { validate: input.rules.validate, mediaIds: input.rules.mediaIds }),
  });
}

// Exactly the accepted ten Create types (BCK-07 §33.1). An adapter is
// registered for every type, but only types with a ready, approved source rule
// are available; the rest are explicit, carry their reason and fail closed
// instead of falling back to a generic schema or Event.
const entries: readonly ContentTypeRegistryEntry[] = Object.freeze([
  entry('event', {
    discoverFamily: 'Event',
    sourceAuthority: 'Event classification v2.2.3 (C0 + schedule-C1 subset)',
    sourceResolver: 'inline_body',
    unavailable: { reason: 'source_contract_pending' },
  }),
  entry('activity', {
    discoverFamily: 'Activity',
    sourceAuthority: 'Recharge Activity create block (ACT-CRT-01 v1.4, Approved)',
    sourceResolver: 'inline_body',
    rules: { validate: validateActivityBody, mediaIds: activityMediaIds },
  }),
  entry('route', {
    discoverFamily: 'Route',
    sourceAuthority: 'BCK-11 immutable RouteRevision',
    sourceResolver: 'pinned_immutable_revision',
    unavailable: { reason: 'dependency_pending', dependency: 'BCK-11' },
  }),
  entry('place', {
    discoverFamily: 'Place',
    sourceAuthority: 'Place create block (PLC-ADP-01, v1.0 Approved)',
    sourceResolver: 'inline_body',
    rules: { validate: validatePlaceBody, mediaIds: placeMediaIds },
  }),
  entry('session', {
    discoverFamily: 'Session',
    sourceAuthority: 'Bookable Session create block (SES-CRT-01)',
    sourceResolver: 'inline_body',
    unavailable: { reason: 'spec_not_approved', dependency: 'SES-CRT-01 spec Draft' },
  }),
  entry('scenario', {
    discoverFamily: 'Scenario',
    sourceAuthority: 'BCK-10 immutable ScenarioRevision',
    sourceResolver: 'pinned_immutable_revision',
    unavailable: { reason: 'dependency_pending', dependency: 'BCK-10' },
  }),
  entry('find_people', {
    discoverFamily: 'Find People',
    sourceAuthority: 'BCK-06 purpose-limited consented profile revision',
    sourceResolver: 'pinned_immutable_revision',
    visibilityPolicy: 'consent_limited',
    unavailable: { reason: 'consent_gate_pending', dependency: 'BCK-06 + OD-11' },
  }),
  entry('class_workshop', {
    discoverFamily: 'Class/Workshop',
    sourceAuthority: 'typed Class / Workshop experience revision',
    sourceResolver: 'inline_body',
    unavailable: {
      reason: 'spec_not_approved',
      dependency: 'Class/Workshop spec Ready for approval',
    },
  }),
  entry('rental', {
    discoverFamily: 'Rental',
    sourceAuthority: 'Rental / Equipment create block (RNT-CRT-01)',
    sourceResolver: 'inline_body',
    unavailable: { reason: 'source_contract_pending' },
  }),
  entry('collection', {
    discoverFamily: 'Collection',
    sourceAuthority: 'Collection revision of stable published object IDs (CLG-CRT-01)',
    sourceResolver: 'published_object_membership',
    unavailable: { reason: 'source_contract_pending' },
  }),
]);

const byId: ReadonlyMap<string, ContentTypeRegistryEntry> = new Map(
  entries.map((item) => [item.typeId, item]),
);

// Load-time invariants: a broken registry must never start serving.
if (
  entries.length !== contentTypeIds.length ||
  byId.size !== entries.length ||
  contentTypeIds.some((id) => !byId.has(id))
)
  throw new Error('content_type_registry_incomplete');
for (const item of entries)
  if (
    (item.availability.status === 'available') !== (item.validate !== undefined) ||
    (item.validate !== undefined) !== (item.mediaIds !== undefined)
  )
    throw new Error(`content_type_registry_inconsistent:${item.typeId}`);

export const contentTypeRegistry = entries;

/** Returns the registered entry, or null for unknown/newer/foreign type ids. */
export function resolveContentType(typeId: unknown): ContentTypeRegistryEntry | null {
  return typeof typeId === 'string' ? (byId.get(typeId) ?? null) : null;
}

/** True only for a type whose source rules are implemented (fail closed otherwise). */
export function isContentTypeAvailable(item: ContentTypeRegistryEntry): boolean {
  return item.availability.status === 'available' && item.validate !== undefined;
}

/** Kept for existing call sites: a source contract exists iff the type is available. */
export const hasSourceContract = isContentTypeAvailable;
