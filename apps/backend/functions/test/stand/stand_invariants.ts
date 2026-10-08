import { identityAuthorityCollections } from '../../src/modules/identity_publisher/infrastructure/firestore_identity_authority_repository.js';
import { contentCollections } from '../../src/modules/content/infrastructure/firestore_content_repository.js';
import { mediaCollections } from '../../src/modules/media/infrastructure/firestore_media_repository.js';
import { moderationCollections } from '../../src/modules/moderation/infrastructure/firestore_moderation_repository.js';
import { standManifestCollection } from './stand_content_event.js';
import type { RawStandState } from './stand_digest.js';
import { standBookings, standEvent, standPages, standUsers } from './stand_plan.js';

/** Returns every violated seed invariant; an empty list means the stand is correctly seeded. */
export function standInvariantProblems(raw: RawStandState): string[] {
  const problems: string[] = [];
  const docs = (collection: string) => [...(raw.get(collection)?.entries() ?? [])];

  const accounts = docs(identityAuthorityCollections.accounts);
  if (accounts.length !== standUsers.length) problems.push(`accounts=${accounts.length}`);
  const sessions = docs(identityAuthorityCollections.sessions);
  const creatorUid = standUsers.find((user) => user.label === 'creator')?.firebaseUid;
  const creatorUserIds = new Set(
    sessions
      .filter(([, session]) => session.firebaseUid === creatorUid)
      .map(([, session]) => String(session.userId)),
  );
  for (const [id, account] of accounts) {
    const roles = Array.isArray(account.systemRoles) ? account.systemRoles.map(String) : [];
    const isCreator = creatorUserIds.has(id);
    if (roles.some((role) => role !== 'User' && role !== 'Creator')) {
      problems.push(`unexpected role on ${isCreator ? 'creator' : 'ordinary'} account`);
    }
    if (roles.includes('Creator') !== isCreator) {
      problems.push(`Creator role mismatch for ${isCreator ? 'creator' : 'ordinary'} account`);
    }
  }
  for (const [, snapshot] of docs(identityAuthorityCollections.accessSnapshots)) {
    const capabilities = Array.isArray(snapshot.capabilityIds) ? snapshot.capabilityIds : [];
    if (capabilities.some((capability) => capability !== 'booking.self_service')) {
      problems.push('Session snapshot carries more than booking.self_service');
    }
  }

  // C2: exactly the seeded staff Account holds the test-only moderation grant, keyed
  // by the real Identity userId; nobody else (Creator, ordinary users) does.
  const staffSession = sessions.find(
    ([, session]) =>
      session.firebaseUid === standUsers.find((u) => u.label === 'staff')?.firebaseUid,
  );
  const staffUserId = staffSession === undefined ? undefined : String(staffSession[1].userId);
  const grants = docs(moderationCollections.staffAuthority);
  if (
    staffUserId === undefined ||
    grants.length !== 1 ||
    grants[0]?.[0] !== staffUserId ||
    grants[0]?.[1].userId !== staffUserId ||
    grants[0]?.[1].scope !== 'moderation'
  ) {
    problems.push('exactly the staff Account must hold the test-only moderation grant');
  }

  // C3: the stand's Event exists through the Content path, with exactly the ids the
  // owner services returned (manifest): Creator draft on the studio Page, ready Media
  // cover, staff approval with an applied receipt, owner publication, visible pointer.
  const manifest = raw.get(standManifestCollection)?.get('seed');
  const event = manifest?.contentEvent as Record<string, unknown> | undefined;
  if (manifest?.base === undefined || event === undefined) {
    problems.push('the stand manifest must record the base seed and the Content Event');
  } else {
    const get = (collection: string, id: unknown) => raw.get(collection)?.get(String(id));
    const draft = get(contentCollections.drafts, event.draftId);
    const submission = get(contentCollections.submissions, event.submissionId);
    const pointer = get(contentCollections.pointers, event.contentId);
    const revision = get(contentCollections.publishedRevisions, event.publishedRevisionId);
    const decision = get(moderationCollections.decisions, event.approveDecisionId);
    const receipt = get(moderationCollections.receipts, event.approveDecisionId);
    const asset = get(mediaCollections.assets, event.assetId);
    const publisher = draft?.publisherRef as Record<string, unknown> | undefined;
    if (
      draft === undefined ||
      draft.contentId !== event.contentId ||
      draft.typeId !== 'event' ||
      !creatorUserIds.has(String(draft.createdByUserId)) ||
      publisher?.type !== 'page' ||
      publisher.id !== event.pageId
    )
      problems.push('the Content Event draft does not match the manifest');
    const moderation = submission?.moderation as Record<string, unknown> | undefined;
    if (
      submission === undefined ||
      submission.contentId !== event.contentId ||
      submission.state !== 'published' ||
      moderation?.policyDecisionId !== event.approveDecisionId
    )
      problems.push('the Content Event submission was not published through its approval');
    if (
      pointer === undefined ||
      pointer.currentPublishedRevisionId !== event.publishedRevisionId ||
      pointer.visibility !== 'visible'
    )
      problems.push('the Content Event is not the visible published revision');
    const attachments = Array.isArray(revision?.mediaAttachments)
      ? (revision.mediaAttachments as Record<string, unknown>[])
      : [];
    if (
      revision?.contentId !== event.contentId ||
      !attachments.some((item) => item.assetId === event.assetId)
    )
      problems.push('the Content Event revision does not carry its Media cover');
    if (
      decision === undefined ||
      decision.action !== 'approve' ||
      decision.staffUserId !== staffUserId ||
      receipt?.outcome !== 'applied'
    )
      problems.push('the Content Event was not approved by the staff Account');
    if (asset?.lifecycle !== 'ready') problems.push('the Content Event cover is not ready');
  }

  const verifications = docs(identityAuthorityCollections.creatorVerifications);
  if (verifications.length !== 1 || verifications[0]?.[1].status !== 'verified') {
    problems.push('exactly one verified Creator verification is required');
  }
  const pages = docs(identityAuthorityCollections.managedPages);
  if (pages.length !== standPages.length) problems.push(`pages=${pages.length}`);
  for (const [id, page] of pages) {
    if (page.status !== 'active' || page.verificationStatus !== 'verified') {
      problems.push(`page ${id} is not active and verified`);
    }
  }
  const memberships = docs(identityAuthorityCollections.pageMemberships);
  if (memberships.length !== standPages.length) problems.push(`memberships=${memberships.length}`);

  const projections = docs('bookingEventProjections');
  // The Booking-test Event is a separate synthetic Event-outbox fixture, not the
  // Content Event: Content publication never makes an Event bookable by itself.
  if (projections.length !== 1 || projections[0]?.[0] !== standEvent.occurrenceId) {
    problems.push('exactly the Booking-test fixture Event projection is required');
  }
  const bookings = docs('bookings');
  if (bookings.length !== standBookings.length) problems.push(`bookings=${bookings.length}`);
  const cancelled = standBookings.filter((plan) => plan.cancelAfterCreate).length;
  const confirmed = bookings.filter(([, booking]) => booking.state === 'confirmed').length;
  if (confirmed !== standBookings.length - cancelled) problems.push(`confirmed=${confirmed}`);
  const expectedUnits = standBookings
    .filter((plan) => !plan.cancelAfterCreate)
    .reduce((sum, plan) => sum + plan.participantUnits, 0);
  const ledgers = docs('bookingPoolLedgers');
  if (ledgers.length !== 1 || ledgers[0]?.[1].confirmedUnits !== expectedUnits) {
    problems.push('inventory ledger does not match the confirmed bookings');
  }

  const enabledFlags = docs('platformFeatureFlagRevisions').map(([, revision]) =>
    String(revision.capabilityId),
  );
  for (const forbidden of ['booking.reconfirm', 'booking.reconfirmation.deadlineWorker']) {
    if (enabledFlags.includes(forbidden)) problems.push(`flag ${forbidden} must stay disabled`);
  }
  return problems;
}
