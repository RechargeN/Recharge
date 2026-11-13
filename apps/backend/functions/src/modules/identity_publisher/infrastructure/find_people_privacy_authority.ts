import { createHash } from 'node:crypto';
import type { Firestore, Transaction } from 'firebase-admin/firestore';

import { FirestoreBookingAccessAuthority } from '../../../booking/firestore_booking_access_authority.js';
import { FirestoreFeatureFlagGate } from '../../../platform/config/firestore_feature_flag_gate.js';
import type {
  AgePolicyDecision,
  AgePolicyPort,
  AgePolicyRequest,
} from '../../../security/age_policy_port.js';
import type { BookingAccessHint } from '../../../shared/booking_access_authority.js';
import { identityFlagIds } from '../../../shared/feature_flags.js';
import { consentExpiresAt, findPeoplePolicy } from '../../../shared/find_people_policy.js';
import type { ServerClock } from '../../../shared/server_clock.js';
import {
  assertContentEmulatorContext,
  contentCollections,
} from '../../content/infrastructure/firestore_content_repository.js';

/**
 * D3.7 Identity-owned records (BCK-06). Server-only: Rules deny every client.
 * `identityAgeAttestations` is written only by server fixtures (FP-OD-04).
 */
export const findPeopleIdentityCollections = Object.freeze({
  consents: 'identityFindPeopleConsents',
  consentReceipts: 'identityFindPeopleConsentReceipts',
  ageAttestations: 'identityAgeAttestations',
});

export interface AgeAttestationRecord {
  readonly schemaVersion: 1;
  readonly userId: string;
  readonly marketId: string;
  readonly ageBand: 'adult_18_plus' | 'minor';
  readonly source: 'synthetic_emulator_fixture';
  readonly policyRevision: string;
  readonly attestedAtUtc: string;
  readonly revokedAtUtc: string | null;
}

/**
 * FP-OD-04: a synthetic server attestation stands in for an age authority in
 * the Emulator only. It answers for the Find People surface and nothing else;
 * a client claim, a date of birth or a Create checkbox is never read. The
 * production composition keeps `LocalUnavailableAgePolicyPort`.
 */
export class SyntheticAgeAttestationPolicy implements AgePolicyPort {
  constructor(private readonly db: Firestore) {
    assertContentEmulatorContext(db);
  }

  async evaluate(request: AgePolicyRequest): Promise<AgePolicyDecision> {
    if (
      request.surfaceId !== findPeoplePolicy.ageSurfaceId ||
      request.marketId !== findPeoplePolicy.marketId
    )
      return { eligible: false, reason: 'policy_unavailable' };
    const userId = request.subjectUserId;
    if (typeof userId !== 'string' || userId.length === 0)
      return { eligible: false, reason: 'evidence_missing' };
    const data = (
      await this.db.collection(findPeopleIdentityCollections.ageAttestations).doc(userId).get()
    ).data() as Partial<AgeAttestationRecord> | undefined;
    if (
      data?.schemaVersion !== 1 ||
      data.userId !== userId ||
      data.source !== 'synthetic_emulator_fixture' ||
      data.policyRevision !== findPeoplePolicy.agePolicyRevision ||
      data.marketId !== request.marketId ||
      data.revokedAtUtc !== null
    )
      return { eligible: false, reason: 'evidence_missing' };
    if (data.ageBand !== 'adult_18_plus') return { eligible: false, reason: 'ineligible' };
    return { eligible: true, policyRevision: findPeoplePolicy.agePolicyRevision };
  }
}

/** The fresh state of one consent as BCK-06 answers it (D3.7 §5.1). */
export type FindPeopleConsentState =
  | { readonly state: 'active'; readonly consentRevision: number; readonly expiresAtUtc: string }
  | { readonly state: 'missing' | 'revoked' | 'expired' | 'unavailable' };

export interface FindPeopleConsentRecord {
  readonly schemaVersion: 1;
  readonly contentId: string;
  readonly subjectUserId: string;
  readonly purposeId: string;
  readonly policyRevision: string;
  readonly state: 'active' | 'revoked';
  readonly revision: number;
  readonly grantedAtUtc: string;
  readonly expiresAtUtc: string;
  readonly revokedAtUtc: string | null;
  readonly updatedAtUtc: string;
}

export type FindPeopleConsentView = Omit<FindPeopleConsentRecord, 'state'> & {
  readonly state: 'active' | 'revoked' | 'expired';
};

export type FindPeopleConsentResult =
  | {
      readonly schemaVersion: 1;
      readonly kind: 'succeeded';
      readonly consent: FindPeopleConsentView | null;
    }
  | { readonly schemaVersion: 1; readonly kind: 'rejected'; readonly code: string };

const rejected = (code: string): FindPeopleConsentResult => ({
  schemaVersion: 1,
  kind: 'rejected',
  code,
});
const hash = (value: string) => createHash('sha256').update(value).digest('hex');
const idPattern = /^[A-Za-z0-9_-]{1,128}$/u;

export function consentDocumentId(contentId: string, userId: string): string {
  return `${contentId}:${userId}`;
}

