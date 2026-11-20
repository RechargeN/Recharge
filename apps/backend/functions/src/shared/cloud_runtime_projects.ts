/**
 * N4a (owner-approved plan 2026-11-13): the reviewed non-production cloud
 * projects one release candidate may run in. The same artifact goes to dev and
 * then to staging; production is never listed here, so nothing in this code
 * base can bind to it.
 */
export const devCloudProject = 'recharge-dev-n2a01';
export const stagingCloudProject = 'recharge-staging-y9y2y';
export const reviewedCloudProjects = Object.freeze([devCloudProject, stagingCloudProject] as const);
export type ReviewedCloudProject = (typeof reviewedCloudProjects)[number];

/** Known project numbers; staging's is read from the deploy configuration. */
const knownProjectNumbers: Readonly<Partial<Record<ReviewedCloudProject, string>>> = Object.freeze({
  [devCloudProject]: '420479958348',
});

export function isReviewedCloudProject(value: unknown): value is ReviewedCloudProject {
  return reviewedCloudProjects.includes(value as ReviewedCloudProject);
}

/**
 * The project a deployed entry binds its options to at load. Unset (local
 * import: tests, tools) falls back to dev, which binds nothing by itself — every
 * request still checks `GCLOUD_PROJECT`. A set but unreviewed project fails the
 * load, so the Firebase CLI cannot deploy the entry anywhere else.
 */
export function loadTimeCloudProject(environment: NodeJS.ProcessEnv): ReviewedCloudProject {
  const value = environment.GCLOUD_PROJECT;
  if (value === undefined || value === '') return devCloudProject;
  if (!isReviewedCloudProject(value)) throw new Error('cloud_runtime_project_unreviewed');
  return value;
}

/** The running project when it is a reviewed one and no Emulator is configured; else null. */
export function cloudRuntimeProject(environment: NodeJS.ProcessEnv): ReviewedCloudProject | null {
  const value = environment.GCLOUD_PROJECT;
  if (
    !isReviewedCloudProject(value) ||
    environment.FIRESTORE_EMULATOR_HOST !== undefined ||
    environment.FIREBASE_AUTH_EMULATOR_HOST !== undefined
  )
    return null;
  return value;
}

/**
 * The project number (App Check audience, Cloud Run URLs). dev's is fixed; for
 * staging it comes from `RECHARGE_PROJECT_NUMBER` in the deploy `.env`, and a
 * value that disagrees with a known number is refused.
 */
export function cloudProjectNumber(
  projectId: ReviewedCloudProject,
  environment: NodeJS.ProcessEnv,
): string | null {
  const known = knownProjectNumbers[projectId];
  const configured = environment.RECHARGE_PROJECT_NUMBER;
  if (configured !== undefined && configured !== '') {
    if (!/^[0-9]{6,20}$/u.test(configured)) return null;
    if (known !== undefined && configured !== known) return null;
    return configured;
  }
  return known ?? null;
}

export function runtimeServiceAccount(name: string, projectId: ReviewedCloudProject): string {
  return `${name}@${projectId}.iam.gserviceaccount.com`;
}

export function mediaBucketFor(projectId: ReviewedCloudProject): string {
  return `${projectId}-media`;
}
