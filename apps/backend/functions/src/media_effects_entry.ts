import type { Firestore } from 'firebase-admin/firestore';

import type {
  ConsumerOutcome,
  ContentEffectConsumer,
  EffectFlagPort,
} from './content_effects_entry.js';
import { mediaComposition } from './media_entry.js';
import {
  ContentMediaAvailability,
  type SweepReport,
} from './modules/content/application/content_media_availability.js';
import { ContentPublicationFeed } from './modules/content/infrastructure/content_publication_feed.js';
import { FirestoreContentRepository } from './modules/content/infrastructure/firestore_content_repository.js';
import type { OrphanSweepReport } from './modules/media/application/orphan_sweep.js';
import type { MediaRetentionPolicy } from './modules/media/domain/media_retention.js';
import { contentFlagIds, mediaFlagIds } from './shared/feature_flags.js';
import type { ServerClock } from './shared/server_clock.js';
import { systemServerClock } from './shared/server_clock.js';

/**
 * D2 (`MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md` §5, §8): Content's reaction to
 * late Media restriction or deletion, composed over the Emulator repositories.
 * Content answers from its own records, Media from its own; neither module
 * imports the other — only this entry wires them.
 */
export function contentMediaAvailability(
  firestore: Firestore,
  options: { readonly clock?: ServerClock } = {},
): ContentMediaAvailability {
  const media = mediaComposition(firestore, options);
  const repository = new FirestoreContentRepository(firestore);
  return new ContentMediaAvailability({
    repository,
    media: media.readiness,
    mediaFacts: media.effectFeed,
    contentFacts: new ContentPublicationFeed(firestore, repository),
    clock: options.clock ?? systemServerClock,
  });
}

function safeName(error: unknown): string {
  return error instanceof Error && /^[A-Za-z][A-Za-z0-9]*$/u.test(error.name)
    ? error.name
    : 'UnknownError';
}

/**
 * Body of the Emulator-only `consumeMediaEffectV1` trigger: Content reads the
 * Media facts after its own checkpoint. A stopped or failed run leaves the
 * checkpoint before the fact, so the next fact or the sweep resumes it.
 */
export async function deliverMediaEffects(
  firestore: Firestore,
  options: { readonly flags: EffectFlagPort; readonly clock?: ServerClock },
): Promise<ConsumerOutcome> {
  const consumer = 'mediaAvailability';
  try {
    if (!(await options.flags.isEnabled(contentFlagIds.mediaAvailability)))
      return { consumer, status: 'disabled' };
    const report = await contentMediaAvailability(firestore, options).deliverMediaEffects();
    return report.stoppedAt === null
      ? { consumer, status: 'completed' }
      : {
          consumer,
          status: 'stopped',
          detail: `${report.stoppedAt.code}:${report.stoppedAt.effectId}`,
        };
  } catch (error) {
    return { consumer, status: 'failed', detail: safeName(error) };
  }
}

/** (b) Content facts: a publication, activation or media change is checked again. */
export function mediaVerificationEffectConsumer(clock?: ServerClock): ContentEffectConsumer {
  return {
    name: 'mediaVerification',
    flagId: contentFlagIds.mediaAvailability,
    async run(firestore) {
      const report = await contentMediaAvailability(
        firestore,
        clock === undefined ? {} : { clock },
      ).deliverContentEffects();
      return report.stoppedAt === null
        ? { status: 'completed' }
        : { status: 'stopped', detail: `${report.stoppedAt.code}:${report.stoppedAt.effectId}` };
    },
  };
}

export interface MediaReconcileReport {
  /** R1: Content ↔ Media; `disabled` without `content.mediaAvailability`. */
  readonly references: SweepReport | 'disabled';
  /** R2: Media orphans; `disabled` without `media.reconcile`. */
  readonly orphans: OrphanSweepReport | 'disabled';
}

/**
 * Body of the Emulator-only `reconcileMediaReferencesV1` schedule and of the
 * stand command: R1, then R2. The runtime passes no retention policy, so R2
 * refuses with `policy_unavailable` and deletes nothing; only the D2 gate passes
 * its explicitly test-only policy (§8).
 */
export async function reconcileMediaReferences(
  firestore: Firestore,
  options: {
    readonly flags: EffectFlagPort;
    readonly clock?: ServerClock;
    readonly retention?: MediaRetentionPolicy;
  },
): Promise<MediaReconcileReport> {
  const clock = options.clock === undefined ? {} : { clock: options.clock };
  const references = (await options.flags.isEnabled(contentFlagIds.mediaAvailability))
    ? await contentMediaAvailability(firestore, clock).sweep()
    : 'disabled';
  const orphans = (await options.flags.isEnabled(mediaFlagIds.reconcile))
    ? await mediaComposition(firestore, {
        ...clock,
        ...(options.retention === undefined ? {} : { retention: options.retention }),
      }).orphanSweep.sweep()
    : 'disabled';
  return { references, orphans };
}
