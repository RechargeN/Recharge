import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { after, test } from 'node:test';

import { IdentityPublisherAuthority } from '../../src/modules/identity_publisher/application/identity_publisher_authority.js';
import { FirestoreIdentityAuthorityRepository } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { LocalPageCreationPolicy } from '../../src/modules/identity_publisher/infrastructure/local_page_creation_policy.js';
import { LocalVerificationDecisionAdapter } from '../../src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.js';
import { SyntheticProviderIdentityVerifier } from '../../src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.js';
import { ModerationService } from '../../src/modules/moderation/application/moderation_service.js';
import type { ContentModerationPort } from '../../src/modules/moderation/application/ports.js';
import { ModerationRepositoryConflict } from '../../src/modules/moderation/domain/repositories.js';
import { moderationPolicyRevision } from '../../src/modules/moderation/domain/moderation.js';
import { ContentModerationAdapter } from '../../src/modules/moderation/infrastructure/content_moderation_adapter.js';
import { EmulatorStaffAuthority } from '../../src/modules/moderation/infrastructure/emulator_staff_authority.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { systemServerClock } from '../../src/shared/server_clock.js';
import type { EntityId } from '../../src/shared/ids.js';
import { createStandModeration, submitEventForReview } from '../stand/stand_moderation.js';
import { emulatorFirestore } from '../support/booking_emulator.js';

const firestore = emulatorFirestore();
const stand = createStandModeration(firestore);
const run = randomUUID().slice(0, 8);
const service = stand.moderation.service;

after(async () => {
  // Leave the shared Emulator tidy for the next test file.
  for (const name of Object.values(moderationCollections)) {
    const snapshot = await firestore.collection(name).get();
    for (const document of snapshot.docs) await document.ref.delete();
  }
});

let worlds = 0;

async function bootstrap() {
  // Account proofs are linked to one user, so every world gets its own proofs.
  const world = (worlds += 1);
  const repository = new FirestoreIdentityAuthorityRepository(firestore);
  const nowUtc = new Date().toISOString();
  const reviewer = randomUUID();
  const authority = new IdentityPublisherAuthority({
    repository,
    providerVerifier: new SyntheticProviderIdentityVerifier(),
    verificationDecisions: new LocalVerificationDecisionAdapter(new Set([reviewer])),
    pagePolicy: new LocalPageCreationPolicy(true, 2),
  });
  const account = async (label: string, userId: string) => {
    await authority.accounts.ensureAccount({
      proof: {
        provider: 'google',
        providerTenant: 'demo-recharge-emulator',
        proof: `local-test:google:moderation-${run}-${world}-${label}`,
      },
      proposedUserId: userId,
      proposedIdentityId: randomUUID(),
      nowUtc,
      accountCreationEnabled: true,
    });
  };
  const creator = randomUUID();
  const staff = randomUUID();
  const outsider = randomUUID();
  await account('reviewer', reviewer);
  await account('creator', creator);
  await account('staff', staff);
  await account('outsider', outsider);
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
  await authority.pages.decidePage({ reviewerId: reviewer, pageId, decision: 'verified', nowUtc });
  const session = async (userId: string) => {
    const sessionId = randomUUID();
    await authority.sessions.issue({
      userId,
      sessionId,
      firebaseUid: `moderation-${run}-${world}-${userId}`,
      installationId: `moderation-${run}-installation`,
      issuedAtUtc: nowUtc,
      snapshotExpiresAtUtc: new Date(Date.now() + 3_600_000).toISOString(),
    });
    return { userId: userId as EntityId, sessionId: sessionId as EntityId };
  };
  // The only staff grant: the stand bootstrap path (never a command or a client).
  await new EmulatorStaffAuthority(firestore, repository).grant(staff, nowUtc);
  return {
    pageId,
    creator: await session(creator),
    staff: await session(staff),
    outsider: await session(outsider),
  };
}

let sequence = 0;
const key = (label: string) => `${label}-${run}-${(sequence += 1)}`;

const command = (
  action: string,
  target: Record<string, unknown>,
  extra: Record<string, unknown> = {},
) => ({
  schemaVersion: 1,
  action,
  idempotencyKey: key(action),
  reason: `operator ${action} for the stand`,
  target,
  ...extra,
});

async function view(contentId: string) {
  const pointer = await stand.contentRepository.transact((tx) => tx.pointer(contentId));
  assert.ok(pointer);
  return pointer;
}

