import assert from 'node:assert/strict';
import { createHash, randomUUID } from 'node:crypto';
import type { Firestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

import { eventAuthoringComposition } from '../../src/content_entry.js';
import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import { createEmulatorMediaComposition } from '../../src/modules/media/infrastructure/emulator_media_composition.js';
import { EmulatorStaffAuthority } from '../../src/modules/moderation/infrastructure/emulator_staff_authority.js';
import type { EntityId } from '../../src/shared/ids.js';
import { standEventBody } from '../stand/stand_content.js';

const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);
const sha256 = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');

export interface EventOptions {
  readonly title: string;
  readonly date: string;
  /** Last edit of the body: registration, capacity, extra occurrences, venue. */
  readonly transform?: (body: Record<string, unknown>) => Record<string, unknown>;
}

/** A command answer kept raw so a test can assert a refusal by its code. */
export interface CommandAnswer {
  readonly stage: 'update' | 'submit' | 'publish' | 'activate';
  readonly kind: string;
  readonly code?: string;
}

function succeeded<T>(result: { kind: string; data?: unknown }, label: string): T {
  assert.equal(result.kind, 'succeeded', `${label}: ${JSON.stringify(result)}`);
  return (result as { data: T }).data;
}

/**
 * A real local publishing world for Emulator tests: a verified Creator with a
 * verified Page, a staff member in the C2 registry and two Sessions. Events go
 * through Content, Media and C2 moderation exactly like the stand; nothing is
 * written to Content storage directly. Every label is unique per run.
 */
