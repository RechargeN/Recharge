import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  cliTarget,
  devProject,
  envFileFor,
  resolveProjectNumber,
  reviewedProjects,
  stagingProject,
} from "./runtime-projects.mjs";
import {
  stageRuntime,
  verifyStage,
} from "./package-n3c-notifications-runtime.mjs";

// N4a (owner-approved 2026-11-13): one release candidate, two reviewed
// non-production projects. The code digest is the same for both stages; the
// predeploy gate binds each stage to its own project.

const uid = "abcdefghijklmnopqrstuvwxyz012345";
const stagingNumber = "123456789012";
const functionsLib = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "functions",
  "lib",
  "src",
  "shared",
  "cloud_runtime_projects.js",
);

test("the script list mirrors the runtime list; production is never reviewed", async () => {
  const runtime = await import(pathToFileURL(functionsLib).href);
  assert.deepEqual([...reviewedProjects], [...runtime.reviewedCloudProjects]);
  assert.equal(devProject, runtime.devCloudProject);
  assert.equal(stagingProject, runtime.stagingCloudProject);
  assert.throws(() => resolveProjectNumber("recharge-prod"));
  assert.throws(() => envFileFor("recharge-prod"));
  assert.equal(resolveProjectNumber(devProject), "420479958348");
  assert.throws(() => resolveProjectNumber(devProject, stagingNumber));
  assert.throws(() => resolveProjectNumber(stagingProject));
  assert.deepEqual(cliTarget({}), {
    projectId: devProject,
    projectNumber: "420479958348",
  });
});

function record(dir, manifest, projectId) {
  const file = path.join(dir, `record-${projectId}.json`);
  const raw = JSON.stringify({
    schemaVersion: 1,
    status: "approved",
    stage: "n3c-deploy",
    projectId,
    stageTreeSha256: manifest.treeSha256,
    runtimeEnabled: manifest.runtimeEnabled,
    automaticDeletion: false,
    ownerApprovalEvidenceRef: "SYNTHETIC-TEST",
    issuedAtUtc: "2020-01-01T00:00:00Z",
    expiresAtUtc: "2099-01-01T00:00:00Z",
  });
  writeFileSync(file, raw);
  return {
    N3C_DEPLOY_RECORD: file,
    N3C_DEPLOY_RECORD_SHA256: createHash("sha256").update(raw).digest("hex"),
  };
}

test("dev and staging stages of one code: same code digest, own project gate", () => {
  const dir = mkdtempSync(path.join(tmpdir(), "n4a-stage-"));
  try {
    const dev = stageRuntime({
      outDir: path.join(dir, "dev"),
      runtimeEnabled: false,
      allowedUids: [uid],
    });
    const staging = stageRuntime({
      outDir: path.join(dir, "staging"),
      runtimeEnabled: false,
      allowedUids: [uid],
      projectId: stagingProject,
      projectNumber: stagingNumber,
    });
    assert.equal(dev.codeTreeSha256, staging.codeTreeSha256);
    assert.notEqual(dev.treeSha256, staging.treeSha256);
    assert.match(
      readFileSync(path.join(dir, "staging", `.env.${stagingProject}`), "utf8"),
      /^RECHARGE_PROJECT_NUMBER=123456789012$/mu,
    );
    assert.doesNotMatch(
      readFileSync(path.join(dir, "dev", `.env.${devProject}`), "utf8"),
      /RECHARGE_PROJECT_NUMBER/u,
    );
    assert.deepEqual(
      verifyStage({
        stageDir: path.join(dir, "staging"),
        env: {
          GCLOUD_PROJECT: stagingProject,
          ...record(dir, staging, stagingProject),
        },
      }),
      [],
    );
    // A staging stage never deploys to dev, nor with a dev record.
    assert.notDeepEqual(
      verifyStage({
        stageDir: path.join(dir, "staging"),
        env: {
          GCLOUD_PROJECT: devProject,
          ...record(dir, staging, devProject),
        },
      }),
      [],
    );
    assert.notDeepEqual(
      verifyStage({
        stageDir: path.join(dir, "staging"),
        env: {
          GCLOUD_PROJECT: stagingProject,
          ...record(dir, staging, devProject),
        },
      }),
      [],
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
