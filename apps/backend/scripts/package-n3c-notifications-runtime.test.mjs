import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { appendFileSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import {
  envFile,
  renderEnv,
  stageRuntime,
  verifyStage,
} from "./package-n3c-notifications-runtime.mjs";

const uid = "abcdefghijklmnopqrstuvwxyz012345";

test("env: switch and exact owner allowlist", () => {
  assert.equal(
    renderEnv({ runtimeEnabled: false, allowedUids: [uid] }),
    `N3C_DEV_ENABLED=false\nN3C_ALLOWED_FIREBASE_UIDS=${uid}\n`,
  );
  assert.throws(() => renderEnv({ runtimeEnabled: true, allowedUids: [] }));
  assert.throws(() => renderEnv({ runtimeEnabled: "yes", allowedUids: [uid] }));
});

function record(dir, manifest, overrides = {}) {
  const file = path.join(dir, "record.json");
  const raw = JSON.stringify({
    schemaVersion: 1,
    status: "approved",
    stage: "n3c-deploy",
    projectId: "recharge-dev-n2a01",
    stageTreeSha256: manifest.treeSha256,
    runtimeEnabled: manifest.runtimeEnabled,
    automaticDeletion: false,
    ownerApprovalEvidenceRef: "SYNTHETIC-TEST",
    issuedAtUtc: "2020-01-01T00:00:00Z",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    ...overrides,
  });
  writeFileSync(file, raw);
  return {
    GCLOUD_PROJECT: "recharge-dev-n2a01",
    N3C_DEPLOY_RECORD: file,
    N3C_DEPLOY_RECORD_SHA256: createHash("sha256").update(raw).digest("hex"),
  };
}

test("stage: the dev Notifications closure, verified against the owner record", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "n3c-stage-"));
  try {
    const stage = path.join(dir, "stage");
    const manifest = stageRuntime({
      outDir: stage,
      runtimeEnabled: false,
      allowedUids: [uid],
    });
    const names = manifest.files.map((f) => f.name);
    assert.ok(names.includes("lib/src/dev_notifications_entry.js"));
    assert.ok(
      names.includes(
        "lib/src/modules/notifications/application/push_dispatcher.js",
      ),
    );
    assert.ok(!names.includes("lib/src/index.js"));
    assert.ok(
      !names.some((n) => /stand\/|\/test\/|dev_content_media/u.test(n)),
    );
    assert.deepEqual(
      verifyStage({ stageDir: stage, env: record(dir, manifest) }),
      [],
    );
    for (const overrides of [
      { stageTreeSha256: "0".repeat(64) },
      { runtimeEnabled: true },
      { automaticDeletion: true },
      { stage: "n3a2-deploy" },
      { ownerApprovalEvidenceRef: "" },
      { expiresAtUtc: "2020-01-02T00:00:00Z" },
    ])
      assert.notDeepEqual(
        verifyStage({ stageDir: stage, env: record(dir, manifest, overrides) }),
        [],
        JSON.stringify(overrides),
      );
    appendFileSync(path.join(stage, envFile), "EXTRA=1\n");
    assert.notDeepEqual(
      verifyStage({ stageDir: stage, env: record(dir, manifest) }),
      [],
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
