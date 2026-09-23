import { getApp, getApps, initializeApp, type App } from 'firebase-admin/app';

export interface EmulatorFirebaseContext {
  readonly projectId: 'demo-recharge';
  readonly firestoreHost: string;
}

export function resolveEmulatorFirebaseContext(
  environment: NodeJS.ProcessEnv,
): EmulatorFirebaseContext | null {
  const firestoreHost = environment.FIRESTORE_EMULATOR_HOST;
  if (
    environment.FUNCTIONS_EMULATOR !== 'true' ||
    environment.GCLOUD_PROJECT !== 'demo-recharge' ||
    firestoreHost === undefined ||
    !isLoopbackHost(firestoreHost)
  ) {
    return null;
  }
  return Object.freeze({ projectId: 'demo-recharge', firestoreHost });
}

export function getOrCreateEmulatorAdminApp(environment: NodeJS.ProcessEnv): App | null {
  const context = resolveEmulatorFirebaseContext(environment);
  if (context === null) return null;
  return getApps().length > 0 ? getApp() : initializeApp({ projectId: context.projectId });
}

function isLoopbackHost(host: string): boolean {
  return /^(?:127\.0\.0\.1|localhost|\[::1\]):\d{2,5}$/.test(host);
}
