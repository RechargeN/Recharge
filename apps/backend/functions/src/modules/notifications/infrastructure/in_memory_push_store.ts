import type { PushStore } from '../application/push_dispatcher.js';
import type { PushAttempt, PushRegistration } from '../domain/push.js';

/** N3c: local and test push state, same contract as the Firestore store. */
export class InMemoryPushStore implements PushStore {
  readonly registrations = new Map<string, PushRegistration>();
  readonly attempts = new Map<string, PushAttempt>();

  registration(installationId: string): Promise<PushRegistration | undefined> {
    return Promise.resolve(this.registrations.get(installationId));
  }

  activeRegistrationsForUser(userId: string): Promise<readonly PushRegistration[]> {
    return Promise.resolve(
      [...this.registrations.values()].filter((r) => r.userId === userId && r.state === 'active'),
    );
  }

  activeRegistrationsForToken(tokenFingerprint: string): Promise<readonly PushRegistration[]> {
    return Promise.resolve(
      [...this.registrations.values()].filter(
        (r) => r.tokenFingerprint === tokenFingerprint && r.state === 'active',
      ),
    );
  }

  putRegistration(registration: PushRegistration): Promise<void> {
    this.registrations.set(registration.installationId, registration);
    return Promise.resolve();
  }

  createAttempt(attempt: PushAttempt): Promise<boolean> {
    if (this.attempts.has(attempt.attemptId)) return Promise.resolve(false);
    this.attempts.set(attempt.attemptId, attempt);
    return Promise.resolve(true);
  }

  putAttempt(attempt: PushAttempt): Promise<void> {
    this.attempts.set(attempt.attemptId, attempt);
    return Promise.resolve();
  }

  attempt(attemptId: string): Promise<PushAttempt | undefined> {
    return Promise.resolve(this.attempts.get(attemptId));
  }

  sentCountForUserOnDay(userId: string, dayKey: string): Promise<number> {
    return Promise.resolve(
      [...this.attempts.values()].filter(
        (a) => a.userId === userId && a.dayKey === dayKey && a.state === 'sent',
      ).length,
    );
  }

  dueAttempts(nowUtc: string, limit: number): Promise<readonly PushAttempt[]> {
    return Promise.resolve(
      [...this.attempts.values()]
        .filter(
          (a) =>
            a.state === 'retry_scheduled' &&
            a.nextAttemptAtUtc !== null &&
            Date.parse(a.nextAttemptAtUtc) <= Date.parse(nowUtc),
        )
        .slice(0, limit),
    );
  }

  staleRegistrations(
    lastSeenBeforeUtc: string,
    limit: number,
  ): Promise<readonly PushRegistration[]> {
    return Promise.resolve(
      [...this.registrations.values()]
        .filter(
          (r) =>
            r.state === 'active' && Date.parse(r.lastSeenAtUtc) < Date.parse(lastSeenBeforeUtc),
        )
        .slice(0, limit),
    );
  }

  subjectRegistrationIds(userId: string, limit: number): Promise<readonly string[]> {
    return Promise.resolve(
      [...this.registrations.values()]
        .filter((r) => r.userId === userId)
        .map((r) => r.installationId)
        .slice(0, limit),
    );
  }

  subjectAttemptIds(userId: string, limit: number): Promise<readonly string[]> {
    return Promise.resolve(
      [...this.attempts.values()]
        .filter((a) => a.userId === userId)
        .map((a) => a.attemptId)
        .slice(0, limit),
    );
  }

  deleteRegistrations(installationIds: readonly string[]): Promise<void> {
    for (const id of installationIds) this.registrations.delete(id);
    return Promise.resolve();
  }

  deleteAttempts(attemptIds: readonly string[]): Promise<void> {
    for (const id of attemptIds) this.attempts.delete(id);
    return Promise.resolve();
  }
}
