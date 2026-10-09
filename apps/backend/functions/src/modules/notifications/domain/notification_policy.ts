import type { NotificationEffect } from './notification_effect.js';

/**
 * F1 local category policy (`notifications-local-policy`). Local to the stand,
 * not a Legal mandatory-message policy (BCK13-OD-04 stays open): which effects
 * create an inbox record, in which category, and which categories a user may
 * switch off. Revisions are immutable; a consumed effect pins the revision it
 * was first claimed with.
 */
export type NotificationCategory = 'booking.receipts' | 'booking.changes';
export type NotificationChannel = 'inApp';

export const notificationCategories: readonly NotificationCategory[] = [
  'booking.receipts',
  'booking.changes',
];

export interface NotificationCategoryPolicy {
  readonly inAppDefault: boolean;
  /** A locked category cannot be switched off by the user (local policy). */
  readonly locked: boolean;
}

export type NotificationRoute =
  | Readonly<{ kind: 'deliver'; category: NotificationCategory; templateKey: string }>
  | Readonly<{ kind: 'suppress'; reason: 'recipient_erasure' }>;

export interface NotificationPolicyRevision {
  readonly policyId: 'notifications-local-policy';
  readonly revision: number;
  readonly channels: readonly NotificationChannel[];
  readonly categories: Readonly<Record<NotificationCategory, NotificationCategoryPolicy>>;
  route(effect: NotificationEffect): NotificationRoute;
}

const revisionOne: NotificationPolicyRevision = Object.freeze({
  policyId: 'notifications-local-policy',
  revision: 1,
  channels: Object.freeze(['inApp'] as const),
  categories: Object.freeze({
    // Confirmation of the user's own action, already visible in the app.
    'booking.receipts': Object.freeze({ inAppDefault: true, locked: false }),
    // A change to an active booking made by the organizer or the system, or one
    // that needs the user's action. Locked by this local policy only.
    'booking.changes': Object.freeze({ inAppDefault: true, locked: true }),
  }),
  route(effect: NotificationEffect): NotificationRoute {
    switch (effect.eventType) {
      case 'booking.confirmed':
        return { kind: 'deliver', category: 'booking.receipts', templateKey: 'booking.confirmed' };
      case 'booking.reconfirmed':
        return {
          kind: 'deliver',
          category: 'booking.receipts',
          templateKey: 'booking.reconfirmed',
        };
      case 'booking.reconfirmationRequired':
        return {
          kind: 'deliver',
          category: 'booking.changes',
          templateKey: 'booking.reconfirmationRequired',
        };
      case 'booking.cancelled':
        switch (effect.cause) {
          case 'userCancelled':
            return {
              kind: 'deliver',
              category: 'booking.receipts',
              templateKey: 'booking.cancelled.byUser',
            };
          case 'occurrenceCancelled':
            return {
              kind: 'deliver',
              category: 'booking.changes',
              templateKey: 'booking.cancelled.occurrence',
            };
          case 'missedReconfirmation':
            return {
              kind: 'deliver',
              category: 'booking.changes',
              templateKey: 'booking.cancelled.missedReconfirmation',
            };
          default:
            return { kind: 'suppress', reason: 'recipient_erasure' };
        }
    }
  },
});

export class NotificationPolicyRegistry {
  readonly #revisions: ReadonlyMap<number, NotificationPolicyRevision>;