function view(record: FindPeopleConsentRecord, nowUtc: string): FindPeopleConsentView {
  const expired =
    record.state === 'active' && Date.parse(record.expiresAtUtc) <= Date.parse(nowUtc);
  return { ...record, state: expired ? 'expired' : record.state };
}

function stateOf(data: unknown, nowUtc: string): FindPeopleConsentState {
  const record = data as Partial<FindPeopleConsentRecord> | undefined;
  if (record === undefined) return { state: 'missing' };
  if (
    record.schemaVersion !== 1 ||
    record.purposeId !== findPeoplePolicy.consentPurposeId ||
    record.policyRevision !== findPeoplePolicy.consentPolicyRevision ||
    typeof record.expiresAtUtc !== 'string' ||
    typeof record.revision !== 'number'
  )
    return { state: 'unavailable' };
  if (record.state === 'revoked') return { state: 'revoked' };
  if (record.state !== 'active') return { state: 'unavailable' };
  if (Date.parse(record.expiresAtUtc) <= Date.parse(nowUtc)) return { state: 'expired' };
  return { state: 'active', consentRevision: record.revision, expiresAtUtc: record.expiresAtUtc };
}

/** Fresh BCK-06 read of one consent (D3.7 §5.1); `missing` when never granted. */
export async function readFindPeopleConsent(
  db: Firestore,
  input: { readonly contentId: string; readonly userId: string; readonly nowUtc: string },
): Promise<FindPeopleConsentState> {
  const snapshot = await db
    .collection(findPeopleIdentityCollections.consents)
    .doc(consentDocumentId(input.contentId, input.userId))
    .get();
  return stateOf(snapshot.data(), input.nowUtc);
}

interface ConsentCommand {
  readonly commandType: 'grantFindPeopleConsent' | 'revokeFindPeopleConsent';
  readonly idempotencyKey: string;
  readonly contentId: string;
  readonly expectedRevision: number;
}

