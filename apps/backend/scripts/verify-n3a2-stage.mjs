import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { pathToFileURL } from "node:url";

import {
  envFile,
  projectId,
  renderEnv,
  treeDigest,
} from "./package-n3a2-content-media-runtime.mjs";

// Firebase CLI predeploy gate for the N3a.2 codebase. Fails closed unless the
// staged tree, its .env and an owner-issued deploy record all match exactly.
// Reads only local files and environment; no network or cloud call.
export function verifyStage({ stageDir, env, now = new Date() }) {
  const errors = [];
  if (env.GCLOUD_PROJECT !== projectId)
    errors.push("deploy target is not recharge-dev-n2a01");
  let manifest;
  try {
    manifest = JSON.parse(
      readFileSync(path.join(stageDir, "stage-manifest.json"), "utf8"),
    );
  } catch {
    return ["stage manifest missing"];
  }
  const digest = treeDigest(stageDir);
  if (digest.sha256 !== manifest.treeSha256)
    errors.push("staged files changed after packaging");
  if (
    digest.files.some((f) =>
      /(^|\/)index\.js$|notifications|stand\/|test\//u.test(f.name),
    )
  )
    errors.push("stage contains modules outside the reviewed closure");
  let expectedEnv;
  try {
    expectedEnv = renderEnv({
      runtimeEnabled: manifest.runtimeEnabled,
      allowedUids: manifest.allowedUids,
    });
  } catch {
    errors.push("stage manifest env inputs invalid");
  }
  const dotenv = readFileSync(path.join(stageDir, envFile), "utf8");
  if (dotenv !== expectedEnv)
    errors.push("stage .env differs from the manifest");
  let record;
  let recordRaw;
  try {
    recordRaw = readFileSync(env.N3A2_DEPLOY_RECORD ?? "", "utf8");
    record = JSON.parse(recordRaw);
  } catch {
    return [...errors, "N3a.2 deploy record missing"];
  }
  if (
    createHash("sha256").update(recordRaw).digest("hex") !==
    env.N3A2_DEPLOY_RECORD_SHA256
  )
    errors.push("deploy record digest mismatch");
  if (
    record.schemaVersion !== 1 ||
    record.status !== "approved" ||
    record.stage !== "n3a2-deploy" ||
    record.projectId !== projectId ||
    record.stageTreeSha256 !== manifest.treeSha256 ||
    record.runtimeEnabled !== manifest.runtimeEnabled ||
    record.publication !== false ||
    record.automaticDeletion !== false ||
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
    process.stderr.write(`N3a.2 predeploy refused: ${errors.join("; ")}\n`);
    process.exitCode = 1;
  } else
    process.stdout.write(
      "N3a.2 stage matches the owner deploy record; proceeding.\n",
    );
}
