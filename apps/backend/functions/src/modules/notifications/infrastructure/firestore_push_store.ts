import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';

import { identityAuthorityCollections } from '../../identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import type { PushSessionPort, PushStore } from '../application/push_dispatcher.js';
import type { PushAttempt, PushRegistration } from '../domain/push.js';

/**
 * N3c (2026-11-13): push state, server-only (Rules deny). Queries use only
 * equality filters and one single-field range, so no composite index is needed.
 */
export const pushCollections = Object.freeze({
  registrations: 'notificationPushRegistrations',
  attempts: 'notificationPushAttempts',
});

function attemptFrom(data: DocumentData): PushAttempt {
  const expiresAt = data.expiresAt as unknown;
  return {
    ...(data as PushAttempt),
    expiresAt: expiresAt instanceof Timestamp ? expiresAt.toDate() : (expiresAt as Date),
  };
}

export class FirestorePushStore implements PushStore {
  constructor(private readonly firestore: Firestore) {}

  private registrations() {
    return this.firestore.collection(pushCollections.registrations);
  }

  private attempts() {
    return this.firestore.collection(pushCollections.attempts);
  }

  async registration(installationId: string): Promise<PushRegistration | undefined> {
    const snapshot = await this.registrations().doc(installationId).get();
    return snapshot.exists ? (snapshot.data() as PushRegistration) : undefined;
  }

  async activeRegistrationsForUser(userId: string): Promise<readonly PushRegistration[]> {
    const snapshot = await this.registrations()
      .where('userId', '==', userId)
      .where('state', '==', 'active')
      .limit(20)
      .get();
    return snapshot.docs.map((doc) => doc.data() as PushRegistration);
  }

  async activeRegistrationsForToken(
    tokenFingerprint: string,
  ): Promise<readonly PushRegistration[]> {
    const snapshot = await this.registrations()
      .where('tokenFingerprint', '==', tokenFingerprint)
      .where('state', '==', 'active')
      .limit(20)
      .get();
    return snapshot.docs.map((doc) => doc.data() as PushRegistration);
  }

  async putRegistration(registration: PushRegistration): Promise<void> {
    await this.registrations().doc(registration.installationId).set(registration);
  }

  async createAttempt(attempt: PushAttempt): Promise<boolean> {
    try {
      await this.attempts().doc(attempt.attemptId).create(attempt);
      return true;
    } catch (error) {
      // ALREADY_EXISTS: another worker or a replay claimed this push.
      if ((error as { code?: unknown }).code === 6) return false;
      throw error;
    }
  }

  async putAttempt(attempt: PushAttempt): Promise<void> {
    await this.attempts().doc(attempt.attemptId).set(attempt);
  }

  async attempt(attemptId: string): Promise<PushAttempt | undefined> {
    const snapshot = await this.attempts().doc(attemptId).get();
    return snapshot.exists ? attemptFrom(snapshot.data()!) : undefined;
  }

  async sentCountForUserOnDay(userId: string, dayKey: string): Promise<number> {
    const snapshot = await this.attempts()
      .where('userId', '==', userId)
      .where('dayKey', '==', dayKey)
      .where('state', '==', 'sent')
      .count()
      .get();
    return snapshot.data().count;
  }

  async dueAttempts(nowUtc: string, limit: number): Promise<readonly PushAttempt[]> {
    // Only scheduled retries carry a next attempt time.
    const snapshot = await this.attempts()
      .where('nextAttemptAtUtc', '<=', nowUtc)
      .orderBy('nextAttemptAtUtc')
      .limit(limit)
      .get();
    return snapshot.docs
      .map((doc) => attemptFrom(doc.data()))
      .filter((attempt) => attempt.state === 'retry_scheduled');
  }

  async staleRegistrations(
    lastSeenBeforeUtc: string,
    limit: number,
  ): Promise<readonly PushRegistration[]> {
    const snapshot = await this.registrations()
      .where('lastSeenAtUtc', '<', lastSeenBeforeUtc)
      .orderBy('lastSeenAtUtc')
      .limit(limit)
      .get();
    return snapshot.docs
      .map((doc) => doc.data() as PushRegistration)
      .filter((registration) => registration.state === 'active');
  }

  async subjectRegistrationIds(userId: string, limit: number): Promise<readonly string[]> {
    const snapshot = await this.registrations().where('userId', '==', userId).limit(limit).get();
    return snapshot.docs.map((doc) => doc.id);
  }

  async subjectAttemptIds(userId: string, limit: number): Promise<readonly string[]> {
    const snapshot = await this.attempts().where('userId', '==', userId).limit(limit).get();
    return snapshot.docs.map((doc) => doc.id);
  }

  async deleteRegistrations(installationIds: readonly string[]): Promise<void> {
    if (installationIds.length === 0) return;
    const batch = this.firestore.batch();
    for (const id of installationIds) batch.delete(this.registrations().doc(id));
    await batch.commit();
  }

  async deleteAttempts(attemptIds: readonly string[]): Promise<void> {
    if (attemptIds.length === 0) return;
    const batch = this.firestore.batch();
    for (const id of attemptIds) batch.delete(this.attempts().doc(id));
    await batch.commit();
  }
}

/** Identity, read-only: an installation keeps push only while its Session is active. */
export class FirestorePushSessions implements PushSessionPort {
  constructor(private readonly firestore: Firestore) {}

  async activeSession(userId: string, installationId: string, nowUtc: string): Promise<boolean> {
    const snapshot = await this.firestore
      .collection(identityAuthorityCollections.sessions)
      .where('userId', '==', userId)
      .where('installationId', '==', installationId)
      .where('status', '==', 'active')
      .limit(5)
      .get();
    return snapshot.docs.some((doc) => {
      const idle = (doc.data() as { idleExpiresAtUtc?: unknown }).idleExpiresAtUtc;
      return typeof idle === 'string' && Date.parse(idle) > Date.parse(nowUtc);
    });
  }
}
