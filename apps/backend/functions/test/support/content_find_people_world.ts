import { randomUUID } from 'node:crypto';
import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

import { readContentJson } from '../../src/contracts/content_schema_registry.js';
import type { ContentBody } from '../../src/contracts/content_v1.js';
import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { findPeopleIdentityCollections } from '../../src/modules/identity_publisher/infrastructure/find_people_privacy_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../src/platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../src/platform/config/firestore_feature_flag_gate.js';
import { findPeoplePolicy } from '../../src/shared/find_people_policy.js';
import type { EntityId } from '../../src/shared/ids.js';
import {
  callBookingFunction,
  createFirebaseActor,
  registerSessionContext,
} from './booking_emulator.js';
import type { PublishingActor } from './content_event_world.js';
import { createSessionWorld } from './content_session_world.js';

export type Answer = { readonly kind: string; readonly code?: string; readonly data?: unknown };

export interface SignedActor extends PublishingActor {
  readonly idToken: string;
}

/** The shared D3.7 wire fixture body, bound to the server's author. */
export async function findPeopleBody(
  authorUserId: string,
  change: (body: Record<string, unknown>) => void = () => undefined,
): Promise<ContentBody> {
  const fixture = (await readContentJson('fixtures/find_people_create_compat.json')) as {
    cases: { name: string; body: ContentBody }[];
  };
  const body = structuredClone(fixture.cases.find((item) => item.name === 'valid')!.body) as {
    findPeople: { hosts: { responsibleHostUserIds: string[] } };
  } & Record<string, unknown>;
  body.findPeople.hosts.responsibleHostUserIds = [authorUserId];
  change(body);
  return body;
}

/**
 * D3.7 Emulator world: the Session world's verified Creator (author), Page and
 * staff, Content with Find People enabled, plus synthetic viewers created
 * through the Identity owner. Age attestations are server fixtures written
 * with the Admin SDK only (FP-OD-04); everything else goes through owner
 * services or the real callables. Every fixture is bound to this run's scope.
 */