export function createContentEventWorld(firestore: Firestore, label: string) {
  const media = createEmulatorMediaComposition({
    firestore,
    bucket: getStorage().bucket('demo-recharge.appspot.com') as never,
  });
  const content = eventAuthoringComposition(firestore, { media });
  const run = randomUUID().slice(0, 8);
  const subcategory = `sub-${label}-${run}`;
  let sequence = 0;
  const key = (name: string) => `${label}-${name}-${run}-${(sequence += 1)}`;

  const actors = (async () => {
    const repository = new FirestoreIdentityAuthorityRepository(firestore);
    const nowUtc = new Date().toISOString();
    const reviewer = randomUUID();
    const authority = new IdentityPublisherAuthority({
      repository,
      providerVerifier: new SyntheticProviderIdentityVerifier(),
      verificationDecisions: new LocalVerificationDecisionAdapter(new Set([reviewer])),
      pagePolicy: new LocalPageCreationPolicy(true, 2),
    });
    const creator = randomUUID();
    const staff = randomUUID();
    for (const [name, id] of [
      ['reviewer', reviewer],
      ['creator', creator],
      ['staff', staff],
    ] as const)
      await authority.accounts.ensureAccount({
        proof: {
          provider: 'google',
          providerTenant: 'demo-recharge-emulator',
          proof: `local-test:google:${label}-${run}-${name}`,
        },
        proposedUserId: id,
        proposedIdentityId: randomUUID(),
        nowUtc,
        accountCreationEnabled: true,
      });
    await authority.creatorVerification.submit({
      userId: creator,
      verificationId: randomUUID(),
      evidenceRefIds: [randomUUID()],
      nowUtc,
    });
    await authority.creatorVerification.decide({
      reviewerId: reviewer,
      userId: creator,
      status: 'verified',
      nowUtc,
    });
    const pageId = randomUUID();
    await authority.pages.create({
      userId: creator,
      pageId,
      membershipId: randomUUID(),
      marketId: 'LV',
      nowUtc,
    });
    await authority.pages.decidePage({
      reviewerId: reviewer,
      pageId,
      decision: 'verified',
      nowUtc,
    });
    await new EmulatorStaffAuthority(firestore, repository).grant(staff, nowUtc);
    const session = async (userId: string) => {
      const sessionId = randomUUID();
      await authority.sessions.issue({
        userId,
        sessionId,
        firebaseUid: `${label}-${run}-${userId}`,
        installationId: `${label}-${run}-installation-${userId}`,
        issuedAtUtc: nowUtc,
        snapshotExpiresAtUtc: new Date(Date.now() + 3_600_000).toISOString(),
      });
      return { userId: userId as EntityId, sessionId: sessionId as EntityId };
    };
    return { pageId, creator: await session(creator), staff: await session(staff) };
  })();

  /** Per object: its draft, cover asset and the stable id of its first occurrence. */
  const records = new Map<string, { draftId: string; cover: string; slotId: string }>();

  function eventBody(cover: string, options: EventOptions, slotId: string) {
    const body = standEventBody(cover, slotId) as Record<string, unknown>;
    const schedule = {
      ...(body.schedule as Record<string, unknown>),
      localStartDate: options.date,
    };
    const slot = {
      ...(body.eventSlots as Record<string, unknown>[])[0],
      localDate: options.date,
      startAtUtc: `${options.date}T15:00:00.000Z`,
      endAtUtc: `${options.date}T17:00:00.000Z`,
    };
    const base = {
      ...body,
      title: options.title,
      subcategoryId: subcategory,
      schedule,
      eventSlots: [slot],
    };
    return options.transform === undefined ? base : options.transform(base);
  }

  /** Draft, Media cover, submit, staff approval, owner publish. */
  async function publish(options: EventOptions): Promise<string> {
    const { creator, staff, pageId } = await actors;
    const publisherRef = { type: 'page', id: pageId } as const;
    const slotId = randomUUID();
    const draft = succeeded<{ draftId: string; contentId: string; revision: number }>(
      await content.content.execute(creator, {
        schemaVersion: 1,
        commandType: 'createDraft',
        idempotencyKey: key('draft'),
        payload: {
          typeId: 'event',
          publisherRef,
          marketId: 'LV',
          body: eventBody(randomUUID(), options, slotId),
        },
      }),
      'createDraft',
    );
    const upload = succeeded<{ uploadSessionId: string; assetId: string }>(
      await media.service.execute(creator, {
        schemaVersion: 1,
        commandType: 'createUploadSession',
        idempotencyKey: key('session'),
        payload: {
          family: 'image',
          marketId: 'LV',
          visibilityClass: 'publicDerived',
          declaredMediaType: 'image/png',
          declaredByteLength: png.length,
          publisherRef,
          entityIntent: { domain: 'content', entityId: draft.contentId, purpose: 'contentMedia' },
        },
      }),
      'upload',
    );
    const asset = await media.repository.transact((tx) => tx.asset(upload.assetId));
    assert.ok(asset);
    await media.objectStore.put(asset.objectKeyHandle, png);
    const confirmed = succeeded<{
      revision: number;
      sourceGenerationRef: { providerGeneration: string };
    }>(
      await media.service.execute(creator, {
        schemaVersion: 1,
        commandType: 'confirmUpload',
        idempotencyKey: key('confirm'),
        payload: {
          uploadSessionId: upload.uploadSessionId,
          expectedSha256: sha256(png),
          expectedByteLength: png.length,
        },
      }),
      'confirm',
    );
    succeeded(
      await media.service.execute(creator, {
        schemaVersion: 1,
        commandType: 'finalizeAsset',
        idempotencyKey: key('finalize'),
        payload: {
          assetId: upload.assetId,
          expectedAssetRevision: confirmed.revision,
          sourceProviderGeneration: confirmed.sourceGenerationRef.providerGeneration,
          expectedSha256: sha256(png),
          expectedByteLength: png.length,
        },
      }),
      'finalize',
    );
    const bound = succeeded<{ revision: number }>(
      await content.content.execute(creator, {
        schemaVersion: 1,
        commandType: 'updateDraft',
        idempotencyKey: key('bind'),
        payload: {
          draftId: draft.draftId,
          expectedRevision: draft.revision,
          body: eventBody(upload.assetId, options, slotId),
        },
      }),
      'bind',
    );
    const submission = succeeded<{ submissionId: string }>(
      await content.content.execute(creator, {
        schemaVersion: 1,
        commandType: 'submitForPublication',
        idempotencyKey: key('submit'),
        payload: { draftId: draft.draftId, expectedDraftRevision: bound.revision },
      }),
      'submit',
    );
    const approved = await content.moderation.service.decide(staff, {
      schemaVersion: 1,
      action: 'approve',
      idempotencyKey: key('approve'),
      reason: `${label} emulator approval`,
      target: { contentId: draft.contentId, submissionId: submission.submissionId },
    });
    assert.equal(approved.kind, 'succeeded', JSON.stringify(approved));
    succeeded(
      await content.content.execute(creator, {
        schemaVersion: 1,
        commandType: 'publishApprovedRevision',
        idempotencyKey: key('publish'),
        payload: { submissionId: submission.submissionId, expectedPointerRevision: 0 },
      }),
      'publish',
    );
    records.set(draft.contentId, { draftId: draft.draftId, cover: upload.assetId, slotId });
    return draft.contentId;
  }

  async function pointer(contentId: string) {
    const current = await content.contentRepository.transact((tx) => tx.pointer(contentId));
    assert.ok(current, `pointer of ${contentId}`);
    return current;
  }

  const answer = (stage: CommandAnswer['stage'], result: { kind: string; code?: string }) => ({
    stage,
    kind: result.kind,
    ...(result.code === undefined ? {} : { code: result.code }),
  });

  /**
   * A new revision of a published object through the whole real path: draft
   * update, submit, staff approval, owner publish. The first stage that does
   * not succeed is returned, so a refusal can be asserted by its code.
   */
  async function revise(contentId: string, options: EventOptions): Promise<CommandAnswer> {
    const { creator, staff } = await actors;
    const record = records.get(contentId);
    assert.ok(record, `published by this world: ${contentId}`);
    const draft = await content.contentRepository.transact((tx) => tx.draftByContentId(contentId));
    assert.ok(draft);
    const updated = (await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'updateDraft',
      idempotencyKey: key('revise'),
      payload: {
        draftId: record.draftId,
        expectedRevision: draft.revision,
        body: eventBody(record.cover, options, record.slotId),
      },
    })) as { kind: string; code?: string; data?: { revision: number } };
    if (updated.kind !== 'succeeded') return answer('update', updated);
    const submitted = (await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'submitForPublication',
      idempotencyKey: key('resubmit'),
      payload: { draftId: record.draftId, expectedDraftRevision: updated.data?.revision },
    })) as { kind: string; code?: string; data?: { submissionId: string } };
    if (submitted.kind !== 'succeeded') return answer('submit', submitted);
    const submissionId = submitted.data?.submissionId as string;
    const approved = await content.moderation.service.decide(staff, {
      schemaVersion: 1,
      action: 'approve',
      idempotencyKey: key('reapprove'),
      reason: `${label} emulator approval`,
      target: { contentId, submissionId },
    });
    assert.equal(approved.kind, 'succeeded', JSON.stringify(approved));
    const published = (await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: key('republish'),
      payload: { submissionId, expectedPointerRevision: (await pointer(contentId)).revision },
    })) as { kind: string; code?: string };
    return answer('publish', published);
  }

  /** Owner rollback (or re-activation) of an earlier immutable revision. */
  async function activate(contentId: string, publishedRevisionId: string): Promise<CommandAnswer> {
    const { creator } = await actors;
    const result = (await content.content.execute(creator, {
      schemaVersion: 1,
      commandType: 'activatePublishedRevision',
      idempotencyKey: key('activate'),
      payload: {
        contentId,
        publishedRevisionId,
        expectedPointerRevision: (await pointer(contentId)).revision,
      },
    })) as { kind: string; code?: string };
    return answer('activate', result);
  }

  const slotIdOf = (contentId: string): string => {
    const record = records.get(contentId);
    assert.ok(record);
    return record.slotId;
  };

  async function ownerWithdraw(contentId: string): Promise<void> {
    const { creator } = await actors;
    const pointer = await content.contentRepository.transact((tx) => tx.pointer(contentId));
    assert.ok(pointer);
    succeeded(
      await content.content.execute(creator, {
        schemaVersion: 1,
        commandType: 'withdrawPublication',
        idempotencyKey: key('withdraw'),
        payload: { contentId, expectedPointerRevision: pointer.revision, mode: 'withdraw' },
      }),
      'withdraw',
    );
  }

  return { subcategory, publish, revise, activate, pointer, ownerWithdraw, slotIdOf };
}