void test('staff authority: only the bootstrap registry grants it, per command', async () => {
  const world = await bootstrap();
  assert.equal((await service.queue(world.staff)).kind, 'succeeded');
  for (const [name, actor] of [
    ['creator', world.creator],
    ['outsider', world.outsider],
  ] as const) {
    const result = await service.queue(actor);
    assert.deepEqual([name, result], [name, { kind: 'rejected', code: 'staff_denied' }]);
  }
  // An unknown Session is unauthenticated, not staff.
  assert.deepEqual(await service.queue({ userId: world.staff.userId, sessionId: randomUUID() }), {
    kind: 'rejected',
    code: 'unauthenticated',
  });
  // A registry entry that was not written by the bootstrap source grants nothing.
  await firestore.collection(moderationCollections.staffAuthority).doc(world.outsider.userId).set({
    userId: world.outsider.userId,
    scope: 'moderation',
    source: 'client-claim',
    grantedAtUtc: new Date().toISOString(),
  });
  assert.deepEqual(await service.queue(world.outsider), { kind: 'rejected', code: 'staff_denied' });
  // A denied command records nothing.
  const denied = await service.decide(world.creator, command('approve', { contentId: 'x' }));
  assert.equal(denied.kind, 'rejected');
});

void test(
  'review, publication, restrict, owner hold and restore keep their own chains',
  { timeout: 180_000 },
  async () => {
    const world = await bootstrap();
    const publisherRef = { type: 'page', id: world.pageId } as const;
    const submitted = await submitEventForReview(stand, world.creator, publisherRef);
    assert.equal(submitted.state, 'under_review');

    // Under review, the owner cannot publish.
    const early = await stand.contentService.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: key('early'),
      payload: { submissionId: submitted.submissionId, expectedPointerRevision: 0 },
    });
    assert.deepEqual(
      [early.kind, early.kind === 'rejected' ? early.code : ''],
      ['rejected', 'moderation_required'],
    );

    const queue = await service.queue(world.staff);
    assert.equal(queue.kind, 'succeeded');
    if (queue.kind !== 'succeeded') return;
    assert.ok(queue.data.pending.some((item) => item.submissionId === submitted.submissionId));

    const target = { contentId: submitted.contentId, submissionId: submitted.submissionId };
    // A reason is mandatory, and a bad one creates nothing.
    assert.deepEqual(
      await service.decide(world.staff, { ...command('approve', target), reason: '' }),
      {
        kind: 'rejected',
        code: 'invalid_contract',
      },
    );

    const approveCommand = command('approve', target);
    const approved = await service.decide(world.staff, approveCommand);
    assert.equal(approved.kind, 'succeeded', JSON.stringify(approved));
    if (approved.kind !== 'succeeded') return;
    const { decision, receipt } = approved.data;
    // Evidence: who, exactly what, which action, why.
    assert.equal(decision.staffUserId, world.staff.userId);
    assert.equal(decision.staffSessionId, world.staff.sessionId);
    assert.equal(decision.target.submissionId, submitted.submissionId);
    assert.equal(decision.target.submissionRevision, 1);
    assert.equal(decision.action, 'approve');
    assert.equal(decision.reason, approveCommand.reason);
    assert.equal(decision.policyRevision, moderationPolicyRevision);
    assert.equal(receipt.outcome, 'applied');
    assert.equal(receipt.decisionId, decision.decisionId);
    assert.equal(receipt.staffUserId, world.staff.userId);
    assert.equal(receipt.reason, approveCommand.reason);

    // Replay returns the same evidence; the same key with other content conflicts.
    const replay = await service.decide(world.staff, approveCommand);
    assert.equal(
      replay.kind === 'succeeded' && replay.data.decision.decisionId,
      decision.decisionId,
    );
    assert.deepEqual(
      await service.decide(world.staff, { ...approveCommand, reason: 'another reason entirely' }),
      { kind: 'rejected', code: 'idempotency_conflict' },
    );
    // The submission is no longer under review: a second decision is stale.
    assert.deepEqual(await service.decide(world.staff, command('reject', target)), {
      kind: 'rejected',
      code: 'target_stale',
    });
    // Receipts and decisions are immutable.
    await assert.rejects(
      stand.ports.repository.transact((tx) => tx.putReceipt(receipt)),
      ModerationRepositoryConflict,
    );

    // The owner publishes what staff approved.
    const published = await stand.contentService.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'publishApprovedRevision',
      idempotencyKey: key('publish'),
      payload: { submissionId: submitted.submissionId, expectedPointerRevision: 0 },
    });
    assert.equal(published.kind, 'succeeded', JSON.stringify(published));
    const visible = await view(submitted.contentId);
    assert.equal(visible.visibility, 'visible');

    // restrict
    const contentTarget = { contentId: submitted.contentId };
    const restricted = await service.decide(world.staff, command('restrict', contentTarget));
    assert.equal(restricted.kind, 'succeeded', JSON.stringify(restricted));
    if (restricted.kind !== 'succeeded') return;
    assert.equal(restricted.data.receipt.outcome, 'applied');
    assert.equal(
      restricted.data.decision.target.publishedRevisionId,
      visible.currentPublishedRevisionId,
    );
    assert.equal(restricted.data.decision.target.pointerRevision, visible.revision);
    const holdRestricted = await view(submitted.contentId);
    assert.equal(holdRestricted.visibility, 'restricted');
    assert.equal(holdRestricted.moderationHold?.decisionId, restricted.data.decision.decisionId);

    // The owner's own withdrawal is a separate hold.
    const ownerWithdrew = await stand.contentService.execute(world.creator, {
      schemaVersion: 1,
      commandType: 'withdrawPublication',
      idempotencyKey: key('owner-withdraw'),
      payload: {
        contentId: submitted.contentId,
        expectedPointerRevision: holdRestricted.revision,
        mode: 'withdraw',
      },
    });
    assert.equal(ownerWithdrew.kind, 'succeeded', JSON.stringify(ownerWithdrew));

    // restore lifts only the moderation hold; the owner hold stays.
    const restored = await service.decide(
      world.staff,
      command('restore', contentTarget, {
        restoresDecisionId: restricted.data.decision.decisionId,
      }),
    );
    assert.equal(restored.kind, 'succeeded', JSON.stringify(restored));
    const afterRestore = await view(submitted.contentId);
    assert.equal(afterRestore.moderationHold, null);
    assert.equal(afterRestore.ownerHold, 'withdrawn');
    assert.equal(afterRestore.visibility, 'withdrawn');

    // A newer decision replaces an older one; restoring the older one is stale.
    const first = await service.decide(world.staff, command('restrict', contentTarget));
    const second = await service.decide(world.staff, command('withdraw', contentTarget));
    assert.ok(first.kind === 'succeeded' && second.kind === 'succeeded');
    if (first.kind !== 'succeeded' || second.kind !== 'succeeded') return;
    const stale = await service.decide(
      world.staff,
      command('restore', contentTarget, { restoresDecisionId: first.data.decision.decisionId }),
    );
    assert.equal(stale.kind, 'succeeded');
    if (stale.kind !== 'succeeded') return;
    assert.equal(stale.data.receipt.outcome, 'refused');
    assert.equal(stale.data.receipt.refusalCode, 'moderation_decision_stale');
    const stillHeld = await view(submitted.contentId);
    assert.equal(stillHeld.moderationHold?.decisionId, second.data.decision.decisionId);
    assert.equal(stillHeld.moderationHold?.kind, 'withdrawn');

    // A restore must name a recorded restrict/withdraw decision of this Content.
    assert.deepEqual(
      await service.decide(
        world.staff,
        command('restore', contentTarget, { restoresDecisionId: 'no-such-decision' }),
      ),
      { kind: 'rejected', code: 'target_not_found' },
    );

    // Every decision has its decision and enforcement audit entries.
    const recent = await stand.ports.repository.recent(50);
    for (const item of recent.filter(
      (entry) => entry.decision.target.contentId === submitted.contentId,
    )) {
      assert.ok(item.receipt, `receipt for ${item.decision.action}`);
      for (const kind of ['decision', 'enforcement']) {
        const audit = await firestore
          .collection(moderationCollections.audit)
          .doc(`${item.decision.decisionId}:${kind}`)
          .get();
        assert.ok(audit.exists, `${kind} audit for ${item.decision.action}`);
      }
    }
  },
);

