// D1 local Media tools (docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md).
// fetch: downloads exactly the artifacts of media-tools.lock.json within the
// budget, verifies them and installs sharp from an isolated, offline cache.
// Everything lives under %LOCALAPPDATA%\Recharge\tools; nothing is deleted:
// refused files move to _rejected for the owner to review.
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import https from "node:https";
import { request as httpRequest } from "node:http";
import {
  connect as netConnect,
  createServer as createNetServer,
} from "node:net";
import { createHash, randomBytes } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath, pathToFileURL } from "node:url";

const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const functionsDir = path.join(backend, "functions");
const lockFile = path.join(backend, "media-tools.lock.json");
export const toolsRoot = path.resolve(
  process.env.LOCALAPPDATA || os.tmpdir(),
  "Recharge",
  "tools",
);
const dirs = {
  downloads: path.join(toolsRoot, "_downloads"),
  staging: path.join(toolsRoot, "_staging"),
  rejected: path.join(toolsRoot, "_rejected"),
  npmCache: path.join(toolsRoot, "npm-cache-d1"),
  resolve: path.join(toolsRoot, "_npm-resolve"),
  gnupg: path.join(toolsRoot, "_gnupg"),
};
const ledgerFile = path.join(toolsRoot, "fetch-ledger.json");

/** Hosts a download may reach, redirects included. */
export const allowedHosts = new Set([
  "nodejs.org",
  "github.com",
  "release-assets.githubusercontent.com",
  "objects.githubusercontent.com",
  "raw.githubusercontent.com",
]);

/** The harmless stand signature (L1); must equal media_tool_limits.ts. */
export const standMarker = "RECHARGE-D1-STAND-MARKER-NOT-MALWARE";
export const standDatabaseName = "recharge-stand.ndb";
export function standDatabase() {
  const hex = Buffer.from(standMarker, "ascii").toString("hex");
  return `Recharge.Test.Marker:0:*:${hex}\n`;
}

function fail(message) {
  throw new Error(message);
}
const log = (message) => process.stdout.write(message + "\n");
const stamp = () =>
  new Date().toISOString().replaceAll(":", "").replace(/\..*$/u, "");

export function readLock(file = lockFile) {
  const lock = JSON.parse(fs.readFileSync(file, "utf8"));
  if (lock.schemaVersion !== 1 || lock.mode !== "L1")
    fail("Unexpected media-tools lock.");
  return lock;
}
function writeLock(lock) {
  fs.writeFileSync(lockFile, JSON.stringify(lock, null, 2) + "\n");
}

export function sha256File(file) {
  const hash = createHash("sha256");
  const fd = fs.openSync(file, "r");
  try {
    const buffer = Buffer.alloc(1 << 20);
    for (;;) {
      const read = fs.readSync(fd, buffer, 0, buffer.length, null);
      if (read === 0) break;
      hash.update(buffer.subarray(0, read));
    }
  } finally {
    fs.closeSync(fd);
  }
  return hash.digest("hex");
}

/** Moves a refused file or directory aside for review; never deletes. */
function reject(target, reason) {
  const into = path.join(dirs.rejected, stamp());
  fs.mkdirSync(into, { recursive: true });
  const moved = path.join(into, path.basename(target));
  if (fs.existsSync(target)) fs.renameSync(target, moved);
  fs.writeFileSync(path.join(into, "REASON.txt"), reason + "\n");
  fail(`${reason} (moved to ${moved})`);
}

// ---------- budget ----------

export function readLedger(file = ledgerFile) {
  return fs.existsSync(file)
    ? JSON.parse(fs.readFileSync(file, "utf8"))
    : { totalBytes: 0, entries: [] };
}
function record(name, bytes) {
  const ledger = readLedger();
  ledger.totalBytes += bytes;
  ledger.entries.push({ name, bytes, at: new Date().toISOString() });
  fs.writeFileSync(ledgerFile, JSON.stringify(ledger, null, 2) + "\n");
  return ledger.totalBytes;
}
export function remainingBudget(lock, ledger) {
  return lock.budgetBytes - ledger.totalBytes;
}

// ---------- download ----------

/**
 * Streams one fixed-size artifact: the size must be announced and equal the
 * manifest; the first byte beyond it, or beyond the budget, aborts.
 */
function download(name, artifact, lock) {
  const target = path.join(
    dirs.downloads,
    path.basename(new URL(artifact.url).pathname),
  );
  if (fs.existsSync(target) && fs.statSync(target).size === artifact.size) {
    if (!artifact.sha256 || sha256File(target) === artifact.sha256) {
      log(`  ${name}: already downloaded and verified`);
      return Promise.resolve(target);
    }
  }
  const budget = remainingBudget(lock, readLedger());
  if (artifact.size > budget)
    fail(
      `${name}: ${artifact.size} bytes exceed the remaining budget ${budget}`,
    );
  fs.mkdirSync(dirs.downloads, { recursive: true });
  const part = target + ".part";
  if (fs.existsSync(part)) reject(part, `${name}: stale partial download`);
  return new Promise((resolve, reject_) => {
    const hash = createHash("sha256");
    let received = 0;
    const get = (url, hops) => {
      const parsed = new URL(url);
      if (parsed.protocol !== "https:" || !allowedHosts.has(parsed.hostname))
        return reject_(
          new Error(`${name}: host not allowed: ${parsed.hostname}`),
        );
      https
        .get(
          url,
          { headers: { "user-agent": "recharge-media-tools" } },
          (response) => {
            if ([301, 302, 303, 307, 308].includes(response.statusCode)) {
              response.resume();
              if (hops >= 5)
                return reject_(new Error(`${name}: too many redirects`));
              return get(
                new URL(response.headers.location, url).toString(),
                hops + 1,
              );
            }
            if (response.statusCode !== 200) {
              response.resume();
              return reject_(new Error(`${name}: HTTP ${response.statusCode}`));
            }
            const announced = Number(response.headers["content-length"]);
            if (announced !== artifact.size) {
              response.destroy();
              return reject_(
                new Error(
                  `${name}: announced ${announced} bytes, manifest ${artifact.size}`,
                ),
              );
            }
            const out = fs.createWriteStream(part, { flags: "wx" });
            response.on("data", (chunk) => {
              received += chunk.length;
              if (received > artifact.size) {
                response.destroy(
                  new Error(`${name}: more bytes than the manifest`),
                );
                return;
              }
              hash.update(chunk);
            });
            response.on("error", (error) => {
              out.destroy();
              reject_(error);
            });
            response.pipe(out);
            out.on("finish", () => {
              if (received !== artifact.size)
                return reject_(
                  new Error(`${name}: received ${received} bytes`),
                );
              resolve({ digest: hash.digest("hex") });
            });
          },
        )
        .on("error", reject_);
    };
    get(artifact.url, 0);
  }).then(
    ({ digest }) => {
      record(name, fileSize(part));
      if (artifact.sha256 && digest !== artifact.sha256)
        reject(part, `${name}: SHA-256 ${digest} differs from the manifest`);
      fs.renameSync(part, target);
      log(`  ${name}: ${artifact.size} bytes, SHA-256 ${digest}`);
      return target;
    },
    (error) => {
      if (fs.existsSync(part)) {
        record(name + " (partial)", fileSize(part));
        reject(part, error.message);
      }
      throw error;
    },
  );
}
const fileSize = (file) => (fs.existsSync(file) ? fs.statSync(file).size : 0);

// ---------- Windows helpers ----------

