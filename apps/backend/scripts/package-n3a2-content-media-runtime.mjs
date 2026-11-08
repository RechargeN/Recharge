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

import { treeDigest } from "./package-n2c-identity-runtime.mjs";

// Stages the Firebase CLI source directory of the N3a.2 dev Content + Media
// codebase. Local only: no npm install, network, Firebase CLI or cloud call.
// The stage holds the compiled import closure of dev_content_media_entry.js,
// the pinned runtime package.json/package-lock.json and the per-project .env.
export const projectId = "recharge-dev-n2a01";
export const envFile = `.env.${projectId}`;
export { treeDigest };
const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const entry = "lib/src/dev_content_media_entry.js";
// Never in this bundle: the default runtime index, notifications, Booking
// commands, test or stand code. (Emulator compositions reachable through the
// shared handlers stay dead code: their own guards refuse the cloud.)
const forbidden =
  /(^|\/)(index\.js$|notifications|booking_(create|cancel|reconfirm)|stand\/|test\/)/u;
const uidPattern = /^[A-Za-z0-9]{20,128}$/u;

export function importClosure(functionsRoot, start = entry) {
  const seen = new Set();
  const stack = [start];
  while (stack.length > 0) {
    const rel = stack.pop();
    if (seen.has(rel)) continue;
    if (forbidden.test(rel.slice("lib/".length)))
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

/** Bare packages the compiled closure loads (import, dynamic import or require). */
export function closurePackages(functionsRoot, files) {
  const names = new Set();
  for (const rel of files) {
    const source = readFileSync(path.join(functionsRoot, rel), "utf8");
    for (const m of source.matchAll(
      /(?:\bfrom\s*|\bimport\s*\(\s*|\bimport\s+|\brequire\s*\(\s*)['"]([^'"]+)['"]/gu,
    )) {
      const spec = m[1];
      if (spec.startsWith(".") || spec.startsWith("node:")) continue;
      names.add(
        spec.startsWith("@")
          ? spec.split("/").slice(0, 2).join("/")
          : spec.split("/")[0],
      );
    }
  }
  return [...names].sort();
}

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
    `N3A2_DEV_ENABLED=${runtimeEnabled}`,
    "RECHARGE_DEV_RUNTIME=content-media",
    "RECHARGE_MEDIA_STORAGE=dev-cloud",
    "RECHARGE_MEDIA_TOOLS=dev-cloud",
    `N3A2_ALLOWED_FIREBASE_UIDS=${allowedUids.join(",")}`,
    "",
  ].join("\n");
}

export function stageRuntime({
  outDir,
  runtimeEnabled,
  allowedUids,
  functionsRoot = path.join(backend, "functions"),
  runtimeRoot = path.join(backend, "n3a2-content-media-runtime"),
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
  const files = importClosure(functionsRoot);
  // 2026-11-08: the first cloud analysis failed on ajv/ajv-formats missing here.
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

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const [outDir, enabled, uids] = process.argv.slice(2);
  if (!outDir || !["true", "false"].includes(enabled) || !uids) {
    process.stderr.write(
      "usage: node package-n3a2-content-media-runtime.mjs <stageDir> <true|false> <uid[,uid]>\n",
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