export function createFindPeopleWorld(firestore: Firestore, label: string) {
  const base = createSessionWorld(firestore, label, {
    enabledTypes: new Set(['find_people'] as const),
  });
  const extraOwned: string[] = [];
  const firebaseUids: string[] = [];

  async function viewer(name: string): Promise<SignedActor> {
    const repository = new FirestoreIdentityAuthorityRepository(firestore);
    const nowUtc = new Date().toISOString();
    const authority = new IdentityPublisherAuthority({
      repository,
      providerVerifier: new SyntheticProviderIdentityVerifier(),
      verificationDecisions: new LocalVerificationDecisionAdapter(new Set()),
      pagePolicy: new LocalPageCreationPolicy(true, 2),
    });
    const userId = randomUUID();
    await authority.accounts.ensureAccount({
      proof: {
        provider: 'google',
        providerTenant: 'demo-recharge-emulator',
        proof: `local-test:google:${base.scope}-${name}`,
      },
      proposedUserId: userId,
      proposedIdentityId: randomUUID(),
      nowUtc,
      accountCreationEnabled: true,
    });
    const sessionId = randomUUID();
    const firebaseUid = `${base.scope}-${userId}`;
    const installationId = `${base.scope}-installation-${userId}`;
    const issued = await authority.sessions.issue({
      userId,
      sessionId,
      firebaseUid,
      installationId,
      issuedAtUtc: nowUtc,
      snapshotExpiresAtUtc: new Date(Date.now() + 3_600_000).toISOString(),
    });
    const idToken = await createFirebaseActor(firebaseUid);
    registerSessionContext(idToken, {
      sessionId,
      sessionHandle: issued.sessionHandle,
      installationId,
    });
    extraOwned.push(userId, sessionId);
    firebaseUids.push(firebaseUid);
    return {
      actor: { userId: userId as EntityId, sessionId: sessionId as EntityId },
      firebaseUid,
      installationId,
      sessionHandle: issued.sessionHandle,
      idToken,
    };
  }

  /** FP-OD-04: a synthetic server attestation; `null` removes it. */
  async function attest(userId: string, band: 'adult_18_plus' | 'minor' | null) {
    const ref = firestore.collection(findPeopleIdentityCollections.ageAttestations).doc(userId);
    if (band === null) return void (await ref.delete());
    await ref.set({
      schemaVersion: 1,
      userId,
      marketId: 'LV',
      ageBand: band,
      source: 'synthetic_emulator_fixture',
      policyRevision: findPeoplePolicy.agePolicyRevision,
      attestedAtUtc: new Date().toISOString(),
      revokedAtUtc: null,
    });
  }

  let sequence = 0;
  const key = (name: string) => `${base.scope}-${name}-${(sequence += 1)}`;
  async function call(
    name: string,
    actor: { readonly idToken: string },
    data: Record<string, unknown>,
  ): Promise<Answer> {
    const response = await callBookingFunction(name, data, actor.idToken);
    return response.body.result as Answer;
  }
  /** Consent and Discover answer flat (no `data` envelope): the whole answer is the data. */
  const flat = async (
    name: string,
    actor: { readonly idToken: string },
    payload: Record<string, unknown>,
  ) => {
    const answer = await call(name, actor, payload);
    return { ...answer, data: answer };
  };
  const content = (
    actor: { idToken: string },
    commandType: string,
    payload: unknown,
    idem?: string,
  ) =>
    call('contentCommandV1', actor, {
      schemaVersion: 1,
      commandType,
      idempotencyKey: idem ?? key(commandType),
      payload,
    });
  const contentQuery = (actor: { idToken: string }, queryType: string, payload: unknown) =>
    call('contentQueryV1', actor, { schemaVersion: 1, queryType, payload });
  const consent = (
    actor: { idToken: string },
    commandType: 'grantFindPeopleConsent' | 'revokeFindPeopleConsent',
    contentId: string,
    expectedRevision: number,
    idem?: string,
  ) =>
    flat('findPeopleConsentCommandV1', actor, {
      schemaVersion: 1,
      commandType,
      idempotencyKey: idem ?? key(commandType),
      payload: { contentId, expectedRevision },
    });
  /** Discover nests its body under `page`, `map` or `details`. */
  const discover = async (actor: { idToken: string }, queryType: string, payload: unknown) => {
    const answer = await call('discoverQueryV1', actor, {
      schemaVersion: 1,
      requestId: key('discover'),
      queryType,
      payload,
    });
    const body = answer as Record<string, unknown>;
    return { ...answer, data: body.page ?? body.map ?? body.details ?? answer };
  };

  async function cleanup() {
    for (const uid of firebaseUids) {
      try {
        await getAuth().deleteUser(uid);
      } catch (error) {
        if ((error as { code?: string }).code !== 'auth/user-not-found') throw error;
      }
    }
    for (const id of extraOwned)
      await firestore.collection(findPeopleIdentityCollections.ageAttestations).doc(id).delete();
    const { creator } = await base.actors;
    await firestore
      .collection(findPeopleIdentityCollections.ageAttestations)
      .doc(creator.actor.userId)
      .delete();
    await base.cleanup(extraOwned);
  }

  return { ...base, viewer, attest, key, call, content, contentQuery, consent, discover, cleanup };
}

/**
 * Local flags this suite turns on, restored exactly afterwards: the revision-1
 * document and the active pointer of each flag are saved first.
 */
export function flagFixture(firestore: Firestore, capabilityIds: readonly string[]) {
  const refs = (capabilityId: string) => {
    const flagKey = featureFlagKey('local', 'LV', capabilityId);
    return {
      flagKey,
      revision: firestore
        .collection(featureFlagRevisionCollection)
        .doc(featureFlagRevisionDocumentId(flagKey, 1)),
      pointer: firestore.collection(featureFlagPointerCollection).doc(flagKey),
    };
  };
  const saved = new Map<
    string,
    { revision: DocumentData | undefined; pointer: DocumentData | undefined }
  >();
  return {
    async save() {
      for (const id of capabilityIds) {
        const { revision, pointer } = refs(id);
        saved.set(id, {
          revision: (await revision.get()).data(),
          pointer: (await pointer.get()).data(),
        });
      }
    },
    async set(capabilityId: string, enabled: boolean) {
      const { flagKey, revision, pointer } = refs(capabilityId);
      await revision.set({
        schemaVersion: 1,
        revision: 1,
        environmentId: 'local',
        marketId: 'LV',
        capabilityId,
        enabled,
        createdAtUtc: '2026-10-19T00:00:00.000Z',
      });
      await pointer.set({ key: flagKey, activeRevision: 1, pointerRevision: 1 });
    },
    async restore() {
      for (const id of capabilityIds) {
        const { revision, pointer } = refs(id);
        const before = saved.get(id);
        if (before?.revision === undefined) await revision.delete();
        else await revision.set(before.revision);
        if (before?.pointer === undefined) await pointer.delete();
        else await pointer.set(before.pointer);
      }
    },
  };
}
