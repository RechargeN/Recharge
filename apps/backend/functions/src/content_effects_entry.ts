import type { Firestore } from 'firebase-admin/firestore';

import { createEmulatorCatalogComposition } from './modules/catalog/infrastructure/emulator_catalog_composition.js';
import { createEmulatorEventBookingHandoff } from './modules/content/infrastructure/firestore_event_booking_handoff_repository.js';
import { catalogFlagIds, contentFlagIds } from './shared/feature_flags.js';
import type { ServerClock } from './shared/server_clock.js';

export interface EffectFlagPort {
  isEnabled(flagId: string): Promise<boolean>;
}

export type ConsumerStatus = 'disabled' | 'completed' | 'stopped' | 'failed';

export interface ConsumerOutcome {
  readonly consumer: string;
  readonly status: ConsumerStatus;
  /** Why a run stopped or failed; the consumer's own checkpoint stays put. */
  readonly detail?: string;
}

/**
 * One downstream reader of committed Content effects. Each consumer keeps its
 * own checkpoint and receipts: a run resumes from its own position, so a
 * failure of one never marks, skips or blocks another.
 */
export interface ContentEffectConsumer {
  readonly name: string;
  readonly flagId: string;
  run(
    firestore: Firestore,
  ): Promise<{ readonly status: 'completed' | 'stopped'; readonly detail?: string }>;
}

/** The E1 Catalog projector: delivery up to the end of the effect feed. */
export function catalogEffectConsumer(clock?: ServerClock): ContentEffectConsumer {
  return {
    name: 'catalog',
    flagId: catalogFlagIds.delivery,
    async run(firestore) {
      const catalog = createEmulatorCatalogComposition(
        firestore,
        clock === undefined ? {} : { clock },
      );
      const active = await catalog.sets.ensureActive();
      const report = await catalog.projector.deliverFromContent(active.setId);
      return report.stoppedAt === null
        ? { status: 'completed' }
        : { status: 'stopped', detail: `${report.stoppedAt.code}:${report.stoppedAt.effectId}` };
    },
  };
}

/**
 * The Content-owned Event → Booking handoff (E2.0): internal-registration
 * Events become `eventBookingOutbox` facts; Booking delivers them with its own
 * delivery records.
 */
export function bookingHandoffEffectConsumer(clock?: ServerClock): ContentEffectConsumer {
  return {
    name: 'bookingHandoff',
    flagId: contentFlagIds.eventBookingHandoff,
    async run(firestore) {
      const { handoff } = createEmulatorEventBookingHandoff(
        firestore,
        clock === undefined ? {} : { clock },
      );
      const report = await handoff.deliver();
      return report.stoppedAt === null
        ? { status: 'completed' }
        : { status: 'stopped', detail: `${report.stoppedAt.code}:${report.stoppedAt.effectId}` };
    },
  };
}

export function defaultEffectConsumers(clock?: ServerClock): readonly ContentEffectConsumer[] {
  return [catalogEffectConsumer(clock), bookingHandoffEffectConsumer(clock)];
}

function safeName(error: unknown): string {
  return error instanceof Error && /^[A-Za-z][A-Za-z0-9]*$/u.test(error.name)
    ? error.name
    : 'UnknownError';
}

/**
 * Body of the Emulator-only `consumeContentEffectV1` trigger (E2). Every
 * enabled consumer runs independently and in order; there is no shared
 * "processed" mark. A consumer that throws is reported as failed while the
 * others still run; its own checkpoint was not advanced, so the next trigger or
 * the stand command resumes it even if no further Content effect ever arrives.
 */
export async function deliverContentEffects(
  firestore: Firestore,
  options: {
    readonly flags: EffectFlagPort;
    readonly consumers?: readonly ContentEffectConsumer[];
  },
): Promise<readonly ConsumerOutcome[]> {
  const outcomes: ConsumerOutcome[] = [];
  for (const consumer of options.consumers ?? defaultEffectConsumers()) {
    let enabled: boolean;
    try {
      enabled = await options.flags.isEnabled(consumer.flagId);
    } catch (error) {
      outcomes.push({ consumer: consumer.name, status: 'failed', detail: safeName(error) });
      continue;
    }
    if (!enabled) {
      outcomes.push({ consumer: consumer.name, status: 'disabled' });
      continue;
    }
    try {
      const result = await consumer.run(firestore);
      outcomes.push({
        consumer: consumer.name,
        status: result.status,
        ...(result.detail === undefined ? {} : { detail: result.detail }),
      });
    } catch (error) {
      outcomes.push({ consumer: consumer.name, status: 'failed', detail: safeName(error) });
    }
  }
  return outcomes;
}
