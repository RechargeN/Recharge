import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { pathToFileURL } from 'node:url';

// The verifier is a plain ES module shared with the CI gate; its function is the
// single implementation of the manifest rules.
const backendRoot = path.resolve(process.cwd(), '..');
const verifier = (await import(
  pathToFileURL(path.join(backendRoot, 'scripts', 'verify-execution-manifest.mjs')).href
)) as { verifyExecutionManifest: (manifest: unknown) => string[] };
const manifestPath = path.join(backendRoot, 'config', 'manifests', 'execution-manifest.json');

type Json = Record<string, unknown>;
const load = (): Json => JSON.parse(readFileSync(manifestPath, 'utf8')) as Json;
const check = (mutate: (manifest: Json) => void): string[] => {
  const manifest = load();
  mutate(manifest);
  return verifier.verifyExecutionManifest(manifest);
};
const env = (manifest: Json, name: string): Json =>
  (manifest.environments as Record<string, Json>)[name] as Json;
const hasProblem = (problems: string[], fragment: string): boolean =>
  problems.some((item) => item.includes(fragment));

void test('the committed execution manifest is consistent with the repository', () => {
  assert.deepEqual(verifier.verifyExecutionManifest(load()), []);
});

void test('the manifest names no provider project, secret value, address or authority', () => {
  const manifest = load();
  for (const name of ['dev', 'stage', 'prod']) {
    const item = env(manifest, name);
    assert.equal(item.projectId, null);
    assert.equal(item.projectIdSuffix, null);
    assert.equal(item.authorized, false);
    assert.deepEqual(item.secretReferences, []);
  }
  assert.equal((manifest.authority as Json).apply, 'denied');
  assert.equal((manifest.authority as Json).authorizationRef, null);
  assert.equal(/@|recharge-(dev|stage|prod)-[a-z0-9]{3,}/u.test(JSON.stringify(manifest)), false);
});

void test('an invented project id, a secret-like value or an address is rejected', () => {
  assert.ok(
    hasProblem(
      check((m) => {
        env(m, 'dev').projectId = 'recharge-dev-ab12cd';
      }),
      'schema',
    ),
  );
  assert.ok(
    hasProblem(
      check((m) => {
        (m.authority as Json).note = 'contact owner@example.com';
      }),
      'secret-like or address-like',
    ),
  );
  assert.ok(
    hasProblem(
      check((m) => {
        (m.authority as Json).note = 'see recharge-stage-ab12cd for the project';
      }),
      'invented provider project id',
    ),
  );
});

void test('collections, indexes and TTL must equal Rules and firestore.indexes.json', () => {
  const missing = check((m) => {
    const collections = (m.firestore as { collections: Json[] }).collections;
    collections.pop();
  });
  assert.ok(hasProblem(missing, 'denied in Rules but not listed'));
  const unknown = check((m) => {
    const collections = (m.firestore as { collections: Json[] }).collections;
    collections.push({
      name: 'contentGhost',
      clientAccess: 'deny',
      owner: 'firebase_cli',
      ttlFields: [],
      compositeIndexes: [],
    });
  });
  assert.ok(hasProblem(unknown, 'contentGhost has no explicit Rules deny'));
  const drift = check((m) => {
    const collections = (m.firestore as { collections: Json[] }).collections;
    const target = collections.find((item) => (item.ttlFields as string[]).length > 0);
    assert.ok(target);
    target.ttlFields = [];
  });
  assert.ok(hasProblem(drift, 'TTL fields differ'));
});

void test('flags equal the code registry, default off and have the right kind', () => {
  assert.ok(
    hasProblem(
      check((m) => {
        const flags = (m.flags as { flags: Json[] }).flags;
        flags.push({ id: 'booking.undeclared', kind: 'feature', defaultState: 'off' });
      }),
      'not in the code registry',
    ),
  );
  assert.ok(
    hasProblem(
      check((m) => {
        const flags = (m.flags as { flags: Json[] }).flags;
        (flags[0] as Json).defaultState = 'on';
      }),
      'schema',
    ),
  );
  assert.ok(
    hasProblem(
      check((m) => {
        const flags = (m.flags as { flags: Json[] }).flags;
        (flags[0] as Json).kind = 'emergencySwitch';
      }),
      'wrong kind',
    ),
  );
});

