import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
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

// Stages the Cloud Build context of the N3b media-tools image. Local only: no
// network, npm install, Docker, gcloud or cloud call. The stage holds the
// compiled import closure of the four entries, the container files, and the
// pinned artifact list rendered from media-tools.lock.json and the Functions
// package-lock (sharp's closure). Its tree digest becomes the image tag.
const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const runtimeDir = path.join(backend, "media-tools-runtime");
export const entries = Object.freeze([
  "media-tools-runtime/src/cloud_tools_host.js",
  "media-tools-runtime/src/cloud_tools_worker.js",
  "media-tools-runtime/src/scanner_prepare.js",
  "media-tools-runtime/src/publish_databases.js",
]);
const allowedPackages = new Set(["sharp"]);
const forbidden =
  /(firebase|firestore|booking|identity|content|notifications|fake_|emulator|stand)/u;
export const closurePackages = Object.freeze([
  "sharp",
  "@img/colour",
  "detect-libc",
  "semver",
  "@img/sharp-linux-x64",
  "@img/sharp-libvips-linux-x64",
]);

/** Relative-import closure of compiled entries; only `node:` and sharp may be bare. */
export function importClosure(buildRoot, starts = entries) {
  const seen = new Set();
  const stack = [...starts];
  while (stack.length > 0) {
    const rel = stack.pop();
    if (seen.has(rel)) continue;
    if (forbidden.test(rel))
      throw new Error(`forbidden module in tools closure: ${rel}`);
    const file = path.join(buildRoot, rel);
    if (!existsSync(file)) throw new Error(`missing compiled module: ${rel}`);
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
      if (spec.startsWith("node:")) continue;
      if (!spec.startsWith(".")) {
        if (!allowedPackages.has(spec))
          throw new Error(`package not allowed in tools closure: ${spec}`);
        continue;
      }
      const next = path.posix.normalize(
        path.posix.join(path.posix.dirname(rel), spec),
      );
      if (next.startsWith(".."))
        throw new Error(`import escapes build: ${rel} -> ${spec}`);
      stack.push(next);
    }
  }
  return [...seen].sort();
}

/** The pinned artifacts the image build fetches and verifies. */
export function renderLock(toolsLock, functionsLock) {
  const linux = toolsLock.linux;
  const version = toolsLock.verified.node.nodeVersion;
  const nodeUrl = `https://nodejs.org/dist/${version}/${linux.node.tarball}`;
  const env = {
    NODE_URL: nodeUrl,
    NODE_SHA256: linux.node.sha256,
    NODE_VERSION: version,
    CLAMAV_DEB_URL: linux.clamav.url,
    CLAMAV_DEB_SHA256: linux.clamav.sha256,
    CLAMAV_SIG_URL: linux.clamavSignature.url,
    CLAMAV_SIG_SHA256: linux.clamavSignature.sha256,
    TALOS_KEY_URL: toolsLock.artifacts.talosKey.url,
    TALOS_KEY_SHA256: toolsLock.verified.talosKeySha256,
    TALOS_FINGERPRINT: toolsLock.verified.gpg.signingKeyFingerprint,
  };
  for (const [key, value] of Object.entries(env))
    if (typeof value !== "string" || !/^[A-Za-z0-9:/._@%+=-]+$/u.test(value))
      throw new Error(`lock value not safe for the build: ${key}`);
  if (!/^[0-9a-f]{64}$/u.test(env.NODE_SHA256)) throw new Error("NODE_SHA256");
  if (!/^[0-9A-F]{40}$/u.test(env.TALOS_FINGERPRINT))
    throw new Error("TALOS_FINGERPRINT");
  const pinned = new Map(
    [...toolsLock.npm, ...linux.npm].map((pkg) => [pkg.name, pkg]),
  );
  const npm = closurePackages.map((name) => {
    const fromFunctions = functionsLock.packages[`node_modules/${name}`];
    const fromTools = pinned.get(name);
    const pkg = fromTools ?? fromFunctions;
    if (pkg === undefined) throw new Error(`unpinned package: ${name}`);
    if (
      fromTools !== undefined &&
      fromFunctions !== undefined &&
      (fromTools.version !== fromFunctions.version ||
        fromTools.integrity !== fromFunctions.integrity)
    )
      throw new Error(`lock files disagree on ${name}`);
    if (!/^sha512-[A-Za-z0-9+/]{86}==$/u.test(pkg.integrity))
      throw new Error(`integrity of ${name}`);
    if (!pkg.resolved.startsWith("https://registry.npmjs.org/"))
      throw new Error(`registry of ${name}`);
    return `${name}|${pkg.resolved}|${pkg.integrity}`;
  });
  return {
    env:
      Object.entries(env)
        .map(([key, value]) => `${key}=${value}`)
        .join("\n") + "\n",
    npm: npm.join("\n") + "\n",
  };
}

