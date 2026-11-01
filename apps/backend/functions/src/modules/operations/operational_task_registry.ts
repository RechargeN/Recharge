import { deepFreeze } from '../../shared/immutable.js';
import {
  bookingFlagIds,
  catalogFlagIds,
  contentFlagIds,
  contentTranslationFlagIds,
  mediaFlagIds,
  notificationsFlagIds,
  operationsEmergencySwitchIds,
} from '../../shared/feature_flags.js';

/**
 * L2 registry of operational task families (OPERATIONS_L2_RECOVERY_AMENDMENT.md
 * §2–5): who owns each queue, what proves its effect and how it recovers. Data
 * only: every effect stays in the owning module. A trigger in `index.ts` or a
 * source file with queue markers that no family claims, or a family without a
 * recovery path or named blocker, fails the coverage test.
 */
export type OperationalFamilyId =
  | 'TF-01'
  | 'TF-02'
  | 'TF-03'
  | 'TF-04'
  | 'TF-05'
  | 'TF-06'
  | 'TF-07'
  | 'TF-08'
  | 'TF-09'
  | 'TF-10'
  | 'TF-11'
  | 'TF-12'
  | 'TF-13'
  | 'TF-14'
  | 'TF-15';

export type RecoveryMechanism =
  /** Token + generation fence every later write of a lost worker. */
  | 'lease_fencing'
  | 'retry_budget'
  | 'dead_letter'
  | 'operator_replay'
  | 'reconciliation'
  /** Own checkpoint moves only with the receipt; a stopped run resumes from it. */
  | 'checkpoint_resume'
  /** A retry first reads the owner's receipt of an earlier attempt. */
  | 'owner_receipt'
  /** A named non-terminal state that the next run continues. */
  | 'resumable_state'
  /** An idempotent full pass that may simply run again. */
  | 'idempotent_rescan';

export const operationsBlockers = [
  'OB-01',
  'OB-02',
  'OB-03',
  'OB-04',
  'OB-05',
  'OB-06',
  'OB-07',
  'OB-08',
  'OB-09',
] as const;
export type OperationsBlocker = (typeof operationsBlockers)[number];

export interface OperationalTaskFamily {
  readonly id: OperationalFamilyId;
  readonly name: string;
  readonly owner: string;
  readonly producer: string;
  readonly consumer: string;
  readonly effect: string;
  /** What proves the effect happened; a checkpoint alone never does. */
  readonly receipt: string;
  /** `src`-relative files that hold this family's queue or worker. */
  readonly sources: readonly string[];
  /** Exported Cloud Function triggers that dispatch it. */
  readonly triggers: readonly string[];
  readonly recovery: readonly RecoveryMechanism[];
  /** L2 emergency switch the console turns; checked at dispatch and before the effect. */
  readonly emergencySwitchId: string | null;
  /** Existing default-off activation flag of the consumer; checked when a run starts. */
  readonly activationFlagId: string | null;
  /** Operator actions the L2 console serves for this family. */
  readonly console: Readonly<{ inspect: boolean; replay: boolean; reconcile: boolean }>;
  readonly blockers: readonly OperationsBlocker[];
}

const noConsole = { inspect: false, replay: false, reconcile: false } as const;

/** `src`-relative path of a module file. */
function mod(module: string, file: string): string {
  return ['modules', module, file].join('/');
}

