import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { hashSessionHandle } from '../modules/identity_publisher/domain/session.js';
import type {
  bookingAccessCapability,
  BookingAccessAuthority,
  BookingAccessDecision,
  BookingAccessHint,
} from '../shared/booking_access_authority.js';

export const bookingIdentityCollections = Object.freeze({
  accounts: 'identityAccounts',
  sessions: 'identitySessions',
  accessSnapshots: 'identityAccessSnapshots',
});

export class FirestoreBookingAccessAuthority implements BookingAccessAuthority {
  constructor(private readonly firestore: Firestore) {}

  async authorize(
    hint: BookingAccessHint,
    now: Date,
    requiredCapability?: typeof bookingAccessCapability,
  ): Promise<BookingAccessDecision> {
    return this.authorizeWithReader(this.firestore, hint, now, requiredCapability);
  }

  authorizeTransaction(
    transaction: Transaction,
    hint: BookingAccessHint,
    now: Date,
    requiredCapability: typeof bookingAccessCapability,
  ): Promise<BookingAccessDecision> {
    return this.authorizeWithReader(transaction, hint, now, requiredCapability);
  }

  private async authorizeWithReader(
    reader: Pick<Firestore, 'getAll'> | Pick<Transaction, 'getAll'>,
    hint: BookingAccessHint,
    now: Date,
    requiredCapability?: typeof bookingAccessCapability,
  ): Promise<BookingAccessDecision> {
    const [sessionSnapshot, accessSnapshot] = await reader.getAll(
      this.firestore.collection(bookingIdentityCollections.sessions).doc(hint.sessionId),
      this.firestore.collection(bookingIdentityCollections.accessSnapshots).doc(hint.sessionId),
    );
    if (sessionSnapshot === undefined || accessSnapshot === undefined) {
      throw new Error('firestore_snapshot_count_mismatch');
    }
    const session = sessionSnapshot.data();
    const access = accessSnapshot.data();
    if (
      !isRecord(session) ||
      typeof session.userId !== 'string' ||
      session.firebaseUid !== hint.firebaseUid ||
      session.installationId !== hint.installationId ||
      session.handleHash !== hashSessionHandle(hint.sessionHandle) ||
      session.status !== 'active'
    ) {
      return { allowed: false, reason: 'session_revoked' };
    }
    const [accountSnapshot] = await reader.getAll(
      this.firestore.collection(bookingIdentityCollections.accounts).doc(session.userId),
    );
    if (accountSnapshot === undefined) throw new Error('firestore_snapshot_count_mismatch');
    const account = accountSnapshot.data();
    if (!isRecord(account) || account.status !== 'active') {
      return { allowed: false, reason: 'account_inactive' };
    }
    if (
      !Number.isSafeInteger(session.authzRevision) ||
      !Number.isSafeInteger(account.securityRevision) ||
      !Number.isSafeInteger(account.revokeBeforeSecurityRevision) ||
      Number(session.authzRevision) < Number(account.revokeBeforeSecurityRevision) ||
      session.authzRevision !== account.securityRevision
    ) {
      return { allowed: false, reason: 'session_revoked' };
    }
    if (
      !isRecord(access) ||
      access.userId !== session.userId ||
      access.sessionId !== hint.sessionId ||
      access.accountRevision !== account.revision ||
      access.sessionRevision !== session.revision ||
      access.authzRevision !== session.authzRevision ||
      !validInstant(access.expiresAtUtc) ||
      now.getTime() > Date.parse(String(access.expiresAtUtc))
    ) {
      return { allowed: false, reason: 'snapshot_stale' };
    }
    if (
      requiredCapability !== undefined &&
      (!Array.isArray(access.capabilityIds) || !access.capabilityIds.includes(requiredCapability))
    ) {
      return { allowed: false, reason: 'capability_denied' };
    }
    return { allowed: true, userId: session.userId };
  }
}

function isRecord(value: unknown): value is Readonly<Record<string, unknown>> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function validInstant(value: unknown): boolean {
  return typeof value === 'string' && Number.isFinite(Date.parse(value));
}
