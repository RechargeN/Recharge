import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { error as logError } from 'firebase-functions/logger';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { bookingHandoffEffectConsumer, deliverContentEffects } from './content_effects_entry.js';
import { devCloudPersistenceSwitch } from './modules/content/infrastructure/firestore_content_repository.js';
import { emergencySwitchState } from './modules/operations/emergency_switch.js';
import { loadTimeCloudProject, runtimeServiceAccount } from './shared/cloud_runtime_projects.js';
import { contentFlagIds, operationsEmergencySwitchIds } from './shared/feature_flags.js';

// Round 2.2 (owner approval 2026-11-19), codebase n4f-content-effects. Not
// re-exported by index.ts. The only Content effect consumer in the cloud is
// the Event → Booking handoff: committed internal-registration Events become
// `eventBookingOutbox` facts, which the n4c-booking workers deliver. Catalog
// and every other consumer stay Emulator-only.
const projectId = loadTimeCloudProject(process.env);

function app() {
  const existing = getApps().find((candidate) => candidate.name === 'recharge-dev-effects');
  if (existing !== undefined && existing.options.projectId !== projectId)
    throw new Error('binding');
  return existing ?? initializeApp({ projectId }, 'recharge-dev-effects');
}

/** Runtime switch: the reviewed project, the Media-chain cloud switch, no Emulator. */
export function devContentEffectsOpen(environment: NodeJS.ProcessEnv): boolean {
  return (
    environment.GCLOUD_PROJECT === projectId &&
    environment.N4F_CONTENT_EFFECTS_ENABLED === 'true' &&
    environment[devCloudPersistenceSwitch.name] === devCloudPersistenceSwitch.value &&
    environment.FIRESTORE_EMULATOR_HOST === undefined
  );
}

/**
 * In the cloud the handoff runs only while its Operations emergency switch is
 * open (round 2.1: a missing switch is contained). Every other consumer is off.
 */
export function cloudEffectFlags(firestore: Firestore) {
  return {
    async isEnabled(flagId: string): Promise<boolean> {
      if (flagId !== contentFlagIds.eventBookingHandoff) return false;
      return (
        (await emergencySwitchState(
          firestore,
          operationsEmergencySwitchIds.contentEventBookingHandoff,
        )) === 'open'
      );
    },
  };
}

export const consumeContentEffectV1 = onDocumentCreated(
  {
    document: 'contentEffects/{effectId}',
    region: 'europe-west1',
    retry: false,
    memory: '256MiB',
    cpu: 1,
    timeoutSeconds: 120,
    minInstances: 0,
    maxInstances: 1,
    // Round 2.2: Firestore IAM is database-wide, so a separate account adds no
    // isolation; the Booking runtime account (already on this database) runs it.
    serviceAccount: runtimeServiceAccount('runtime-booking', projectId),
  },
  async () => {
    if (!devContentEffectsOpen(process.env)) return;
    const firestore = getFirestore(app());
    const outcomes = await deliverContentEffects(firestore, {
      flags: cloudEffectFlags(firestore),
      consumers: [bookingHandoffEffectConsumer()],
    });
    for (const outcome of outcomes)
      if (outcome.status === 'failed' || outcome.status === 'stopped')
        logError('content_effect_consumer_incomplete', outcome);
  },
);
