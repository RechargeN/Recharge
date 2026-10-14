// D1-L: the Linux side of the local Media tools
// (docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md §15). Runs on the CI runner
// ubuntu-24.04 only. ClamAV comes from the official .deb (extracted, never
// installed into the system); the official signature databases come through
// freshclam and are never committed, uploaded or mirrored; memory is capped by
// cgroup v2 scopes created with systemd-run, and stopping a scope ends every
// process in it (the Linux counterpart of the Windows Job Object).
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash, randomBytes } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";

import {
  MiB,
  clamdConf,
  directorySize,
  download,
  fail,
  fetchTalosKey,
  freePort,
  functionsDir,
  hostHelpers,
  hostModule,
  http,
  instanceDir,
  log,
  portOpen,
  readLedger,
  readLock,
  record,
  reject as moveAside,
  remainingBudget,
  runRoot,
  sha256File,
  sleep,
  stamp,
  standDatabase,
  standDatabaseName,
  standMarker,
  stateOf,
  tinyJpeg,
  toolsRoot,
  verifyGpgSignature,
} from "./media-tools.mjs";

/** cgroup v2 limits per scope; TasksMax counts threads too. */
export const scopeLimits = Object.freeze({
  service: { memoryMax: 768 * MiB, tasksMax: 512 },
  clamd: { memoryMax: 2048 * MiB, tasksMax: 256 },
});

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });
  if (result.status !== 0)
    fail(
      `${path.basename(command)} ${args.join(" ")} exited ${result.status}: ${(result.stderr || result.stdout || "").trim().slice(-800)}`,
    );
  return result.stdout;
}

function walk(dir, visit) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, visit);
    else if (entry.isFile() || entry.isSymbolicLink()) visit(full);
  }
}

/** Where the verified .deb keeps the root certificate of CVD signatures. */
export const debCertsPath = Object.freeze(["usr", "local", "etc", "certs"]);
export const cvdCertFile = "clamav.crt";

/**
 * DEF-08: the certificate that verifies CVD signatures comes only from the
 * extracted, SHA-256 and GPG checked .deb. The directory and `clamav.crt`
 * must be a plain directory and a plain, readable, non-empty file (no
 * symbolic link or junction); otherwise the gate stops before freshclam runs
 * and downloads anything, instead of ClamAV falling back to its compiled
 * default path.
 */
export function cvdCerts(root) {
  const dir = path.join(root, ...debCertsPath);
  const file = path.join(dir, cvdCertFile);
  const entry = (target) => {
    try {
      return fs.lstatSync(target);
    } catch {
      return null;
    }
  };
  const folder = entry(dir);
  if (folder === null)
    fail(`CVD certificates missing: ${dir} does not exist in the ClamAV .deb`);
  if (folder.isSymbolicLink() || !folder.isDirectory())
    fail(`CVD certificates refused: ${dir} is not a plain directory`);
  const cert = entry(file);
  if (cert === null) fail(`CVD certificates missing: ${file}`);
  if (cert.isSymbolicLink() || !cert.isFile())
    fail(`CVD certificates refused: ${file} is not a plain file`);
  if (cert.size === 0) fail(`CVD certificates refused: ${file} is empty`);
  try {
    fs.accessSync(file, fs.constants.R_OK);
  } catch {
    fail(`CVD certificates refused: ${file} is not readable`);
  }
  return { dir, file: cvdCertFile, size: cert.size, sha256: sha256File(file) };
}

/** The extracted ClamAV: executables, library directories and certificates. */
export function linuxTools(lock = readLock()) {
  const root = path.join(toolsRoot, lock.linux.clamav.directory);
  if (!fs.existsSync(root))
    fail("ClamAV for Linux is not extracted; run fetch");
  const found = {};
  const libDirs = new Set();
  walk(root, (file) => {
    const base = path.basename(file);
    if (["clamd", "freshclam", "sigtool"].includes(base)) found[base] = file;
    if (/^libclamav\.so/u.test(base)) libDirs.add(path.dirname(file));
  });
  for (const name of ["clamd", "freshclam", "sigtool"])
    if (found[name] === undefined) fail(`${name} not found in the ClamAV .deb`);
  const certsFile = cvdCerts(root);
  const libraryPath = [...libDirs, process.env.LD_LIBRARY_PATH]
    .filter(Boolean)
    .join(":");
  return {
    root,
    ...found,
    certs: certsFile.dir,
    certsFile,
    libraryPath,
    env: { ...process.env, LD_LIBRARY_PATH: libraryPath },
  };
}

/** Any port parses; `--version` exits before clamd listens. */
export const versionProbePort = 3310;

/**
 * clamd 1.5.4 parses its configuration before it answers `--version`, and the
 * extracted .deb has no default clamd.conf (D1-L run 38246774477). The probe
 * writes the project configuration (`clamdConf`) into a fresh temporary
 * directory, passes it with `--config-file` and removes the directory
 * afterwards, also when clamd fails or cannot start. A failure keeps the exit
 * code and the output in the error for diagnosis.
 */
