import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { randomUUID } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import { createServer } from "node:net";
import { fileURLToPath } from "node:url";

export const project = "demo-recharge";
export const ports = {
  auth: 9099,
  firestore: 8080,
  functions: 5001,
  storage: 9199,
  pubsub: 8085,
  hub: 4400,
  logging: 4500,
};
const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const self = fileURLToPath(import.meta.url);
const root = path.resolve(
  process.env.LOCALAPPDATA || os.tmpdir(),
  "Recharge",
  "emulator-stand",
  project,
);
const stateFile = path.join(root, "state.json");
const dataDir = path.join(root, "data");
const marker = ".recharge-stand-data";
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
function fail(message) {
  throw new Error(message);
}
export function assertPlainPath(target) {
  let current = path.resolve(target);
  for (;;) {
    if (fs.existsSync(current) && fs.lstatSync(current).isSymbolicLink())
      fail("Symlink/junction refused: " + current);
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
}
export function assertIdentity(actual, expected, runId) {
  if (
    !actual ||
    actual.pid !== expected.pid ||
    actual.started !== expected.started ||
    actual.executable?.toLowerCase() !== expected.executable?.toLowerCase() ||
    !actual.command?.includes(runId)
  )
    fail("Stale state or foreign process; no process stopped.");
}
export function validateState(s) {
  if (
    s?.version !== 1 ||
    s.project !== project ||
    !/^[a-f0-9-]{36}$/.test(s.runId) ||
    !["starting", "running", "stopped"].includes(s.phase) ||
    !Number.isInteger(s.supervisor?.pid) ||
    !s.supervisor.started ||
    !s.supervisor.executable ||
    s.config !== path.join(root, s.runId + ".json")
  )
    fail("Invalid/stale state; refused.");
  return s;
}
function readState() {
  assertPlainPath(stateFile);
  return fs.existsSync(stateFile)
    ? validateState(JSON.parse(fs.readFileSync(stateFile, "utf8")))
    : null;
}
function writeState(s) {
  const tmp = stateFile + "." + randomUUID() + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(s, null, 2), { flag: "wx" });
  fs.renameSync(tmp, stateFile);
}
function ps(script, env = {}) {
  const encoded = Buffer.from(
    '$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"; ' +
      script,
    "utf16le",
  ).toString("base64");
  const result = spawnSync(
    "powershell.exe",
    ["-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
    { encoding: "utf8", windowsHide: true, env: { ...process.env, ...env } },
  );
  if (result.status !== 0)
    fail("Windows process inspection failed: " + result.stderr);
  return result.stdout.trim();
}
function processes() {
  const output = ps(
    'Get-CimInstance Win32_Process | ForEach-Object { [pscustomobject]@{pid=[int]$_.ProcessId;parent=[int]$_.ParentProcessId;started=$_.CreationDate.ToUniversalTime().ToString("o");executable=$_.ExecutablePath;command=$_.CommandLine} } | ConvertTo-Json -Compress',
  );
  return [].concat(JSON.parse(output || "[]"));
}
export function getProcess(pid) {
  return processes().find((p) => p.pid === pid);
}
function descendants(all, parent) {
  const result = [];
  function visit(pid) {
    for (const child of all.filter((p) => p.parent === pid)) {
      visit(child.pid);
      result.push(child);
    }
  }
  visit(parent);
  return result;
}
export function validateReset(target, expected, content) {
  if (
    path.resolve(target) !== path.resolve(expected) ||
    path.basename(target) !== "data" ||
    content !== project
  )
    fail("Reset path/marker mismatch.");
  assertPlainPath(target);
}
function guard() {
  for (const name of [
    "FIREBASE_CONFIG",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY",
    "AWS_SESSION_TOKEN",
    "AZURE_CLIENT_SECRET",
  ]) {
    if (Object.hasOwn(process.env, name))
      fail("Credential/cloud config environment present: " + name);
  }
  if (
    fs
      .readdirSync(path.join(backend, "functions"))
      .some((name) => name === ".env" || name.startsWith(".env."))
  )
    fail("Functions dotenv file present; stand refuses to load it.");

  if (process.platform !== "win32") fail("A1 supports Windows only.");
  assertPlainPath(root);
  const repo = path.resolve(backend, "..", "..");
  const relative = path.relative(repo, root);
  if (!relative.startsWith("..") && !path.isAbsolute(relative))
    fail("State must be outside Git checkout.");
  for (const name of [
    "GOOGLE_CLOUD_PROJECT",
    "GCLOUD_PROJECT",
    "GCP_PROJECT",
    "CLOUDSDK_CORE_PROJECT",
  ]) {
    if (Object.hasOwn(process.env, name) && process.env[name] !== project)
      fail("Foreign project environment: " + name);
  }
  const result = spawnSync(
    process.execPath,
    [path.join(backend, "scripts", "verify-no-cloud-context.mjs")],
    { cwd: backend, encoding: "utf8", windowsHide: true },
  );
  if (result.status !== 0)
    fail(
      "Cloud-context gate refused:\n" +
        (result.error?.message || result.stderr),
    );
  const credentialFiles = [
    path.join(
      process.env.APPDATA || "",
      "gcloud",
      "application_default_credentials.json",
    ),
    path.join(
      os.homedir(),
      ".config",
      "gcloud",
      "application_default_credentials.json",
    ),
  ];
  if (credentialFiles.some((p) => fs.existsSync(p)))
    fail("ADC credentials present; refused (contents not read).");
  for (const folder of [
    process.env.APPDATA,
    path.join(os.homedir(), ".config"),
  ].filter(Boolean)) {
    const f = path.join(folder, "configstore", "firebase-tools.json");
    if (fs.existsSync(f)) {
      const config = JSON.parse(fs.readFileSync(f, "utf8"));
      if (config.tokens || config.user || config.additionalAccounts?.length)
        fail("Firebase cached login present; refused.");
    }
  }
}
async function freePorts() {
  for (const port of Object.values(ports)) {
    await new Promise((resolve, reject) => {
      const server = createServer();
      server.once("error", () =>
        reject(new Error("Port occupied by another/stale process: " + port)),
      );
      server.listen(port, "127.0.0.1", () => server.close(resolve));
    });
  }
}
async function json(url, init) {
  const response = await fetch(url, {
    ...init,
    headers: { Authorization: "Bearer owner", ...init?.headers },
    signal: AbortSignal.timeout(init?.method === "POST" ? 120000 : 5000),
  });
  if (!response.ok)
    fail(
      "Emulator identity request failed: " + url + " (" + response.status + ")",
    );
  return response.json();
}
export function assertProjectEvidence(s, cli, locator, hub, mapping) {
  if (
    !cli ||
    cli.pid !== s.cli?.pid ||
    cli.started !== s.cli.started ||
    cli.executable?.toLowerCase() !== s.cli.executable?.toLowerCase() ||
    !/--project demo-recharge(?:\s|$)/.test(cli.command || "") ||
    !cli.command?.includes(s.config) ||
    locator.pid !== cli.pid ||
    hub.pid !== cli.pid
  )
    fail("Project/process identity mismatch.");
  for (const entry of Object.values(mapping)) {
    if (
      !["127.0.0.1", "::1", "localhost"].includes(entry.host) ||
      entry.listen?.some(
        (listener) => !["127.0.0.1", "::1"].includes(listener.address),
      )
    )
      fail("Non-loopback service advertised by hub.");
  }
  for (const [name, port] of Object.entries(ports)) {
    if (name === "logging") continue;
    if (mapping[name]?.host !== "127.0.0.1" || mapping[name]?.port !== port)
      fail("Emulator host/port identity mismatch: " + name);
    if (mapping[name].listen?.some((entry) => entry.address !== "127.0.0.1"))
      fail("Non-loopback listener: " + name);
  }
}
export function assertListenerOwnership(listeners, ownedPids) {
  for (const port of Object.values(ports)) {
    const matches = listeners.filter((entry) => entry.port === port);
    if (
      !matches.length ||
      matches.some(
        (entry) => entry.host !== "127.0.0.1" || !ownedPids.includes(entry.pid),
      )
    )
      fail("Foreign/missing/non-loopback listener on port " + port);
  }
}
async function identity(s) {
  assertIdentity(getProcess(s.supervisor.pid), s.supervisor, s.runId);
  if (fs.existsSync(path.join(root, s.runId + ".failed")))
    fail("Supervisor failure; state retained, no adoption.");
  const cli = getProcess(s.cli?.pid);
  if (cli?.parent !== s.supervisor.pid) fail("Foreign CLI parent.");
  const locator = JSON.parse(
    fs.readFileSync(path.join(os.tmpdir(), "hub-" + project + ".json"), "utf8"),
  );
  const hub = await json("http://127.0.0.1:4400/");
  const mapping = await json("http://127.0.0.1:4400/emulators");
  assertProjectEvidence(s, cli, locator, hub, mapping);
  const owned = descendants(processes(), cli.pid);
  const listeners = [].concat(
    JSON.parse(
      ps(
        "Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in @(9099,8080,5001,9199,8085,4400,4500) } | ForEach-Object { [pscustomobject]@{host=$_.LocalAddress;port=[int]$_.LocalPort;pid=[int]$_.OwningProcess} } | ConvertTo-Json -Compress",
      ) || "[]",
    ),
  );
  assertListenerOwnership(listeners, [
    cli.pid,
    ...owned.map((entry) => entry.pid),
  ]);

  await json(
    "http://127.0.0.1:9099/emulator/v1/projects/" + project + "/config",
  );
  await json(
    "http://127.0.0.1:8080/v1/projects/" +
      project +
      "/databases/(default)/documents/rechargeStandProbe",
    { headers: { Authorization: "Bearer owner" } },
  );
  await json("http://127.0.0.1:9199/v0/b/" + project + ".appspot.com/o");
  await json("http://127.0.0.1:8085/v1/projects/" + project + "/topics");
  // Functions project selection is established by the verified CLI, plus its backends response.
  // Functions load after the other emulators answer, so "running" requires loaded triggers.
  const backends = await json("http://127.0.0.1:5001/backends");
  const loaded = backends.backends?.[0]?.functionTriggers;
  if (!Array.isArray(loaded) || loaded.length === 0)
    fail("Functions are not loaded yet.");
}
function toolchain() {
  const lock = JSON.parse(
    fs.readFileSync(path.join(backend, "toolchain.lock.json"), "utf8"),
  );
  if (process.version !== "v" + lock.node.version)
    fail("Pinned Node required: " + lock.node.version);
  const java = spawnSync(
    path.join(process.env.JAVA_HOME || "", "bin", "java.exe"),
    ["-version"],
    { encoding: "utf8", windowsHide: true },
  );
  if (
    java.status !== 0 ||
    !(java.stderr + java.stdout).includes(lock.java.version)
  )
    fail("Pinned JAVA_HOME required: " + lock.java.version);
}
function configuration(runId) {
  const config = JSON.parse(
    fs.readFileSync(path.join(backend, "firebase.json"), "utf8"),
  );
  for (const name of ["auth", "firestore", "functions", "storage", "pubsub"]) {
    if (
      config.emulators[name]?.host !== "127.0.0.1" ||
      config.emulators[name]?.port !== ports[name]
    )
      fail("Unexpected firebase.json emulator configuration: " + name);
  }
  if (
    config.emulators.ui?.enabled !== false ||
    config.emulators.singleProjectMode !== true
  )
    fail("UI/singleProjectMode configuration refused.");
  // firebase-tools joins projectDir (this config's directory) with the source, so an
  // absolute path would be concatenated; a relative path resolves to the real directory.
  config.functions.source = path.relative(
    root,
    path.join(backend, "functions"),
  );
  config.firestore.rules = path.join(backend, config.firestore.rules);
  config.firestore.indexes = path.join(backend, config.firestore.indexes);
  config.storage.rules = path.join(backend, config.storage.rules);
  config.emulators.hub = { host: "127.0.0.1", port: ports.hub };
  config.emulators.logging = { host: "127.0.0.1", port: ports.logging };
  const filename = path.join(root, runId + ".json");
  fs.writeFileSync(filename, JSON.stringify(config, null, 2), { flag: "wx" });
  return filename;
}
function checkData() {
  validateReset(
    dataDir,
    path.join(root, "data"),
    fs.readFileSync(path.join(dataDir, marker), "utf8"),
  );
  // Refuse nested junctions as well, before export/import/deletion.
  function visit(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const item = path.join(dir, e.name);
      if (fs.lstatSync(item).isSymbolicLink())
        fail("Nested symlink/junction refused.");
      if (e.isDirectory()) visit(item);
    }
  }
  visit(dataDir);
}
async function start() {
  const previous = readState();
  if (previous && previous.phase !== "stopped")
    fail(
      "Live/stale state; use verified stop or explicit reset. State is never adopted.",
    );
  if (
    previous &&
    (getProcess(previous.supervisor.pid) ||
      (previous.cli && getProcess(previous.cli.pid)))
  )
    fail("Recorded PID live/reused; refused.");
  toolchain();
  await freePorts();
  const locatorPath = path.join(os.tmpdir(), "hub-" + project + ".json");
  if (fs.existsSync(locatorPath)) fail("Existing project locator; refused.");
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir);
    fs.writeFileSync(path.join(dataDir, marker), project, { flag: "wx" });
  }
  checkData();
  const runId = randomUUID();
  const config = configuration(runId);
  const log = fs.openSync(path.join(root, runId + ".log"), "a");
  const child = spawn(process.execPath, [self, "--supervisor", runId, config], {
    cwd: root,
    detached: true,
    windowsHide: true,
    stdio: ["ignore", log, log],
  });
  child.unref();
  fs.closeSync(log);
  let supervisor;
  for (let attempt = 0; attempt < 20 && !supervisor; attempt++) {
    await delay(100);
    supervisor = getProcess(child.pid);
  }
  if (!supervisor) fail("Supervisor failed; inspect log.");
  const s = {
    version: 1,
    project,
    phase: "starting",
    runId,
    config,
    supervisor,
  };
  writeState(s);
  const deadline = Date.now() + 180000;
  while (Date.now() < deadline) {
    await delay(1000);
    assertIdentity(getProcess(supervisor.pid), supervisor, runId);
    const cliFile = path.join(root, runId + ".cli.json");
    if (fs.existsSync(cliFile))
      s.cli = JSON.parse(fs.readFileSync(cliFile, "utf8"));
    if (s.cli) {
      writeState(s);
      try {
        await identity(s);
        s.phase = "running";
        writeState(s);
        console.log("running " + project + " " + runId);
        return;
      } catch {
        /* Not ready yet. Starting state remains recoverable by a verified stop. */
      }
    }
  }
  fail(
    "Startup timed out; state retained. Use status and verified stop; no automatic kill.",
  );
}
async function exportData() {
  checkData();
  await json("http://127.0.0.1:4400/_admin/export", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      path: path.join(dataDir, "export"),
      initiatedBy: "Recharge A1",
      targets: ["auth", "firestore", "storage"],
    }),
  });
}
export async function verifyRunning() {
  const s = readState();
  if (s?.phase !== "running") fail("Stand is not running.");
  await identity(s);
  return s;
}
async function exportRunning() {
  const s = await verifyRunning();
  await exportData();
  console.log(
    "exported " +
      project +
      " " +
      s.runId +
      " to " +
      path.join(dataDir, "export"),
  );
}
async function stop() {
  const s = readState();
  if (!s) {
    await freePorts();
    console.log("stopped (no state)");
    return;
  }
  if (s.phase === "stopped") {
    if (getProcess(s.supervisor.pid) || (s.cli && getProcess(s.cli.pid)))
      fail("Recorded PID reused/live; refused.");

    await freePorts();
    console.log("stopped");
    return;
  }
  assertIdentity(getProcess(s.supervisor.pid), s.supervisor, s.runId);
  if (s.phase === "running") {
    await identity(s);
    await exportData();
  }
  // Only the verified supervisor may stop its verified descendants.
  fs.writeFileSync(path.join(root, s.runId + ".stop"), s.runId, { flag: "wx" });
  for (let n = 0; n < 30; n++) {
    await delay(1000);
    if (!getProcess(s.supervisor.pid)) {
      await freePorts();
      const locatorPath = path.join(os.tmpdir(), "hub-" + project + ".json");
      if (fs.existsSync(locatorPath)) {
        assertPlainPath(locatorPath);
        const locator = JSON.parse(fs.readFileSync(locatorPath, "utf8"));
        if (locator.pid !== s.cli?.pid || getProcess(locator.pid))
          fail("Foreign/stale locator; refused.");
        fs.unlinkSync(locatorPath);
      }
      s.phase = "stopped";
      writeState(s);
      console.log("stopped " + s.runId);
      return;
    }
  }
  fail("Stop timed out; state retained.");
}
async function status() {
  const s = readState();
  if (!s) {
    await freePorts();
    console.log("stopped (no state)");
    return;
  }
  if (s.phase === "stopped") {
    if (getProcess(s.supervisor.pid) || (s.cli && getProcess(s.cli.pid)))
      fail("Recorded PID reused/live; refused.");

    await freePorts();
    console.log("stopped " + s.runId);
    return;
  }
  await identity(s);
  console.log(s.phase + " " + project + " " + s.runId);
}
async function reset(yes) {
  console.warn(
    "WARNING: reset permanently deletes only " + dataDir + " and stand state.",
  );
  if (!yes) fail("Explicit --yes required.");
  const s = readState();
  if (s) {
    // Stale state may only be cleared if every recorded PID is absent; reused/foreign PID refuses.
    if (getProcess(s.supervisor.pid) || (s.cli && getProcess(s.cli.pid)))
      fail("Live/reused/foreign PID; reset refused.");
  }
  await freePorts();
  if (fs.existsSync(path.join(os.tmpdir(), "hub-" + project + ".json")))
    fail("Project locator exists; reset refused.");
  if (fs.existsSync(dataDir)) {
    checkData();
    fs.rmSync(dataDir, { recursive: true });
  }
  if (s) {
    for (const filename of [
      stateFile,
      s.config,
      path.join(root, s.runId + ".cli.json"),
      path.join(root, s.runId + ".stop"),
      path.join(root, s.runId + ".failed"),
    ]) {
      assertPlainPath(filename);
      if (fs.existsSync(filename)) fs.unlinkSync(filename);
    }
  }
  console.log("reset complete; logs retained.");
}
export function stopOwnedProcesses(owned) {
  ps(
    '$items = ConvertFrom-Json -InputObject $env:RECHARGE_STOP_IDENTITIES; foreach ($item in $items) { $candidate = Get-CimInstance Win32_Process -Filter ("ProcessId = " + $item.pid); if ($candidate -and ($candidate.CreationDate.ToUniversalTime().Ticks -ne ([datetime]$item.started).ToUniversalTime().Ticks -or $candidate.ExecutablePath -ne $item.executable -or [int]$candidate.ParentProcessId -ne $item.parent)) { throw "Identity changed; refused" } }; foreach ($item in $items) { $candidate = Get-CimInstance Win32_Process -Filter ("ProcessId = " + $item.pid); if ($candidate) { if ($candidate.CreationDate.ToUniversalTime().Ticks -ne ([datetime]$item.started).ToUniversalTime().Ticks -or $candidate.ExecutablePath -ne $item.executable -or [int]$candidate.ParentProcessId -ne $item.parent) { throw "Identity changed; refused" }; Stop-Process -Id $item.pid -ErrorAction Stop } }',
    { RECHARGE_STOP_IDENTITIES: JSON.stringify(owned) },
  );
  // Diagnostic evidence only: retain checked PID identities outside Git.
  // This runs after the existing identity-checked stop action succeeds.
  const auditFile = path.join(root, "process-stop-audit.jsonl");
  assertPlainPath(auditFile);
  fs.mkdirSync(root, { recursive: true });
  fs.appendFileSync(
    auditFile,
    JSON.stringify({
      atUtc: new Date().toISOString(),
      outcome: "identityCheckedStopCompleted",
      candidates: owned.map(({ pid, parent, started, executable }) => ({
        pid,
        parent,
        started,
        executable,
      })),
    }) + "\n",
  );
}
async function supervise(runId, config) {
  guard();
  toolchain();
  if (
    !/^[a-f0-9-]{36}$/.test(runId) ||
    config !== path.join(root, runId + ".json")
  )
    fail("Supervisor arguments refused.");
  const cliPath = path.join(
    backend,
    "functions",
    "node_modules",
    "firebase-tools",
    "lib",
    "bin",
    "firebase.js",
  );
  const args = [
    cliPath,
    "emulators:start",
    "--project",
    project,
    "--config",
    config,
    "--only",
    "auth,firestore,functions,storage,pubsub",
    "--non-interactive",
  ];
  if (
    fs.existsSync(path.join(dataDir, "export", "firebase-export-metadata.json"))
  )
    args.push("--import", path.join(dataDir, "export"));
  const cli = spawn(process.execPath, args, {
    cwd: root,
    windowsHide: true,
    stdio: "inherit",
    env: {
      ...process.env,
      GCLOUD_PROJECT: project,
      GOOGLE_CLOUD_PROJECT: project,
      RECHARGE_STAND_RUN_ID: runId,
    },
  });
  let exited = false;
  cli.on("exit", () => {
    exited = true;
  });
  await delay(500);
  const identity = getProcess(cli.pid);
  if (!identity) fail("Firebase CLI failed; inspect log.");
  fs.writeFileSync(
    path.join(root, runId + ".cli.json"),
    JSON.stringify(identity),
    { flag: "wx" },
  );
  while (!exited) {
    await delay(500);
    const request = path.join(root, runId + ".stop");
    if (fs.existsSync(request)) {
      if (fs.readFileSync(request, "utf8") !== runId)
        fail("Foreign stop request.");
      const s = readState();
      if (s?.runId !== runId || s.supervisor.pid !== process.pid)
        fail("Supervisor state changed.");
      assertIdentity(getProcess(process.pid), s.supervisor, runId);
      const all = processes();
      const owned = [
        ...descendants(all, cli.pid),
        all.find((p) => p.pid === cli.pid),
      ].filter(Boolean);
      if (
        !owned.some((p) => p.pid === cli.pid && p.started === identity.started)
      )
        fail("CLI identity changed.");
      const allowed = new Set([
        process.execPath.toLowerCase(),
        path.join(process.env.JAVA_HOME, "bin", "java.exe").toLowerCase(),
      ]);
      allowed.add(
        path
          .join(process.env.SystemRoot, "System32", "conhost.exe")
          .toLowerCase(),
      );
      const cmdPath = path
        .join(process.env.SystemRoot, "System32", "cmd.exe")
        .toLowerCase();
      if (
        owned.some(
          (p) =>
            p.executable?.toLowerCase() === cmdPath &&
            (!p.command?.includes(
              "cloud-pubsub-emulator --host=127.0.0.1 --port=8085",
            ) ||
              p.parent !== cli.pid),
        )
      )
        fail("Foreign cmd wrapper.");
      allowed.add(cmdPath);
      const foreign = owned.filter(
        (p) => !allowed.has(p.executable?.toLowerCase()),
      );
      // Name what was refused, so a refusal can be diagnosed from the log.
      if (foreign.length > 0)
        fail(
          "Foreign executable in process tree: " +
            foreign
              .map(
                (p) =>
                  `${p.pid} ${p.executable ?? "<no path>"} ${String(p.command ?? "").slice(0, 120)}`,
              )
              .join("; "),
        );
      // Recheck each PID/start time/path inside the same PowerShell action, never taskkill /T.
      stopOwnedProcesses(owned);
      return;
    }
  }
  fail("Firebase CLI exited unexpectedly; state retained.");
}
export async function main(args) {
  guard();
  if (args[0] === "--supervisor") {
    await supervise(args[1], args[2]);
    return;
  }
  if (
    !["start", "stop", "status", "reset", "export"].includes(args[0]) ||
    args.slice(1).some((a) => a !== "--yes") ||
    (args.length > 1 && args[0] !== "reset")
  )
    fail("Usage: emulator-stand.mjs start|stop|status|export|reset [--yes]");
  fs.mkdirSync(root, { recursive: true });
  const lock = path.join(root, "command.lock");
  try {
    fs.mkdirSync(lock);
  } catch {
    fail("Concurrent command/stale command lock; refused: " + lock);
  }
  try {
    if (args[0] === "start") await start();
    if (args[0] === "stop") await stop();
    if (args[0] === "status") await status();
    if (args[0] === "export") await exportRunning();
    if (args[0] === "reset") await reset(args.includes("--yes"));
  } finally {
    fs.rmdirSync(lock);
  }
}
if (process.argv[1] && path.resolve(process.argv[1]) === self) {
  main(process.argv.slice(2)).catch((error) => {
    if (
      process.argv[2] === "--supervisor" &&
      /^[a-f0-9-]{36}$/.test(process.argv[3] || "")
    ) {
      try {
        const failurePath = path.join(root, process.argv[3] + ".failed");
        assertPlainPath(failurePath);
        fs.writeFileSync(failurePath, "Supervisor failed; inspect run log.", {
          flag: "wx",
        });
      } catch {
        /* Preserve the original refusal. */
      }
    }
    console.error(error.message);
    process.exitCode = 1;
  });
}
