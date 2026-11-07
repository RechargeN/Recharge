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
} from "./package-n3a2-content-media-runtime.mjs";
import { verifyStage } from "./verify-n3a2-stage.mjs";

const uid = "abcdefghijklmnopqrstuvwxyz012345";

test("env: every dev switch, exact owner allowlist, boolean runtime", () => {
  assert.equal(
    renderEnv({ runtimeEnabled: false, allowedUids: [uid] }),
    `N3A2_DEV_ENABLED=false\nRECHARGE_DEV_RUNTIME=content-media\nRECHARGE_MEDIA_STORAGE=dev-cloud\nRECHARGE_MEDIA_TOOLS=dev-cloud\nN3A2_ALLOWED_FIREBASE_UIDS=${uid}\n`,
  );
  assert.throws(() => renderEnv({ runtimeEnabled: true, allowedUids: [] }));
  assert.throws(() =>
    renderEnv({ runtimeEnabled: true, allowedUids: ["bad uid"] }),
  );
  assert.throws(() => renderEnv({ runtimeEnabled: "yes", allowedUids: [uid] }));
});

function record(dir, manifest, overrides = {}) {
  const file = path.join(dir, "record.json");
  const raw = JSON.stringify({
    schemaVersion: 1,
    status: "approved",
    stage: "n3a2-deploy",
    projectId: "recharge-dev-n2a01",
    stageTreeSha256: manifest.treeSha256,
    runtimeEnabled: manifest.runtimeEnabled,
    publication: false,
    automaticDeletion: false,
    ownerApprovalEvidenceRef: "SYNTHETIC-TEST",
    issuedAtUtc: "2020-01-01T00:00:00Z",
    expiresAtUtc: "2099-01-01T00:00:00Z",
    ...overrides,
  });
  writeFileSync(file, raw);
  return {
    GCLOUD_PROJECT: "recharge-dev-n2a01",
    N3A2_DEPLOY_RECORD: file,
    N3A2_DEPLOY_RECORD_SHA256: createHash("sha256").update(raw).digest("hex"),
  };
}

test("stage: the compiled closure of the dev entry, verified against the owner record", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "n3a2-stage-"));
  try {
    const stage = path.join(dir, "stage");
    const manifest = stageRuntime({
      outDir: stage,
      runtimeEnabled: false,
      allowedUids: [uid],
    });
    const names = manifest.files.map((f) => f.name);
    assert.ok(names.includes("lib/src/dev_content_media_entry.js"));
    assert.ok(!names.includes("lib/src/index.js"));
    assert.ok(!names.some((n) => /notifications|stand\//u.test(n)));
    assert.deepEqual(
      verifyStage({ stageDir: stage, env: record(dir, manifest) }),
      [],
    );
    // A record for another tree, publication or deletion, or an enabled runtime is refused.
    for (const overrides of [
      { stageTreeSha256: "0".repeat(64) },
      { runtimeEnabled: true },
      { publication: true },
      { automaticDeletion: true },
      { stage: "n2c-deploy" },
      { expiresAtUtc: "2020-01-02T00:00:00Z" },
    ])
      assert.notDeepEqual(
        verifyStage({ stageDir: stage, env: record(dir, manifest, overrides) }),
        [],
        JSON.stringify(overrides),
      );
    // Any change after packaging is refused.
    appendFileSync(path.join(stage, envFile), "EXTRA=1\n");
    assert.notDeepEqual(
      verifyStage({ stageDir: stage, env: record(dir, manifest) }),
      [],
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
