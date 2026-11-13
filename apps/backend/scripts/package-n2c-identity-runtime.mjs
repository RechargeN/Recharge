import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  cliTarget,
  codeTreeDigest,
  envFileFor,
  isReviewedProject,
  projectNumberEnvLines,
  resolveProjectNumber,
} from "./runtime-projects.mjs";

// Stages the Firebase CLI source directory of the five isolated N2c Session
// functions. Local only: no npm install, network, Firebase CLI or cloud call.
// The stage holds the compiled import closure of dev_identity_entry.js, the
// pinned runtime package.json/package-lock.json and the per-project .env.
// dev defaults; N4a stages the same code for staging (projectId + projectNumber).
export const projectId = "recharge-dev-n2a01";
export const envFile = `.env.${projectId}`;
const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const entry = "lib/src/dev_identity_entry.js";
const forbidden =
  /(^|\/)(index\.js$|media|scanner|processor|push|notifications|booking)/u;

export function importClosure(functionsRoot, start = entry) {
  const seen = new Set();
  const stack = [start];
  while (stack.length > 0) {
    const rel = stack.pop();
    if (seen.has(rel)) continue;
    if (forbidden.test(rel.slice("lib/src/".length)))
      throw new Error(`forbidden module in runtime closure: ${rel}`);
    const file = path.join(functionsRoot, rel);
    if (!existsSync(file))
      throw new Error(`missing compiled module: ${rel} (run npm run build)`);
    seen.add(rel);
    const source = readFileSync(file, "utf8");
    const specifiers = [
      ...source.matchAll(
        /\b(?:import|export)\s[^'"]*?from\s*['"]([^'"]+)['"]/gu,
      ),
      ...source.matchAll(/\bimport\s*\(\s*['"]([^'"]+)['"]\s*\)/gu),
      ...source.matchAll(/\bimport\s+['"]([^'"]+)['"]/gu),
    ].map((m) => m[1]);
    for (const spec of specifiers) {
      if (!spec.startsWith(".")) continue; // packages come from the lockfile
      const next = path.posix.normalize(
        path.posix.join(path.posix.dirname(rel), spec),
      );
      if (!next.startsWith("lib/src/"))
        throw new Error(`import escapes lib/src: ${rel} -> ${spec}`);
      stack.push(next);
    }
  }
  return [...seen].sort();
}

/** Digest over every staged file except node_modules and the manifest itself. */
export function treeDigest(stageDir) {
  const files = [];
  const walk = (dir) => {
    for (const name of readdirSync(dir).sort()) {
      const full = path.join(dir, name);
      const rel = path.relative(stageDir, full).split(path.sep).join("/");
      if (rel === "node_modules" || rel === "stage-manifest.json") continue;
      if (statSync(full).isDirectory()) walk(full);
      else
        files.push({
          name: rel,
          sha256: createHash("sha256").update(readFileSync(full)).digest("hex"),
        });
    }
  };
  walk(stageDir);
  files.sort((a, b) => a.name.localeCompare(b.name));
  const sha256 = createHash("sha256")
    .update(JSON.stringify(files))
    .digest("hex");
  return { sha256, files };
}

export function renderEnv({
  appId,
  runtimeEnabled,
  projectId: target = projectId,
  projectNumber,
}) {
  const number = resolveProjectNumber(target, projectNumber);
  if (!new RegExp(`^1:${number}:android:[a-f0-9]+$`, "u").test(appId ?? ""))
    throw new Error("exact Android Firebase app ID of the project required");
  if (typeof runtimeEnabled !== "boolean")
    throw new Error("runtimeEnabled must be boolean");
  return [
    `N2C_DEV_AUTH_ENABLED=${runtimeEnabled}`,
    `N2C_ALLOWED_APP_IDS=${appId}`,
    ...projectNumberEnvLines(target, number),
    "",
  ].join("\n");
}

export function stageRuntime({
  outDir,
  appId,
  runtimeEnabled,
  projectId: target = projectId,
  projectNumber,
  functionsRoot = path.join(backend, "functions"),
  runtimeRoot = path.join(backend, "n2c-identity-runtime"),
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
  const env = renderEnv({
    appId,
    runtimeEnabled,
    projectId: target,
    projectNumber: number,
  });
  const files = importClosure(functionsRoot);
  // Recreate everything except an already installed node_modules.
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
  write(envFileFor(target), env);
  const digest = treeDigest(outDir);
  const manifest = {
    schemaVersion: 1,
    projectId: target,
    projectNumber: number,
    entry,
    runtimeEnabled,
    appId,
    codeTreeSha256: codeTreeDigest(outDir),
    treeSha256: digest.sha256,
    files: digest.files,
  };
  write("stage-manifest.json", JSON.stringify(manifest, null, 2) + "\n");
  return manifest;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const [outDir, appId, enabled] = process.argv.slice(2);
  if (!outDir || !appId || !["true", "false"].includes(enabled)) {
    process.stderr.write(
      "usage: node package-n2c-identity-runtime.mjs <stageDir> <androidAppId> <true|false>\n",
    );
    process.exitCode = 1;
  } else {
    const manifest = stageRuntime({
      outDir,
      appId,
      runtimeEnabled: enabled === "true",
      ...cliTarget(process.env),
    });
    process.stdout.write(
      `${manifest.treeSha256}  ${manifest.files.length} staged files (runtimeEnabled=${manifest.runtimeEnabled})\n`,
    );
  }
}
