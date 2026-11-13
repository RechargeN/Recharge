import assert from 'node:assert/strict';
import test from 'node:test';

import { DevFirebaseProviderIdentityVerifier } from '../../../src/modules/identity_publisher/infrastructure/dev_firebase_provider_identity_verifier.js';
import { DevIdentitySessionBinding } from '../../../src/modules/identity_publisher/infrastructure/dev_identity_session_binding.js';
import {
  cloudToolsConfigFrom,
  cloudToolsUrlsFor,
  devCloudToolsUrls,
} from '../../../src/modules/media/infrastructure/cloud_tools_client.js';
import { assertDevCloudStorageContext } from '../../../src/modules/media/infrastructure/dev_cloud_object_store.js';
import { DevFirebaseAppCheckPort } from '../../../src/platform/adapters/dev_firebase_app_check.js';
import {
  cloudProjectNumber,
  cloudRuntimeProject,
  devCloudProject,
  isReviewedCloudProject,
  loadTimeCloudProject,
  mediaBucketFor,
  reviewedCloudProjects,
  runtimeServiceAccount,
  stagingCloudProject,
} from '../../../src/shared/cloud_runtime_projects.js';

// N4a (owner-approved 2026-11-13): one release candidate runs in dev and then in
// staging; production and any other project are refused everywhere.

const stagingNumber = '123456789012';
const token = 'a'.repeat(64);

void test('exactly dev and staging are reviewed; production never', () => {
  assert.deepEqual(reviewedCloudProjects, ['recharge-dev-n2a01', 'recharge-staging-y9y2y']);
  for (const other of ['recharge-prod', 'recharge-production', 'demo-recharge', '', undefined])
    assert.equal(isReviewedCloudProject(other), false, String(other));
  assert.equal(loadTimeCloudProject({}), devCloudProject);
  assert.equal(loadTimeCloudProject({ GCLOUD_PROJECT: stagingCloudProject }), stagingCloudProject);
  assert.throws(() => loadTimeCloudProject({ GCLOUD_PROJECT: 'recharge-prod' }));
  assert.equal(cloudRuntimeProject({ GCLOUD_PROJECT: stagingCloudProject }), stagingCloudProject);
  assert.equal(
    cloudRuntimeProject({ GCLOUD_PROJECT: devCloudProject, FIRESTORE_EMULATOR_HOST: 'x' }),
    null,
  );
  assert.equal(
    runtimeServiceAccount('runtime-media', stagingCloudProject),
    'runtime-media@recharge-staging-y9y2y.iam.gserviceaccount.com',
  );
  assert.equal(mediaBucketFor(stagingCloudProject), 'recharge-staging-y9y2y-media');
});

void test('project numbers: fixed for dev, configured for staging, never contradicted', () => {
  assert.equal(cloudProjectNumber(devCloudProject, {}), '420479958348');
  assert.equal(
    cloudProjectNumber(devCloudProject, { RECHARGE_PROJECT_NUMBER: '420479958348' }),
    '420479958348',
  );
  assert.equal(
    cloudProjectNumber(devCloudProject, { RECHARGE_PROJECT_NUMBER: stagingNumber }),
    null,
  );
  assert.equal(cloudProjectNumber(stagingCloudProject, {}), null);
  assert.equal(
    cloudProjectNumber(stagingCloudProject, { RECHARGE_PROJECT_NUMBER: stagingNumber }),
    stagingNumber,
  );
  assert.equal(cloudProjectNumber(stagingCloudProject, { RECHARGE_PROJECT_NUMBER: '12ab' }), null);
});

void test('identity, App Check and the Session binding accept staging, refuse others', () => {
  const verify = () => Promise.reject(new Error('unused'));
  assert.doesNotThrow(() => new DevFirebaseProviderIdentityVerifier(stagingCloudProject, verify));
  assert.throws(() => new DevFirebaseProviderIdentityVerifier('recharge-prod', verify));
  const stagingApp = `1:${stagingNumber}:android:abcdef123456`;
  const env = { RECHARGE_PROJECT_NUMBER: stagingNumber };
  assert.doesNotThrow(
    () => new DevFirebaseAppCheckPort(stagingCloudProject, [stagingApp], verify, () => 0, env),
  );
  // A dev app id cannot be used with the staging number, and staging needs its number.
  assert.throws(
    () =>
      new DevFirebaseAppCheckPort(
        stagingCloudProject,
        ['1:420479958348:android:abcdef123456'],
        verify,
        () => 0,
        env,
      ),
  );
  assert.throws(
    () => new DevFirebaseAppCheckPort(stagingCloudProject, [stagingApp], verify, () => 0, {}),
  );
  const construct = (project: string) =>
    new DevIdentitySessionBinding(project, {} as never, {} as never, {} as never, {} as never);
  assert.doesNotThrow(() => construct(stagingCloudProject));
  assert.throws(() => construct('recharge-prod'));
});

void test('Media storage and tools bind to the project they run in', () => {
  const staging = {
    RECHARGE_MEDIA_STORAGE: 'dev-cloud',
    GCLOUD_PROJECT: stagingCloudProject,
  };
  assert.doesNotThrow(() => assertDevCloudStorageContext('recharge-staging-y9y2y-media', staging));
  assert.throws(() => assertDevCloudStorageContext('recharge-dev-n2a01-media', staging));
  assert.throws(() =>
    assertDevCloudStorageContext('recharge-prod-media', {
      ...staging,
      GCLOUD_PROJECT: 'recharge-prod',
    }),
  );
  const idToken = () => Promise.resolve('id');
  const tools = cloudToolsConfigFrom(
    {
      RECHARGE_MEDIA_TOOLS: 'dev-cloud',
      GCLOUD_PROJECT: stagingCloudProject,
      RECHARGE_PROJECT_NUMBER: stagingNumber,
      RECHARGE_MEDIA_TOOLS_TOKEN: token,
    },
    idToken,
  );
  assert.equal(tools?.scanner.url, cloudToolsUrlsFor(stagingNumber).scanner);
  assert.equal(tools?.processor.url, 'https://media-processor-123456789012.europe-west1.run.app');
  const dev = cloudToolsConfigFrom(
    {
      RECHARGE_MEDIA_TOOLS: 'dev-cloud',
      GCLOUD_PROJECT: devCloudProject,
      RECHARGE_MEDIA_TOOLS_TOKEN: token,
    },
    idToken,
  );
  assert.equal(dev?.scanner.url, devCloudToolsUrls.scanner);
  assert.throws(() =>
    cloudToolsConfigFrom(
      {
        RECHARGE_MEDIA_TOOLS: 'dev-cloud',
        GCLOUD_PROJECT: stagingCloudProject,
        RECHARGE_MEDIA_TOOLS_TOKEN: token,
      },
      idToken,
    ),
  );
});