export const operationalTaskRegistry: readonly OperationalTaskFamily[] = deepFreeze([
  {
    id: 'TF-01',
    name: 'Event → Booking projection delivery',
    owner: 'booking',
    producer: 'content handoff → eventBookingOutbox',
    consumer: 'booking projection delivery',
    effect: 'bookingEventProjections and occurrence lifecycle',
    receipt: 'projection revisions + sourceEventDigest',
    sources: ['booking/event_projection_delivery.ts', 'booking/event_projection_runtime.ts'],
    triggers: ['consumeEventBookingOutboxV1', 'retryEventBookingProjectionDeliveriesV1'],
    recovery: [
      'lease_fencing',
      'retry_budget',
      'dead_letter',
      'operator_replay',
      'owner_receipt',
      'reconciliation',
    ],
    emergencySwitchId: operationsEmergencySwitchIds.eventProjectionDelivery,
    activationFlagId: bookingFlagIds.eventProjectionDelivery,
    console: { inspect: true, replay: true, reconcile: true },
    blockers: ['OB-01', 'OB-02', 'OB-07', 'OB-09'],
  },
  {
    id: 'TF-02',
    name: 'Reconfirmation deadline',
    owner: 'booking',
    producer: 'discovery over bookings',
    consumer: 'reconfirmation deadline worker',
    effect: 'auto-cancel of the booking with key, usage, ledger, audit and outbox',
    receipt: 'booking state and reconfirmation revision; job outcome',
    sources: ['booking/reconfirmation_deadline_worker.ts'],
    triggers: ['releaseMissedReconfirmationsV1'],
    recovery: ['lease_fencing', 'retry_budget', 'dead_letter', 'operator_replay', 'owner_receipt'],
    emergencySwitchId: operationsEmergencySwitchIds.reconfirmationDeadlineWorker,
    activationFlagId: bookingFlagIds.reconfirmationDeadlineWorker,
    console: { inspect: true, replay: true, reconcile: false },
    blockers: ['OB-01', 'OB-02', 'OB-07', 'OB-09'],
  },
  {
    id: 'TF-03',
    name: 'Booking notification obligation',
    owner: 'notifications',
    producer: 'booking → bookingOutbox',
    consumer: 'notification effect consumer',
    effect: 'inbox item',
    receipt: 'notificationEffectReceipts + attempt records',
    sources: [
      mod('notifications', 'application/consume_notification_effect.ts'),
      mod('notifications', 'application/notification_reconciler.ts'),
      mod('notifications', 'domain/delivery_attempt.ts'),
      mod('notifications', 'infrastructure/firestore_notifications_repository.ts'),
      mod('notifications', 'infrastructure/in_memory_notifications_repository.ts'),
      // The operations port reads receipt lease and retry fields.
      'notifications_entry.ts',
    ],
    triggers: ['consumeNotificationEffectV1'],
    recovery: [
      'lease_fencing',
      'retry_budget',
      'dead_letter',
      'operator_replay',
      'owner_receipt',
      'reconciliation',
    ],
    emergencySwitchId: operationsEmergencySwitchIds.notificationsConsumeBooking,
    activationFlagId: notificationsFlagIds.consumeBooking,
    console: { inspect: true, replay: true, reconcile: true },
    blockers: ['OB-01', 'OB-07', 'OB-08', 'OB-09'],
  },
  {
    id: 'TF-04',
    name: 'Content → Catalog delivery',
    owner: 'catalog',
    producer: 'contentEffects',
    consumer: 'catalog projector',
    effect: 'catalog item versions in the active set',
    receipt: 'catalogFactReceipts + set checkpoint',
    sources: ['content_effects_entry.ts', mod('catalog', 'application/catalog_projector.ts')],
    triggers: ['consumeContentEffectV1'],
    recovery: ['checkpoint_resume', 'owner_receipt', 'reconciliation'],
    emergencySwitchId: null,
    activationFlagId: catalogFlagIds.delivery,
    console: noConsole,
    blockers: ['OB-03', 'OB-07'],
  },
  {
    id: 'TF-05',
    name: 'Content → Booking handoff',
    owner: 'content',
    producer: 'contentEffects',
    consumer: 'event booking handoff',
    effect: 'eventBookingOutbox fact',
    receipt: 'eventBookingHandoffReceipts and per-object state',
    sources: [
      mod('content', 'application/event_booking_handoff.ts'),
      mod('content', 'infrastructure/firestore_event_booking_handoff_repository.ts'),
    ],
    triggers: ['consumeContentEffectV1'],
    recovery: ['checkpoint_resume', 'owner_receipt', 'reconciliation'],
    emergencySwitchId: null,
    activationFlagId: contentFlagIds.eventBookingHandoff,
    console: noConsole,
    blockers: ['OB-07'],
  },
  {
    id: 'TF-06',
    name: 'Content ↔ Media availability',
    owner: 'content',
    producer: 'contentEffects and mediaEffects',
    consumer: 'content media availability',
    effect: 'media suppression in the publication pointer',
    receipt: 'contentMediaAvailabilityReceipts + status checkpoint',
    sources: [
      'media_effects_entry.ts',
      mod('content', 'application/content_media_availability.ts'),
    ],
    triggers: ['consumeMediaEffectV1', 'consumeContentEffectV1', 'reconcileMediaReferencesV1'],
    recovery: ['checkpoint_resume', 'owner_receipt', 'reconciliation'],
    emergencySwitchId: null,
    activationFlagId: contentFlagIds.mediaAvailability,
    console: noConsole,
    blockers: ['OB-03', 'OB-07'],
  },
  {
    id: 'TF-07',
    name: 'Media orphan sweep R2',
    owner: 'media',
    producer: 'schedule',
    consumer: 'orphan sweep',
    effect: 'abandoned attempt or deleted orphan',
    receipt: 'processing receipt or deletion status',
    sources: [
      mod('media', 'application/orphan_sweep.ts'),
      mod('media', 'application/orphan_reconciler.ts'),
    ],
    triggers: ['reconcileMediaReferencesV1'],
    recovery: ['idempotent_rescan', 'reconciliation'],
    emergencySwitchId: null,
    activationFlagId: mediaFlagIds.reconcile,
    console: noConsole,
    blockers: ['OB-07'],
  },
  {
    id: 'TF-08',
    name: 'Media deletion',
    owner: 'media',
    producer: 'owner deleteAsset and DSR',
    consumer: 'media deletion service',
    effect: 'Storage source and variants removed',
    receipt: 'mediaDeletionStatuses completed',
    sources: [mod('media', 'application/media_deletion_service.ts')],
    triggers: [],
    recovery: ['resumable_state', 'owner_receipt'],
    // Privacy deletion is a safe exit and never behind a flag.
    emergencySwitchId: null,
    activationFlagId: null,
    console: noConsole,
    blockers: [],
  },
  {
    id: 'TF-09',
    name: 'Media processing attempt',
    owner: 'media',
    producer: 'upload finalize',
    consumer: 'scan and process through local tools',
    effect: 'variants and lifecycle',
    receipt: 'mediaProcessingReceipts, immutable per attempt',
    sources: [
      mod('media', 'application/media_service.ts'),
      mod('media', 'domain/media_policy.ts'),
      mod('media', 'infrastructure/emulator_media_composition.ts'),
      'contracts/media_v1.ts',
    ],
    triggers: [],
    recovery: ['retry_budget', 'owner_receipt', 'reconciliation'],
    emergencySwitchId: null,
    activationFlagId: mediaFlagIds.upload,
    console: noConsole,
    blockers: ['OB-07'],
  },
  {
    id: 'TF-10',
    name: 'DSR domain task',
    owner: 'privacy_orchestration',
    producer: 'privacy request intake',
    consumer: 'privacy domain task runner',
    effect: 'owner handlers per domain',
    receipt: 'task outcome, sweep checkpoint and final verification',
    sources: [
      mod('privacy_orchestration', 'application/privacy_domain_task_runner.ts'),
      mod('privacy_orchestration', 'application/privacy_orchestration_service.ts'),
      mod('privacy_orchestration', 'domain/privacy_domain_task.ts'),
      mod('privacy_orchestration', 'infrastructure/firestore_privacy_subject_sweep.ts'),
      mod('privacy_orchestration', 'infrastructure/registry_privacy_task_handler.ts'),
      // Restore admission re-applies DSR tasks with the same runner (OPS-L2 §6).
      mod('operations', 'restore_admission.ts'),
    ],
    triggers: [],
    recovery: [
      'lease_fencing',
      'retry_budget',
      'checkpoint_resume',
      'resumable_state',
      'reconciliation',
    ],
    emergencySwitchId: null,
    activationFlagId: null,
    console: noConsole,
    blockers: ['OB-04'],
  },
  {
    id: 'TF-11',
    name: 'Find People exact-location purge',
    owner: 'content',
    producer: 'schedule',
    consumer: 'find people retention purge',
    effect: 'exact meeting data redacted',
    receipt: 'draft revision and audit entry without values',
    sources: [mod('content', 'infrastructure/find_people_private_location_retention.ts')],
    triggers: ['purgeFindPeoplePrivateLocationsV1'],
    recovery: ['idempotent_rescan'],
    emergencySwitchId: null,
    activationFlagId: null,
    console: noConsole,
    blockers: [],
  },
  {
    id: 'TF-12',
    name: 'Booking retention TTL',
    owner: 'booking',
    producer: 'expiresAt on Booking records',
    consumer: 'provider TTL (absent locally)',
    effect: 'physical deletion',
    receipt: 'none locally',
    sources: ['booking/retention.ts'],
    triggers: [],
    recovery: [],
    emergencySwitchId: null,
    activationFlagId: null,
    console: noConsole,
    blockers: ['OB-05'],
  },
  {
    id: 'TF-13',
    name: 'K3 repair execution',
    owner: 'admin_support',
    producer: 'approved repair proposal',
    consumer: 'admin support execute',
    effect: 'moderation decision and content disposition',
    receipt: 'owner receipt per step',
    sources: [mod('admin_support', 'admin_support_service.ts')],
    triggers: [],
    recovery: ['resumable_state', 'owner_receipt'],
    emergencySwitchId: null,
    activationFlagId: 'moderation.staff',
    console: noConsole,
    blockers: ['OB-01'],
  },
  {
    id: 'TF-14',
    name: 'Content local import (D4)',
    owner: 'content',
    producer: 'client import session',
    consumer: 'content local import lifecycle',
    effect: 'imported drafts',
    receipt: 'import binding',
    sources: [mod('content', 'domain/local_import_binding.ts'), 'contracts/content_v1.ts'],
    triggers: [],
    recovery: ['lease_fencing', 'resumable_state', 'owner_receipt'],
    emergencySwitchId: null,
    activationFlagId: null,
    console: noConsole,
    blockers: [],
  },
  {
    id: 'TF-15',
    name: 'Content translation on request and cache purge (ADR 0022)',
    owner: 'content_translation',
    producer: 'reader request; contentPublicationPointers or contentSafetyHolds change',
    consumer: 'content translation provider call and cache purge',
    effect: 'contentTranslations entry or its removal',
    receipt: 'cache entry + cost ledger row, under the lease token',
    sources: [mod('content_translation', 'firestore_content_translation_service.ts')],
    triggers: [
      'purgeContentTranslationsV1',
      'purgeContentTranslationsOnHoldV1',
      'sweepContentTranslationsV1',
    ],
    recovery: ['lease_fencing', 'idempotent_rescan'],
    emergencySwitchId: operationsEmergencySwitchIds.contentTranslation,
    activationFlagId: contentTranslationFlagIds.onDemand,
    console: noConsole,
    blockers: [],
  },
]);

