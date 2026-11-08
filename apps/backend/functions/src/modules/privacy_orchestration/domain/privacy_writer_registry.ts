import { deepFreeze } from '../../../shared/immutable.js';
import type { PrivacyPolicyBlocker } from './privacy_domain_task.js';

/**
 * L1 writer registry (PRIVACY_L1_DSR_RETENTION_HOLD_AMENDMENT.md §3–4): every
 * Firestore collection the backend writes, who owns it, how a data subject's
 * records are found and what an erasure may do with them. It is data only; the
 * owning module performs every effect. A collection missing here, or a privacy
 * domain without a handler, fails the registry coverage test.
 *
 * `subjectField` names the field that holds the subject's ID; `$id` means the
 * document ID is the subject's ID; `{subject}` in a path stands for the
 * subject's own map key; `null` means the records cannot be found by subject at
 * all, which an erasure reports as blocked rather than as done.
 */
export type PrivacyErasureRule =
  /** Owner-equivalent deletion or tombstone (PB-00) or an accepted domain rule. */
  | { readonly kind: 'delete' }
  /** Direct identifier replaced by a scoped pseudonym (BCK09-RETENTION-DEC-01). */
  | { readonly kind: 'anonymize' }
  /** Kept on purpose: an erasure fence or DSR evidence with no accepted end. */
  | { readonly kind: 'fence'; readonly blocker: PrivacyPolicyBlocker }
  /** Waits for a named policy decision; nothing is changed. */
  | { readonly kind: 'blocked'; readonly blocker: PrivacyPolicyBlocker }
  /** Rebuilt from owning sources; follows their tombstones. */
  | { readonly kind: 'derived' }
  /** Holds no personal identifier (configuration, aggregates, event facts). */
  | { readonly kind: 'not_subject_data' };

export interface PrivacyRegistryEntry {
  readonly collection: string;
  /** Writer ID of the amendment's registry (W1–W20) or `config`. */
  readonly writer: string;
  /** Privacy domain that answers for this entry; `null` when no task applies. */
  readonly domainId: string | null;
  readonly subjectField: string | null;
  readonly erasure: PrivacyErasureRule;
}

/** Domains a full erasure dispatches, each answered by one owning handler. */
export const privacyErasureDomainIds = [
  'admin_support',
  'booking',
  'content',
  'content_translation',
  'identity',
  'library',
  'media',
  'moderation',
  'notifications',
  'quick_plan',
  'reviews',
  'route',
  'scenario',
  'security',
  'trust_safety',
] as const;
export type PrivacyErasureDomainId = (typeof privacyErasureDomainIds)[number];

/** Revision of the policy the L1 handlers apply; a change restarts their sweeps. */
export const privacyPolicyRevision = 'l1-local-owner-2026-10-24-pb00';

const del = { kind: 'delete' } as const;
const anonymize = { kind: 'anonymize' } as const;
const derived = { kind: 'derived' } as const;
const none = { kind: 'not_subject_data' } as const;
const blocked = (blocker: PrivacyPolicyBlocker) => ({ kind: 'blocked', blocker }) as const;
const fence = (blocker: PrivacyPolicyBlocker) => ({ kind: 'fence', blocker }) as const;

function rows(
  writer: string,
  domainId: string | null,
  entries: readonly (readonly [string, string | null, PrivacyErasureRule])[],
): PrivacyRegistryEntry[] {
  return entries.map(([collection, subjectField, erasure]) => ({
    collection,
    writer,
    domainId,
    subjectField,
    erasure,
  }));
}

