import type { Firestore, Transaction } from 'firebase-admin/firestore';

import {
  featureFlagKey,
  featureFlagPointerCollection,
  featureFlagRevisionCollection,
} from '../../platform/config/feature_flag_repository.js';
import { featureFlagRevisionDocumentId } from '../../platform/config/firestore_feature_flag_gate.js';
import type { EnvironmentId } from '../../config/environment.js';
import { devCloudProject, stagingCloudProject } from '../../shared/cloud_runtime_projects.js';

export type EmergencySwitchState = 'open' | 'contained';

const emulatorVariables = [
  'FIRESTORE_EMULATOR_HOST',
  'FIREBASE_AUTH_EMULATOR_HOST',
  'FIREBASE_STORAGE_EMULATOR_HOST',
  'STORAGE_EMULATOR_HOST',
] as const;

/**
 * Round 2.1 (owner approval 2026-11-18): the environment whose switches this
 * runtime reads. The local Emulator (`demo-recharge`) is `local`; the reviewed
 * dev and staging projects are `dev` and `stage`, only with no Emulator
 * variable and a consistent project alias. Anything else — production, an
 * unknown project, a mixed setup — has no switches and stays contained.
 */
export function emergencySwitchEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): EnvironmentId | null {
  if (environment.FUNCTIONS_EMULATOR === 'true')
    return environment.GCLOUD_PROJECT === 'demo-recharge' ? 'local' : null;
  for (const name of emulatorVariables) if ((environment[name] ?? '') !== '') return null;
  const project = environment.GCLOUD_PROJECT;
  const alias = environment.GOOGLE_CLOUD_PROJECT;
  if (alias !== undefined && alias !== project) return null;
  if (project === devCloudProject) return 'dev';
  if (project === stagingCloudProject) return 'stage';
  return null;
}

/**
 * L2 emergency switch read (OPS-L2 §5). Unlike an activation flag it fails
 * closed: a pointer whose revision is missing, foreign or malformed, a read
 * error, or a runtime with no switch environment means contained. No pointer
 * means open on the local Emulator but contained in the cloud: dev and
 * staging open a switch only through an explicit operator revision
 * (round 2.1), so a deploy never opens anything by itself. Read it inside the
 * effect transaction when there is one.
 */
export async function emergencySwitchState(
  firestore: Firestore,
  switchId: string,
  transaction?: Transaction,
): Promise<EmergencySwitchState> {
  const environmentId = emergencySwitchEnvironment();
  if (environmentId === null) return 'contained';
  try {
    const key = featureFlagKey(environmentId, 'LV', switchId);
    const pointerRef = firestore.collection(featureFlagPointerCollection).doc(key);
    const pointer = (
      transaction === undefined ? await pointerRef.get() : await transaction.get(pointerRef)
    ).data();
    if (pointer === undefined) return environmentId === 'local' ? 'open' : 'contained';
    const activeRevision: unknown = pointer.activeRevision;
    if (
      pointer.key !== key ||
      typeof activeRevision !== 'number' ||
      !Number.isSafeInteger(activeRevision) ||
      activeRevision < 1
    )
      return 'contained';
    const revisionRef = firestore
      .collection(featureFlagRevisionCollection)
      .doc(featureFlagRevisionDocumentId(key, activeRevision));
    const revision = (
      transaction === undefined ? await revisionRef.get() : await transaction.get(revisionRef)
    ).data();
    if (
      revision?.schemaVersion !== 1 ||
      revision.environmentId !== environmentId ||
      revision.marketId !== 'LV' ||
      revision.capabilityId !== switchId ||
      revision.revision !== activeRevision ||
      typeof revision.enabled !== 'boolean'
    )
      return 'contained';
    return revision.enabled ? 'contained' : 'open';
  } catch {
    return 'contained';
  }
}
