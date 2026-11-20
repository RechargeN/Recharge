import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { pathToFileURL } from "node:url";

import { renderEnv, treeDigest } from "./package-n2c-identity-runtime.mjs";
import {
  codeTreeDigest,
  envFileFor,
  isReviewedProject,
} from "./runtime-projects.mjs";

// Firebase CLI predeploy gate for the N2c codebase. Fails closed unless the
// staged tree, its .env and an owner-issued deploy record all match exactly.
// Reads only local files and environment; no network or cloud call.
export function verifyStage({ stageDir, env, now = new Date() }) {
  const errors = [];
  let manifest;
  try {
    manifest = JSON.parse(
      readFileSync(path.join(stageDir, "stage-manifest.json"), "utf8"),
    );
  } catch {
    return ["stage manifest missing"];
  }
  // N4a: the reviewed project the stage was packaged for (dev or staging).
  if (
    !isReviewedProject(manifest.projectId) ||
    env.GCLOUD_PROJECT !== manifest.projectId
  )
    errors.push("deploy target is not the reviewed project of this stage");
  const digest = treeDigest(stageDir);
  if (digest.sha256 !== manifest.treeSha256)
    errors.push("staged files changed after packaging");
  if (codeTreeDigest(stageDir) !== manifest.codeTreeSha256)
    errors.push("staged code differs from the release candidate digest");
  if (digest.files.some((f) => /(^|\/)index\.js$|media|booking/u.test(f.name)))
    errors.push("stage contains shared backend modules");
  let expectedEnv;
  let dotenv;
  try {
    expectedEnv = renderEnv({
      appId: manifest.appId,
      runtimeEnabled: manifest.runtimeEnabled,
      projectId: manifest.projectId,
      projectNumber: manifest.projectNumber,
    });
    dotenv = readFileSync(
      path.join(stageDir, envFileFor(manifest.projectId)),
      "utf8",
    );
  } catch {
    errors.push("stage manifest env inputs invalid");
  }
  if (dotenv !== expectedEnv)
    errors.push("stage .env differs from the manifest");
  let record;
  let recordRaw;
  try {
    recordRaw = readFileSync(env.N2C_DEPLOY_RECORD ?? "", "utf8");
    record = JSON.parse(recordRaw);
  } catch {
    return [...errors, "N2c deploy record missing"];
  }
  if (
    createHash("sha256").update(recordRaw).digest("hex") !==
    env.N2C_DEPLOY_RECORD_SHA256
  )
    errors.push("deploy record digest mismatch");
  if (
    record.schemaVersion !== 1 ||
    record.status !== "approved" ||
    record.stage !== "n2c-deploy" ||
    record.projectId !== manifest.projectId ||
    record.stageTreeSha256 !== manifest.treeSha256 ||
    record.runtimeEnabled !== manifest.runtimeEnabled ||
    record.appCheckEnforcement !== false ||
    !(record.ownerApprovalEvidenceRef?.length > 0) ||
    !(Date.parse(record.issuedAtUtc) <= now.getTime()) ||
    !(Date.parse(record.expiresAtUtc) > now.getTime())
  )
    errors.push("deploy record does not authorize this exact stage");
  return errors;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const errors = verifyStage({
    stageDir: path.resolve(process.argv[2] ?? "stage"),
    env: process.env,
  });
  if (errors.length) {
    process.stderr.write(`N2c predeploy refused: ${errors.join("; ")}\n`);
    process.exitCode = 1;
  } else
    process.stdout.write(
      "N2c stage matches the owner deploy record; proceeding.\n",
    );
}
