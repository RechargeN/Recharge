import type { Firestore } from 'firebase-admin/firestore';
import {
  bookingAccessCapability,
  type BookingAccessAuthority,
  type BookingAccessDecision,
  type BookingAccessHint,
} from '../shared/booking_access_authority.js';

export const bookingIdentityCollections = Object.freeze({
  accounts: 'identityAccounts',
  sessions: 'identitySessions',
  accessSnapshots: 'identityAccessSnapshots',
});

export class FirestoreBookingAccessAuthority implements BookingAccessAuthority {
  constructor(private readonly firestore: Firestore) {}

  async authorize(hint: BookingAccessHint, now: Date): Promise<BookingAccessDecision> {
    const [accountSnapshot, sessionSnapshot, accessSnapshot] = await this.firestore.getAll(
      this.firestore.collection(bookingIdentityCollections.accounts).doc(hint.actorId),
      this.firestore.collection(bookingIdentityCollections.sessions).doc(hint.sessionId),
      this.firestore.collection(bookingIdentityCollections.accessSnapshots).doc(hint.sessionId),
    );
    if (
      accountSnapshot === undefined ||
      sessionSnapshot === undefined ||
      accessSnapshot === undefined
    ) {
      throw new Error('firestore_snapshot_count_mismatch');
    }
    const account = accountSnapshot.data();
    const session = sessionSnapshot.data();
    const access = accessSnapshot.data();
    if (!isRecord(account) || account.status !== 'active') {
      return { allowed: false, reason: 'account_inactive' };
    }
    if (
      !isRecord(session) ||
      session.userId !== hint.actorId ||
      session.status !== 'active' ||
      !validInstant(session.issuedAtUtc) ||
      !validInstant(account.revokeAllBeforeUtc) ||
      Date.parse(String(session.issuedAtUtc)) <= Date.parse(String(account.revokeAllBeforeUtc))
    ) {
      return { allowed: false, reason: 'session_revoked' };
    }
    if (
      !isRecord(access) ||
      access.userId !== hint.actorId ||
      access.sessionId !== hint.sessionId ||
      access.revision !== hint.accessSnapshotRevision ||
      access.accountRevision !== account.revision ||
      access.sessionRevision !== session.revision ||
      access.authzRevision !== session.authzRevision ||
      !validInstant(access.expiresAtUtc) ||
      now.getTime() > Date.parse(String(access.expiresAtUtc))
    ) {
      return { allowed: false, reason: 'snapshot_stale' };
    }
    if (
      !Array.isArray(access.capabilityIds) ||
      !access.capabilityIds.includes(bookingAccessCapability)
    ) {
      return { allowed: false, reason: 'capability_denied' };
    }
    return { allowed: true };
  }
}

function isRecord(value: unknown): value is Readonly<Record<string, unknown>> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function validInstant(value: unknown): boolean {
  return typeof value === 'string' && Number.isFinite(Date.parse(value));
}
