import type { ServerClock } from '../../../shared/server_clock.js';
import type {
  NotificationCategory,
  NotificationPreferences,
} from '../domain/notification_policy.js';
import {
  afterSend,
  dayKeyOf,
  genericPushText,
  newPushAttempt,
  pushConfig,
  pushEnabled,
  registerPush,
  revokePush,
  type PushAttempt,
  type PushPlatform,
  type PushRegistration,
  type PushRevokeReason,
  type PushSendResult,
} from '../domain/push.js';

/** FCM (or a test double). Never throws: every outcome is a typed result. */
export interface PushProviderPort {
  send(message: {
    readonly token: string;
    readonly notificationId: string;
    readonly category: NotificationCategory;
    readonly title: string;
    readonly body: string;
    readonly ttlSeconds: number;
  }): Promise<PushSendResult>;
}

/**
 * Push state, separate from the inbox: registrations per installation and one
 * attempt per notification and installation (create-if-absent = idempotency).
 */
export interface PushStore {
  registration(installationId: string): Promise<PushRegistration | undefined>;
  activeRegistrationsForUser(userId: string): Promise<readonly PushRegistration[]>;
  activeRegistrationsForToken(tokenFingerprint: string): Promise<readonly PushRegistration[]>;
  putRegistration(registration: PushRegistration): Promise<void>;
  /** false when the attempt already exists (another worker or a replay). */
  createAttempt(attempt: PushAttempt): Promise<boolean>;
  putAttempt(attempt: PushAttempt): Promise<void>;
  attempt(attemptId: string): Promise<PushAttempt | undefined>;
  sentCountForUserOnDay(userId: string, dayKey: string): Promise<number>;
  dueAttempts(nowUtc: string, limit: number): Promise<readonly PushAttempt[]>;
  staleRegistrations(
    lastSeenBeforeUtc: string,
    limit: number,
  ): Promise<readonly PushRegistration[]>;
  /** DSR: every registration and attempt of the user. */
  subjectRegistrationIds(userId: string, limit: number): Promise<readonly string[]>;
  subjectAttemptIds(userId: string, limit: number): Promise<readonly string[]>;
  deleteRegistrations(installationIds: readonly string[]): Promise<void>;
  deleteAttempts(attemptIds: readonly string[]): Promise<void>;
}

/** Identity, read-only: a registration lives only while its Session does. */
export interface PushSessionPort {
  activeSession(userId: string, installationId: string, nowUtc: string): Promise<boolean>;
}

export interface PushDispatcherDependencies {
  readonly store: PushStore;
  readonly provider: PushProviderPort;
  readonly sessions: PushSessionPort;
  readonly preferences: (userId: string) => Promise<NotificationPreferences | undefined>;
  readonly clock: ServerClock;
  /** Safe metadata only: never a token, never notification text. */
  readonly log?: (event: string, fields: Readonly<Record<string, unknown>>) => void;
}

/**
 * N3c (owner-approved 2026-11-13). Runs after the inbox item is committed; a
 * failure here never touches the inbox, the receipt or the source effect.
 */
export class PushDispatcher {
  constructor(private readonly deps: PushDispatcherDependencies) {}

  async register(input: {
    readonly userId: string;
    readonly installationId: string;
    readonly platform: PushPlatform;
    readonly token: string;
  }): Promise<PushRegistration> {
    const now = this.now();
    const next = registerPush(await this.deps.store.registration(input.installationId), {
      ...input,
      nowUtc: now,
    });
    // One token, one active user (OD-06): another installation or account
    // holding the same token is revoked.
    for (const other of await this.deps.store.activeRegistrationsForToken(next.tokenFingerprint))
      if (other.installationId !== next.installationId) await this.revoke(other, 'rebound', now);
    await this.deps.store.putRegistration(next);
    this.log('push_registered', next, { revision: next.revision });
    return next;
  }

  /** Only the caller's own installation; another user's registration is untouched. */
  async unregister(userId: string, installationId: string): Promise<boolean> {
    const current = await this.deps.store.registration(installationId);
    if (current === undefined || current.userId !== userId || current.state !== 'active')
      return false;
    await this.revoke(current, 'unregistered', this.now());
    return true;
  }

