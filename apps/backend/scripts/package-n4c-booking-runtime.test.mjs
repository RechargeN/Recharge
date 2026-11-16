import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { appendFileSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import {
  renderEnv,
  stageRuntime,
  verifyStage,
} from "./package-n4c-booking-runtime.mjs";

const uid = "abcdefghijklmnopqrstuvwxyz012345";
const staging = "recharge-staging-y9y2y";
const number = "30205452447";

test("env: switch, exact owner allowlist, load run closed by default", () => {
  assert.equal(
    renderEnv({ runtimeEnabled: false, allowedUids: [uid] }),
    `N4C_BOOKING_ENABLED=false\nN4C_ALLOWED_FIREBASE_UIDS=${uid}\nN4C_LOAD_ENABLED=false\nN4C_LOAD_MAX_INSTANCES=1\nN4C_LOAD_CONCURRENCY=1\n`,
  );
  assert.throws(() => renderEnv({ runtimeEnabled: true, allowedUids: [] }));
  assert.throws(() => renderEnv({ runtimeEnabled: "yes", allowedUids: [uid] }));
});

test("env: the load run is staging only and inside the reviewed bounds", () => {
  const load = { enabled: true, maxInstances: 3, concurrency: 20 };
  assert.match(
    renderEnv({
      runtimeEnabled: true,
      allowedUids: [uid],
      load,
      projectId: staging,
      projectNumber: number,
    }),
    /N4C_LOAD_ENABLED=true\nN4C_LOAD_MAX_INSTANCES=3\nN4C_LOAD_CONCURRENCY=20\n/u,
  );
  assert.throws(
    () => renderEnv({ runtimeEnabled: true, allowedUids: [uid], load }),
    /staging only/u,
  );
  for (const bad of [
    { ...load, maxInstances: 4 },
    { ...load, concurrency: 41 },
    { ...load, maxInstances: 0 },
    { ...load, enabled: "true" },
  ])
    assert.throws(
      () =>
        renderEnv({
          runtimeEnabled: true,
          allowedUids: [uid],
          load: bad,
          projectId: staging,
          projectNumber: number,
        }),
      /reviewed bounds/u,
    );
});

function record(dir, manifest, overrides = {}) {
  const file = path.join(dir, "record.json");
  const raw = JSON.stringify({
    schemaVersion: 1,
    status: "approved",
    stage: "n4c-deploy",
    projectId: manifest.projectId,
    stageTreeSha256: manifest.treeSha256,
    runtimeEnabled: manifest.runtimeEnabled,
    loadEnabled: manifest.load.enabled,
    loadMaxInstances: manifest.load.maxInstances,
    loadConcurrency: manifest.load.concurrency,
    automaticDeletion: false,
    ownerApprovalEvidenceRef: "SYNTHETIC-TEST",
    issuedAtUtc: "2020-01-01T00:00:00Z",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    ...overrides,
  });
  writeFileSync(file, raw);
  return {
    GCLOUD_PROJECT: manifest.projectId,
    N4C_DEPLOY_RECORD: file,
    N4C_DEPLOY_RECORD_SHA256: createHash("sha256").update(raw).digest("hex"),
  };
}

test("stage: the Booking closure without workers, verified against the owner record", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "n4c-stage-"));
  try {
    const stage = path.join(dir, "stage");
    const manifest = stageRuntime({
      outDir: stage,
      runtimeEnabled: false,
      allowedUids: [uid],
    });
    const names = manifest.files.map((f) => f.name);
    assert.ok(names.includes("lib/src/dev_booking_entry.js"));
    assert.ok(names.includes("lib/src/booking/create_internal_booking.js"));
    assert.ok(names.includes("lib/src/contracts/booking_v1.js"));
    assert.ok(!names.includes("lib/src/index.js"));
    assert.ok(
      !names.some((n) =>
        /stand\/|\/test\/|reconfirmation_deadline_worker|event_projection_runtime|dev_notifications|dev_content_media/u.test(
          n,
        ),
      ),
    );
    assert.deepEqual(
      verifyStage({ stageDir: stage, env: record(dir, manifest) }),
      [],
    );
    // A record that approves a different load setting does not cover this stage.
    assert.match(
      verifyStage({
        stageDir: stage,
        env: record(dir, manifest, { loadEnabled: true }),
      }).join(),
      /loadEnabled mismatch/u,
    );
    assert.match(
      verifyStage({
        stageDir: stage,
        env: { ...record(dir, manifest), GCLOUD_PROJECT: "recharge-prod" },
      }).join(),
      /not the reviewed project/u,
    );
    appendFileSync(
      path.join(stage, "lib/src/dev_booking_entry.js"),
      "\n// drift\n",
    );
    assert.match(
      verifyStage({ stageDir: stage, env: record(dir, manifest) }).join(),
      /changed after packaging/u,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("stage: staging carries the load settings into the manifest and the record", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "n4c-stage-"));
  try {
    const stage = path.join(dir, "stage");
    const manifest = stageRuntime({
      outDir: stage,
      runtimeEnabled: true,
      allowedUids: [uid],
      load: { enabled: true, maxInstances: 3, concurrency: 20 },
      projectId: staging,
      projectNumber: number,
    });
    assert.deepEqual(manifest.load, {
      enabled: true,
      maxInstances: 3,
      concurrency: 20,
    });
    assert.deepEqual(
      verifyStage({ stageDir: stage, env: record(dir, manifest) }),
      [],
    );
    assert.match(
      verifyStage({
        stageDir: stage,
        env: record(dir, manifest, { loadMaxInstances: 1 }),
      }).join(),
      /loadMaxInstances mismatch/u,
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
