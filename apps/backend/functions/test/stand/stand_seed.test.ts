import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseEntityId } from '../../src/shared/ids.js';
import { digestStandState, type Plain } from './stand_digest.js';
import { assertStandEnvironment, StandGuardError } from './stand_guard.js';
import { standInvariantProblems } from './stand_invariants.js';
import {
  standBookings,
  standCreatorVerification,
  standEvent,
  standMaximumOwnedPages,
  standPages,
  standUsers,
} from './stand_plan.js';

const validEnvironment: NodeJS.ProcessEnv = {
  GCLOUD_PROJECT: 'demo-recharge',
  FUNCTIONS_EMULATOR: 'true',
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
};

void test('guard accepts only the loopback demo-recharge Emulator environment', () => {
  assert.doesNotThrow(() => assertStandEnvironment(validEnvironment));
  for (const override of [
    { GCLOUD_PROJECT: 'recharge-prod' },
    { GOOGLE_CLOUD_PROJECT: 'recharge-prod' },
    { FUNCTIONS_EMULATOR: 'false' },
    { FIRESTORE_EMULATOR_HOST: '10.0.0.5:8080' },
    { FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099' },
    { FIREBASE_STORAGE_EMULATOR_HOST: '192.168.1.5:9199' },
    { GOOGLE_APPLICATION_CREDENTIALS: 'C:/secret.json' },
    { FIREBASE_TOKEN: 'token' },
  ]) {
    assert.throws(
      () => assertStandEnvironment({ ...validEnvironment, ...override }),
      StandGuardError,
      JSON.stringify(Object.keys(override)),
    );
  }
});

void test('plan is internally consistent and uses only canonical ids', () => {
  assert.equal(standUsers.length, 3);
  assert.equal(new Set(standUsers.map((user) => user.firebaseUid)).size, 3);
  assert.equal(standPages.length, standMaximumOwnedPages);
  for (const id of [
    ...standPages.flatMap((page) => [page.pageId, page.membershipId]),
    standCreatorVerification.verificationId,
    ...standCreatorVerification.evidenceRefIds,
  ]) {
    assert.doesNotThrow(() => parseEntityId(id), id);
  }
  const labels = new Set<string>(standUsers.map((user) => user.label));
  const units = standBookings.reduce((sum, booking) => sum + booking.participantUnits, 0);
  for (const booking of standBookings) assert.ok(labels.has(booking.user));
  assert.ok(units <= standEvent.totalCapacity);
  assert.equal(new Set(standBookings.map((booking) => booking.idempotencyKey)).size, 3);
});

type MutableState = Map<string, Map<string, Plain>>;

function raw(prefix: string): MutableState {
  const creator = `${prefix}-creator`;
  const viewer = `${prefix}-viewer`;
  const staff = `${prefix}-staff`;
  const session = (uid: string, userId: string, issued: string): Plain => ({
    firebaseUid: uid,
    userId,
    issuedAtUtc: issued,
    handleHash: `${prefix}${'a'.repeat(60)}`,
  });
  const snapshot = (userId: string): Plain => ({
    userId,
    capabilityIds: ['booking.self_service'],
    evaluatedAtUtc: '2026-10-05T10:00:05.000Z',
  });
  const studio = standPages.find((page) => page.label === 'studio')?.pageId ?? 'studio';
  const event = {
    pageId: studio,
    contentId: `${prefix}-content`,
    draftId: `${prefix}-draft`,
    submissionId: `${prefix}-submission`,
    publishedRevisionId: `${prefix}-revision`,
    assetId: `${prefix}-asset`,
    uploadSessionId: `${prefix}-upload`,
    approveDecisionId: `${prefix}-decision`,
    completedAtUtc: '2026-10-05T10:00:09.000Z',
  };
  return new Map<string, Map<string, Plain>>([
    [
      'standManifest',
      new Map<string, Plain>([
        [
          'seed',
          {
            schemaVersion: 1,
            base: { completedAtUtc: '2026-10-05T10:00:08.000Z' },
            contentEvent: event,
          },
        ],
      ]),
    ],
    [
      'contentDrafts',
      new Map<string, Plain>([
        [
          event.draftId,
          {
            draftId: event.draftId,
            contentId: event.contentId,
            typeId: 'event',
            createdByUserId: creator,
            publisherRef: { type: 'page', id: studio },
          },
        ],
      ]),
    ],
    [
      'contentSubmissions',
      new Map<string, Plain>([
        [
          event.submissionId,
          {
            contentId: event.contentId,
            state: 'published',
            moderation: { policyDecisionId: event.approveDecisionId },
          },
        ],
      ]),
    ],
    [
      'contentPublicationPointers',
      new Map<string, Plain>([
        [
          event.contentId,
          { currentPublishedRevisionId: event.publishedRevisionId, visibility: 'visible' },
        ],
      ]),
    ],
    [
      'contentPublishedRevisions',
      new Map<string, Plain>([
        [
          event.publishedRevisionId,
          { contentId: event.contentId, mediaAttachments: [{ assetId: event.assetId }] },
        ],
      ]),
    ],
    [
      'moderationDecisions',
      new Map<string, Plain>([
        [event.approveDecisionId, { action: 'approve', staffUserId: staff }],
      ]),
    ],
    [
      'moderationEnforcementReceipts',
      new Map<string, Plain>([[event.approveDecisionId, { outcome: 'applied' }]]),
    ],
    [
      'mediaAssets',
      new Map<string, Plain>([
        [event.assetId, { lifecycle: 'ready', objectKeyHandle: `objk:${prefix}` }],
      ]),
    ],
    [
      'identityAccounts',
      new Map<string, Plain>([
        [creator, { userId: creator, systemRoles: ['Creator', 'User'] }],
        [viewer, { userId: viewer, systemRoles: ['User'] }],
        [staff, { userId: staff, systemRoles: ['User'] }],
      ]),
    ],
    [
      'identitySessions',
      new Map<string, Plain>([
        [`${prefix}-s1`, session(standUsers[0].firebaseUid, creator, '2026-10-05T10:00:01.000Z')],
        [`${prefix}-s2`, session(standUsers[1].firebaseUid, viewer, '2026-10-05T10:00:02.000Z')],
        [`${prefix}-s3`, session(standUsers[2].firebaseUid, staff, '2026-10-05T10:00:03.000Z')],
      ]),
    ],
    [
      'identityAccessSnapshots',
      new Map<string, Plain>([
        [`${prefix}-s1`, snapshot(creator)],
        [`${prefix}-s2`, snapshot(viewer)],
        [`${prefix}-s3`, snapshot(staff)],
      ]),
    ],
    [
      'moderationStaffAuthority',
      new Map<string, Plain>([[staff, { userId: staff, scope: 'moderation' }]]),
    ],
    [
      'identityCreatorVerifications',
      new Map<string, Plain>([[creator, { userId: creator, status: 'verified' }]]),
    ],
    [
      'identityManagedPages',
      new Map<string, Plain>(
        standPages.map((page) => [
          page.pageId,
          { pageId: page.pageId, status: 'active', verificationStatus: 'verified' },
        ]),
      ),
    ],
    [
      'identityPageMemberships',
      new Map<string, Plain>(
        standPages.map((page) => [
          page.membershipId,
          {
            role: 'owner',
            status: 'active',
            capabilityIds: ['content.create', 'content.publish', 'content.submit', 'manage_page'],
          },
        ]),
      ),
    ],
    [
      'bookingEventProjections',
      new Map<string, Plain>([[standEvent.occurrenceId, { eventId: standEvent.eventId }]]),
    ],
    [
      'bookings',
      new Map<string, Plain>([
        [`${prefix}-b1`, { userId: viewer, state: 'confirmed', participantUnits: 2 }],
        [`${prefix}-b2`, { userId: creator, state: 'confirmed', participantUnits: 1 }],
        [`${prefix}-b3`, { userId: staff, state: 'cancelled', participantUnits: 1 }],
      ]),
    ],
    ['bookingPoolLedgers', new Map<string, Plain>([['ledger-1', { confirmedUnits: 3 }]])],
    [
      'platformFeatureFlagRevisions',
      new Map<string, Plain>([['f1', { capabilityId: 'booking.create' }]]),
    ],
  ]);
}

void test('digest is identical when only server-generated ids and volatile values differ', () => {
  const first = digestStandState(raw('11111111-1111-4111-8111-111111111111'), []);
  const second = digestStandState(raw('22222222-2222-4222-8222-2222222222222'), []);
  assert.equal(first.digest, second.digest);
});

void test('digest changes when seeded authority changes', () => {
  const baseline = digestStandState(raw('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'), []);
  const changed = raw('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
  const viewer = changed
    .get('identityAccounts')
    ?.get('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa-viewer');
  assert.ok(viewer);
  (viewer.systemRoles as string[]).push('Creator');
  assert.notEqual(digestStandState(changed, []).digest, baseline.digest);
});

void test('invariants accept the seed shape and reject elevated ordinary accounts', () => {
  const prefix = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  assert.deepEqual(standInvariantProblems(raw(prefix)), []);
  const elevated = raw(prefix);
  elevated.get('identityAccounts')?.set(`${prefix}-viewer`, {
    userId: `${prefix}-viewer`,
    systemRoles: ['User', 'Creator'],
  });
  assert.ok(standInvariantProblems(elevated).some((problem) => problem.includes('Creator')));
  const staffCapabilities = raw(prefix);
  staffCapabilities.get('identityAccessSnapshots')?.set(`${prefix}-s3`, {
    userId: `${prefix}-staff`,
    capabilityIds: ['booking.self_service', 'content.publish'],
  });
  assert.ok(standInvariantProblems(staffCapabilities).length > 0);
});

void test('invariants reject an owner membership left without its Content capabilities', () => {
  const prefix = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  const withdrawn = raw(prefix);
  const membershipId = standPages[0]?.membershipId ?? '';
  withdrawn.get('identityPageMemberships')?.set(membershipId, {
    role: 'owner',
    status: 'active',
    capabilityIds: ['manage_page'],
  });
  assert.ok(standInvariantProblems(withdrawn).some((problem) => problem.includes(membershipId)));
});

void test('invariants require the moderation grant on exactly the staff Account', () => {
  const prefix = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const missing = raw(prefix);
  missing.get('moderationStaffAuthority')?.clear();
  assert.ok(standInvariantProblems(missing).some((problem) => problem.includes('moderation')));
  // A grant on the Creator (or any second Account) is not a staff grant.
  const creatorGranted = raw(prefix);
  creatorGranted.get('moderationStaffAuthority')?.set(`${prefix}-creator`, {
    userId: `${prefix}-creator`,
    scope: 'moderation',
  });
  assert.ok(
    standInvariantProblems(creatorGranted).some((problem) => problem.includes('moderation')),
  );
  const wrongAccount = raw(prefix);
  wrongAccount.get('moderationStaffAuthority')?.clear();
  wrongAccount.get('moderationStaffAuthority')?.set(`${prefix}-viewer`, {
    userId: `${prefix}-viewer`,
    scope: 'moderation',
  });
  assert.ok(standInvariantProblems(wrongAccount).some((problem) => problem.includes('moderation')));
});

void test('the staff registry is part of the digest', () => {
  const prefix = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  const baseline = digestStandState(raw(prefix), []);
  const changed = raw(prefix);
  changed.get('moderationStaffAuthority')?.clear();
  assert.notEqual(digestStandState(changed, []).digest, baseline.digest);
});

void test('invariants require the Content Event of the manifest, approved by staff', () => {
  const prefix = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
  assert.deepEqual(standInvariantProblems(raw(prefix)), []);
  const missing = raw(prefix);
  missing.get('standManifest')?.clear();
  assert.ok(standInvariantProblems(missing).some((problem) => problem.includes('manifest')));
  const unpublished = raw(prefix);
  unpublished.get('contentSubmissions')?.set(`${prefix}-submission`, {
    contentId: `${prefix}-content`,
    state: 'under_review',
    moderation: {},
  });
  assert.ok(standInvariantProblems(unpublished).some((problem) => problem.includes('submission')));
  // An approval recorded for anyone but the staff Account is not the seeded approval.
  const creatorApproved = raw(prefix);
  creatorApproved.get('moderationDecisions')?.set(`${prefix}-decision`, {
    action: 'approve',
    staffUserId: `${prefix}-creator`,
  });
  assert.ok(standInvariantProblems(creatorApproved).some((problem) => problem.includes('staff')));
  const hidden = raw(prefix);
  hidden.get('contentPublicationPointers')?.set(`${prefix}-content`, {
    currentPublishedRevisionId: `${prefix}-revision`,
    visibility: 'restricted',
  });
  assert.ok(standInvariantProblems(hidden).some((problem) => problem.includes('visible')));
});
