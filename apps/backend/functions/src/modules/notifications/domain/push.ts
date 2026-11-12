import { createHash } from 'node:crypto';

import type { NotificationCategory, NotificationPreferences } from './notification_policy.js';

/**
 * N3c (owner-approved plan 2026-11-13, BCK13-OD-04/06/07/08): FCM push is a
 * best-effort hint sent only after the inbox item exists; the inbox stays the
 * source of truth. Tokens live only on the server; logs carry the fingerprint.
 */
export const pushConfig = Object.freeze({
  /** OD-08: beyond this the inbox alone carries the notification. */
  maxPerUserPerDay: 20,
  /** OD-07 */
  ttlSeconds: 86_400,
  maxAttempts: 5,
  baseBackoffMs: 30_000,
  /** OD-06: like FCM, a registration unseen for this long is revoked. */
  staleAfterDays: 270,
  attemptRetentionDays: 30,
});

/** Shown on a locked screen; details only inside the app after sign-in. */
export const genericPushText = Object.freeze({
  title: 'Recharge',
  body: 'You have a new notification.',
});

// ----------------------------------------------------------- registrations

export type PushPlatform = 'android';
export type PushRevokeReason =
  'unregistered' | 'rebound' | 'invalid_token' | 'session_ended' | 'stale' | 'recipient_erasure';

export interface PushRegistration {
  readonly schemaVersion: 1;
  /** The Recharge Session installation; one registration per installation. */
  readonly installationId: string;
  readonly userId: string;
  readonly platform: PushPlatform;
  readonly token: string;
  readonly tokenFingerprint: string;
  readonly state: 'active' | 'revoked';
  readonly revokeReason: PushRevokeReason | null;
  readonly revision: number;
  readonly createdAtUtc: string;
  readonly updatedAtUtc: string;
  readonly lastSeenAtUtc: string;
}

const installationPattern = /^(?!__name__$)[A-Za-z0-9._:-]{1,128}$/u;
const tokenPattern = /^[A-Za-z0-9_:\-.]{20,4096}$/u;

export function isInstallationId(value: unknown): value is string {
  return typeof value === 'string' && installationPattern.test(value);
}

export function isPushToken(value: unknown): value is string {
  return typeof value === 'string' && tokenPattern.test(value);
}

/** A token is high-entropy; its SHA-256 prefix correlates logs without the token. */
export function tokenFingerprint(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex').slice(0, 32);
}

/**
 * Registers or refreshes the installation's token for the user. The same user
 * and token only refresh `lastSeenAtUtc`; anything else is a new revision.
 */
export function registerPush(
  current: PushRegistration | undefined,
  input: {
    readonly installationId: string;
    readonly userId: string;
    readonly platform: PushPlatform;
    readonly token: string;
    readonly nowUtc: string;
  },
): PushRegistration {
  if (
    current !== undefined &&
    current.state === 'active' &&
    current.userId === input.userId &&
    current.token === input.token
  )
    return { ...current, lastSeenAtUtc: input.nowUtc };
  return {
    schemaVersion: 1,
    installationId: input.installationId,
    userId: input.userId,
    platform: input.platform,
    token: input.token,
    tokenFingerprint: tokenFingerprint(input.token),
    state: 'active',
    revokeReason: null,
    revision: (current?.revision ?? 0) + 1,
    createdAtUtc: current?.createdAtUtc ?? input.nowUtc,
    updatedAtUtc: input.nowUtc,
    lastSeenAtUtc: input.nowUtc,
  };
}

export function revokePush(
  registration: PushRegistration,
  reason: PushRevokeReason,
  nowUtc: string,
): PushRegistration {
  if (registration.state === 'revoked') return registration;
  return {
    ...registration,
    state: 'revoked',
    revokeReason: reason,
    revision: registration.revision + 1,
    updatedAtUtc: nowUtc,
  };
}

// ----------------------------------------------------------------- policy

/** OD-04: both booking categories push by default; the user may switch push off. */
export function pushEnabled(
  preferences: NotificationPreferences | undefined,
  category: NotificationCategory,
): boolean {
  return preferences?.categories[category]?.push ?? true;
}

export type PushSendResult =
  | Readonly<{ kind: 'accepted'; providerMessageId: string }>
  | Readonly<{ kind: 'invalid_token'; code: string }>
  | Readonly<{ kind: 'transient'; code: string }>
  | Readonly<{ kind: 'rejected'; code: string }>;

