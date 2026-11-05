import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  appendFileSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import {
  envFile,
  importClosure,
  renderEnv,
  stageRuntime,
} from "./package-n2c-identity-runtime.mjs";
import { verifyStage } from "./verify-n2c-stage.mjs";

const appId = "1:420479958348:android:abc123";

function fakeFunctions(files) {
  const root = mkdtempSync(path.join(tmpdir(), "n2c-pkg-"));
  for (const [rel, body] of Object.entries(files)) {
    mkdirSync(path.dirname(path.join(root, rel)), { recursive: true });
    writeFileSync(path.join(root, rel), body);
  }
  return root;
}

function record(manifest, overrides = {}) {
  const dir = mkdtempSync(path.join(tmpdir(), "n2c-rec-"));
  const file = path.join(dir, "deploy.json");
  const raw = JSON.stringify({
    schemaVersion: 1,
    status: "approved",
    stage: "n2c-deploy",
    projectId: "recharge-dev-n2a01",
    stageTreeSha256: manifest.treeSha256,
    runtimeEnabled: manifest.runtimeEnabled,
    appCheckEnforcement: false,
    ownerApprovalEvidenceRef: "SYNTHETIC-TEST-ONLY",
    issuedAtUtc: "2020-01-01T00:00:00Z",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    ...overrides,
  });
  writeFileSync(file, raw);
  return {
    GCLOUD_PROJECT: "recharge-dev-n2a01",
    N2C_DEPLOY_RECORD: file,
    N2C_DEPLOY_RECORD_SHA256: createHash("sha256").update(raw).digest("hex"),
  };
}

test("closure follows relative imports only and stays inside lib/src", () => {
  const root = fakeFunctions({
    "lib/src/dev_identity_entry.js":
      "import { a } from './a.js';\nimport x from 'firebase-admin/app';\nexport { b } from './sub/b.js';",
    "lib/src/a.js": "export const a = 1; import('./sub/c.js');",
    "lib/src/sub/b.js": "export const b = 2;",
    "lib/src/sub/c.js": "export const c = 3;",
    "lib/src/unused.js": "export const u = 0;",
  });
  assert.deepEqual(importClosure(root), [
    "lib/src/a.js",
    "lib/src/dev_identity_entry.js",
    "lib/src/sub/b.js",
    "lib/src/sub/c.js",
  ]);
});

test("closure refuses shared index, Media/Booking modules and escapes", () => {
  for (const target of [
    "lib/src/index.js",
    "lib/src/modules/media/x.js",
    "lib/src/modules/booking/x.js",
  ]) {
    const spec = "./" + target.slice("lib/src/".length);
    const root = fakeFunctions({
      "lib/src/dev_identity_entry.js": `import '${spec}';`,
      [target]: "",
    });
    assert.throws(() => importClosure(root), /forbidden module/u);
  }
  const escape = fakeFunctions({
    "lib/src/dev_identity_entry.js": "import '../../secret.js';",
  });
  assert.throws(() => importClosure(escape), /escapes lib\/src/u);
});

test(".env carries only the runtime flag and the exact dev app ID", () => {
  assert.equal(
    renderEnv({ appId, runtimeEnabled: false }),
    `N2C_DEV_AUTH_ENABLED=false\nN2C_ALLOWED_APP_IDS=${appId}\n`,
  );
  for (const bad of [
    "1:999:android:abc",
    "1:420479958348:ios:abc",
    `${appId},1:420479958348:android:def`,
  ])
    assert.throws(() => renderEnv({ appId: bad, runtimeEnabled: false }));
});

test("real stage is reproducible, isolated and accepted only with its exact record", () => {
  const out = mkdtempSync(path.join(tmpdir(), "n2c-stage-"));
  const first = stageRuntime({ outDir: out, appId, runtimeEnabled: false });
  const second = stageRuntime({ outDir: out, appId, runtimeEnabled: false });
  assert.equal(first.treeSha256, second.treeSha256);
  const names = first.files.map((f) => f.name);
  assert.ok(names.includes("lib/src/dev_identity_entry.js"));
  assert.ok(names.includes("package-lock.json") && names.includes(envFile));
  assert.ok(
    !names.some((n) => /index\.js$|media|booking|notifications/u.test(n)),
  );
  assert.deepEqual(verifyStage({ stageDir: out, env: record(first) }), []);
  // Wrong project, enabled-runtime record, expired record, tampered digest.
  assert.notDeepEqual(
    verifyStage({
      stageDir: out,
      env: { ...record(first), GCLOUD_PROJECT: "recharge-prod-x" },
    }),
    [],
  );
  assert.notDeepEqual(
    verifyStage({
      stageDir: out,
      env: record(first, { runtimeEnabled: true }),
    }),
    [],
  );
  assert.notDeepEqual(
    verifyStage({
      stageDir: out,
      env: record(first, { expiresAtUtc: "2021-01-01T00:00:00Z" }),
    }),
    [],
  );
  assert.notDeepEqual(
    verifyStage({
      stageDir: out,
      env: { ...record(first), N2C_DEPLOY_RECORD_SHA256: "0".repeat(64) },
    }),
    [],
  );
  // Any change after packaging is refused.
  appendFileSync(path.join(out, "lib/src/dev_identity_entry.js"), "\n//x");
  assert.ok(
    verifyStage({ stageDir: out, env: record(first) }).includes(
      "staged files changed after packaging",
    ),
  );
  // A later stage that enables the runtime has a different digest.
  const enabled = stageRuntime({ outDir: out, appId, runtimeEnabled: true });
  assert.notEqual(enabled.treeSha256, first.treeSha256);
  assert.match(
    readFileSync(path.join(out, envFile), "utf8"),
    /N2C_DEV_AUTH_ENABLED=true/u,
  );
});
