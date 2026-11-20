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
  closureSchemaGroups,
  closurePackages,
  importClosure,
  treeDigest,
} from "./package-n3a2-content-media-runtime.mjs";
import {
  cliTarget,
  codeTreeDigest,
  envFileFor,
  isReviewedProject,
  projectNumberEnvLines,
  resolveProjectNumber,
  stagingProject,
} from "./runtime-projects.mjs";

// N4c (owner-approved 2026-11-16): stages the Firebase CLI source of the Booking
// codebase (n4c-booking) and, as its predeploy gate, verifies it against an
// owner-issued deploy record. Local only: no npm install, network, Firebase CLI
// or cloud call. The load-run settings exist for staging only.
export const projectId = "recharge-dev-n2a01";
export const envFile = `.env.${projectId}`;
const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const entry = "lib/src/dev_booking_entry.js";
// Never in this bundle: the default runtime index, stand or tests. Round 2.2
// (owner approval 2026-11-19): the Booking workers ship, behind the Operations
// emergency switches of round 2.1 (contained until an operator opens them).
const forbidden = /(^|\/)(index\.js$|stand\/|test\/)/u;
const uidPattern = /^[A-Za-z0-9]{20,128}$/u;

const noLoad = Object.freeze({
  enabled: false,
  maxInstances: 1,
  concurrency: 1,
});

function checkedLoad(target, load = noLoad) {
  const { enabled, maxInstances, concurrency } = load;
  if (
    typeof enabled !== "boolean" ||
    !Number.isSafeInteger(maxInstances) ||
    !Number.isSafeInteger(concurrency) ||
    maxInstances < 1 ||
    maxInstances > 3 ||
    concurrency < 1 ||
    concurrency > 40
  )
    throw new Error("load settings outside the reviewed bounds");
  if (
    target !== stagingProject &&
    (enabled || maxInstances !== 1 || concurrency !== 1)
  )
    throw new Error("the load run exists in staging only");
  return { enabled, maxInstances, concurrency };
}

export function renderEnv({
  runtimeEnabled,
  allowedUids,
  load,
  createDisabled = false,
  privacyEnabled = false,
  projectId: target = projectId,
  projectNumber,
}) {
  const number = resolveProjectNumber(target, projectNumber);
  if (typeof runtimeEnabled !== "boolean")
    throw new Error("runtimeEnabled must be boolean");
  if (
    !Array.isArray(allowedUids) ||
    allowedUids.length === 0 ||
    allowedUids.some((uid) => !uidPattern.test(uid))
  )
    throw new Error("exact owner Firebase uid allowlist required");
  const settings = checkedLoad(target, load);
  if (typeof createDisabled !== "boolean")
    throw new Error("createDisabled must be boolean");
  if (typeof privacyEnabled !== "boolean")
    throw new Error("privacyEnabled must be boolean");
  return [
    `N4C_BOOKING_ENABLED=${runtimeEnabled}`,
    `N4C_BOOKING_CREATE_DISABLE=${createDisabled}`,
    `N4C_ALLOWED_FIREBASE_UIDS=${allowedUids.join(",")}`,
    `N4C_LOAD_ENABLED=${settings.enabled}`,
    `N4C_LOAD_MAX_INSTANCES=${settings.maxInstances}`,
    `N4C_LOAD_CONCURRENCY=${settings.concurrency}`,
    // Round 2.2: the Event → Booking handoff follows the runtime switch; its
    // Operations switch (contained until an operator opens it) still decides.
    `N4F_CONTENT_EFFECTS_ENABLED=${runtimeEnabled}`,
    "RECHARGE_DEV_RUNTIME=content-media",
    // Step 2 (owner decision 2026-11-20): the DSR intake and worker open only
    // with the runtime and an explicit privacy deploy switch.
    `N5D_PRIVACY_ENABLED=${runtimeEnabled && privacyEnabled}`,
    ...projectNumberEnvLines(target, number),
    "",
  ].join("\n");
}