export function ps(script, { env = {}, input } = {}) {
  const encoded = Buffer.from(
    '$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"; ' +
      script,
    "utf16le",
  ).toString("base64");
  const result = spawnSync(
    "powershell.exe",
    ["-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
    {
      encoding: "utf8",
      windowsHide: true,
      env: { ...process.env, ...env },
      input,
    },
  );
  if (result.status !== 0)
    fail(
      "PowerShell step failed: " +
        readableError(result.stderr || result.stdout),
    );
  return result.stdout.trim();
}

/** PowerShell reports errors as CLIXML on a redirected stderr. */
export function readableError(text) {
  const errors = [...text.matchAll(/<S S="Error">([^<]*)<\/S>/gu)].map(
    (match) =>
      match[1]
        .replace(/_x000D__x000A_|_x000A_/gu, " ")
        .replace(/_x[0-9A-F]{4}_/gu, ""),
  );
  return (errors.length > 0 ? errors.join("") : text).trim().slice(0, 600);
}

/**
 * Lists the zip's central directory, refuses it when the declared size, entry
 * count or any path is out of bounds, then extracts with every entry capped at
 * its declared length.
 */
export const zipScript = `
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($env:RECHARGE_ZIP)
try {
  $entries = @($zip.Entries)
  if ($entries.Count -gt [int64]$env:RECHARGE_MAX_ENTRIES) { throw "zip has $($entries.Count) entries" }
  $declared = [int64]0
  foreach ($e in $entries) {
    $name = $e.FullName
    if ($name -match '(^[\\\\/])|(:)|(^|[\\\\/])\\.\\.([\\\\/]|$)' -or $name -match '[\\x00-\\x1f]') { throw "unsafe path: $name" }
    if ((($e.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw "link entry: $name" }
    $declared += $e.Length
  }
  if ($declared -gt [int64]$env:RECHARGE_MAX_BYTES) { throw "zip declares $declared bytes" }
  $root = [System.IO.Path]::GetFullPath($env:RECHARGE_DEST)
  [System.IO.Directory]::CreateDirectory($root) | Out-Null
  $buffer = New-Object byte[] 65536
  $written = [int64]0
  foreach ($e in $entries) {
    $target = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $e.FullName))
    if (-not $target.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar)) { throw "escapes: $($e.FullName)" }
    if ($e.FullName.EndsWith('/') -or $e.FullName.EndsWith('\\')) { [System.IO.Directory]::CreateDirectory($target) | Out-Null; continue }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
    $in = $e.Open(); $out = [System.IO.File]::Open($target, 'CreateNew')
    try {
      $count = [int64]0
      while (($n = $in.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $count += $n
        if ($count -gt $e.Length) { throw "entry larger than declared: $($e.FullName)" }
        $out.Write($buffer, 0, $n)
      }
      if ($count -ne $e.Length) { throw "entry size mismatch: $($e.FullName)" }
      $written += $count
    } finally { $out.Dispose(); $in.Dispose() }
  }
  [Console]::Out.Write((@{ entries = $entries.Count; bytes = $written } | ConvertTo-Json -Compress))
} finally { $zip.Dispose() }
`;

function extract(name, zip, unpack, finalDir) {
  if (fs.existsSync(finalDir)) {
    log(`  ${name}: already extracted`);
    return null;
  }
  const staging = path.join(dirs.staging, `${name}-${stamp()}`);
  try {
    const out = ps(zipScript, {
      env: {
        RECHARGE_ZIP: zip,
        RECHARGE_DEST: staging,
        RECHARGE_MAX_BYTES: String(unpack.maxBytes),
        RECHARGE_MAX_ENTRIES: String(unpack.maxEntries),
      },
    });
    const result = JSON.parse(out);
    log(
      `  ${name}: ${result.entries} entries, ${result.bytes} bytes extracted`,
    );
    return { staging, ...result };
  } catch (error) {
    if (fs.existsSync(staging))
      reject(staging, `${name}: extraction refused: ${error.message}`);
    throw error;
  }
}

function filesDigest(directory) {
  const lines = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else
        lines.push(
          `${path.relative(directory, full).replaceAll("\\", "/")} ${sha256File(full)}`,
        );
    }
  };
  walk(directory);
  lines.sort();
  return {
    count: lines.length,
    digest: createHash("sha256").update(lines.join("\n")).digest("hex"),
    lines,
  };
}

// ---------- steps ----------

export function nodePaths(lock = readLock()) {
  const home = path.join(toolsRoot, lock.artifacts.node.directory);
  return {
    home,
    node: path.join(home, "node.exe"),
    npmCli: path.join(home, "node_modules", "npm", "bin", "npm-cli.js"),
  };
}

async function restoreNode(lock) {
  log("Node.js 22.23.2 (restores the pinned npm 10.9.8)");
  const artifact = lock.artifacts.node;
  const zip = await download("node", artifact, lock);
  const paths = nodePaths(lock);
  const extracted = extract("node", zip, artifact.unpack, paths.home);
  if (extracted) {
    const inner = path.join(extracted.staging, artifact.directory);
    if (!fs.existsSync(path.join(inner, "node.exe")))
      reject(extracted.staging, "node: unexpected archive layout");
    fs.renameSync(inner, paths.home);
  }
  const nodeSha = sha256File(paths.node);
  if (nodeSha !== artifact.nodeExeSha256)
    fail(`node.exe SHA-256 ${nodeSha} is not the release`);
  const npmManifest = JSON.parse(
    fs.readFileSync(
      path.join(paths.home, "node_modules", "npm", "package.json"),
      "utf8",
    ),
  );
  if (npmManifest.version !== artifact.npmVersion)
    fail(`bundled npm ${npmManifest.version}, expected ${artifact.npmVersion}`);
  const version = spawnSync(paths.node, [paths.npmCli, "--version"], {
    encoding: "utf8",
  });
  if (version.stdout.trim() !== artifact.npmVersion)
    fail(`npm --version answered ${version.stdout.trim()}`);
  const nodeVersion = spawnSync(paths.node, ["--version"], {
    encoding: "utf8",
  }).stdout.trim();
  log(
    `  node ${nodeVersion}, npm ${version.stdout.trim()}, node.exe SHA-256 verified`,
  );
  return {
    nodeVersion,
    npmVersion: version.stdout.trim(),
    nodeExeSha256: nodeSha,
  };
}

function directorySize(dir) {
  if (!fs.existsSync(dir)) return 0;
  let total = 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    total += entry.isDirectory() ? directorySize(full) : fs.statSync(full).size;
  }
  return total;
}

const npmEnv = () => ({
  ...process.env,
  npm_config_update_notifier: "false",
  npm_config_fund: "false",
  npm_config_audit: "false",
});

/**
 * Runs the pinned npm while a watchdog measures the isolated cache: growth
 * beyond the remaining budget stops npm at once. The growth is recorded.
 */
function npmWatched(paths, args, cwd, lock, phase) {
  return new Promise((resolve, reject_) => {
    const before = directorySize(dirs.npmCache);
    const allowance = remainingBudget(lock, readLedger());
    const child = spawn(paths.node, [paths.npmCli, ...args], {
      cwd,
      windowsHide: true,
      env: npmEnv(),
    });
    let out = "";
    let err = "";
    child.stdout.on("data", (chunk) => (out += chunk));
    child.stderr.on("data", (chunk) => (err += chunk));
    let exceeded = false;
    const timer = setInterval(() => {
      if (directorySize(dirs.npmCache) - before > allowance) {
        exceeded = true;
        child.kill();
      }
    }, 500);
    child.on("exit", (code) => {
      clearInterval(timer);
      const grown = directorySize(dirs.npmCache) - before;
      const total = record(`npm ${phase}`, grown);
      if (exceeded || total > lock.budgetBytes)
        return reject_(
          new Error(`budget exceeded during npm ${phase} (${total} bytes)`),
        );
      if (code !== 0)
        return reject_(
          new Error(`npm ${phase} failed: ${(err || out).trim().slice(-800)}`),
        );
      resolve({ out, grown });
    });
  });
}

