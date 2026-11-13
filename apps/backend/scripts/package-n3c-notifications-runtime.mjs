import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  closurePackages,
  importClosure,
  treeDigest,
} from "./package-n3a2-content-media-runtime.mjs";

// N3c (owner-approved 2026-11-13): stages the Firebase CLI source of the dev
// Notifications codebase (n3c-notifications) and, as its predeploy gate,
// verifies it against an owner-issued deploy record. Local only: no npm
// install, network, Firebase CLI or cloud call.
export const projectId = "recharge-dev-n2a01";
export const envFile = `.env.${projectId}`;
const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const entry = "lib/src/dev_notifications_entry.js";
// Never in this bundle: the default runtime index, Booking commands, stand or tests.
const forbidden =
  /(^|\/)(index\.js$|booking_(create|cancel|reconfirm)|stand\/|test\/)/u;
const uidPattern = /^[A-Za-z0-9]{20,128}$/u;

export function renderEnv({ runtimeEnabled, allowedUids }) {
  if (typeof runtimeEnabled !== "boolean")
    throw new Error("runtimeEnabled must be boolean");
  if (
    !Array.isArray(allowedUids) ||
    allowedUids.length === 0 ||
    allowedUids.some((uid) => !uidPattern.test(uid))
  )
    throw new Error("exact owner Firebase uid allowlist required");
  return [
    `N3C_DEV_ENABLED=${runtimeEnabled}`,
    `N3C_ALLOWED_FIREBASE_UIDS=${allowedUids.join(",")}`,
    "",
  ].join("\n");
}

export function stageRuntime({
  outDir,
  runtimeEnabled,
  allowedUids,
  functionsRoot = path.join(backend, "functions"),
  runtimeRoot = path.join(backend, "n3c-notifications-runtime"),
}) {
  const pkg = JSON.parse(
    readFileSync(path.join(runtimeRoot, "package.json"), "utf8"),
  );
  const lock = JSON.parse(
    readFileSync(path.join(runtimeRoot, "package-lock.json"), "utf8"),
  );
  if (pkg.main !== entry || pkg.type !== "module")
    throw new Error("runtime package.json must point at the isolated entry");
  if (
    JSON.stringify(lock.packages?.[""]?.dependencies) !==
    JSON.stringify(pkg.dependencies)
  )
    throw new Error("lockfile root dependencies differ from package.json");
  if (Object.values(pkg.dependencies).some((v) => !/^\d+\.\d+\.\d+$/u.test(v)))
    throw new Error("runtime dependencies must be exact versions");
  const env = renderEnv({ runtimeEnabled, allowedUids });
  const files = importClosure(functionsRoot, entry, forbidden);
  const missing = closurePackages(functionsRoot, files).filter(
    (name) => !(name in pkg.dependencies),
  );
  if (missing.length > 0)
    throw new Error(`runtime package lacks ${missing.join(", ")}`);
  if (existsSync(outDir))
    for (const name of readdirSync(outDir))
      if (name !== "node_modules")
        rmSync(path.join(outDir, name), { recursive: true, force: true });
  mkdirSync(outDir, { recursive: true });
  const write = (rel, data) => {
    mkdirSync(path.dirname(path.join(outDir, rel)), { recursive: true });
    writeFileSync(path.join(outDir, rel), data);
  };
  write("package.json", readFileSync(path.join(runtimeRoot, "package.json")));
  write(
    "package-lock.json",
    readFileSync(path.join(runtimeRoot, "package-lock.json")),
  );
  for (const rel of files)
    write(rel, readFileSync(path.join(functionsRoot, rel)));
  write(envFile, env);
  const digest = treeDigest(outDir);
  const manifest = {
    schemaVersion: 1,
    projectId,
    entry,
    runtimeEnabled,
    allowedUids,
    treeSha256: digest.sha256,
    files: digest.files,
  };
  write("stage-manifest.json", JSON.stringify(manifest, null, 2) + "\n");
  return manifest;
}

/** Firebase CLI predeploy gate: the staged tree, its .env and the owner record match exactly. */
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
  if (digest.files.some((f) => forbidden.test(f.name.replace(/^lib\//u, ""))))
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
  if (readFileSync(path.join(stageDir, envFile), "utf8") !== expectedEnv)
    errors.push("stage .env differs from the manifest");
  let raw;
  let record;
  try {
    raw = readFileSync(env.N3C_DEPLOY_RECORD ?? "", "utf8");
    record = JSON.parse(raw);
  } catch {
    return [...errors, "N3c deploy record missing"];
  }
  if (
    createHash("sha256").update(raw).digest("hex") !==
    env.N3C_DEPLOY_RECORD_SHA256
  )
    errors.push("deploy record hash mismatch");
  const expected = {
    schemaVersion: 1,
    status: "approved",
    stage: "n3c-deploy",
    projectId,
    stageTreeSha256: manifest.treeSha256,
    runtimeEnabled: manifest.runtimeEnabled,
    automaticDeletion: false,
  };
  for (const [key, value] of Object.entries(expected))
    if (record[key] !== value) errors.push(`deploy record ${key} mismatch`);
  if (
    typeof record.ownerApprovalEvidenceRef !== "string" ||
    record.ownerApprovalEvidenceRef === ""
  )
    errors.push("deploy record lacks owner approval evidence");
  if (!(
    Date.parse(record.issuedAtUtc) <= now.getTime() &&
    now.getTime() < Date.parse(record.expiresAtUtc)
  ))
    errors.push("deploy record outside its validity window");
  return errors;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const args = process.argv.slice(2);
  if (args[0] === "--verify") {
    const errors = verifyStage({
      stageDir: args[1] ?? "stage",
      env: process.env,
    });
    if (errors.length > 0) {
      process.stderr.write(`N3c stage refused:\n- ${errors.join("\n- ")}\n`);
      process.exitCode = 1;
    } else process.stdout.write("N3c stage verified\n");
  } else {
    const [outDir, enabled, uids] = args;
    if (!outDir || !["true", "false"].includes(enabled) || !uids) {
      process.stderr.write(
        "usage: node package-n3c-notifications-runtime.mjs <stageDir> <true|false> <uid[,uid]> | --verify <stageDir>\n",
      );
      process.exitCode = 1;
    } else {
      const manifest = stageRuntime({
        outDir,
        runtimeEnabled: enabled === "true",
        allowedUids: uids.split(","),
      });
      process.stdout.write(
        `${manifest.treeSha256}  ${manifest.files.length} staged files (runtimeEnabled=${manifest.runtimeEnabled})\n`,
      );
    }
  }
}
