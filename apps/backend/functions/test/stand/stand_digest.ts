import { createHash } from 'node:crypto';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import { exactBookingCollectionNames } from '../../src/booking/transactions.js';
import { eventBookingDeliveryCollections } from '../../src/booking/event_projection_delivery.js';
import { identityAuthorityCollections } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import {
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { standManifestCollection } from './stand_content_event.js';
import { isAuthUserNotFound } from './stand_guard.js';
import { standEvent, standUsers } from './stand_plan.js';

/** Domain records of the Content-path Event; idempotency and audit records are excluded as noise. */
const seededContentCollections = [
  contentCollections.drafts,
  contentCollections.submissions,
  contentCollections.publishedRevisions,
  contentCollections.pointers,
  contentCollections.effects,
  mediaCollections.assets,
  mediaCollections.sessions,
  mediaCollections.receipts,
  moderationCollections.decisions,
  moderationCollections.receipts,
];

/** Collections that describe seeded domain state. Rate-limit counters and audit noise are excluded. */
export const digestCollections: readonly string[] = Object.freeze(
  [
    ...new Set([
      ...Object.values(identityAuthorityCollections),
      ...exactBookingCollectionNames,
      ...Object.values(eventBookingDeliveryCollections),
      featureFlagRevisionCollection,
      featureFlagPointerCollection,
      // C2: the test-only staff registry is seeded authority, so it is part of the digest.
      moderationCollections.staffAuthority,
      // C3: the seeded Event is created through Content, Media and moderation.
      ...seededContentCollections,
      standManifestCollection,
    ]),
  ].sort(),
);

/** Hashes derived from server-generated actor/booking ids differ per run by construction. */
const hashPattern = /([mr]1_)?[0-9a-f]{64}/gu;
const instantPattern = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z/gu;
const keptInstants = new Set<string>([
  standEvent.publishedAt,
  standEvent.occurrenceStartsAt,
  standEvent.occurrenceEndsAt,
  standEvent.registrationOpensAt,
  standEvent.registrationClosesAt,
  standEvent.cancellationDeadline,
]);
/** Fields whose value is a fresh secret or per-run random token by design. */
const volatileKeys = new Set([
  'handleHash',
  'identityId',
  // Storage Emulator object generations are time-based by design.
  'providerGeneration',
  'sourceGeneration',
  'sourceProviderGeneration',
]);

/**
 * D3.1: inside a Media asset's `variantRefs` only, the values the fake
 * processor derives from its per-process counter (a resumed Place seed runs it
 * in two processes). Everywhere else these keys stay significant.
 */
const fakeVariantKeys = new Set(['variantId', 'byteLength']);

/**
 * D3.1: lists the domain itself stores sorted by asset id (Media readiness and
 * the publication pointer); ids are random per run, so after labelling their
 * order is canonicalised. Nothing else is reordered: a draft's `mediaAssetIds`
 * and a body's gallery keep the user's order.
 */
const assetSortedKeys = new Set(['mediaAttachments', 'mediaConfirmations', 'mediaSuppression']);
const assetSortedKeysIn: Readonly<Record<string, ReadonlySet<string>>> = {
  [contentCollections.publishedRevisions]: new Set(['mediaAssetIds']),
};

export interface StandDigest {
  readonly digest: string;
  readonly normalized: unknown;
}

export type Plain = Record<string, unknown>;

export type RawStandState = ReadonlyMap<string, ReadonlyMap<string, Plain>>;

export async function collectStandState(firestore: Firestore): Promise<RawStandState> {
  const raw = new Map<string, Map<string, Plain>>();
  for (const collection of digestCollections) {
    const documents = new Map<string, Plain>();
    for (const document of (await firestore.collection(collection).get()).docs) {
      documents.set(document.id, document.data());
    }
    raw.set(collection, documents);
  }
  return raw;
}

export async function computeStandDigest(firestore: Firestore): Promise<StandDigest> {
  return digestStandState(await collectStandState(firestore), await authSnapshot());
}

/** Pure normalization: server-generated ids become labels, volatile values become placeholders. */
export function digestStandState(raw: RawStandState, auth: unknown): StandDigest {
  const labels = deriveLabels(raw);
  const collections: Record<string, unknown[]> = {};
  for (const [collection, documents] of raw) {
    const normalizer = new Normalizer(labels, assetSortedKeysIn[collection]);
    // Hash-named documents can collapse to one normalized id, so entries stay a sorted list.
    const entries = [...documents].map(([id, data]) => ({
      id: normalizer.text(id),
      data: normalizer.value(data),
    }));
    entries.sort((left, right) => compare(stableStringify(left), stableStringify(right)));
    collections[collection] = entries;
  }
  const normalized = { auth, collections };
  const digest = createHash('sha256').update(stableStringify(normalized), 'utf8').digest('hex');
  return Object.freeze({ digest, normalized });
}

async function authSnapshot(): Promise<unknown> {
  const users = [];
  for (const user of standUsers) {
    try {
      const record = await getAuth().getUser(user.firebaseUid);
      users.push({
        label: user.label,
        uid: record.uid,
        email: record.email ?? null,
        disabled: record.disabled,
        providers: record.providerData.map((provider) => provider.providerId).sort(),
      });
    } catch (error) {
      if (!isAuthUserNotFound(error)) throw error;
      users.push({ label: user.label, uid: user.firebaseUid, missing: true });
    }
  }
  return users;
}

/** Derives stable labels for server-generated ids from Auth uid → Session → Account → Booking. */
function deriveLabels(raw: ReadonlyMap<string, ReadonlyMap<string, Plain>>): Map<string, string> {
  const labels = new Map<string, string>();
  const uidToLabel = new Map<string, string>(standUsers.map((u) => [u.firebaseUid, u.label]));
  const userLabelById = new Map<string, string>();
  const sessionsByLabel = new Map<string, Array<{ id: string; issuedAt: string }>>();
  for (const [sessionId, session] of raw.get(identityAuthorityCollections.sessions) ?? []) {
    const label = uidToLabel.get(String(session.firebaseUid));
    if (label === undefined) continue;
    labels.set(String(session.userId), `user:${label}`);
    userLabelById.set(String(session.userId), label);
    const list = sessionsByLabel.get(label) ?? [];
    list.push({ id: sessionId, issuedAt: String(session.issuedAtUtc) });
    sessionsByLabel.set(label, list);
  }
  // A recovered Session supersedes the first one; order by issue time gives a stable label.
  for (const [label, list] of sessionsByLabel) {
    list.sort((left, right) => compare(left.issuedAt, right.issuedAt));
    list.forEach((entry, index) => labels.set(entry.id, `session:${label}:${index + 1}`));
  }
  for (const [bookingId, booking] of raw.get('bookings') ?? []) {
    const label = userLabelById.get(String(booking.userId));
    if (label !== undefined) labels.set(bookingId, `booking:${label}`);
  }
  // C3: ids the owner services returned for the seeded Event, named by the manifest.
  const manifest = raw.get(standManifestCollection)?.get('seed');
  const event = manifest?.contentEvent as Record<string, unknown> | undefined;
  if (event !== undefined) {
    for (const [key, name] of Object.entries({
      contentId: 'content',
      draftId: 'draft',
      submissionId: 'submission',
      publishedRevisionId: 'revision',
      assetId: 'asset',
      uploadSessionId: 'upload',
      approveDecisionId: 'decision',
    })) {
      const value = event[key];
      if (typeof value === 'string') labels.set(value, `${name}:seed-event`);
    }
    const asset = raw.get(mediaCollections.assets)?.get(String(event.assetId));
    if (typeof asset?.objectKeyHandle === 'string')
      labels.set(asset.objectKeyHandle, 'objk:seed-event');
  }
  // D3.1/D3.2: the seeded Place and Activity, named by their manifests.
  for (const [manifestKey, tag] of [
    ['contentPlace', 'seed-place'],
    ['contentActivity', 'seed-activity'],
    ['contentRental', 'seed-rental'],
  ] as const) {
    const seeded = manifest?.[manifestKey] as Record<string, unknown> | undefined;
    if (seeded === undefined) continue;
    for (const [key, name] of Object.entries({
      contentId: 'content',
      draftId: 'draft',
      submissionId: 'submission',
      publishedRevisionId: 'revision',
      approveDecisionId: 'decision',
    })) {
      const value = seeded[key];
      if (typeof value === 'string') labels.set(value, `${name}:${tag}`);
    }
    const gallery = Array.isArray(seeded.galleryAssetIds) ? seeded.galleryAssetIds : [];
    const images: Array<[unknown, string]> = [
      [seeded.coverAssetId, 'cover'],
      ...gallery.map((assetId, index): [unknown, string] => [assetId, `gallery-${index + 1}`]),
    ];
    for (const [assetId, role] of images) {
      if (typeof assetId !== 'string') continue;
      labels.set(assetId, `asset:${tag}-${role}`);
      const asset = raw.get(mediaCollections.assets)?.get(assetId);
      if (typeof asset?.objectKeyHandle === 'string')
        labels.set(asset.objectKeyHandle, `objk:${tag}-${role}`);
      for (const [sessionId, session] of raw.get(mediaCollections.sessions) ?? [])
        if (session.assetId === assetId) labels.set(sessionId, `upload:${tag}-${role}`);
    }
  }
  return labels;
}

class Normalizer {
  readonly #ordered: Array<[string, string]>;
  readonly #sortedKeys: ReadonlySet<string>;

  constructor(labels: ReadonlyMap<string, string>, sortedKeys: ReadonlySet<string> = new Set()) {
    this.#ordered = [...labels].sort(([a], [b]) => b.length - a.length);
    this.#sortedKeys = new Set([...assetSortedKeys, ...sortedKeys]);
  }

  text(input: string): string {
    let output = input;
    for (const [from, to] of this.#ordered) output = output.split(from).join(to);
    return output
      .replace(hashPattern, (_match, prefix: string | undefined) => `${prefix ?? ''}<hash>`)
      .replace(instantPattern, (match) => (keptInstants.has(match) ? match : '<utc>'));
  }

  value(input: unknown, key?: string, inVariant = false): unknown {
    if (key !== undefined && volatileKeys.has(key)) return '<volatile>';
    if (inVariant && key !== undefined && fakeVariantKeys.has(key)) return '<volatile>';
    if (input instanceof Timestamp) return '<timestamp>';
    if (typeof input === 'string') return this.text(input);
    if (Array.isArray(input)) {
      const items = input.map((item) => this.value(item, undefined, key === 'variantRefs'));
      return key !== undefined && this.#sortedKeys.has(key) ? [...items].sort(byJson) : items;
    }
    if (typeof input === 'object' && input !== null) {
      const entries = Object.entries(input as Plain).map(
        ([name, item]) => [this.text(name), this.value(item, name, inVariant)] as const,
      );
      entries.sort(([left], [right]) => compare(left, right));
      return Object.fromEntries(entries);
    }
    return input;
  }
}

function byJson(left: unknown, right: unknown): number {
  return compare(stableStringify(left), stableStringify(right));
}

function compare(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

function stableStringify(value: unknown): string {
  return JSON.stringify(value, (_key, item: unknown) =>
    typeof item === 'object' && item !== null && !Array.isArray(item)
      ? Object.fromEntries(
          Object.entries(item as Plain).sort(([left], [right]) => compare(left, right)),
        )
      : item,
  );
}