  constructor(
    revisions: readonly NotificationPolicyRevision[],
    private readonly activeRevision: number,
  ) {
    this.#revisions = new Map(revisions.map((policy) => [policy.revision, policy]));
    if (!this.#revisions.has(activeRevision)) throw new TypeError('notification_policy_missing');
  }

  active(): NotificationPolicyRevision {
    return this.#revisions.get(this.activeRevision)!;
  }

  get(revision: number): NotificationPolicyRevision | undefined {
    return this.#revisions.get(revision);
  }
}

export const notificationPolicyRevisionOne = revisionOne;
export const defaultNotificationPolicies = new NotificationPolicyRegistry([revisionOne], 1);

/** Stored per account; only unlocked categories are ever stored. */
export interface NotificationPreferences {
  readonly schemaVersion: 1;
  readonly userId: string;
  readonly revision: number;
  readonly policyRevision: number;
  readonly categories: Readonly<
    Partial<Record<NotificationCategory, Readonly<{ inApp: boolean }>>>
  >;
  /** Set only by the Notifications privacy restriction task. */
  readonly processingRestricted: boolean;
  readonly updatedAtUtc: string;
}

export class PreferencesUnreadable extends Error {
  constructor() {
    super('preferences_unreadable');
  }
}

/** Strict read of a stored preference document; anything else fails closed. */
export function parseStoredPreferences(userId: string, data: unknown): NotificationPreferences {
  if (typeof data !== 'object' || data === null || Array.isArray(data))
    throw new PreferencesUnreadable();
  const raw = data as Record<string, unknown>;
  const categories = raw.categories;
  if (
    raw.schemaVersion !== 1 ||
    raw.userId !== userId ||
    !Number.isSafeInteger(raw.revision) ||
    (raw.revision as number) < 1 ||
    !Number.isSafeInteger(raw.policyRevision) ||
    typeof raw.processingRestricted !== 'boolean' ||
    typeof raw.updatedAtUtc !== 'string' ||
    typeof categories !== 'object' ||
    categories === null ||
    Array.isArray(categories)
  )
    throw new PreferencesUnreadable();
  const parsed: Partial<Record<NotificationCategory, { inApp: boolean }>> = {};
  for (const [key, value] of Object.entries(categories as Record<string, unknown>)) {
    if (!notificationCategories.includes(key as NotificationCategory))
      throw new PreferencesUnreadable();
    const entry = value as Record<string, unknown> | null;
    if (
      typeof entry !== 'object' ||
      entry === null ||
      Object.keys(entry).length !== 1 ||
      typeof entry.inApp !== 'boolean'
    )
      throw new PreferencesUnreadable();
    parsed[key as NotificationCategory] = { inApp: entry.inApp };
  }
  return {
    schemaVersion: 1,
    userId,
    revision: raw.revision as number,
    policyRevision: raw.policyRevision as number,
    categories: parsed,
    processingRestricted: raw.processingRestricted,
    updatedAtUtc: raw.updatedAtUtc,
  };
}

/** Whether the in-app channel is on for a category; locked categories always are. */
export function inAppDecision(
  policy: NotificationPolicyRevision,
  preferences: NotificationPreferences | undefined,
  category: NotificationCategory,
): Readonly<{ enabled: boolean; locked: boolean }> {
  const rule = policy.categories[category];
  if (rule.locked) return { enabled: true, locked: true };
  return { enabled: preferences?.categories[category]?.inApp ?? rule.inAppDefault, locked: false };
}

export type PreferenceUpdateResult =
  | Readonly<{ kind: 'updated'; preferences: NotificationPreferences }>
  | Readonly<{ kind: 'invalid_preference'; detail: string }>
  | Readonly<{ kind: 'stale_revision' }>;

/**
 * Applies a user update: `{ category: { inApp: boolean } }` for unlocked
 * categories only. Locked category, unknown category or channel, and a channel
 * outside the policy (push, email, SMS) are refused, never ignored.
 */
export function applyPreferenceUpdate(input: {
  readonly policy: NotificationPolicyRevision;
  readonly current: NotificationPreferences | undefined;
  readonly userId: string;
  readonly expectedRevision: number;
  readonly categories: unknown;
  readonly nowUtc: string;
}): PreferenceUpdateResult {
  const currentRevision = input.current?.revision ?? 0;
  if (input.expectedRevision !== currentRevision) return { kind: 'stale_revision' };
  const raw = input.categories;
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw))
    return { kind: 'invalid_preference', detail: 'categories_invalid' };
  const entries = Object.entries(raw as Record<string, unknown>);
  if (entries.length === 0) return { kind: 'invalid_preference', detail: 'categories_empty' };
  const next: Partial<Record<NotificationCategory, { inApp: boolean }>> = {
    ...(input.current?.categories ?? {}),
  };
  for (const [key, value] of entries) {
    if (!notificationCategories.includes(key as NotificationCategory))
      return { kind: 'invalid_preference', detail: 'category_unknown' };
    const category = key as NotificationCategory;
    if (input.policy.categories[category].locked)
      return { kind: 'invalid_preference', detail: 'category_locked' };
    if (typeof value !== 'object' || value === null || Array.isArray(value))
      return { kind: 'invalid_preference', detail: 'channels_invalid' };
    const channels = Object.entries(value as Record<string, unknown>);
    if (channels.length === 0) return { kind: 'invalid_preference', detail: 'channels_invalid' };
    for (const [channel, enabled] of channels) {
      if (!input.policy.channels.includes(channel as NotificationChannel))
        return { kind: 'invalid_preference', detail: 'channel_unknown' };
      if (typeof enabled !== 'boolean')
        return { kind: 'invalid_preference', detail: 'channel_value_invalid' };
    }
    next[category] = { inApp: (value as { inApp: boolean }).inApp };
  }
  return {
    kind: 'updated',
    preferences: {
      schemaVersion: 1,
      userId: input.userId,
      revision: currentRevision + 1,
      policyRevision: input.policy.revision,
      categories: next,
      processingRestricted: input.current?.processingRestricted ?? false,
      updatedAtUtc: input.nowUtc,
    },
  };
}