function npmLsProblems(paths) {
  const result = spawnSync(
    paths.node,
    [paths.npmCli, "ls", "--all", "--json"],
    {
      cwd: functionsDir,
      encoding: "utf8",
      windowsHide: true,
      env: npmEnv(),
      maxBuffer: 64 * 1024 * 1024,
    },
  );
  return JSON.parse(result.stdout || "{}").problems ?? [];
}

/** Path of a tarball in the cacache content store, from its SRI. */
export function cachedTarball(cache, integrity) {
  const hex = Buffer.from(
    integrity.replace(/^sha512-/u, ""),
    "base64",
  ).toString("hex");
  return path.join(
    cache,
    "_cacache",
    "content-v2",
    "sha512",
    hex.slice(0, 2),
    hex.slice(2, 4),
    hex.slice(4),
  );
}

function lockPackages(file) {
  return JSON.parse(fs.readFileSync(file, "utf8")).packages;
}

async function installSharp(lock, paths) {
  log("sharp 0.35.5 from an isolated cache, installed offline");
  const wanted = lock.npm;
  const installed = path.join(
    functionsDir,
    "node_modules",
    "sharp",
    "package.json",
  );
  if (
    fs.existsSync(installed) &&
    JSON.parse(fs.readFileSync(installed, "utf8")).version === "0.35.5"
  ) {
    log("  already installed");
    return verifyInstall(lock);
  }
  fs.mkdirSync(dirs.npmCache, { recursive: true });
  const cacheArg = ["--cache", dirs.npmCache];
  const problems = npmLsProblems(paths);
  if (problems.length > 0)
    fail(
      `node_modules is not clean before the install: ${problems.slice(0, 5).join("; ")}`,
    );

  // Phase 0: metadata only, in a copy of package.json and the lock.
  const resolveDir = path.join(dirs.resolve, stamp());
  fs.mkdirSync(resolveDir, { recursive: true });
  for (const file of ["package.json", "package-lock.json"])
    fs.copyFileSync(path.join(functionsDir, file), path.join(resolveDir, file));
  const metadata = await npmWatched(
    paths,
    [
      "install",
      "sharp@0.35.5",
      "--save-exact",
      "--package-lock-only",
      "--ignore-scripts",
      ...cacheArg,
    ],
    resolveDir,
    lock,
    "metadata",
  );
  log(`  metadata: ${metadata.grown} bytes`);
  const oldPackages = lockPackages(
    path.join(functionsDir, "package-lock.json"),
  );
  const newPackages = lockPackages(path.join(resolveDir, "package-lock.json"));
  const added = Object.keys(newPackages).filter((key) => !(key in oldPackages));
  if (added.length !== 30)
    fail(`resolution added ${added.length} lock entries, expected 30`);
  for (const pkg of wanted) {
    const entry = newPackages[`node_modules/${pkg.name}`];
    if (
      entry?.version !== pkg.version ||
      entry.integrity !== pkg.integrity ||
      entry.resolved !== pkg.resolved
    )
      fail(`resolution of ${pkg.name} differs from the manifest`);
  }

  // Phase 1: exactly the six tarballs into the isolated cache.
  const tarballs = await npmWatched(
    paths,
    [
      "cache",
      "add",
      ...wanted.map((pkg) => `${pkg.name}@${pkg.version}`),
      "--prefer-offline",
      ...cacheArg,
    ],
    functionsDir,
    lock,
    "tarballs",
  );
  for (const pkg of wanted) {
    const file = cachedTarball(dirs.npmCache, pkg.integrity);
    if (!fs.existsSync(file))
      fail(`${pkg.name}: tarball with the manifest integrity is not cached`);
    const size = fs.statSync(file).size;
    if (size > pkg.maxTarballBytes)
      reject(file, `${pkg.name}: tarball ${size} bytes over its bound`);
  }
  log(`  tarballs: cache grew by ${tarballs.grown} bytes`);

  // Phase 2: the real install cannot reach the network.
  const topBefore = new Set(listTopLevel());
  await npmWatched(
    paths,
    ["install", "sharp@0.35.5", "--save-exact", "--offline", ...cacheArg],
    functionsDir,
    lock,
    "install",
  );
  const newTop = listTopLevel()
    .filter((name) => !topBefore.has(name))
    .sort();
  const gone = [...topBefore].filter((name) => !listTopLevel().includes(name));
  const expectedTop = wanted.map((pkg) => pkg.name).sort();
  if (JSON.stringify(newTop) !== JSON.stringify(expectedTop) || gone.length > 0)
    fail(
      `install added ${JSON.stringify(newTop)} and removed ${JSON.stringify(gone)}; expected only ${JSON.stringify(expectedTop)}`,
    );
  return verifyInstall(lock, oldPackages);
}

function listTopLevel() {
  const root = path.join(functionsDir, "node_modules");
  const names = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith(".")) continue;
    if (entry.name.startsWith("@"))
      for (const inner of fs.readdirSync(path.join(root, entry.name)))
        names.push(`${entry.name}/${inner}`);
    else names.push(entry.name);
  }
  return names;
}

function verifyInstall(lock, oldPackages) {
  const packages = lockPackages(path.join(functionsDir, "package-lock.json"));
  const report = [];
  for (const pkg of lock.npm) {
    const dir = path.join(functionsDir, "node_modules", ...pkg.name.split("/"));
    const manifest = JSON.parse(
      fs.readFileSync(path.join(dir, "package.json"), "utf8"),
    );
    if (manifest.version !== pkg.version)
      fail(`${pkg.name}: installed ${manifest.version}`);
    for (const hook of ["preinstall", "install", "postinstall"])
      if (manifest.scripts?.[hook])
        fail(`${pkg.name}: unexpected ${hook} script`);
    const size = directorySize(dir);
    if (size !== pkg.unpackedBytes)
      fail(
        `${pkg.name}: ${size} bytes unpacked, registry ${pkg.unpackedBytes}`,
      );
    const entry = packages[`node_modules/${pkg.name}`];
    if (entry?.integrity !== pkg.integrity)
      fail(`${pkg.name}: lock integrity differs`);
    const tarball = cachedTarball(dirs.npmCache, pkg.integrity);
    const tarballFacts = fs.existsSync(tarball)
      ? {
          tarballBytes: fs.statSync(tarball).size,
          tarballSha256: sha256File(tarball),
        }
      : {};
    const notices = fs
      .readdirSync(dir)
      .filter((name) => /licen[cs]e|notice|third.?party|copying/iu.test(name));
    report.push({
      name: pkg.name,
      version: pkg.version,
      unpackedBytes: size,
      notices,
      ...tarballFacts,
    });
  }
  if (oldPackages) {
    const added = Object.keys(packages).filter((key) => !(key in oldPackages));
    const removed = Object.keys(oldPackages).filter(
      (key) => !(key in packages),
    );
    if (added.length !== 30 || removed.length !== 0)
      fail(`lock changed by +${added.length}/-${removed.length} entries`);
  }
  log(
    `  installed and verified: ${report.map((r) => `${r.name}@${r.version}`).join(", ")}`,
  );
  return report;
}

function findGpg() {
  for (const candidate of [
    "C:\\Program Files\\Git\\usr\\bin\\gpg.exe",
    path.join(process.env.ProgramFiles || "", "Git", "usr", "bin", "gpg.exe"),
  ])
    if (fs.existsSync(candidate)) return candidate;
  return null;
}

