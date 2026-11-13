import type { Firestore } from 'firebase-admin/firestore';

import {
  readFindPeopleConsent,
  SyntheticAgeAttestationPolicy,
} from '../../identity_publisher/infrastructure/find_people_privacy_authority.js';
import { findPeoplePolicy } from '../../../shared/find_people_policy.js';
import { safetyRestricted } from '../../../shared/safety_instruction.js';
import { publisherUser, relationEffects } from '../../../shared/safety_visibility.js';
import type {
  FindPeopleConsentState,
  FindPeoplePrivacyPort,
} from '../application/ports/find_people_privacy_port.js';
import { isPubliclyVisible } from '../domain/publication_pointer.js';
import { FirestoreContentRepository } from './firestore_content_repository.js';

/**
 * D3.7 §6 Emulator adapter of the Find People privacy port over its owners:
 * BCK-06 consent and the synthetic 18+ attestation (Identity), K2 relations
 * and T&S holds. It only reads; every answer is fresh, so a revoke, expiry,
 * block or sanction removes the object from the very next response, whatever
 * snapshot or cursor the caller holds. Any read failure is a refusal.
 */
export class FirestoreFindPeoplePrivacy implements FindPeoplePrivacyPort {
  readonly #age: SyntheticAgeAttestationPolicy;

  constructor(private readonly db: Firestore) {
    this.#age = new SyntheticAgeAttestationPolicy(db);
  }

  async isAdult(input: {
    readonly userId: string;
    readonly marketId: string;
    readonly nowUtc: string;
  }): Promise<boolean> {
    const decision = await this.#age.evaluate({
      marketId: input.marketId as never,
      surfaceId: findPeoplePolicy.ageSurfaceId,
      purposeId: findPeoplePolicy.consentPurposeId,
      subjectUserId: input.userId,
      nowUtc: input.nowUtc,
    });
    return decision.eligible;
  }

  consent(input: {
    readonly contentId: string;
    readonly userId: string;
    readonly nowUtc: string;
  }): Promise<FindPeopleConsentState> {
    return readFindPeopleConsent(this.db, input);
  }

  async publicReadAllowed(input: {
    readonly viewerUserId: string;
    readonly contentId: string;
    readonly publisherRef: { readonly type: string; readonly id: string };
    readonly hostUserId: string | null;
    readonly meetingEndUtc: string | null;
    readonly nowUtc: string;
  }): Promise<boolean> {
    const { hostUserId, meetingEndUtc, nowUtc } = input;
    if (hostUserId === null || meetingEndUtc === null || input.viewerUserId === '') return false;
    // FP-OD-03: the request expires at its meeting end.
    if (Date.parse(meetingEndUtc) <= Date.parse(nowUtc)) return false;
    const consent = await this.consent({ contentId: input.contentId, userId: hostUserId, nowUtc });
    if (consent.state !== 'active') return false;
    const marketId = findPeoplePolicy.marketId;
    if (!(await this.isAdult({ userId: hostUserId, marketId, nowUtc }))) return false;
    if (!(await this.isAdult({ userId: input.viewerUserId, marketId, nowUtc }))) return false;
    const owner = await publisherUser(this.db, input.publisherRef);
    const people = [...new Set([hostUserId, ...(owner === null ? [] : [owner])])];
    const now = new Date(nowUtc);
    for (const person of people) {
      if (await safetyRestricted(this.db, 'catalog', person, now, input.contentId)) return false;
      if (person === input.viewerUserId) continue;
      // K2 (owner policy 2026-10-15): block either way or the viewer's mute hides it everywhere.
      const effects = await relationEffects(this.db, input.viewerUserId, person);
      if (effects.blocked || effects.muted) return false;
    }
    return true;
  }

  /**
   * The Catalog gate for one listed Find People item: Content's own pointer
   * is read fresh first, so an owner hide, unpublish or moderation hold wins
   * even before the Catalog received the effect.
   */
  async catalogItemVisible(input: {
    readonly viewerUserId: string | undefined;
    readonly contentId: string;
    readonly publishedRevisionId: string;
    readonly publisherRef: { readonly type: string; readonly id: string };
    readonly hostUserId: string | null;
    readonly meetingEndUtc: string | null;
    readonly nowUtc: string;
  }): Promise<boolean> {
    if (input.viewerUserId === undefined) return false;
    const pointer = await new FirestoreContentRepository(this.db).transact((tx) =>
      tx.pointer(input.contentId),
    );
    if (
      !isPubliclyVisible(pointer) ||
      pointer?.currentPublishedRevisionId !== input.publishedRevisionId
    )
      return false;
    return this.publicReadAllowed({ ...input, viewerUserId: input.viewerUserId });
  }
}