export function stageRuntime({
  outDir,
  runtimeEnabled,
  allowedUids,
  load,
  createDisabled = false,
  privacyEnabled = false,
  projectId: target = projectId,
  projectNumber,
  functionsRoot = path.join(backend, "functions"),
  runtimeRoot = path.join(backend, "n4c-booking-runtime"),
}) {
  const number = resolveProjectNumber(target, projectNumber);
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
  const settings = checkedLoad(target, load);
  const env = renderEnv({
    runtimeEnabled,
    allowedUids,
    load: settings,
    createDisabled,
    privacyEnabled,
    projectId: target,
    projectNumber: number,
  });
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
  // Round 2.2: the Content handoff validates against the contract schemas.
  const schemaRoot = path.resolve(
    backend,
    "..",
    "..",
    "packages",
    "api_contracts",
    "schema",
  );
  for (const group of closureSchemaGroups(files))
    for (const name of readdirSync(path.join(schemaRoot, group, "v1")).sort())
      if (name.endsWith(".schema.json"))
        write(
          `contracts/${group}/v1/${name}`,
          readFileSync(path.join(schemaRoot, group, "v1", name)),
        );
  write(envFileFor(target), env);
  const digest = treeDigest(outDir);
  const manifest = {
    schemaVersion: 1,
    projectId: target,
    projectNumber: number,
    entry,
    runtimeEnabled,
    allowedUids,
    load: settings,
    createDisabled,
    privacyEnabled,
    codeTreeSha256: codeTreeDigest(outDir),
    treeSha256: digest.sha256,
    files: digest.files,
  };
  write("stage-manifest.json", JSON.stringify(manifest, null, 2) + "\n");
  return manifest;
}

/** Firebase CLI predeploy gate: the staged tree, its .env and the owner record match exactly. */
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
  if (digest.files.some((f) => forbidden.test(f.name.replace(/^lib\//u, ""))))
    errors.push("stage contains modules outside the reviewed closure");
  let expectedEnv;
  try {
    expectedEnv = renderEnv({
      runtimeEnabled: manifest.runtimeEnabled,
      allowedUids: manifest.allowedUids,
      load: manifest.load,
      createDisabled: manifest.createDisabled,
      privacyEnabled: manifest.privacyEnabled ?? false,
      projectId: manifest.projectId,
      projectNumber: manifest.projectNumber,
    });
  } catch {
    errors.push("stage manifest env inputs invalid");
  }
  let dotenv;
  try {
    dotenv = readFileSync(
      path.join(stageDir, envFileFor(manifest.projectId)),
      "utf8",
    );
  } catch {
    errors.push("stage .env missing");
  }
  if (dotenv !== expectedEnv)
    errors.push("stage .env differs from the manifest");
  let raw;
  let record;
  try {
    raw = readFileSync(env.N4C_DEPLOY_RECORD ?? "", "utf8");
    record = JSON.parse(raw);
  } catch {
    return [...errors, "N4c deploy record missing"];
  }
  if (
    createHash("sha256").update(raw).digest("hex") !==
    env.N4C_DEPLOY_RECORD_SHA256
  )
    errors.push("deploy record hash mismatch");
  const expected = {
    schemaVersion: 1,
    status: "approved",
    stage: "n4c-deploy",
    projectId: manifest.projectId,
    stageTreeSha256: manifest.treeSha256,
    runtimeEnabled: manifest.runtimeEnabled,
    loadEnabled: manifest.load?.enabled,
    loadMaxInstances: manifest.load?.maxInstances,
    loadConcurrency: manifest.load?.concurrency,
    createDisabled: manifest.createDisabled,
    privacyEnabled: manifest.privacyEnabled ?? false,
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
      process.stderr.write(`N4c stage refused:\n- ${errors.join("\n- ")}\n`);
      process.exitCode = 1;
    } else process.stdout.write("N4c stage verified\n");
  } else {
    const [
      outDir,
      enabled,
      uids,
      loadEnabled,
      maxInstances,
      concurrency,
      createDisabled,
      privacyEnabled,
    ] = args;
    if (
      !outDir ||
      !["true", "false"].includes(enabled) ||
      !uids ||
      ![undefined, "true", "false"].includes(loadEnabled) ||
      ![undefined, "true", "false"].includes(createDisabled) ||
      ![undefined, "true", "false"].includes(privacyEnabled)
    ) {
      process.stderr.write(
        "usage: node package-n4c-booking-runtime.mjs <stageDir> <true|false> <uid[,uid]> [<loadEnabled> <maxInstances> <concurrency> [<createDisabled> [<privacyEnabled>]]] | --verify <stageDir>\n",
      );
      process.exitCode = 1;
    } else {
      const manifest = stageRuntime({
        outDir,
        runtimeEnabled: enabled === "true",
        allowedUids: uids.split(","),
        ...(loadEnabled === undefined
          ? {}
          : {
              load: {
                enabled: loadEnabled === "true",
                maxInstances: Number(maxInstances),
                concurrency: Number(concurrency),
              },
            }),
        createDisabled: createDisabled === "true",
        privacyEnabled: privacyEnabled === "true",
        ...cliTarget(process.env),
      });
      process.stdout.write(
        `${manifest.treeSha256}  ${manifest.files.length} staged files (runtimeEnabled=${manifest.runtimeEnabled}, load=${manifest.load.enabled}, createDisabled=${manifest.createDisabled}, privacyEnabled=${manifest.privacyEnabled})\n`,
      );
    }
  }
}