async function fetchClamav(lock) {
  log("ClamAV 1.5.4 (Windows x64 portable zip)");
  const { clamav, clamavSignature, talosKey } = lock.artifacts;
  const zip = await download("clamav", clamav, lock);
  const sig = await download("clamav-signature", clamavSignature, lock);
  const key = await download("talos-key", { ...talosKey, sha256: null }, lock);
  const keyBytes = fs.readFileSync(key);
  const blob = createHash("sha1")
    .update(Buffer.concat([Buffer.from(`blob ${keyBytes.length}\0`), keyBytes]))
    .digest("hex");
  if (blob !== talosKey.gitBlob)
    reject(key, `talos key git blob ${blob} differs from the manifest`);
  const keySha256 = sha256File(key);

  let gpg = { performed: false, reason: "gpg not found" };
  const gpgExe = findGpg();
  if (gpgExe) {
    const home = path.join(dirs.gnupg, stamp());
    fs.mkdirSync(home, { recursive: true });
    const run = (args) =>
      spawnSync(
        gpgExe,
        ["--homedir", home, "--batch", "--no-tty", "--status-fd", "1", ...args],
        {
          encoding: "utf8",
          windowsHide: true,
        },
      );
    const imported = run(["--import", key]);
    const verified = run(["--verify", sig, zip]);
    const good = /\[GNUPG:\] GOODSIG/u.test(verified.stdout);
    const valid = /\[GNUPG:\] VALIDSIG ([0-9A-F]{40})/u.exec(verified.stdout);
    if (!good || !valid)
      fail(
        `GPG signature check failed: ${(verified.stdout + verified.stderr).slice(0, 600)}`,
      );
    const keyId =
      /\[GNUPG:\] IMPORT_OK \d+ ([0-9A-F]{40})/u.exec(imported.stdout)?.[1] ??
      null;
    gpg = {
      performed: true,
      good: true,
      signingKeyFingerprint: valid[1],
      importedKeyFingerprint: keyId,
      homedir: home,
    };
    log(`  GPG: good signature, key ${valid[1]}`);
  }

  const finalDir = path.join(toolsRoot, clamav.directory);
  const extracted = extract("clamav", zip, clamav.unpack, finalDir);
  if (extracted) {
    const top = fs.readdirSync(extracted.staging);
    const inner =
      top.length === 1 &&
      fs.statSync(path.join(extracted.staging, top[0])).isDirectory()
        ? path.join(extracted.staging, top[0])
        : extracted.staging;
    if (!fs.existsSync(path.join(inner, "clamd.exe")))
      reject(extracted.staging, "clamav: clamd.exe not found");
    fs.renameSync(inner, finalDir);
  }
  const files = filesDigest(finalDir);
  fs.writeFileSync(
    path.join(toolsRoot, "clamav-1.5.4.files.txt"),
    files.lines.join("\n") + "\n",
  );
  log(`  ${files.count} files, digest ${files.digest}`);
  return {
    keySha256,
    gpg,
    files: { count: files.count, digest: files.digest },
  };
}

async function fetchAll() {
  const lock = readLock();
  for (const dir of Object.values(dirs)) fs.mkdirSync(dir, { recursive: true });
  log(
    `Budget ${lock.budgetBytes} bytes; already used ${readLedger().totalBytes}`,
  );
  const node = await restoreNode(lock);
  const paths = nodePaths(lock);
  const npmReport = await installSharp(lock, paths);
  const clamav = await fetchClamav(lock);
  const stand = standDatabase();
  lock.databases.stand = {
    file: standDatabaseName,
    signature: "Recharge.Test.Marker",
    sha256: createHash("sha256").update(stand).digest("hex"),
  };
  lock.npm = lock.npm.map((pkg) => {
    const facts = npmReport.find((item) => item.name === pkg.name) ?? {};
    return {
      ...pkg,
      tarballBytes: facts.tarballBytes,
      tarballSha256: facts.tarballSha256,
      notices: facts.notices ?? [],
    };
  });
  lock.verified = {
    at: new Date().toISOString(),
    downloadedBytes: readLedger().totalBytes,
    node,
    talosKeySha256: clamav.keySha256,
    gpg: clamav.gpg.performed
      ? { good: true, signingKeyFingerprint: clamav.gpg.signingKeyFingerprint }
      : { good: false, reason: clamav.gpg.reason },
    clamavFiles: clamav.files,
  };
  writeLock(lock);
  log(
    `Done. Downloaded ${readLedger().totalBytes} of ${lock.budgetBytes} budget bytes.`,
  );
}

// ---------- Job Object keeper (amendment §3.8, §4.2) ----------

const MiB = 1024 * 1024;
export const jobLimits = Object.freeze({
  service: { processBytes: 768 * MiB, jobBytes: 1024 * MiB, processes: 3 },
  clamd: { processBytes: 1024 * MiB, jobBytes: 1280 * MiB, processes: 2 },
});
export const jobFlags = Object.freeze({
  activeProcess: 0x8,
  processMemory: 0x100,
  jobMemory: 0x200,
  dieOnUnhandledException: 0x400,
  breakawayOk: 0x800,
  silentBreakawayOk: 0x1000,
  killOnJobClose: 0x2000,
});