export function operationalFamily(id: string): OperationalTaskFamily | undefined {
  return operationalTaskRegistry.find((family) => family.id === id);
}

/** Mechanisms that let a stopped or failed task continue; lease or receipt alone do not. */
const continuing: readonly RecoveryMechanism[] = [
  'retry_budget',
  'operator_replay',
  'reconciliation',
  'checkpoint_resume',
  'resumable_state',
  'idempotent_rescan',
];

/**
 * Compares the registry with what the sources show: every trigger and every
 * file with queue markers belongs to a family, and every family either can
 * continue after a failure or names the blocker that stops it. An empty list
 * means covered.
 */
export function operationalRegistryGaps(input: {
  readonly triggers: readonly string[];
  readonly workerFiles: readonly string[];
  readonly registry?: readonly OperationalTaskFamily[];
}): string[] {
  const registry = input.registry ?? operationalTaskRegistry;
  const gaps: string[] = [];
  const claimedTriggers = new Set(registry.flatMap((family) => family.triggers));
  const claimedFiles = new Set(registry.flatMap((family) => family.sources));
  for (const trigger of input.triggers)
    if (!claimedTriggers.has(trigger)) gaps.push(`trigger_unregistered:${trigger}`);
  for (const file of input.workerFiles)
    if (!claimedFiles.has(file)) gaps.push(`worker_unregistered:${file}`);
  for (const family of registry) {
    const recovers = family.recovery.some((mechanism) => continuing.includes(mechanism));
    if (!recovers && family.blockers.length === 0) gaps.push(`recovery_missing:${family.id}`);
    if (family.recovery.includes('dead_letter') && !family.recovery.includes('operator_replay'))
      gaps.push(`dead_letter_without_replay:${family.id}`);
    if (family.console.replay && !family.recovery.includes('dead_letter'))
      gaps.push(`replay_without_dead_letter:${family.id}`);
  }
  return gaps.sort();
}
