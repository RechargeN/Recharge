import { standProject } from './stand_plan.js';

const forbiddenEnvironmentNames = Object.freeze([
  'GOOGLE_APPLICATION_CREDENTIALS',
  'CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE',
  'FIREBASE_TOKEN',
  'GOOGLE_OAUTH_ACCESS_TOKEN',
  'GOOGLE_REFRESH_TOKEN',
  'FIREBASE_CONFIG',
]);
const expectedHosts = Object.freeze({
  FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
  FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
});

export class StandGuardError extends Error {}

/** The seed refuses anything that is not the loopback demo-recharge Emulator stand. */
export function assertStandEnvironment(env: NodeJS.ProcessEnv): void {
  for (const name of forbiddenEnvironmentNames) {
    if (Object.hasOwn(env, name)) throw new StandGuardError(`forbidden environment name: ${name}`);
  }
  for (const name of ['GCLOUD_PROJECT', 'GOOGLE_CLOUD_PROJECT']) {
    if (env[name] !== undefined && env[name] !== standProject) {
      throw new StandGuardError(`${name} must be ${standProject}`);
    }
  }
  if (env.GCLOUD_PROJECT !== standProject) {
    throw new StandGuardError(`GCLOUD_PROJECT must be ${standProject}`);
  }
  if (env.FUNCTIONS_EMULATOR !== 'true') {
    throw new StandGuardError('FUNCTIONS_EMULATOR must be true');
  }
  for (const [name, expected] of Object.entries(expectedHosts)) {
    if (env[name] !== expected) throw new StandGuardError(`${name} must be ${expected}`);
  }
  for (const name of ['FIREBASE_STORAGE_EMULATOR_HOST', 'PUBSUB_EMULATOR_HOST']) {
    const value = env[name];
    if (value !== undefined && !/^127\.0\.0\.1:\d+$/u.test(value)) {
      throw new StandGuardError(`${name} must be loopback`);
    }
  }
}

export function isAuthUserNotFound(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    (error as { code?: unknown }).code === 'auth/user-not-found'
  );
}