/** C# P/Invoke class compiled by Windows PowerShell's Add-Type (built-in .NET Framework). */
export const jobSource = String.raw`
using System;
using System.Runtime.InteropServices;
public static class RechargeJob {
  [StructLayout(LayoutKind.Sequential)] public struct IoCounters { public ulong R, W, O, RB, WB, OB; }
  [StructLayout(LayoutKind.Sequential)] public struct BasicLimit {
    public long PerProcessUserTimeLimit; public long PerJobUserTimeLimit; public uint LimitFlags;
    public UIntPtr MinimumWorkingSetSize; public UIntPtr MaximumWorkingSetSize; public uint ActiveProcessLimit;
    public UIntPtr Affinity; public uint PriorityClass; public uint SchedulingClass; }
  [StructLayout(LayoutKind.Sequential)] public struct ExtendedLimit {
    public BasicLimit Basic; public IoCounters Io; public UIntPtr ProcessMemoryLimit; public UIntPtr JobMemoryLimit;
    public UIntPtr PeakProcessMemoryUsed; public UIntPtr PeakJobMemoryUsed; }
  [StructLayout(LayoutKind.Sequential)] public struct Violation {
    public uint LimitFlags, ViolationLimitFlags; public ulong IoReadBytes, IoReadBytesLimit, IoWriteBytes, IoWriteBytesLimit;
    public long PerJobUserTime, PerJobUserTimeLimit; public ulong JobMemory, JobMemoryLimit;
    public int RateControlTolerance, RateControlToleranceLimit; }
  [StructLayout(LayoutKind.Sequential)] public struct Accounting {
    public long TotalUserTime, TotalKernelTime, ThisPeriodTotalUserTime, ThisPeriodTotalKernelTime;
    public uint TotalPageFaultCount, TotalProcesses, ActiveProcesses, TotalTerminatedProcesses; }
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr CreateJobObjectW(IntPtr a, string name);
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr OpenJobObjectW(uint access, bool inherit, string name);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool SetInformationJobObject(IntPtr job, int cls, ref ExtendedLimit info, uint length);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool QueryInformationJobObject(IntPtr job, int cls, out ExtendedLimit info, uint length, IntPtr ret);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool QueryInformationJobObject(IntPtr job, int cls, out Accounting info, uint length, IntPtr ret);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool QueryInformationJobObject(IntPtr job, int cls, out Violation info, uint length, IntPtr ret);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool QueryInformationJobObject(IntPtr job, int cls, IntPtr info, uint length, IntPtr ret);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
  [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
  [DllImport("kernel32.dll", SetLastError = true)] static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool result);
  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
  static void Check(bool ok, string what) { if (!ok) throw new InvalidOperationException(what + " failed: win32 " + Marshal.GetLastWin32Error()); }
  // Creates the named job and puts this process into it; processes it starts are born inside.
  public static void JoinNew(string name, ulong processBytes, ulong jobBytes, uint processes) {
    IntPtr job = CreateJobObjectW(IntPtr.Zero, name);
    Check(job != IntPtr.Zero, "CreateJobObject");
    if (Marshal.GetLastWin32Error() == 183) throw new InvalidOperationException("job name already exists");
    ExtendedLimit info = new ExtendedLimit();
    info.Basic.LimitFlags = 0x8 | 0x100 | 0x200 | 0x400 | 0x2000;
    info.Basic.ActiveProcessLimit = processes;
    info.ProcessMemoryLimit = new UIntPtr(processBytes);
    info.JobMemoryLimit = new UIntPtr(jobBytes);
    Check(SetInformationJobObject(job, 9, ref info, (uint)Marshal.SizeOf(typeof(ExtendedLimit))), "SetInformationJobObject");
    Check(AssignProcessToJobObject(job, GetCurrentProcess()), "AssignProcessToJobObject");
  }
  public static string Describe(string name) {
    IntPtr job = OpenJobObjectW(0x0004, false, name);
    if (job == IntPtr.Zero) return "{\"exists\":false,\"error\":" + Marshal.GetLastWin32Error() + "}";
    try {
      Accounting acc; ExtendedLimit ext; Violation now;
      Check(QueryInformationJobObject(job, 1, out acc, (uint)Marshal.SizeOf(typeof(Accounting)), IntPtr.Zero), "accounting");
      Check(QueryInformationJobObject(job, 9, out ext, (uint)Marshal.SizeOf(typeof(ExtendedLimit)), IntPtr.Zero), "limits");
      string memory = QueryInformationJobObject(job, 13, out now, (uint)Marshal.SizeOf(typeof(Violation)), IntPtr.Zero) ? now.JobMemory.ToString() : "null";
      int size = 8 + 64 * IntPtr.Size; IntPtr buffer = Marshal.AllocHGlobal(size); string pids = "";
      try {
        Check(QueryInformationJobObject(job, 3, buffer, (uint)size, IntPtr.Zero), "pid list");
        int count = Marshal.ReadInt32(buffer, 4);
        for (int i = 0; i < count; i++) pids += (i == 0 ? "" : ",") + Marshal.ReadIntPtr(buffer, 8 + i * IntPtr.Size).ToInt64();
      } finally { Marshal.FreeHGlobal(buffer); }
      return "{\"exists\":true,\"active\":" + acc.ActiveProcesses + ",\"pids\":[" + pids + "],\"flags\":" + ext.Basic.LimitFlags +
        ",\"activeLimit\":" + ext.Basic.ActiveProcessLimit + ",\"processLimit\":" + ext.ProcessMemoryLimit + ",\"jobLimit\":" + ext.JobMemoryLimit +
        ",\"peakProcess\":" + ext.PeakProcessMemoryUsed + ",\"peakJob\":" + ext.PeakJobMemoryUsed + ",\"jobMemoryNow\":" + memory + "}";
    } finally { CloseHandle(job); }
  }
  public static bool InJob(int pid, string name) {
    IntPtr job = OpenJobObjectW(0x0004, false, name); Check(job != IntPtr.Zero, "OpenJobObject");
    IntPtr process = OpenProcess(0x1000, false, pid); Check(process != IntPtr.Zero, "OpenProcess");
    try { bool result; Check(IsProcessInJob(process, job, out result), "IsProcessInJob"); return result; }
    finally { CloseHandle(process); CloseHandle(job); }
  }
}`;

/**
 * The keeper: joins a new job with the limits, starts the target inside it
 * (`-NoNewWindow`, so no extra console host in the job), reports both pids in
 * the ready file and lives as long as the target. Closing it closes the last
 * job handle, and KILL_ON_JOB_CLOSE ends every process of the job.
 */
export const keeperScript = `
$ready = $env:RECHARGE_KEEPER_READY
function Report($value) { $tmp = "$ready.tmp"; Set-Content -LiteralPath $tmp -Value ($value | ConvertTo-Json -Compress) -Encoding ASCII; Move-Item -LiteralPath $tmp -Destination $ready -Force }
try {
  Add-Type -TypeDefinition $env:RECHARGE_KEEPER_SOURCE
  [RechargeJob]::JoinNew($env:RECHARGE_KEEPER_JOB, [uint64]$env:RECHARGE_KEEPER_PROCESS_BYTES, [uint64]$env:RECHARGE_KEEPER_JOB_BYTES, [uint32]$env:RECHARGE_KEEPER_PROCESSES)
  $argumentList = (ConvertFrom-Json $env:RECHARGE_KEEPER_ARGS) | ForEach-Object { '"' + $_ + '"' }
  $p = Start-Process -FilePath $env:RECHARGE_KEEPER_EXE -ArgumentList ($argumentList -join ' ') -WorkingDirectory $env:RECHARGE_KEEPER_CWD -PassThru -NoNewWindow -RedirectStandardOutput $env:RECHARGE_KEEPER_OUT -RedirectStandardError $env:RECHARGE_KEEPER_ERR
  $null = $p.Handle
  Report @{ ok = $true; keeper = $PID; child = $p.Id }
  $p.WaitForExit()
} catch {
  Report @{ ok = $false; keeper = $PID; error = $_.Exception.Message }
  exit 1
}
`;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

export async function launchInJob({
  jobName,
  limits,
  exe,
  args,
  cwd,
  runDir,
  role,
  env = {},
}) {
  const ready = path.join(runDir, `${role}.ready.json`);
  if (fs.existsSync(ready)) fail(`${role}: a ready file already exists`);
  const encoded = Buffer.from(
    '$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"; ' +
      keeperScript,
    "utf16le",
  ).toString("base64");
  // A detached powershell.exe has no console and exits at once, so a short
  // synchronous PowerShell starts the keeper with its own hidden console.
  ps(
    `$p = Start-Process -FilePath powershell.exe -ArgumentList ('-NoProfile -NonInteractive -EncodedCommand ' + $env:RECHARGE_KEEPER_ENCODED) -WindowStyle Hidden -PassThru; [Console]::Out.Write($p.Id)`,
    {
      env: {
        ...env,
        RECHARGE_KEEPER_ENCODED: encoded,
        RECHARGE_KEEPER_READY: ready,
        RECHARGE_KEEPER_SOURCE: jobSource,
        RECHARGE_KEEPER_JOB: jobName,
        RECHARGE_KEEPER_PROCESS_BYTES: String(limits.processBytes),
        RECHARGE_KEEPER_JOB_BYTES: String(limits.jobBytes),
        RECHARGE_KEEPER_PROCESSES: String(limits.processes),
        RECHARGE_KEEPER_EXE: exe,
        RECHARGE_KEEPER_ARGS: JSON.stringify(args),
        RECHARGE_KEEPER_CWD: cwd,
        RECHARGE_KEEPER_OUT: path.join(runDir, `${role}.out.log`),
        RECHARGE_KEEPER_ERR: path.join(runDir, `${role}.err.log`),
      },
    },
  );
  const deadline = Date.now() + 60_000;
  while (!fs.existsSync(ready)) {
    if (Date.now() > deadline) fail(`${role}: the keeper did not report`);
    await sleep(200);
  }
  const report = JSON.parse(fs.readFileSync(ready, "utf8"));
  if (!report.ok) fail(`${role}: ${report.error}`);
  return { keeper: report.keeper, child: report.child, jobName };
}

const jobPrelude = () =>
  `Add-Type -TypeDefinition $env:RECHARGE_KEEPER_SOURCE; `;