export function clamdVersion(
  tools,
  { spawn = spawnSync, tmpRoot = os.tmpdir() } = {},
) {
  const dir = fs.mkdtempSync(path.join(tmpRoot, "recharge-clamd-version-"));
  try {
    const conf = path.join(dir, "clamd.conf");
    fs.writeFileSync(conf, clamdConf(dir, versionProbePort));
    const args = [`--config-file=${conf}`, "--version"];
    const result = spawn(tools.clamd, args, {
      encoding: "utf8",
      maxBuffer: 1024 * 1024,
      env: tools.env,
    });
    const output = [result.stdout, result.stderr]
      .filter((text) => typeof text === "string" && text.trim() !== "")
      .map((text) => text.trim())
      .join("\n")
      .slice(-800);
    if (result.error)
      fail(`clamd --version could not start: ${result.error.message}`);
    if (result.status !== 0)
      fail(
        `clamd --version exited ${result.status ?? `by signal ${result.signal}`}: ${output || "(no output)"}`,
      );
    return result.stdout.trim();
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

function binaryLines(tools) {
  return ["clamd", "freshclam", "sigtool"]
    .map((name) => `${name} ${sha256File(tools[name])}`)
    .sort();
}

/** ClamAV .deb: SHA-256 and GPG, extracted with dpkg-deb, never installed. */
export async function fetchLinux() {
  const lock = readLock();
  const budget = { budgetBytes: lock.linux.budgetBytes };
  fs.mkdirSync(toolsRoot, { recursive: true });
  log("ClamAV 1.5.4 (Linux x86_64 .deb, extracted, not installed)");
  const deb = await download("clamav-linux", lock.linux.clamav, budget);
  const sig = await download(
    "clamav-linux-signature",
    lock.linux.clamavSignature,
    budget,
  );
  const { key, keySha256 } = await fetchTalosKey(lock, budget);
  if (keySha256 !== lock.verified?.talosKeySha256)
    fail("the Cisco Talos key differs from the key verified on Windows");
  const gpg = verifyGpgSignature(sig, deb, key);
  if (!gpg.performed) fail("gpg is required on the Linux runner");
  const dir = path.join(toolsRoot, lock.linux.clamav.directory);
  if (!fs.existsSync(dir)) {
    const staging = `${dir}.staging-${stamp()}`;
    run("dpkg-deb", ["-x", deb, staging]);
    fs.renameSync(staging, dir);
  }
  const tools = linuxTools(lock);
  const version = clamdVersion(tools);
  if (!version.startsWith("ClamAV 1.5.4"))
    fail(`unexpected clamd version: ${version}`);
  const lines = binaryLines(tools);
  fs.writeFileSync(
    path.join(toolsRoot, "clamav-linux.binaries.txt"),
    lines.join("\n") + "\n",
  );
  log(
    `  ${version}; certs ${tools.certs}; ${cvdCertFile} ${tools.certsFile.size} bytes, SHA-256 ${tools.certsFile.sha256}`,
  );
  return {
    deb: { size: fs.statSync(deb).size, sha256: sha256File(deb) },
    gpg: { good: gpg.good, signingKeyFingerprint: gpg.signingKeyFingerprint },
    keySha256,
    clamd: version,
    certs: tools.certsFile,
    binaries: lines,
  };
}

/**
 * Runs a command while a watchdog keeps a directory within its allowance.
 * The watchdog polls; the growth at exit is checked again, so a burst
 * between two polls fails too, whatever the exit code. A failure carries the
 * growth in `grown` for the ledger.
 */
export function watched(command, args, options, dir, allowance) {
  return new Promise((resolve, refuse) => {
    const before = directorySize(dir);
    const failure = (message, grown) =>
      refuse(Object.assign(new Error(message), { grown }));
    const child = spawn(command, args, { stdio: "inherit", ...options });
    let exceeded = false;
    const timer = setInterval(() => {
      if (directorySize(dir) - before > allowance) {
        exceeded = true;
        child.kill("SIGKILL");
      }
    }, 500);
    child.on("error", (error) => {
      clearInterval(timer);
      failure(
        `${path.basename(command)}: ${error.message}`,
        directorySize(dir) - before,
      );
    });
    child.on("exit", (code) => {
      clearInterval(timer);
      const grown = directorySize(dir) - before;
      if (exceeded || grown > allowance)
        return failure(
          `download budget exceeded: ${grown} bytes, allowance ${allowance}`,
          grown,
        );
      if (code !== 0)
        return failure(`${path.basename(command)} exited ${code}`, grown);
      resolve(grown);
    });
  });
}

/** What freshclam may still add: its own cap, never more than the D1-L budget leaves. */
export function officialAllowance(linux, ledger) {
  const allowance = Math.min(
    linux.officialDatabaseBudgetBytes,
    remainingBudget({ budgetBytes: linux.budgetBytes }, ledger),
  );
  if (allowance <= 0)
    fail(
      `no download budget left for the official databases: ${ledger.totalBytes} of ${linux.budgetBytes} bytes used`,
    );
  return allowance;
}

/** The databases the gate needs, each as exactly one of .cvd or .cld. */
export const requiredDatabases = Object.freeze(["main", "daily", "bytecode"]);

/** Missing or doubled required databases among the file names of a directory. */
export function databaseSetProblems(names) {
  const problems = [];
  for (const base of requiredDatabases) {
    const forms = [`${base}.cvd`, `${base}.cld`].filter((name) =>
      names.includes(name),
    );
    if (forms.length === 0)
      problems.push(`${base}: missing (neither ${base}.cvd nor ${base}.cld)`);
    else if (forms.length > 1)
      problems.push(`${base}: both ${forms.join(" and ")}; expected one`);
  }
  return problems;
}

export const officialDatabaseDir = () => path.join(runRoot, "official-db");

/**
 * The freshclam run of the gate (DEF-08). `CVDCertsDirectory` serves freshclam
 * itself; the test load of a downloaded database happens in libclamav 1.5.4,
 * which knows only `CVD_CERTS_DIR` and its compiled default (run 38547611633
 * failed on `/usr/local/etc/certs`). Both point to the verified .deb directory.
 * `--cvdcertsdir` is not added: no evidence needs it. Download TLS is
 * unchanged.
 */
export function freshclamInvocation(tools, { dir, root = runRoot }) {
  const conf = path.join(root, "freshclam.conf");
  fs.writeFileSync(
    conf,
    [
      `DatabaseDirectory ${dir}`,
      `UpdateLogFile ${path.join(root, "freshclam.log")}`,
      "DatabaseMirror database.clamav.net",
      "DNSDatabaseInfo current.cvd.clamav.net",
      "ScriptedUpdates yes",
      "Foreground yes",
      `CVDCertsDirectory ${tools.certs}`,
      "",
    ].join("\n"),
  );
  return {
    command: tools.freshclam,
    args: [`--config-file=${conf}`, "--stdout"],
    options: { env: { ...tools.env, CVD_CERTS_DIR: tools.certs } },
    conf,
  };
}

/**
 * One freshclam run into a runner-local directory. The growth is checked
 * against the allowance at exit and the ledger total against the D1-L budget;
 * an incomplete set fails as well. A refused directory moves to _rejected.
 */
export async function fetchOfficialDatabases(lock = readLock()) {
  const tools = linuxTools(lock);
  const dir = officialDatabaseDir();
  if (fs.existsSync(dir) && fs.readdirSync(dir).length > 0)
    fail(`${dir} is not empty; the gate downloads into a fresh directory`);
  fs.mkdirSync(dir, { recursive: true });
  const freshclam = freshclamInvocation(tools, { dir });
  const allowance = officialAllowance(lock.linux, readLedger());
  log(`official databases through freshclam (allowance ${allowance} bytes)`);
  let grown;
  try {
    grown = await watched(
      freshclam.command,
      freshclam.args,
      freshclam.options,
      dir,
      allowance,
    );
  } catch (error) {
    record("official databases (refused)", error.grown ?? 0);
    moveAside(dir, `freshclam refused: ${error.message}`);
  }
  const total = record("official databases", grown);
  if (total > lock.linux.budgetBytes)
    moveAside(
      dir,
      `the D1-L downloads total ${total} bytes, over the budget of ${lock.linux.budgetBytes}`,
    );
  const problems = databaseSetProblems(fs.readdirSync(dir));
  if (problems.length > 0)
    moveAside(dir, `incomplete official databases: ${problems.join("; ")}`);
  log(`  ${grown} bytes of ${allowance} allowed`);
  return { dir, bytes: grown };
}

/** `sigtool --info` text: version, build time, signature count, verification. */
export function parseSigtoolInfo(text) {
  const field = (name) =>
    new RegExp(`^${name}:\\s*(.+)$`, "mu").exec(text)?.[1]?.trim() ?? null;
  const number = (name) => {
    const value = field(name);
    return value === null ? null : Number(value);
  };
  return {
    buildTime: field("Build time"),
    version: number("Version"),
    signatures: number("Signatures"),
    functionalityLevel: number("Functionality level"),
    builder: field("Builder"),
    verified: /Verification OK/u.test(text),
  };
}

export const noticePattern = /^(COPYING|LICEN[CS]E|NOTICE|README)/iu;

/** Versions, SHA-256, signature check and every notice file of each database. */
export function inspectDatabases(
  dir = officialDatabaseDir(),
  lock = readLock(),
) {
  const tools = linuxTools(lock);
  const certs = tools.certs === null ? [] : [`--cvdcertsdir=${tools.certs}`];
  const names = fs
    .readdirSync(dir)
    .filter((name) => /\.(cvd|cld)$/u.test(name))
    .sort();
  const problems = databaseSetProblems(names);
  if (problems.length > 0)
    fail(`incomplete official databases: ${problems.join("; ")}`);
  const databases = names.map((name) => {
    const file = path.join(dir, name);
    const info = parseSigtoolInfo(
      run(tools.sigtool, [...certs, `--info=${file}`], { env: tools.env }),
    );
    const unpacked = path.join(runRoot, "unpacked", name);
    fs.mkdirSync(unpacked, { recursive: true });
    run(tools.sigtool, [...certs, `--unpack=${file}`], {
      env: tools.env,
      cwd: unpacked,
    });
    const contents = fs.readdirSync(unpacked).sort();
    const notices = contents
      .filter((entry) => noticePattern.test(entry))
      .map((entry) => {
        const bytes = fs.readFileSync(path.join(unpacked, entry));
        return {
          file: entry,
          bytes: bytes.length,
          sha256: createHash("sha256").update(bytes).digest("hex"),
          text: bytes.subarray(0, 64 * 1024).toString("utf8"),
        };
      });
    return {
      name,
      bytes: fs.statSync(file).size,
      sha256: sha256File(file),
      ...info,
      entries: contents.length,
      copying: notices.some((notice) => /^COPYING/iu.test(notice.file)),
      notices,
    };
  });
  return { inspectedAt: new Date().toISOString(), databases };
}

/** License files of the Linux sharp packages, at the versions of the lock. */
export function npmNotices(lock = readLock()) {
  return lock.linux.npm.map((pkg) => {
    const dir = path.join(functionsDir, "node_modules", ...pkg.name.split("/"));
    const manifest = JSON.parse(
      fs.readFileSync(path.join(dir, "package.json"), "utf8"),
    );
    if (manifest.version !== pkg.version || manifest.license !== pkg.license)
      fail(`${pkg.name}: installed ${manifest.version} (${manifest.license})`);
    const notices = fs
      .readdirSync(dir)
      .filter((entry) => /licen[cs]e|notice|third.?party|copying/iu.test(entry))
      .map((entry) => {
        const bytes = fs.readFileSync(path.join(dir, entry));
        return {
          file: entry,
          bytes: bytes.length,
          sha256: createHash("sha256").update(bytes).digest("hex"),
          text: bytes.subarray(0, 64 * 1024).toString("utf8"),
        };
      });
    return {
      name: pkg.name,
      version: pkg.version,
      license: pkg.license,
      notices,
    };
  });
}

/** Markdown for the step summary; notice texts go into collapsed blocks. */
export function inspectionMarkdown(fetched, inspection, packages) {
  const lines = [
    "## D1-L inspect: ClamAV and official databases",
    "",
    `- ClamAV .deb: ${fetched.deb.size} bytes, SHA-256 \`${fetched.deb.sha256}\`; GPG good, key \`${fetched.gpg.signingKeyFingerprint}\``,
    `- ${fetched.clamd}`,
    `- CVD certificate: \`${[...debCertsPath, fetched.certs.file].join("/")}\` from the .deb, ${fetched.certs.size} bytes, SHA-256 \`${fetched.certs.sha256}\``,
    "",
    "| Database | Version | Build time | Signatures | Signature check | Bytes | SHA-256 | COPYING |",
    "|---|---|---|---|---|---|---|---|",
    ...inspection.databases.map(
      (db) =>
        `| ${db.name} | ${db.version} | ${db.buildTime} | ${db.signatures} | ${db.verified ? "OK" : "FAILED"} | ${db.bytes} | \`${db.sha256}\` | ${db.copying ? "found" : "NOT FOUND"} |`,
    ),
    "",
  ];
  for (const db of inspection.databases)
    for (const notice of db.notices)
      lines.push(
        `<details><summary>${db.name}: ${notice.file} (${notice.bytes} bytes, SHA-256 ${notice.sha256})</summary>`,
        "",
        "```text",
        notice.text,
        "```",
        "</details>",
        "",
      );
  lines.push("## Linux sharp packages: license files", "");
  for (const pkg of packages) {
    lines.push(`- ${pkg.name}@${pkg.version} (${pkg.license})`);
    for (const notice of pkg.notices)
      lines.push(
        `  - ${notice.file}: ${notice.bytes} bytes, SHA-256 \`${notice.sha256}\``,
      );
  }
  return lines.join("\n") + "\n";
}

export function writeSummary(markdown) {
  process.stdout.write(markdown);
  if (process.env.GITHUB_STEP_SUMMARY)
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown);
}

// ---------- cgroup scopes ----------

/**
 * sudo drops LD_* and most of the environment, so the scope runs
 * `/usr/bin/env NAME=value ... <exe>`; secrets never go in here (see the
 * secrets file of startLinux).
 */
export function scopeArgs({ unit, limits, uid, gid, env = {}, exe, args }) {
  return [
    "-n",
    "systemd-run",
    "--scope",
    "--quiet",
    `--unit=${unit}`,
    `--uid=${uid}`,
    `--gid=${gid}`,
    "-p",
    `MemoryMax=${limits.memoryMax}`,
    "-p",
    "MemorySwapMax=0",
    "-p",
    `TasksMax=${limits.tasksMax}`,
    // DEF-10: systemd's DefaultOOMPolicy=stop ends the whole unit after a
    // kernel OOM kill; the cap must end only the process over it (the worker),
    // as the Windows Job Object refuses the allocation (J2).
    "-p",
    "OOMPolicy=continue",
    "--",
    "/usr/bin/env",
    ...Object.entries(env).map(([name, value]) => `${name}=${value}`),
    exe,
    ...args,
  ];
}

/** systemctl show plus the scope's cgroup files. */
export function describeScope(unit) {
  const shown = spawnSync(
    "systemctl",
    [
      "show",
      `${unit}.scope`,
      "-p",
      "ActiveState,ControlGroup,MemoryMax,MemorySwapMax,TasksMax",
    ],
    { encoding: "utf8" },
  );
  const props = Object.fromEntries(
    (shown.stdout ?? "")
      .trim()
      .split("\n")
      .filter((line) => line.includes("="))
      .map((line) => [
        line.slice(0, line.indexOf("=")),
        line.slice(line.indexOf("=") + 1),
      ]),
  );
  const cgroup = props.ControlGroup
    ? path.join("/sys/fs/cgroup", props.ControlGroup)
    : null;
  const read = (name) => {
    if (cgroup === null) return null;
    try {
      return fs.readFileSync(path.join(cgroup, name), "utf8").trim();
    } catch {
      return null;
    }
  };
  const events = Object.fromEntries(
    (read("memory.events") ?? "")
      .split("\n")
      .filter(Boolean)
      .map((line) => {
        const [key, value] = line.split(" ");
        return [key, Number(value)];
      }),
  );
  return {
    unit,
    active: props.ActiveState === "active",
    memoryMax: Number(props.MemoryMax),
    memorySwapMax: Number(props.MemorySwapMax),
    tasksMax: Number(props.TasksMax),
    memoryCurrent: Number(read("memory.current") ?? Number.NaN),
    memoryPeak: Number(read("memory.peak") ?? Number.NaN),
    oomKills: events.oom_kill ?? 0,
    pids: (read("cgroup.procs") ?? "").split("\n").filter(Boolean).map(Number),
  };
}

export function inScope(pid, unit) {
  try {
    return fs
      .readFileSync(`/proc/${pid}/cgroup`, "utf8")
      .includes(`/${unit}.scope`);
  } catch {
    return false;
  }
}

export async function launchInScope({
  unit,
  limits,
  exe,
  args,
  cwd,
  runDir,
  role,
  env = {},
}) {
  const out = fs.openSync(path.join(runDir, `${role}.out.log`), "a");
  const err = fs.openSync(path.join(runDir, `${role}.err.log`), "a");
  const child = spawn(
    "sudo",
    scopeArgs({
      unit,
      limits,
      uid: process.getuid(),
      gid: process.getgid(),
      env: { HOME: process.env.HOME ?? "/tmp", ...env },
      exe,
      args,
    }),
    { cwd, detached: true, stdio: ["ignore", out, err] },
  );
  child.unref();
  const deadline = Date.now() + 30_000;
  for (;;) {
    const described = describeScope(unit);
    if (described.active && described.pids.length > 0)
      return { unit, pids: described.pids };
    if (child.exitCode !== null)
      fail(
        `${role}: systemd-run exited ${child.exitCode}: ${fs.readFileSync(path.join(runDir, `${role}.err.log`), "utf8").slice(-600)}`,
      );
    if (Date.now() > deadline) fail(`${role}: the scope ${unit} did not start`);
    await sleep(200);
  }
}

export async function stopScope(unit) {
  if (!describeScope(unit).active) return;
  run("sudo", ["-n", "systemctl", "stop", `${unit}.scope`]);
  const deadline = Date.now() + 20_000;
  while (describeScope(unit).active) {
    if (Date.now() > deadline) fail(`scope ${unit} is still active`);
    await sleep(200);
  }
}

// ---------- the service on Linux ----------

function scopeMatches(described, limits) {
  return (
    described.memoryMax === limits.memoryMax &&
    described.memorySwapMax === 0 &&
    described.tasksMax === limits.tasksMax
  );
}

export async function startLinux({
  instance = "stand",
  standSignaturesOnly = false,
  selftestProbes = false,
  databaseMode = "official",
} = {}) {
  const lock = readLock();
  if (!fs.existsSync(hostModule))
    fail("Build first: lib/test/stand/media_tools_host.js is missing");
  if (fs.existsSync(stateOf(instance)))
    fail(`Instance ${instance} already has a state file; stop it first`);
  const tools = linuxTools(lock);
  const recorded = fs
    .readFileSync(path.join(toolsRoot, "clamav-linux.binaries.txt"), "utf8")
    .trim()
    .split("\n");
  if (JSON.stringify(binaryLines(tools)) !== JSON.stringify(recorded))
    fail("ClamAV binaries changed since fetch");
  const runDir = instanceDir(instance);
  if (fs.existsSync(runDir))
    fs.renameSync(runDir, `${runDir}.previous-${stamp()}`);
  for (const sub of ["db", "tmp"])
    fs.mkdirSync(path.join(runDir, sub), { recursive: true });
  fs.writeFileSync(path.join(runDir, "db", standDatabaseName), standDatabase());
  if (
    sha256File(path.join(runDir, "db", standDatabaseName)) !==
    lock.databases.stand?.sha256
  )
    fail("stand database does not match the lock");
  if (databaseMode === "official") {
    const official = fs
      .readdirSync(officialDatabaseDir())
      .filter((name) => /\.(cvd|cld)$/u.test(name));
    const problems = databaseSetProblems(official);
    if (problems.length > 0)
      fail(
        `official databases incomplete (${problems.join("; ")}); run the inspect stage first`,
      );
    for (const name of official)
      fs.copyFileSync(
        path.join(officialDatabaseDir(), name),
        path.join(runDir, "db", name),
      );
  } else if (databaseMode !== "stand")
    fail(`unknown database mode ${databaseMode}`);

  const clamdPort = await freePort();
  const port = await freePort();
  const token = randomBytes(32).toString("hex");
  const controlToken = randomBytes(32).toString("hex");
  const conf = path.join(runDir, "clamd.conf");
  fs.writeFileSync(
    conf,
    clamdConf(runDir, clamdPort, { bytecode: databaseMode === "official" }) +
      (tools.certs === null ? "" : `CVDCertsDirectory ${tools.certs}\n`),
  );
  const tag = `${instance}-${randomBytes(4).toString("hex")}`.replace(
    /[^A-Za-z0-9_.-]/gu,
    "-",
  );
  const units = {
    clamd: `recharge-media-clamd-${tag}`,
    service: `recharge-media-tools-${tag}`,
  };
  const started = {
    version: 1,
    platform: "linux",
    instance,
    units,
    clamdPort,
    port,
    standSignaturesOnly,
    selftestProbes,
    databaseMode,
  };
  try {
    await launchInScope({
      unit: units.clamd,
      limits: scopeLimits.clamd,
      exe: tools.clamd,
      args: [`--config-file=${conf}`],
      cwd: runDir,
      runDir,
      role: "clamd",
      env: clamdLaunchEnv(tools),
    });
    const helpers = await hostHelpers();
    let version = null;
    for (const deadline = Date.now() + 240_000; version === null;) {
      try {
        version = await helpers.clamdVersion(clamdPort);
      } catch {
        if (Date.now() > deadline) fail("clamd did not answer within 240 s");
        await sleep(1000);
      }
    }
    if (databaseMode === "official" && version.daily === undefined)
      fail(
        `clamd answered without an official daily: ${JSON.stringify(version)}`,
      );
    const positive = await helpers.clamdScan(
      clamdPort,
      Buffer.from(`probe ${standMarker} probe`, "ascii"),
    );
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

    const secretsFile = path.join(runDir, "host.secrets.json");
    fs.writeFileSync(secretsFile, JSON.stringify({ token, controlToken }), {
      mode: 0o600,
    });
    await launchInScope({
      unit: units.service,
      limits: scopeLimits.service,
      exe: process.execPath,
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
        RECHARGE_TOOLS_SECRETS_FILE: secretsFile,
        RECHARGE_TOOLS_CLAMD_PORT: String(clamdPort),
        RECHARGE_TOOLS_INSTANCE: tag,
      },
    });
    for (const deadline = Date.now() + 20_000; !(await portOpen(port));) {
      if (Date.now() > deadline) fail("the service did not listen within 20 s");
      await sleep(250);
    }
    for (const [key, unit] of Object.entries(units)) {
      const described = describeScope(unit);
      if (!scopeMatches(described, scopeLimits[key]))
        fail(`scope ${unit} limits differ: ${JSON.stringify(described)}`);
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
    if (!inScope(health.json.worker.pid, units.service))
      fail("the worker is not inside the service scope");
    fs.writeFileSync(
      path.join(runDir, "access.json"),
      JSON.stringify(
        { port, token, standSignaturesOnly, databaseMode },
        null,
        2,
      ),
    );
    fs.writeFileSync(
      path.join(runDir, "control.json"),
      JSON.stringify({ controlToken }, null, 2),
    );
    fs.writeFileSync(
      stateOf(instance),
      JSON.stringify({ ...started, at: new Date().toISOString() }, null, 2),
    );
    log(
      `media tools ${instance}: service 127.0.0.1:${port}, clamd 127.0.0.1:${clamdPort}, database ${databaseMode}${standSignaturesOnly ? " (stand exemption)" : ""}`,
    );
    return { ...started, token, controlToken };
  } catch (error) {
    for (const unit of Object.values(units))
      await stopScope(unit).catch(() => undefined);
    throw error;
  }
}

export async function stopLinux({ instance = "stand" } = {}) {
  const file = stateOf(instance);
  if (!fs.existsSync(file)) fail(`Instance ${instance} is not running`);
  const state = JSON.parse(fs.readFileSync(file, "utf8"));
  if (state.platform !== "linux") fail("not a Linux instance");
  const { controlToken } = JSON.parse(
    fs.readFileSync(path.join(instanceDir(instance), "control.json"), "utf8"),
  );
  if (describeScope(state.units.service).active) {
    try {
      await http(state.port, "POST", "/v1/control/drain", controlToken);
    } catch {
      // A service that does not answer is ended with its scope below.
    }
    const deadline = Date.now() + 25_000;
    while (
      describeScope(state.units.service).pids.length > 0 &&
      Date.now() < deadline
    )
      await sleep(250);
  }
  for (const unit of [state.units.service, state.units.clamd])
    await stopScope(unit);
  for (const port of [state.port, state.clamdPort])
    if (await portOpen(port)) fail(`port ${port} is still open`);
  fs.renameSync(
    file,
    path.join(instanceDir(instance), `state.stopped-${stamp()}.json`),
  );
  log(`media tools ${instance}: stopped and verified`);
}

export async function statusLinux({ instance = "stand" } = {}) {
  const file = stateOf(instance);
  if (!fs.existsSync(file)) return { instance, state: "down" };
  const state = JSON.parse(fs.readFileSync(file, "utf8"));
  const { token } = JSON.parse(
    fs.readFileSync(path.join(instanceDir(instance), "access.json"), "utf8"),
  );
  let health = null;
  try {
    health = (await http(state.port, "GET", "/v1/health", token)).json;
  } catch {
    health = null;
  }
  const scopes = Object.fromEntries(
    Object.entries(state.units).map(([key, unit]) => [
      key,
      describeScope(unit),
    ]),
  );
  return {
    instance,
    state:
      Object.values(scopes).every((scope) => scope.active) && health !== null
        ? "up"
        : "broken",
    scopes,
    health,
  };
}

/**
 * The environment of clamd inside its scope. clamd loads and verifies the
 * official CVDs in libclamav 1.5.4, the same code that ignored the
 * configuration directive in freshclam's test load (DEF-08) and knows only
 * `CVD_CERTS_DIR`; the `CVDCertsDirectory` line in clamd.conf stays.
 */
export function clamdLaunchEnv(tools) {
  return { LD_LIBRARY_PATH: tools.libraryPath, CVD_CERTS_DIR: tools.certs };
}

/** A probe that fails becomes data for a check instead of ending the gate. */
export async function attemptProbe(run) {
  try {
    return { ok: true, value: await run() };
  } catch (error) {
    return { ok: false, error: error.message };
  }
}

/**
 * L2 verdict (DEF-10): the worker cannot use more than the scope allows and
 * the host survives. A broken connection is a failed check with the scope
 * facts, not a crash of the gate.
 */
export function l2Verdict({ probe, before, after, hostAlive, memoryMax }) {
  const answer = probe.ok ? (probe.value.json?.answer ?? {}) : {};
  const ok =
    probe.ok &&
    probe.value.status === 200 &&
    (answer.kind === "exit" || answer.refused === true) &&
    after.memoryPeak <= memoryMax &&
    hostAlive;
  return {
    ok,
    facts: {
      ...(probe.ok ? { answer } : { error: probe.error }),
      scopeActive: after.active,
      oomKills: after.oomKills - before.oomKills,
      peakMiB: Math.round(after.memoryPeak / MiB),
      hostAlive,
    },
  };
}

/** journalctl arguments for the scopes of a self-check (read through sudo). */
export function journalArgs(units, since) {
  return {
    scopes: [
      "-n",
      "journalctl",
      "--no-pager",
      "-o",
      "short-iso",
      `--since=${since}`,
      ...Object.values(units).flatMap((unit) => ["-u", `${unit}.scope`]),
    ],
    kernel: [
      "-n",
      "journalctl",
      "--no-pager",
      "-o",
      "short-iso",
      "-k",
      `--since=${since}`,
    ],
  };
}

/** The last journal lines of the scopes and the kernel OOM lines, or why not. */
function scopeJournal(units, since) {
  const args = journalArgs(units, since);
  const tail = (lines, count) => lines.slice(-count).join("\n");
  const read = (list) => {
    const result = spawnSync("sudo", list, {
      encoding: "utf8",
      maxBuffer: 8 * 1024 * 1024,
    });
    if (result.status !== 0)
      return {
        error: `journalctl exited ${result.status}: ${(result.stderr || "").trim().slice(-300)}`,
      };
    return { lines: (result.stdout || "").split("\n").filter(Boolean) };
  };
  const scopes = read(args.scopes);
  const kernel = read(args.kernel);
  return {
    scopes: scopes.error ?? tail(scopes.lines, 40),
    kernelOom:
      kernel.error ??
      tail(
        kernel.lines.filter((line) =>
          /oom|out of memory|killed process/iu.test(line),
        ),
        20,
      ),
  };
}

/** L1–L6: the Linux counterparts of J1–J6 (amendment §3.8, §15.3). */
export async function selftestLinux() {
  const instance = `selftest-${stamp()}`;
  // journalctl --since: "YYYY-MM-DD HH:MM:SS UTC", one minute of margin.
  const since = `${new Date(Date.now() - 60_000).toISOString().slice(0, 19).replace("T", " ")} UTC`;
  const report = {
    instance,
    at: new Date().toISOString(),
    platform: "linux",
    checks: {},
  };
  const check = (id, ok, facts) => {
    report.checks[id] = { ok: Boolean(ok), ...facts };
    log(`  ${id}: ${ok ? "ok" : "FAILED"} ${JSON.stringify(facts)}`);
  };
  const service = await startLinux({
    instance,
    selftestProbes: true,
    databaseMode: "stand",
  });
  const { port, token, controlToken, units } = service;
  try {
    const health = (await http(port, "GET", "/v1/health", token)).json;
    const serviceScope = describeScope(units.service);
    const clamdScope = describeScope(units.clamd);
    check(
      "L1",
      scopeMatches(serviceScope, scopeLimits.service) &&
        inScope(health.worker.pid, units.service) &&
        serviceScope.pids.length >= 2,
      { scope: serviceScope, worker: health.worker.pid },
    );
    check(
      "L6",
      scopeMatches(clamdScope, scopeLimits.clamd) &&
        clamdScope.pids.length >= 1,
      { scope: clamdScope },
    );

    // L2: the worker cannot use more than the scope allows; the host survives.
    // A failed probe is a failed check with facts and the journal (DEF-10).
    const beforeL2 = describeScope(units.service);
    const l2Probe = await attemptProbe(() =>
      http(
        port,
        "POST",
        "/v1/selftest/probe",
        controlToken,
        Buffer.from(JSON.stringify({ kind: "allocate", mib: 1024 })),
      ),
    );
    const afterL2 = describeScope(units.service);
    const healthAfterL2 = await attemptProbe(() =>
      http(port, "GET", "/v1/health", token),
    );
    const hostAlive = healthAfterL2.ok && healthAfterL2.value.status === 200;
    const l2 = l2Verdict({
      probe: l2Probe,
      before: beforeL2,
      after: afterL2,
      hostAlive,
      memoryMax: scopeLimits.service.memoryMax,
    });
    check(
      "L2",
      l2.ok,
      l2.ok ? l2.facts : { ...l2.facts, journal: scopeJournal(units, since) },
    );

    // L3: a hung worker is ended at the deadline and its memory is released.
    // Without a living host it cannot run; that is a failed check, not a skip.
    if (!hostAlive)
      check("L3", false, { reason: "the service host is not alive after L2" });
    else {
      const l3Run = await attemptProbe(() => hungWorkerCheck());
      if (l3Run.ok) check("L3", l3Run.value.ok, l3Run.value.facts);
      else
        check("L3", false, {
          error: l3Run.error,
          journal: scopeJournal(units, since),
        });
    }

    async function hungWorkerCheck() {
      const hung = http(
        port,
        "POST",
        "/v1/selftest/probe",
        controlToken,
        Buffer.from(JSON.stringify({ kind: "hang", mib: 400 })),
      );
      await sleep(4_000);
      const during = describeScope(units.service);
      const hungWorker = (await http(port, "GET", "/v1/health", token)).json
        .worker?.pid;
      const l3 = await hung;
      const after = describeScope(units.service);
      const releasedMiB = Math.round(
        (during.memoryCurrent - after.memoryCurrent) / MiB,
      );
      const next = await http(port, "POST", "/v1/process", token, tinyJpeg, {
        "content-type": "application/octet-stream",
        "x-recharge-request-id": randomBytes(8).toString("hex"),
        "x-recharge-sha256": createHash("sha256")
          .update(tinyJpeg)
          .digest("hex"),
        "x-recharge-profiles": "display,thumb",
      });
      const nextWorker = (await http(port, "GET", "/v1/health", token)).json
        .worker?.pid;
      return {
        ok:
          l3.json?.answer?.kind === "timeout" &&
          !after.pids.includes(hungWorker) &&
          releasedMiB >= 380 &&
          next.status === 200 &&
          next.json.result === "succeeded" &&
          nextWorker !== undefined &&
          nextWorker !== hungWorker,
        facts: {
          hungWorker,
          memoryDuringMiB: Math.round(during.memoryCurrent / MiB),
          memoryAfterMiB: Math.round(after.memoryCurrent / MiB),
          releasedMiB,
          nextResult: next.json?.result,
          nextWorker,
        },
      };
    }

    // L4: a scope that does not admit the process keeps nothing running.
    const l4Dir = path.join(instanceDir(instance), "l4");
    fs.mkdirSync(l4Dir, { recursive: true });
    const l4Unit = `recharge-media-l4-${randomBytes(4).toString("hex")}`;
    let l4 = { started: false };
    try {
      await launchInScope({
        unit: l4Unit,
        limits: { memoryMax: 16 * MiB, tasksMax: 64 },
        exe: process.execPath,
        args: ["-e", "setTimeout(() => {}, 60000)"],
        cwd: l4Dir,
        runDir: l4Dir,
        role: "l4",
      });
      l4.started = true;
    } catch (error) {
      l4.error = error.message;
    }
    await sleep(3_000);
    const l4Scope = describeScope(l4Unit);
    await stopScope(l4Unit).catch(() => undefined);
    check("L4", l4Scope.pids.length === 0 || !l4Scope.active, {
      ...l4,
      scope: l4Scope,
    });
  } finally {
    let stopError = null;
    try {
      await stopLinux({ instance });
    } catch (error) {
      stopError = error.message;
    }
    const scopesGone = Object.values(units).every(
      (unit) => !describeScope(unit).active,
    );
    const portsClosed =
      !(await portOpen(port)) && !(await portOpen(service.clamdPort));
    check("L5", stopError === null && scopesGone && portsClosed, {
      stopError,
      scopesGone,
      portsClosed,
    });
    fs.writeFileSync(
      path.join(runRoot, `${instance}.selftest.json`),
      JSON.stringify(report, null, 2),
    );
  }
  const failed = Object.entries(report.checks)
    .filter(([, value]) => !value.ok)
    .map(([id]) => id);
  if (failed.length > 0) fail(`self-check failed: ${failed.join(", ")}`);
  return report;
}