export const privacyWriterRegistry: readonly PrivacyRegistryEntry[] = deepFreeze([
  ...rows('W1', 'identity', [
    ['identityAccounts', '$id', blocked('PB-01')],
    ['identityProviderLinks', 'userId', blocked('PB-01')],
    ['identitySessions', 'userId', blocked('PB-01')],
    ['identityAccessSnapshots', 'userId', blocked('PB-01')],
    ['identityCreatorVerifications', 'userId', blocked('PB-01')],
    // ADR 0023 (2026-11-08): exported and erased with the account (PB-01).
    ['identitySellerDeclarations', 'userId', blocked('PB-01')],
  ]),
  ...rows('W2', 'identity', [
    ['identityManagedPages', 'ownerUserId', blocked('PB-03')],
    ['identityPageMemberships', 'userId', blocked('PB-03')],
  ]),
  ...rows('W3', 'identity', [
    ['identityFindPeopleConsents', 'userId', blocked('PB-01')],
    ['identityFindPeopleConsentReceipts', 'subjectUserId', blocked('PB-01')],
    ['identityAgeAttestations', '$id', blocked('PB-01')],
  ]),
  ...rows('W4', 'security', [
    ['securityRateLimitCounters', 'accountId', blocked('PB-05')],
    ['securityRateLimitAttempts', 'accountId', blocked('PB-05')],
    ['securityAudit', 'accountId', blocked('PB-05')],
    ['securityAuditEvents', null, blocked('PB-05')],
  ]),
  ...rows('W5', 'booking', [
    ['bookings', 'userId', anonymize],
    ['bookingActiveKeys', 'actorId', anonymize],
    ['bookingUserUsage', 'actorId', anonymize],
    ['bookingIdempotency', 'actorId', anonymize],
    ['bookingAudit', 'actorId', anonymize],
    ['bookingOutbox', 'actorId', anonymize],
  ]),
  ...rows('W5', null, [
    ['bookingEventProjections', null, none],
    // Declared with the Booking collections; no writer exists in the code.
    ['bookingHolds', null, none],
    ['bookingPoolLedgers', null, none],
    ['bookingReconfirmationDeadlineJobs', null, none],
    ['bookingReconfirmationDeadlineCheckpoints', null, none],
    ['eventBookingOutbox', null, none],
    ['bookingProjectionDeliveries', null, none],
    ['bookingProjectionDiscoveryCheckpoints', null, none],
    ['bookingProjectionOperatorAudit', null, none],
  ]),
  ...rows('W6', 'content', [
    // No Content command erases a draft: a D4.1 rollback keeps the body.
    ['contentDrafts', 'createdByUserId', blocked('PB-18')],
    ['contentSubmissions', null, blocked('PB-02')],
    ['contentPublishedRevisions', 'publisherRef.id', blocked('PB-02')],
    ['contentIdempotency', 'actorUserId', blocked('PB-05')],
    ['contentAudit', 'actorUserId', blocked('PB-05')],
    ['contentEffects', null, blocked('PB-02')],
  ]),
  ...rows('W6', null, [
    ['contentPublicationPointers', null, none],
    ['contentMediaAvailabilityStatus', null, none],
    ['contentMediaAvailabilityReceipts', null, none],
    ['eventBookingHandoffCheckpoints', null, none],
    ['eventBookingHandoffReceipts', null, none],
    ['eventBookingHandoffStates', null, none],
  ]),
  ...rows('W7', 'content', [['contentExternalBindings', 'createdByUserId', blocked('PB-18')]]),
  ...rows('W8', 'media', [
    ['mediaAssets', 'ownerSubjectId', del],
    ['mediaUploadSessions', 'ownerSubjectId', blocked('PB-14')],
    ['mediaProcessingReceipts', null, blocked('PB-14')],
    ['mediaDeletionStatuses', null, blocked('PB-14')],
    ['mediaIdempotency', 'actorUserId', blocked('PB-05')],
    ['mediaAudit', 'actorUserId', blocked('PB-05')],
    ['mediaEffects', null, blocked('PB-14')],
  ]),
  ...rows('W9', 'moderation', [
    ['moderationDecisions', 'staffUserId', blocked('PB-11')],
    ['moderationEnforcementReceipts', null, blocked('PB-11')],
    ['moderationIdempotency', 'actorUserId', blocked('PB-11')],
    ['moderationAudit', 'actorUserId', blocked('PB-11')],
    ['moderationPublisherTrust', 'publisherRef.id', blocked('PB-11')],
    ['moderationStaffAuthority', '$id', blocked('PB-11')],
    ['moderationRemoderationQueue', null, blocked('PB-11')],
    ['moderationWorkflowReceipts', null, blocked('PB-11')],
  ]),
  ...rows('W10', 'moderation', [
    ['trustSafetyReports', 'reporterUserId', blocked('PB-09')],
    ['trustSafetyReportReceipts', 'reporterUserId', blocked('PB-09')],
    ['trustSafetyInbox', null, blocked('PB-09')],
  ]),
  ...rows('W11', null, [
    ['catalogProjectionSets', null, derived],
    ['catalogActivePointer', null, derived],
    ['catalogItemVersions', null, derived],
    ['catalogSourceStates', null, derived],
    ['catalogFactReceipts', null, derived],
    ['catalogReports', null, derived],
  ]),
  ...rows('W12', 'notifications', [
    ['notificationInboxItems', 'recipientId', del],
    ['notificationEffectReceipts', 'recipientId', anonymize],
    ['notificationDeliveryAttempts', null, del],
    ['notificationPreferences', '$id', del],
    ['notificationCommandReceipts', 'userId', del],
  ]),
  ...rows('W12', null, [['notificationReconcileCheckpoints', null, none]]),
  ...rows('W13', 'library', [
    ['libraryEntries', 'ownerId', del],
    ['libraryCommandReceipts', 'ownerId', del],
    ['libraryOwners', '$id', fence('PB-16')],
  ]),
  ...rows('W14', 'reviews', [
    ['reviews', 'authorId', blocked('PB-04')],
    ['reviewAuthorTargets', 'authorId', blocked('PB-04')],
    ['reviewReceipts', null, blocked('PB-05')],
    ['reviewAudit', 'actorId', blocked('PB-05')],
  ]),
  ...rows('W14', null, [['ratingProjections', null, derived]]),
  ...rows('W15', 'trust_safety', [
    // PB-00: the subject's own relations, through the owner's deactivation.
    ['safetyRelations', 'ownerId', del],
    // Another person's relation naming the subject is that person's data.
    ['safetyRelations', 'targetUserId', blocked('PB-09')],
    ['safetyReceipts', null, blocked('PB-05')],
    ['safetySanctions', 'subjectUserId', blocked('PB-09')],
    ['safetyAppeals', 'subjectUserId', blocked('PB-09')],
    ['safetyNotices', 'subjectUserId', blocked('PB-09')],
    ['safetyAudit', null, blocked('PB-09')],
    ['safetyAttemptLimits', null, blocked('PB-05')],
    ['safetyOwnerAuthority', null, blocked('PB-10')],
    ['contentSafetyHolds', 'subjectUserId', blocked('PB-09')],
    ['catalogSafetyHolds', 'subjectUserId', blocked('PB-09')],
    ['bookingSafetyHolds', 'subjectUserId', blocked('PB-09')],
  ]),
  ...rows('W16', 'admin_support', [
    ['adminSupportCases', null, blocked('PB-10')],
    ['adminRepairProposals', null, blocked('PB-10')],
    ['adminRepairApprovals', null, blocked('PB-10')],
    ['adminRepairExecutions', null, blocked('PB-10')],
    ['adminReadAudit', 'actorId', blocked('PB-10')],
    // Operator replay audit of the Booking deadline worker: staff identities only.
    ['bookingReconfirmationDeadlineOperatorAudit', null, blocked('PB-10')],
    // L2 operations console: the test-only operator registry and its audit.
    ['operationsOperatorAuthority', '$id', blocked('PB-10')],
    ['operationsOperatorAudit', 'actorId', blocked('PB-10')],
  ]),
  ...rows('W17', 'quick_plan', [
    ['quickPlans', 'ownerId', del],
    // The subject's invitation in another owner's plan is shared data.
    ['quickPlans', 'invitations.{subject}.inviteeId', blocked('PB-12')],
    ['quickPlanCommandReceipts', 'ownerId', blocked('PB-05')],
  ]),
  ...rows('W18', 'scenario', [
    ['scenarios', 'ownerId', del],
    ['scenarioMembers', 'actorId', blocked('PB-12')],
    ['scenarioInvites', 'ownerId', blocked('PB-12')],
    ['scenarioInvites', 'recipientId', blocked('PB-12')],
    ['scenarioCommandReceipts', 'actorId', blocked('PB-05')],
    ['scenarioRevisions', 'ownerId', blocked('PB-02')],
    ['scenarioShares', 'ownerId', blocked('PB-02')],
  ]),
  ...rows('W19', 'route', [
    ['routes', 'ownerId', del],
    ['routeRevisions', 'ownerId', blocked('PB-02')],
    ['routeCommandReceipts', 'ownerId', blocked('PB-05')],
  ]),
  ...rows('W20', null, [
    ['privacyRequests', 'subjectId', fence('PB-16')],
    ['privacyDomainTasks', 'subjectId', fence('PB-16')],
    ['privacyTaskProgress', null, fence('PB-16')],
    ['bookingPrivacyProgress', null, fence('PB-16')],
    ['privacyLegalHolds', 'subjectId', fence('PB-16')],
    ['privacyLegalHoldAudit', null, fence('PB-16')],
    ['privacyHoldAuthority', null, none],
  ]),
  // L3 product analytics (ANALYTICS_L3 §6–7). Events carry no account, Session,
  // device or subject key by contract, so a subject's records cannot be found;
  // this is not a claim that they are anonymous (PA-B05).
  ...rows('W21', null, [
    ['productAnalyticsEvents', null, none],
    ['productAnalyticsDailyAggregates', null, derived],
  ]),
  // Test-only staff reader registry and its access audit: staff identities only.
  ...rows('W21', 'admin_support', [
    ['productAnalyticsAccessAuthority', '$id', blocked('PB-10')],
    ['productAnalyticsAccessAudit', 'actorId', blocked('PB-10')],
  ]),
  // ADR 0022: translations are derived from public revisions and follow their
  // lifecycle; only the daily account counter names a subject.
  ...rows('W22', 'content_translation', [['contentTranslationAccountUsage', 'accountId', del]]),
  ...rows('W22', null, [
    ['contentTranslations', null, derived],
    ['contentTranslationLeases', null, none],
    ['contentTranslationObjectUsage', null, none],
    ['contentTranslationBudgets', null, none],
    ['contentTranslationCostLedger', null, none],
  ]),
  ...rows('config', null, [
    ['platformFeatureFlagRevisions', null, none],
    ['platformActiveFeatureFlagPointers', null, none],
    ['referenceMarketConfigRevisions', null, none],
    ['referenceActivationPointers', null, none],
    ['platformReleaseManifests', null, none],
    ['platformActiveReleasePointers', null, none],
  ]),
]);