const invalidTokenCodes = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);
const transientCodes = new Set([
  'messaging/internal-error',
  'messaging/server-unavailable',
  'messaging/unavailable',
  'messaging/quota-exceeded',
  'messaging/message-rate-exceeded',
  'messaging/device-message-rate-exceeded',
  'app/network-error',
  'app/network-timeout',
]);

/** OD-07: provider answers by class; an unknown code is not retried. */
export function classifyProviderError(code: string): PushSendResult['kind'] {
  if (invalidTokenCodes.has(code)) return 'invalid_token';
  if (transientCodes.has(code)) return 'transient';
  return 'rejected';
}

// --------------------------------------------------------------- attempts

export type PushAttemptState =
  'sending' | 'sent' | 'retry_scheduled' | 'dead_lettered' | 'invalid_token' | 'suppressed';
export type PushSuppressReason = 'user_preference' | 'rate_limited' | 'session_ended';

export interface PushAttempt {
  readonly schemaVersion: 1;
  /** Idempotency key: one push per notification and installation. */
  readonly attemptId: string;
  readonly notificationId: string;
  readonly installationId: string;
  readonly userId: string;
  readonly category: NotificationCategory;
  readonly state: PushAttemptState;
  readonly attemptCount: number;
  readonly nextAttemptAtUtc: string | null;
  readonly lastErrorCode: string | null;
  readonly providerMessageId: string | null;
  readonly suppressReason: PushSuppressReason | null;
  /** UTC day of the first send, for the per-day limit. */
  readonly dayKey: string;
  readonly createdAtUtc: string;
  readonly updatedAtUtc: string;
  readonly expiresAt: Date;
}

export function pushAttemptId(notificationId: string, installationId: string): string {
  return `npa_${createHash('sha256')
    .update(`${notificationId}|${installationId}`, 'utf8')
    .digest('hex')
    .slice(0, 40)}`;
}

export function dayKeyOf(nowUtc: string): string {
  return nowUtc.slice(0, 10);
}

export function newPushAttempt(input: {
  readonly notificationId: string;
  readonly installationId: string;
  readonly userId: string;
  readonly category: NotificationCategory;
  readonly nowUtc: string;
  readonly suppressReason?: PushSuppressReason;
}): PushAttempt {
  return {
    schemaVersion: 1,
    attemptId: pushAttemptId(input.notificationId, input.installationId),
    notificationId: input.notificationId,
    installationId: input.installationId,
    userId: input.userId,
    category: input.category,
    state: input.suppressReason === undefined ? 'sending' : 'suppressed',
    attemptCount: 0,
    nextAttemptAtUtc: null,
    lastErrorCode: null,
    providerMessageId: null,
    suppressReason: input.suppressReason ?? null,
    dayKey: dayKeyOf(input.nowUtc),
    createdAtUtc: input.nowUtc,
    updatedAtUtc: input.nowUtc,
    expiresAt: new Date(Date.parse(input.nowUtc) + pushConfig.attemptRetentionDays * 86_400_000),
  };
}

/** Applies one provider answer; retries back off exponentially up to the limit. */
export function afterSend(
  attempt: PushAttempt,
  result: PushSendResult,
  nowUtc: string,
): PushAttempt {
  const count = attempt.attemptCount + 1;
  const base = { ...attempt, attemptCount: count, updatedAtUtc: nowUtc };
  switch (result.kind) {
    case 'accepted':
      return {
        ...base,
        state: 'sent',
        nextAttemptAtUtc: null,
        lastErrorCode: null,
        providerMessageId: result.providerMessageId,
      };
    case 'invalid_token':
      return {
        ...base,
        state: 'invalid_token',
        nextAttemptAtUtc: null,
        lastErrorCode: result.code,
      };
    case 'rejected':
      return {
        ...base,
        state: 'dead_lettered',
        nextAttemptAtUtc: null,
        lastErrorCode: result.code,
      };
    case 'transient':
      if (count >= pushConfig.maxAttempts)
        return {
          ...base,
          state: 'dead_lettered',
          nextAttemptAtUtc: null,
          lastErrorCode: result.code,
        };
      return {
        ...base,
        state: 'retry_scheduled',
        nextAttemptAtUtc: new Date(
          Date.parse(nowUtc) + pushConfig.baseBackoffMs * 2 ** (count - 1),
        ).toISOString(),
        lastErrorCode: result.code,
      };
  }
}