export function describeJob(jobName) {
  return JSON.parse(
    ps(
      jobPrelude() +
        `[Console]::Out.Write([RechargeJob]::Describe($env:RECHARGE_JOB))`,
      {
        env: { RECHARGE_KEEPER_SOURCE: jobSource, RECHARGE_JOB: jobName },
      },
    ),
  );
}
export function inJob(pid, jobName) {
  return (
    ps(
      jobPrelude() +
        `[Console]::Out.Write([RechargeJob]::InJob([int]$env:RECHARGE_PID, $env:RECHARGE_JOB))`,
      {
        env: {
          RECHARGE_KEEPER_SOURCE: jobSource,
          RECHARGE_JOB: jobName,
          RECHARGE_PID: String(pid),
        },
      },
    ) === "True"
  );
}

/** PID, start time, executable and commit (KB) of live processes; absent ones are left out. */
export function identities(pids) {
  if (pids.length === 0) return [];
  const out = ps(
    `$ids = @(${pids.map((pid) => Number(pid)).join(",")}); ` +
      `Get-CimInstance Win32_Process | Where-Object { $ids -contains [int]$_.ProcessId } | ForEach-Object { [pscustomobject]@{ pid = [int]$_.ProcessId; started = $_.CreationDate.ToUniversalTime().ToString("o"); executable = $_.ExecutablePath; commitKb = [int64]$_.PageFileUsage } } | ConvertTo-Json -Compress`,
  );
  return [].concat(out ? JSON.parse(out) : []);
}

// ---------- the service ----------

const runRoot = path.join(toolsRoot, "run");
const hostModule = path.join(
  functionsDir,
  "lib",
  "test",
  "stand",
  "media_tools_host.js",
);
const instanceDir = (instance) => path.join(runRoot, instance);
const stateOf = (instance) => path.join(instanceDir(instance), "state.json");