/** The registry rows one privacy domain answers for. */
export function privacyRegistryRows(domainId: string): readonly PrivacyRegistryEntry[] {
  return privacyWriterRegistry.filter((entry) => entry.domainId === domainId);
}

/**
 * Coverage check used by the registry test: every written collection has a
 * row, every dispatched domain has a handler and every row's domain is one a
 * full erasure dispatches. Returns the gaps; an empty list means covered.
 */
export function privacyRegistryGaps(input: {
  readonly writtenCollections: readonly string[];
  readonly handlerDomainIds: readonly string[];
  readonly registry?: readonly PrivacyRegistryEntry[];
}): readonly string[] {
  const registry = input.registry ?? privacyWriterRegistry;
  const registered = new Set(registry.map((entry) => entry.collection));
  const gaps = [
    ...input.writtenCollections
      .filter((collection) => !registered.has(collection))
      .map((collection) => `collection_unregistered:${collection}`),
    ...privacyErasureDomainIds
      .filter((domainId) => !input.handlerDomainIds.includes(domainId))
      .map((domainId) => `handler_missing:${domainId}`),
    ...registry
      .filter(
        (entry) =>
          entry.domainId !== null &&
          !(privacyErasureDomainIds as readonly string[]).includes(entry.domainId),
      )
      .map((entry) => `domain_unknown:${entry.domainId}:${entry.collection}`),
    ...registry
      .filter(
        (entry) =>
          entry.domainId === null &&
          (entry.erasure.kind === 'delete' ||
            entry.erasure.kind === 'anonymize' ||
            entry.erasure.kind === 'blocked'),
      )
      .map((entry) => `domain_missing:${entry.collection}`),
  ];
  return Object.freeze([...new Set(gaps)].sort());
}