function exactKeys(value: Record<string, unknown>, keys: readonly string[]): boolean {
  return Object.keys(value).every((key) => keys.includes(key)) && keys.every((key) => key in value);
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

export function parseConsentCommand(raw: unknown): ConsentCommand | null {
  const value = record(raw);
  if (!value || !exactKeys(value, ['schemaVersion', 'commandType', 'idempotencyKey', 'payload']))
    return null;
  const payload = record(value.payload);
  if (
    value.schemaVersion !== 1 ||
    (value.commandType !== 'grantFindPeopleConsent' &&
      value.commandType !== 'revokeFindPeopleConsent') ||
    typeof value.idempotencyKey !== 'string' ||
    value.idempotencyKey.length < 8 ||
    value.idempotencyKey.length > 200 ||
    !payload ||
    !exactKeys(payload, ['contentId', 'expectedRevision']) ||
    typeof payload.contentId !== 'string' ||
    !idPattern.test(payload.contentId) ||
    !Number.isSafeInteger(payload.expectedRevision) ||
    (payload.expectedRevision as number) < 0
  )
    return null;
  return {
    commandType: value.commandType,
    idempotencyKey: value.idempotencyKey,
    contentId: payload.contentId,
    expectedRevision: payload.expectedRevision as number,
  };
}

/**
 * D3.7 §5.1: BCK-06 owner commands for Find People consent. The subject is
 * always the verified Session user; only the author of the exact Find People
 * draft can grant, and only while holding an adult attestation. Revoking is
 * always possible, also with the feature flag off: reducing exposure is never
 * blocked. Emulator-only persistence with CAS and idempotency receipts.
 */
export class FirestoreFindPeopleConsentService {
  constructor(
    private readonly db: Firestore,
    private readonly clock: ServerClock,
  ) {
    assertContentEmulatorContext(db);
  }

  private async actor(tx: Transaction, hint: BookingAccessHint): Promise<string | null> {
    try {
      const decision = await new FirestoreBookingAccessAuthority(this.db).authorizeTransaction(
        tx,
        hint,
        this.clock.now(),
      );
      return decision.allowed ? decision.userId : null;
    } catch (error) {
      if (error instanceof TypeError) return null;
      throw error;
    }
  }

  async command(hint: BookingAccessHint, raw: unknown): Promise<FindPeopleConsentResult> {
    const command = parseConsentCommand(raw);
    if (!command) return rejected('invalid_contract');
    return this.db.runTransaction(async (tx) => {
      const userId = await this.actor(tx, hint);
      if (!userId) return rejected('unauthenticated');
      return this.#apply(tx, userId, command);
    });
  }

  /**
   * The same owner command for a subject the server itself resolved (the
   * Emulator stand and tests, never a callable): no client can name a user.
   */
  async commandAs(userId: string, raw: unknown): Promise<FindPeopleConsentResult> {
    const command = parseConsentCommand(raw);
    if (!command) return rejected('invalid_contract');
    return this.db.runTransaction((tx) => this.#apply(tx, userId, command));
  }

  async #apply(
    tx: Transaction,
    userId: string,
    command: ConsentCommand,
  ): Promise<FindPeopleConsentResult> {
    const age = new SyntheticAgeAttestationPolicy(this.db);
    const nowUtc = this.clock.now().toISOString();
    const receiptRef = this.db
      .collection(findPeopleIdentityCollections.consentReceipts)
      .doc(`${userId}:${hash(`${command.commandType}:${command.idempotencyKey}`)}`);
    const semanticHash = hash(JSON.stringify([command.contentId, command.expectedRevision]));
    const receipt = (await tx.get(receiptRef)).data();
    if (receipt)
      return receipt.semanticHash === semanticHash
        ? (receipt.result as FindPeopleConsentResult)
        : rejected('idempotency_conflict');
    const consentRef = this.db
      .collection(findPeopleIdentityCollections.consents)
      .doc(consentDocumentId(command.contentId, userId));
    const existing = (await tx.get(consentRef)).data() as FindPeopleConsentRecord | undefined;
    const finish = (result: FindPeopleConsentResult) => {
      tx.create(receiptRef, {
        schemaVersion: 1,
        userId,
        semanticHash,
        result,
        recordedAtUtc: nowUtc,
      });
      return result;
    };
    const currentRevision = existing?.revision ?? 0;
    if (command.commandType === 'revokeFindPeopleConsent') {
      if (existing === undefined) return rejected('not_found');
      if (existing.state === 'revoked')
        return finish({ schemaVersion: 1, kind: 'succeeded', consent: view(existing, nowUtc) });
      if (currentRevision !== command.expectedRevision) return rejected('revision_conflict');
      const revoked: FindPeopleConsentRecord = {
        ...existing,
        state: 'revoked',
        revision: currentRevision + 1,
        revokedAtUtc: nowUtc,
        updatedAtUtc: nowUtc,
      };
      tx.set(consentRef, revoked);
      return finish({ schemaVersion: 1, kind: 'succeeded', consent: view(revoked, nowUtc) });
    }
    const flags = new FirestoreFeatureFlagGate(this.db, 'local', 'LV');
    if (!(await flags.isEnabled(identityFlagIds.findPeopleConsent, tx)))
      return rejected('feature_disabled');
    if (currentRevision !== command.expectedRevision) return rejected('revision_conflict');
    const drafts = await tx.get(
      this.db
        .collection(contentCollections.drafts)
        .where('contentId', '==', command.contentId)
        .limit(2),
    );
    const draft = drafts.size === 1 ? drafts.docs[0]?.data() : undefined;
    // Only the author of exactly this Find People draft can consent to it.
    if (draft?.typeId !== 'find_people' || draft.createdByUserId !== userId)
      return rejected('not_found');
    const adult = await age.evaluate({
      marketId: findPeoplePolicy.marketId,
      surfaceId: findPeoplePolicy.ageSurfaceId,
      purposeId: findPeoplePolicy.consentPurposeId,
      subjectUserId: userId,
      nowUtc,
    });
    if (!adult.eligible) return rejected('age_eligibility_required');
    if (existing !== undefined && stateOf(existing, nowUtc).state === 'active')
      return finish({ schemaVersion: 1, kind: 'succeeded', consent: view(existing, nowUtc) });
    const granted: FindPeopleConsentRecord = {
      schemaVersion: 1,
      contentId: command.contentId,
      subjectUserId: userId,
      purposeId: findPeoplePolicy.consentPurposeId,
      policyRevision: findPeoplePolicy.consentPolicyRevision,
      state: 'active',
      revision: currentRevision + 1,
      grantedAtUtc: nowUtc,
      expiresAtUtc: consentExpiresAt(nowUtc),
      revokedAtUtc: null,
      updatedAtUtc: nowUtc,
    };
    tx.set(consentRef, granted);
    return finish({ schemaVersion: 1, kind: 'succeeded', consent: view(granted, nowUtc) });
  }

  /** The caller's own consent for one publication; `null` when never granted. */
  async query(hint: BookingAccessHint, raw: unknown): Promise<FindPeopleConsentResult> {
    const value = record(raw);
    const payload = record(value?.payload);
    if (
      !value ||
      !exactKeys(value, ['schemaVersion', 'queryType', 'payload']) ||
      value.schemaVersion !== 1 ||
      value.queryType !== 'getMyFindPeopleConsent' ||
      !payload ||
      !exactKeys(payload, ['contentId']) ||
      typeof payload.contentId !== 'string' ||
      !idPattern.test(payload.contentId)
    )
      return rejected('invalid_contract');
    const contentId = payload.contentId;
    return this.db.runTransaction(async (tx) => {
      const userId = await this.actor(tx, hint);
      if (!userId) return rejected('unauthenticated');
      const data = (
        await tx.get(
          this.db
            .collection(findPeopleIdentityCollections.consents)
            .doc(consentDocumentId(contentId, userId)),
        )
      ).data() as FindPeopleConsentRecord | undefined;
      return {
        schemaVersion: 1,
        kind: 'succeeded',
        consent: data === undefined ? null : view(data, this.clock.now().toISOString()),
      };
    });
  }
}