  /** After the inbox item exists: one attempt per active, still signed-in installation. */
  async dispatch(item: {
    readonly notificationId: string;
    readonly recipientId: string;
    readonly category: NotificationCategory;
  }): Promise<readonly PushAttempt[]> {
    const now = this.now();
    const registrations = await this.deps.store.activeRegistrationsForUser(item.recipientId);
    if (registrations.length === 0) return [];
    const enabled = pushEnabled(await this.deps.preferences(item.recipientId), item.category);
    const sentToday = await this.deps.store.sentCountForUserOnDay(item.recipientId, dayKeyOf(now));
    const results: PushAttempt[] = [];
    for (const registration of registrations) {
      const base = {
        notificationId: item.notificationId,
        installationId: registration.installationId,
        userId: item.recipientId,
        category: item.category,
        nowUtc: now,
      };
      if (
        !(await this.deps.sessions.activeSession(
          item.recipientId,
          registration.installationId,
          now,
        ))
      ) {
        await this.revoke(registration, 'session_ended', now);
        continue;
      }
      const suppressReason = !enabled
        ? ('user_preference' as const)
        : sentToday + results.filter((a) => a.state === 'sent').length >=
            pushConfig.maxPerUserPerDay
          ? ('rate_limited' as const)
          : undefined;
      const attempt = newPushAttempt({
        ...base,
        ...(suppressReason === undefined ? {} : { suppressReason }),
      });
      if (!(await this.deps.store.createAttempt(attempt))) continue;
      if (suppressReason !== undefined) {
        this.log('push_suppressed', registration, { reason: suppressReason });
        results.push(attempt);
        continue;
      }
      results.push(await this.send(attempt, registration));
    }
    return results;
  }

  /** Reconciliation: retries that are due, then registrations unseen for too long. */
  async reconcile(limit = 50): Promise<{ readonly retried: number; readonly revoked: number }> {
    const now = this.now();
    let retried = 0;
    for (const attempt of await this.deps.store.dueAttempts(now, limit)) {
      const registration = await this.deps.store.registration(attempt.installationId);
      if (
        registration === undefined ||
        registration.state !== 'active' ||
        registration.userId !== attempt.userId
      ) {
        await this.deps.store.putAttempt({
          ...attempt,
          state: 'suppressed',
          suppressReason: 'session_ended',
          nextAttemptAtUtc: null,
          updatedAtUtc: now,
        });
        continue;
      }
      await this.send(attempt, registration);
      retried += 1;
    }
    const staleBefore = new Date(
      Date.parse(now) - pushConfig.staleAfterDays * 86_400_000,
    ).toISOString();
    let revoked = 0;
    for (const registration of await this.deps.store.staleRegistrations(staleBefore, limit)) {
      await this.revoke(registration, 'stale', now);
      revoked += 1;
    }
    return { retried, revoked };
  }

  /** DSR erasure: registrations and attempts of the subject are deleted. */
  eraseSubject(userId: string, limit = 200): Promise<number> {
    return erasePushSubject(this.deps.store, userId, limit);
  }

  private async send(attempt: PushAttempt, registration: PushRegistration): Promise<PushAttempt> {
    let result: PushSendResult;
    try {
      result = await this.deps.provider.send({
        token: registration.token,
        notificationId: attempt.notificationId,
        category: attempt.category,
        title: genericPushText.title,
        body: genericPushText.body,
        ttlSeconds: pushConfig.ttlSeconds,
      });
    } catch {
      result = { kind: 'transient', code: 'provider_threw' };
    }
    const now = this.now();
    const next = afterSend(attempt, result, now);
    await this.deps.store.putAttempt(next);
    if (result.kind === 'invalid_token') await this.revoke(registration, 'invalid_token', now);
    this.log('push_attempt', registration, {
      state: next.state,
      attemptCount: next.attemptCount,
      code: next.lastErrorCode,
    });
    return next;
  }

  private async revoke(
    registration: PushRegistration,
    reason: PushRevokeReason,
    nowUtc: string,
  ): Promise<void> {
    await this.deps.store.putRegistration(revokePush(registration, reason, nowUtc));
    this.log('push_revoked', registration, { reason });
  }

  private now(): string {
    return this.deps.clock.now().toISOString();
  }

  private log(
    event: string,
    registration: PushRegistration,
    fields: Readonly<Record<string, unknown>>,
  ): void {
    this.deps.log?.(event, { tokenFingerprint: registration.tokenFingerprint, ...fields });
  }
}

/** DSR erasure of a subject's push registrations and attempts (also used by L1). */
export async function erasePushSubject(
  store: PushStore,
  userId: string,
  limit = 200,
): Promise<number> {
  const registrations = await store.subjectRegistrationIds(userId, limit);
  const attempts = await store.subjectAttemptIds(userId, limit);
  await store.deleteRegistrations(registrations);
  await store.deleteAttempts(attempts);
  return registrations.length + attempts.length;
}