void test('locations and identities follow the accepted baseline and never cross environments', () => {
  assert.ok(
    hasProblem(
      check((m) => {
        ((m.locationPolicy as Json).firestore as Json).location = 'nam5';
      }),
      'schema',
    ),
  );
  assert.ok(
    hasProblem(
      check((m) => {
        const accounts = env(m, 'dev').serviceAccounts as Json[];
        accounts.push({
          name: 'deploy-prod',
          kind: 'deploy',
          purpose: 'foreign deploy identity',
          deployed: false,
          authorized: false,
        });
      }),
      'deploy-prod',
    ),
  );
  assert.ok(
    hasProblem(
      check((m) => {
        const accounts = env(m, 'stage').serviceAccounts as Json[];
        accounts.push({
          name: 'god-mode',
          kind: 'operator',
          purpose: 'not in the catalogue',
          deployed: false,
          authorized: false,
        });
      }),
      'not in the identity catalogue',
    ),
  );
});

void test('every resource has one owner and the Firebase CLI owns Rules, indexes, TTL and Functions', () => {
  assert.ok(
    hasProblem(
      check((m) => {
        (m.resourceOwners as Json[]).push({ resource: 'firestore.rules', owner: 'terraform' });
      }),
      'has two entries',
    ),
  );
  assert.ok(
    hasProblem(
      check((m) => {
        const owners = m.resourceOwners as Json[];
        (owners.find((item) => item.resource === 'firestore.ttl') as Json).owner = 'terraform';
      }),
      'must be owned by the Firebase CLI',
    ),
  );
});

void test('containment never blocks cancelling a Booking or a mandatory privacy operation', () => {
  for (const blocking of [
    'booking.cancel.incidentDisable',
    'booking.query.incidentDisable',
    'identity.session.issue.incidentDisable',
    'identity.session.rotate.incidentDisable',
  ])
    assert.ok(
      hasProblem(
        check((m) => {
          const budget = env(m, 'prod').budget as { containment: { killSwitchIds: string[] } };
          budget.containment.killSwitchIds.push(blocking);
        }),
        'can block booking.cancel',
      ),
      blocking,
    );
  assert.ok(
    hasProblem(
      check((m) => {
        const budget = env(m, 'dev').budget as { containment: { neverBlocked: string[] } };
        budget.containment.neverBlocked = budget.containment.neverBlocked.filter(
          (item) => item !== 'privacy.dsr.deletion',
        );
      }),
      'neverBlocked lacks privacy.dsr.deletion',
    ),
  );
  // No automatic billing detach and no hard-stop claim, in any environment.
  for (const name of ['dev', 'stage', 'prod']) {
    const budget = env(load(), name).budget as Json;
    assert.equal(budget.automaticBillingDetach, false);
    assert.equal(budget.hardStop, false);
    assert.equal(budget.status, 'proposed');
  }
  assert.ok(
    hasProblem(
      check((m) => {
        (env(m, 'stage').budget as Json).guardrailMonthlyEur = 500;
      }),
      'budget differs from the proposed',
    ),
  );
});

void test('the runbooks the manifest names exist', () => {
  assert.ok(
    hasProblem(
      check((m) => {
        (m.procedures as { runbooks: string[] }).runbooks.push('docs/runbooks/backend-missing.md');
      }),
      'is absent',
    ),
  );
});

void test('validation workflow cannot become the WIF deployment identity', () => {
  assert.ok(
    hasProblem(
      check((m) => {
        (env(m, 'dev').workloadIdentity as Json).workflowFile =
          '.github/workflows/backend-iac-validate.yml';
      }),
      'schema',
    ),
  );
});

void test('dev inventory is generated from the manifest, never cloud observations', async () => {
  const { devResourceInventory } = (await import(
    pathToFileURL(path.join(backendRoot, 'scripts', 'verify-execution-manifest.mjs')).href
  )) as { devResourceInventory: (manifest: unknown) => Json };
  const manifest = load();
  const inventory = devResourceInventory(manifest);
  assert.equal(inventory.status, 'draft-not-authorized-not-observed');
  assert.equal(inventory.projectId, null);
  assert.deepEqual((inventory.terraformCandidates as Json).serviceAccounts, [
    'deploy-dev',
    'runtime-booking',
    'runtime-identity',
  ]);
  assert.deepEqual(
    (inventory.firebaseCliOwned as Json).collections,
    (manifest.firestore as Json).collections,
  );
  assert.deepEqual((inventory.firebaseCliOwned as Json).flags, manifest.flags);
});
