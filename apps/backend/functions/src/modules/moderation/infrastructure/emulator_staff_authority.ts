import type { Firestore } from 'firebase-admin/firestore';

import { assertContentEmulatorContext } from '../../content/infrastructure/firestore_content_repository.js';
import type { IdentityAuthorityRepository } from '../../identity_publisher/domain/repositories.js';
import { assertCurrentSession } from '../../identity_publisher/domain/session.js';
import type { StaffAuthorityPort, StaffAuthorityResult } from '../application/ports.js';
import { moderationCollections } from './firestore_moderation_repository.js';

export const staffAuthoritySource = 'test-only-emulator-stand-bootstrap';

/**
 * TEST-ONLY staff authority for the local stand. It is not production IAM and
 * not a general Admin: a registry of real Identity `userId` values, written only
 * by the stand bootstrap and readable only inside the verified `demo-recharge`
 * loopback Emulator context (the constructor refuses any other). A user without
 * an entry has no staff authority; a missing entry is a refusal, and a user
 * label, Firebase UID or client claim is never consulted.
 */
export class EmulatorStaffAuthority implements StaffAuthorityPort {
  constructor(
    private readonly firestore: Firestore,
    private readonly identity: IdentityAuthorityRepository,
    environment: NodeJS.ProcessEnv = process.env,
  ) {
    assertContentEmulatorContext(firestore, environment);
  }

  /**
   * Bootstrap only: called by the stand seed, never by a service command or a
   * mobile client. Idempotent for the same user; it never rewrites an entry.
   */
  async grant(userId: string, grantedAtUtc: string): Promise<void> {
    const reference = this.firestore.collection(moderationCollections.staffAuthority).doc(userId);
    try {
      await reference.create({
        userId,
        scope: 'moderation',
        source: staffAuthoritySource,
        grantedAtUtc,
      });
    } catch (error) {
      if ((error as { code?: unknown }).code !== 6) throw error; // ALREADY_EXISTS
    }
  }

  async evaluate(request: {
    readonly actor: { readonly userId: string; readonly sessionId: string };
    readonly nowUtc: string;
  }): Promise<StaffAuthorityResult> {
    const sessionValid = await this.identity.transact(async (transaction) => {
      const account = await transaction.account(request.actor.userId);
      const session = await transaction.session(request.actor.sessionId);
      if (account === null || session === null) return false;
      try {
        assertCurrentSession(session, account, request.nowUtc);
      } catch {
        return false;
      }
      return true;
    });
    if (!sessionValid) return { allowed: false, reason: 'session_invalid' };
    const entry = await this.firestore
      .collection(moderationCollections.staffAuthority)
      .doc(request.actor.userId)
      .get();
    if (
      !entry.exists ||
      entry.get('userId') !== request.actor.userId ||
      entry.get('scope') !== 'moderation' ||
      entry.get('source') !== staffAuthoritySource
    )
      return { allowed: false, reason: 'staff_denied' };
    return { allowed: true };
  }
}