void test(
  'a rejected submission returns the draft to its author',
  { timeout: 180_000 },
  async () => {
    const world = await bootstrap();
    const submitted = await submitEventForReview(stand, world.creator, {
      type: 'page',
      id: world.pageId,
    });
    const rejected = await service.decide(
      world.staff,
      command('reject', { contentId: submitted.contentId, submissionId: submitted.submissionId }),
    );
    assert.equal(rejected.kind, 'succeeded', JSON.stringify(rejected));
    const submission = await stand.contentRepository.transact((tx) =>
      tx.submission(submitted.submissionId),
    );
    assert.equal(submission?.state, 'rejected');
    const draft = await stand.contentRepository.transact((tx) => tx.draft(submitted.draftId));
    assert.equal(draft?.status, 'editing');
    const pointer = await stand.contentRepository.transact((tx) => tx.pointer(submitted.contentId));
    assert.equal(pointer, null);
  },
);

void test('instructions that do not match a recorded decision change nothing', async () => {
  const world = await bootstrap();
  const submitted = await submitEventForReview(stand, world.creator, {
    type: 'page',
    id: world.pageId,
  });
  const target = { contentId: submitted.contentId, submissionId: submitted.submissionId };
  const forged = (extra: Record<string, unknown>) => ({
    schemaVersion: 1,
    commandType: 'applyModerationDisposition',
    idempotencyKey: key('forged'),
    payload: {
      instructionId: 'forged-instruction',
      decisionId: randomUUID(),
      policyRevision: moderationPolicyRevision,
      disposition: 'approve',
      target,
      reasonCategory: 'operator_decision',
      effectiveAtUtc: '2026-01-01T00:00:00.000Z',
      attestation: 'a'.repeat(64),
      ...extra,
    },
  });
  const unknownDecision = await stand.contentService.applyModerationDisposition(forged({}));
  assert.deepEqual(
    [unknownDecision.kind, unknownDecision.kind === 'rejected' ? unknownDecision.code : ''],
    ['rejected', 'capability_denied'],
  );
  // A recorded decision cannot be reused for another disposition or target.
  const reject = await service.decide(world.staff, command('reject', target));
  assert.equal(reject.kind, 'succeeded', JSON.stringify(reject));
  if (reject.kind !== 'succeeded') return;
  const { decision } = reject.data;
  const reused = await stand.contentService.applyModerationDisposition(
    forged({
      decisionId: decision.decisionId,
      disposition: 'approve',
      attestation: decision.attestation,
      effectiveAtUtc: decision.decidedAtUtc,
    }),
  );
  assert.equal(reused.kind, 'rejected');
  const submission = await stand.contentRepository.transact((tx) =>
    tx.submission(submitted.submissionId),
  );
  assert.equal(submission?.state, 'rejected');
});