const lf = (text) => text.replace(/\r\n/gu, "\n");

function filesUnder(dir, base = dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory()
      ? filesUnder(full, base)
      : [path.relative(base, full).replaceAll("\\", "/")];
  });
}

export function treeDigest(dir, skip = new Set(["stage.json"])) {
  const hash = createHash("sha256");
  for (const rel of filesUnder(dir).sort()) {
    if (skip.has(rel)) continue;
    const digest = createHash("sha256")
      .update(readFileSync(path.join(dir, rel)))
      .digest("hex");
    hash.update(`${rel}\0${digest}\n`);
  }
  return hash.digest("hex");
}

export function stage({
  build = true,
  out = path.join(runtimeDir, "stage"),
} = {}) {
  const buildRoot = path.join(runtimeDir, "build");
  if (build) {
    const tsc = path.join(
      backend,
      "functions",
      "node_modules",
      "typescript",
      "bin",
      "tsc",
    );
    const result = spawnSync(
      process.execPath,
      [tsc, "-p", path.join(runtimeDir, "tsconfig.json")],
      { encoding: "utf8" },
    );
    if (result.status !== 0)
      throw new Error(`tsc failed:\n${result.stdout}${result.stderr}`);
  }
  const closure = importClosure(buildRoot);
  rmSync(out, { recursive: true, force: true });
  mkdirSync(path.join(out, "app", "dist"), { recursive: true });
  for (const rel of closure) {
    const target = path.join(out, "app", "dist", rel);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, lf(readFileSync(path.join(buildRoot, rel), "utf8")));
  }
  writeFileSync(
    path.join(out, "app", "package.json"),
    JSON.stringify(
      { name: "media-tools", private: true, type: "module" },
      null,
      2,
    ) + "\n",
  );
  for (const name of [
    "Dockerfile",
    "start.sh",
    "fetch-verify.sh",
    "cloudbuild.yaml",
  ])
    writeFileSync(
      path.join(out, name),
      lf(readFileSync(path.join(runtimeDir, "container", name), "utf8")),
    );
  const rendered = renderLock(
    JSON.parse(
      readFileSync(path.join(backend, "media-tools.lock.json"), "utf8"),
    ),
    JSON.parse(
      readFileSync(
        path.join(backend, "functions", "package-lock.json"),
        "utf8",
      ),
    ),
  );
  writeFileSync(path.join(out, "tools.lock.env"), rendered.env);
  writeFileSync(path.join(out, "npm.list"), rendered.npm);
  writeFileSync(path.join(out, ".gcloudignore"), "stage.json\n.gcloudignore\n");
  const digest = treeDigest(out);
  const manifest = {
    schemaVersion: 1,
    stage: "n3b-media-tools",
    treeDigest: digest,
    imageTag: `n3b-${digest.slice(0, 16)}`,
    closure,
    files: filesUnder(out)
      .filter((rel) => rel !== "stage.json")
      .sort()
      .map((rel) => ({
        path: rel,
        bytes: statSync(path.join(out, rel)).size,
      })),
  };
  writeFileSync(
    path.join(out, "stage.json"),
    JSON.stringify(manifest, null, 2) + "\n",
  );
  return manifest;
}

if (
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url
) {
  const manifest = stage();
  console.log(
    JSON.stringify({
      treeDigest: manifest.treeDigest,
      imageTag: manifest.imageTag,
      modules: manifest.closure.length,
    }),
  );
}