function freePort() {
  return new Promise((resolve, reject) => {
    const server = createNetServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

function portOpen(port) {
  return new Promise((resolve) => {
    const socket = netConnect({ host: "127.0.0.1", port });
    socket.once("connect", () => {
      socket.destroy();
      resolve(true);
    });
    socket.once("error", () => resolve(false));
  });
}

export function http(port, method, route, token, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const payload = body ?? Buffer.alloc(0);
    const req = httpRequest({
      host: "127.0.0.1",
      port,
      method,
      path: route,
      agent: false,
      headers: {
        connection: "close",
        authorization: `Bearer ${token}`,
        "content-length": String(payload.length),
        ...headers,
      },
    });
    req.setTimeout(30_000, () => req.destroy(new Error("http timeout")));
    req.on("response", (response) => {
      const chunks = [];
      response.on("data", (chunk) => chunks.push(chunk));
      response.on("end", () => {
        const text = Buffer.concat(chunks).toString("utf8");
        resolve({
          status: response.statusCode,
          json: text ? JSON.parse(text) : null,
        });
      });
    });
    req.on("error", reject);
    req.end(payload);
  });
}

function verifyBinaries(lock, clamavDir) {
  const listed = new Map(
    fs
      .readFileSync(path.join(toolsRoot, "clamav-1.5.4.files.txt"), "utf8")
      .trim()
      .split("\n")
      .map((line) => {
        const at = line.lastIndexOf(" ");
        return [line.slice(0, at), line.slice(at + 1)];
      }),
  );
  const digest = createHash("sha256")
    .update([...listed].map(([file, sha]) => `${file} ${sha}`).join("\n"))
    .digest("hex");
  if (digest !== lock.verified?.clamavFiles?.digest)
    fail("ClamAV file list does not match the lock");
  for (const [file, sha] of listed)
    if (
      /\.(exe|dll)$/iu.test(file) &&
      sha256File(path.join(clamavDir, file)) !== sha
    )
      fail(`ClamAV binary changed: ${file}`);
  if (sha256File(nodePaths(lock).node) !== lock.artifacts.node.nodeExeSha256)
    fail("node.exe does not match the lock");
}

export function clamdConf(runDir, port) {
  const at = (name) => path.join(runDir, name);
  return [
    `TCPSocket ${port}`,
    "TCPAddr 127.0.0.1",
    "Foreground yes",
    `DatabaseDirectory ${at("db")}`,
    `TemporaryDirectory ${at("tmp")}`,
    `LogFile ${at("clamd-log.txt")}`,
    "LogTime yes",
    "MaxThreads 2",
    "MaxQueue 4",
    "MaxConnectionQueueLength 4",
    "ReadTimeout 10",
    "CommandReadTimeout 5",
    "SendBufTimeout 500",
    "IdleTimeout 30",
    "StreamMaxLength 2M",
    "MaxScanSize 8M",
    "MaxFileSize 4M",
    "MaxRecursion 8",
    "MaxFiles 100",
    "MaxScanTime 10000",
    "AlertExceedsMax yes",
    "AlertBrokenMedia yes",
    "AlertEncrypted yes",
    "Bytecode no",
    "",
  ].join("\n");
}

async function hostHelpers() {
  return import(pathToFileURL(hostModule).href);
}

/** Starts clamd and the service, each inside its own job (§4.11). */
export async function start({
  instance = "stand",
  standSignaturesOnly = false,
  selftestProbes = false,
} = {}) {
  const lock = readLock();
  if (!fs.existsSync(hostModule))
    fail("Build first: lib/test/stand/media_tools_host.js is missing");
  if (fs.existsSync(stateOf(instance)))
    fail(`Instance ${instance} already has a state file; stop it first`);
  const clamavDir = path.join(toolsRoot, lock.artifacts.clamav.directory);
  verifyBinaries(lock, clamavDir);
  const runDir = instanceDir(instance);
  if (fs.existsSync(runDir))
    fs.renameSync(runDir, `${runDir}.previous-${stamp()}`);
  for (const sub of ["db", "tmp"])
    fs.mkdirSync(path.join(runDir, sub), { recursive: true });
  const database = standDatabase();
  fs.writeFileSync(path.join(runDir, "db", standDatabaseName), database);
  if (
    sha256File(path.join(runDir, "db", standDatabaseName)) !==
    lock.databases.stand?.sha256
  )
    fail("stand database does not match the lock");
  if (fs.readdirSync(path.join(runDir, "db")).join() !== standDatabaseName)
    fail("the database directory holds more than the stand database");

  const clamdPort = await freePort();
  const port = await freePort();
  const token = randomBytes(32).toString("hex");
  const controlToken = randomBytes(32).toString("hex");
  fs.writeFileSync(
    path.join(runDir, "clamd.conf"),
    clamdConf(runDir, clamdPort),
  );
  const tag = `${instance}-${randomBytes(4).toString("hex")}`;
  const jobs = {
    clamd: `Local\\recharge-media-clamd-${tag}`,
    service: `Local\\recharge-media-tools-${tag}`,
  };
  const started = {
    instance,
    jobs,
    clamdPort,
    port,
    standSignaturesOnly,
    selftestProbes,
    processes: {},
  };
  try {
    const clamd = await launchInJob({
      jobName: jobs.clamd,
      limits: jobLimits.clamd,
      exe: path.join(clamavDir, "clamd.exe"),
      args: [`--config-file=${path.join(runDir, "clamd.conf")}`],
      cwd: clamavDir,
      runDir,
      role: "clamd",
    });
    started.processes.clamdKeeper = clamd.keeper;
    started.processes.clamd = clamd.child;
    const helpers = await hostHelpers();
    let version = null;
    for (const deadline = Date.now() + 60_000; version === null;) {
      try {
        version = await helpers.clamdVersion(clamdPort);
      } catch {
        if (Date.now() > deadline) fail("clamd did not answer within 60 s");
        await sleep(500);
      }
    }
    const marker = Buffer.from(`probe ${standMarker} probe`, "ascii");
    const positive = await helpers.clamdScan(clamdPort, marker);
    if (
      positive.kind !== "found" ||
      !/^Recharge\.Test\.Marker(\.UNOFFICIAL)?$/u.test(positive.signature)
    )
      fail(`stand signature not loaded: ${JSON.stringify(positive)}`);
    const negative = await helpers.clamdScan(
      clamdPort,
      Buffer.from("clean probe", "ascii"),
    );
    if (negative.kind !== "ok")
      fail(`clean probe not clean: ${JSON.stringify(negative)}`);
    started.clamd = { version, marker: positive.signature };

    const paths = nodePaths(lock);
    const host = await launchInJob({
      jobName: jobs.service,
      limits: jobLimits.service,
      exe: paths.node,
      args: [
        hostModule,
        ...(standSignaturesOnly ? ["--stand-signatures-only"] : []),
        ...(selftestProbes ? ["--selftest-probes"] : []),
      ],
      cwd: functionsDir,
      runDir,
      role: "host",
      env: {
        RECHARGE_TOOLS_PORT: String(port),
        RECHARGE_TOOLS_TOKEN: token,
        RECHARGE_TOOLS_CONTROL_TOKEN: controlToken,
        RECHARGE_TOOLS_CLAMD_PORT: String(clamdPort),
        RECHARGE_TOOLS_INSTANCE: tag,
      },
    });
    started.processes.hostKeeper = host.keeper;
    started.processes.host = host.child;
    for (const deadline = Date.now() + 20_000; !(await portOpen(port));) {
      if (Date.now() > deadline) fail("the service did not listen within 20 s");
      await sleep(250);
    }
    for (const [name, pid] of Object.entries(started.processes)) {
      const job = name.startsWith("clamd") ? jobs.clamd : jobs.service;
      if (!inJob(pid, job)) fail(`${name} (${pid}) is not inside ${job}`);
    }
    for (const [key, job] of Object.entries(jobs)) {
      const described = describeJob(job);
      const limits = jobLimits[key];
      if (
        described.processLimit !== limits.processBytes ||
        described.jobLimit !== limits.jobBytes ||
        described.activeLimit !== limits.processes ||
        (described.flags & jobFlags.killOnJobClose) === 0 ||
        (described.flags &
          (jobFlags.breakawayOk | jobFlags.silentBreakawayOk)) !==
          0
      )
        fail(`job ${job} limits differ: ${JSON.stringify(described)}`);
    }
    const armed = await http(port, "POST", "/v1/control/arm", controlToken);
    if (armed.status !== 204) fail(`arm answered ${armed.status}`);
    const health = await http(port, "GET", "/v1/health", token);
    if (
      health.status !== 200 ||
      health.json.state !== "ready" ||
      health.json.worker === null
    )
      fail(`service not ready: ${JSON.stringify(health.json)}`);
    if (!describeJob(jobs.service).pids.includes(health.json.worker.pid))
      fail("the worker is not inside the service job");
    started.identities = identities(Object.values(started.processes));
    if (started.identities.length !== Object.keys(started.processes).length)
      fail("a started process is already gone");
    fs.writeFileSync(
      path.join(runDir, "access.json"),
      JSON.stringify({ port, token, standSignaturesOnly }, null, 2),
    );
    fs.writeFileSync(
      path.join(runDir, "control.json"),
      JSON.stringify({ controlToken }, null, 2),
    );
    fs.writeFileSync(
      stateOf(instance),
      JSON.stringify(
        { version: 1, ...started, at: new Date().toISOString() },
        null,
        2,
      ),
    );
    log(
      `media tools ${instance}: service 127.0.0.1:${port}, clamd 127.0.0.1:${clamdPort}, ${standSignaturesOnly ? "stand signatures only (L1 test mode)" : "no database exemption"}`,
    );
    return { ...started, token, controlToken };
  } catch (error) {
    await stopProcesses(started);
    throw error;
  }
}

/** Keepers are stopped only after their identity is confirmed; the jobs end the rest. */
async function stopProcesses(started) {
  const recorded =
    started.identities ?? identities(Object.values(started.processes));
  for (const keeper of ["hostKeeper", "clamdKeeper"]) {
    const pid = started.processes[keeper];
    if (pid === undefined) continue;
    const known = recorded.find((item) => item.pid === pid);
    const live = identities([pid])[0];
    if (live === undefined) continue;
    if (
      known === undefined ||
      live.started !== known.started ||
      live.executable?.toLowerCase() !== known.executable?.toLowerCase()
    )
      fail(`process ${pid} is not the recorded keeper; nothing stopped`);
    ps(`Stop-Process -Id ${pid} -ErrorAction Stop`);
  }
  const deadline = Date.now() + 15_000;
  while (identities(Object.values(started.processes)).length > 0) {
    if (Date.now() > deadline)
      fail("processes of the media tools are still alive");
    await sleep(250);
  }
}

export async function stop({ instance = "stand" } = {}) {
  const file = stateOf(instance);
  if (!fs.existsSync(file)) fail(`Instance ${instance} is not running`);
  const state = JSON.parse(fs.readFileSync(file, "utf8"));
  const live = identities(Object.values(state.processes));
  for (const item of live) {
    const known = state.identities.find((entry) => entry.pid === item.pid);
    if (
      known === undefined ||
      known.started !== item.started ||
      known.executable?.toLowerCase() !== item.executable?.toLowerCase()
    )
      fail(
        `PID ${item.pid} was reused by another process; refused, nothing stopped`,
      );
  }
  const { controlToken } = JSON.parse(
    fs.readFileSync(path.join(instanceDir(instance), "control.json"), "utf8"),
  );
  if (live.some((item) => item.pid === state.processes.host)) {
    try {
      await http(state.port, "POST", "/v1/control/drain", controlToken);
    } catch {
      // A service that does not answer is ended through its job below.
    }
    const deadline = Date.now() + 25_000;
    while (
      identities([state.processes.host]).length > 0 &&
      Date.now() < deadline
    )
      await sleep(250);
  }
  await stopProcesses(state);
  const leftovers = Object.values(state.jobs).filter(
    (job) => describeJob(job).exists,
  );
  if (leftovers.length > 0) fail(`jobs still open: ${leftovers.join(", ")}`);
  for (const port of [state.port, state.clamdPort])
    if (await portOpen(port)) fail(`port ${port} is still open`);
  fs.renameSync(
    file,
    path.join(instanceDir(instance), `state.stopped-${stamp()}.json`),
  );
  log(`media tools ${instance}: stopped and verified`);
}

export async function status({ instance = "stand" } = {}) {
  const file = stateOf(instance);
  if (!fs.existsSync(file)) return { instance, state: "down" };
  const state = JSON.parse(fs.readFileSync(file, "utf8"));
  const { token } = JSON.parse(
    fs.readFileSync(path.join(instanceDir(instance), "access.json"), "utf8"),
  );
  const live = identities(Object.values(state.processes));
  let health = null;
  try {
    health = (await http(state.port, "GET", "/v1/health", token)).json;
  } catch {
    health = null;
  }
  return {
    instance,
    state:
      live.length === Object.keys(state.processes).length && health !== null
        ? "up"
        : "broken",
    processes: live,
    jobs: Object.fromEntries(
      Object.entries(state.jobs).map(([key, job]) => [key, describeJob(job)]),
    ),
    health,
  };
}

// ---------- self-check J1–J6 (§3.8) ----------

const tinyJpeg = Buffer.from(
  "/9j/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAAQABADASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAP/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAAAAAAAAAAAAAAAAAABf/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/AKAATb//2Q==",
  "base64",
);

export async function selftest() {
  const instance = `selftest-${stamp()}`;
  const report = {
    instance,
    at: new Date().toISOString(),
    tools: toolVersions(),
    checks: {},
  };
  const check = (id, ok, facts) => {
    report.checks[id] = { ok: Boolean(ok), ...facts };
    log(`  ${id}: ${ok ? "ok" : "FAILED"} ${JSON.stringify(facts)}`);
  };
  const service = await start({ instance, selftestProbes: true });
  const { port, token, controlToken, jobs, processes } = service;
  try {
    // J1 + J6: limits, flags and membership of both jobs.
    const health = (await http(port, "GET", "/v1/health", token)).json;
    const serviceJob = describeJob(jobs.service);
    const clamdJob = describeJob(jobs.clamd);
    const flagsOk = (job) =>
      (job.flags & jobFlags.killOnJobClose) !== 0 &&
      (job.flags & jobFlags.dieOnUnhandledException) !== 0 &&
      (job.flags & (jobFlags.breakawayOk | jobFlags.silentBreakawayOk)) === 0;
    check(
      "J1",
      serviceJob.processLimit === jobLimits.service.processBytes &&
        serviceJob.jobLimit === jobLimits.service.jobBytes &&
        serviceJob.activeLimit === jobLimits.service.processes &&
        flagsOk(serviceJob) &&
        inJob(processes.hostKeeper, jobs.service) &&
        inJob(processes.host, jobs.service) &&
        inJob(health.worker.pid, jobs.service),
      { job: serviceJob, worker: health.worker.pid },
    );
    check(
      "J6",
      clamdJob.processLimit === jobLimits.clamd.processBytes &&
        clamdJob.jobLimit === jobLimits.clamd.jobBytes &&
        clamdJob.activeLimit === jobLimits.clamd.processes &&
        flagsOk(clamdJob) &&
        inJob(processes.clamd, jobs.clamd),
      { job: clamdJob },
    );

    // J2: the worker cannot commit beyond its per-process limit.
    const firstWorker = health.worker.pid;
    const j2 = await http(
      port,
      "POST",
      "/v1/selftest/probe",
      controlToken,
      Buffer.from(JSON.stringify({ kind: "allocate", mib: 1024 })),
    );
    const afterJ2 = describeJob(jobs.service);
    const limitMiB = jobLimits.service.processBytes / MiB;
    check(
      "J2",
      j2.status === 200 &&
        j2.json.answer?.refused === true &&
        j2.json.answer.reached < limitMiB &&
        afterJ2.peakProcess <= jobLimits.service.processBytes,
      {
        answer: j2.json?.answer,
        peakProcessMiB: Math.round(afterJ2.peakProcess / MiB),
        worker: firstWorker,
      },
    );

    // J3: a hung worker is ended at the deadline and its memory is released.
    const hung = http(
      port,
      "POST",
      "/v1/selftest/probe",
      controlToken,
      Buffer.from(JSON.stringify({ kind: "hang", mib: 400 })),
    );
    await sleep(4_000);
    const during = describeJob(jobs.service);
    const hungWorker = (await http(port, "GET", "/v1/health", token)).json
      .worker?.pid;
    const hungCommit = identities([hungWorker])[0]?.commitKb ?? 0;
    const j3 = await hung;
    const after = describeJob(jobs.service);
    const releasedMiB = Math.round(
      (during.jobMemoryNow - after.jobMemoryNow) / MiB,
    );
    const sha = createHash("sha256").update(tinyJpeg).digest("hex");
    const next = await http(port, "POST", "/v1/process", token, tinyJpeg, {
      "content-type": "application/octet-stream",
      "x-recharge-request-id": randomBytes(8).toString("hex"),
      "x-recharge-sha256": sha,
      "x-recharge-profiles": "display,thumb",
    });
    const nextWorker = (await http(port, "GET", "/v1/health", token)).json
      .worker?.pid;
    check(
      "J3",
      j3.json?.answer?.kind === "timeout" &&
        identities([hungWorker]).length === 0 &&
        during.active === 3 &&
        after.active === 2 &&
        releasedMiB >= 380 &&
        next.status === 200 &&
        next.json.result === "succeeded" &&
        nextWorker !== undefined &&
        nextWorker !== hungWorker,
      {
        hungWorker,
        hungCommitMiB: Math.round(hungCommit / 1024),
        activeDuring: during.active,
        activeAfter: after.active,
        jobMemoryDuringMiB: Math.round(during.jobMemoryNow / MiB),
        jobMemoryAfterMiB: Math.round(after.jobMemoryNow / MiB),
        releasedMiB,
        nextResult: next.json?.result,
        nextWorker,
      },
    );

    // J4: a job that does not admit the process starts nothing.
    const j4Dir = path.join(instanceDir(instance), "j4");
    fs.mkdirSync(j4Dir, { recursive: true });
    let j4Error = null;
    try {
      await launchInJob({
        jobName: `Local\\recharge-media-j4-${randomBytes(4).toString("hex")}`,
        limits: { processBytes: 128 * MiB, jobBytes: 256 * MiB, processes: 1 },
        exe: nodePaths().node,
        args: ["-e", "setTimeout(() => {}, 60000)"],
        cwd: j4Dir,
        runDir: j4Dir,
        role: "j4",
      });
    } catch (error) {
      j4Error = error.message;
    }
    check("J4", j4Error !== null && /quota/iu.test(j4Error), {
      error: j4Error,
    });
  } finally {
    // J5: stopping ends every process through the jobs.
    let stopError = null;
    try {
      await stop({ instance });
    } catch (error) {
      stopError = error.message;
    }
    const gone = identities(Object.values(processes)).length === 0;
    const jobsGone = Object.values(jobs).every(
      (job) => !describeJob(job).exists,
    );
    const portsClosed =
      !(await portOpen(port)) && !(await portOpen(service.clamdPort));
    check("J5", stopError === null && gone && jobsGone && portsClosed, {
      stopError,
      gone,
      jobsGone,
      portsClosed,
    });
    const file = path.join(runRoot, `${instance}.selftest.json`);
    fs.writeFileSync(file, JSON.stringify(report, null, 2));
    log(`self-check report: ${file}`);
  }
  const failed = Object.entries(report.checks)
    .filter(([, value]) => !value.ok)
    .map(([id]) => id);
  if (failed.length > 0) fail(`self-check failed: ${failed.join(", ")}`);
  return report;
}

function toolVersions() {
  const out = ps(
    `$net = Get-ItemProperty 'HKLM:\\SOFTWARE\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full' -Name Release, Version; ` +
      `$csc = Join-Path $env:WINDIR 'Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe'; ` +
      `[Console]::Out.Write((@{ powershell = $PSVersionTable.PSVersion.ToString(); netFramework = $net.Version; netRelease = $net.Release; csc = (Get-Item $csc).VersionInfo.FileVersion; osBuild = [Environment]::OSVersion.Version.ToString() } | ConvertTo-Json -Compress))`,
  );
  return { ...JSON.parse(out), node: process.version };
}

export async function main(args) {
  const [command, ...rest] = args;
  const instance = rest
    .find((arg) => arg.startsWith("--instance="))
    ?.slice("--instance=".length);
  const yes = rest.includes("--yes");
  switch (command) {
    case "fetch":
      if (!yes) fail("Usage: media-tools.mjs fetch --yes");
      return fetchAll();
    case "start":
      if (rest.includes("--selftest-probes"))
        fail("--selftest-probes is reserved for selftest");
      return void (await start({
        instance,
        standSignaturesOnly: rest.includes("--stand-signatures-only"),
      }));
    case "stop":
      return stop({ instance });
    case "status":
      return log(JSON.stringify(await status({ instance }), null, 2));
    case "selftest":
      if (!yes) fail("Usage: media-tools.mjs selftest --yes");
      return void (await selftest());
    default:
      fail(
        "Usage: media-tools.mjs fetch|start|stop|status|selftest [--yes] [--instance=<name>] [--stand-signatures-only]",
      );
  }
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`media-tools: ${error.message}\n`);
    process.exitCode = 1;
  });