void test('a decision whose enforcement was interrupted resumes with the same key', async () => {
  const world = await bootstrap();
  const submitted = await submitEventForReview(stand, world.creator, {
    type: 'page',
    id: world.pageId,
  });
  const adapter = new ContentModerationAdapter(
    firestore,
    stand.contentRepository,
    stand.contentService,
  );
  let failures = 1;
  const flaky: ContentModerationPort = {
    reviewQueue: (limit) => adapter.reviewQueue(limit),
    submission: (id) => adapter.submission(id),
    publication: (id) => adapter.publication(id),
    enforce: (instruction) => {
      if (failures > 0) {
        failures -= 1;
        return Promise.reject(new Error('connection lost after send'));
      }
      return adapter.enforce(instruction);
    },
  };
  const interrupted = new ModerationService({
    repository: stand.ports.repository,
    staff: stand.moderation.staff,
    content: flaky,
    clock: systemServerClock,
  });
  const approve = command('approve', {
    contentId: submitted.contentId,
    submissionId: submitted.submissionId,
  });
  assert.deepEqual(await interrupted.decide(world.staff, approve), {
    kind: 'rejected',
    code: 'unknown_outcome',
  });
  // The decision is recorded, Content is untouched and there is no receipt yet.
  const before = await stand.contentRepository.transact((tx) =>
    tx.submission(submitted.submissionId),
  );
  assert.equal(before?.state, 'under_review');
  const resumed = await interrupted.decide(world.staff, approve);
  assert.equal(resumed.kind, 'succeeded', JSON.stringify(resumed));
  if (resumed.kind !== 'succeeded') return;
  assert.equal(resumed.data.receipt.outcome, 'applied');
  const after = await stand.contentRepository.transact((tx) =>
    tx.submission(submitted.submissionId),
  );
  assert.equal(after?.state, 'approved_for_publication');
  // Exactly one decision exists for the key.
  const decisions = (await stand.ports.repository.recent(100)).filter(
    (item) => item.decision.target.submissionId === submitted.submissionId,
  );
  assert.equal(decisions.length, 1);
});
