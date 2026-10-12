import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, appendFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { selectGroups, suiteTimeoutMs } from "./run-emulator-test-groups.mjs";
import { createServer } from "node:net";
import { fileURLToPath, pathToFileURL } from "node:url";

const args = process.argv.slice(2);
const loadEvidenceMode =
  args.length === 1 && args[0] === "--booking-load-evidence";
const groupName =
  args.length === 2 && args[0] === "--group" ? args[1] : undefined;
if (args.length !== 0 && !loadEvidenceMode && groupName === undefined) {
  throw new Error(
    "usage: run-emulator-tests.mjs [--group NAME | --booking-load-evidence]",
  );
}
const selectedGroups = selectGroups(groupName);

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const functionsRoot = path.join(backendRoot, "functions");
const cloudGate = path.join(
  backendRoot,
  "scripts",
  "verify-no-cloud-context.mjs",
);
const firebaseCli = path.join(
  functionsRoot,
  "node_modules",
  "firebase-tools",
  "lib",
  "bin",
  "firebase.js",
);
const compiler = path.join(
  functionsRoot,
  "node_modules",
  "typescript",
  "bin",
  "tsc",
);
const functionEntry = path.join(functionsRoot, "lib", "src", "index.js");
const emulatorPorts = [5001, 8080, 8085, 9099, 9199];

async function assertPortFree(port) {
  await new Promise((resolve, reject) => {
    const server = createServer();
    server.once("error", (error) => {
      reject(
        new Error(`R0 emulator port ${port} is unavailable`, { cause: error }),
      );
    });
    server.listen(port, "127.0.0.1", () => {
      server.close((error) =>
        error === undefined ? resolve() : reject(error),
      );
    });
  });
}

async function assertPortsFree() {
  for (const port of emulatorPorts) {
    await assertPortFree(port);
  }
}

function cleanupWindowsListeners() {
  if (process.platform !== "win32") {
    return;
  }

  const script = [
    "$ports = @(5001, 8080, 8085, 9099, 9199)",
    "$listeners = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -eq '127.0.0.1' -and $_.LocalPort -in $ports }",
    "foreach ($processId in ($listeners.OwningProcess | Sort-Object -Unique)) {",
    "  $candidate = Get-Process -Id $processId -ErrorAction Stop",
    '  if ($candidate.Path -ne $env:R0_EXPECTED_JAVA -and $candidate.Path -ne $env:R0_EXPECTED_NODE) { throw "Refusing to stop unrelated process $processId" }',
    "  Stop-Process -Id $processId -ErrorAction Stop",
    "}",
  ].join("; ");
  const cleanup = spawnSync(
    "powershell.exe",
    ["-NoProfile", "-NonInteractive", "-Command", script],
    {
      encoding: "utf8",
      env: {
        ...process.env,
        R0_EXPECTED_JAVA: path.join(
          process.env.JAVA_HOME ?? "",
          "bin",
          "java.exe",
        ),
        R0_EXPECTED_NODE: process.execPath,
      },
      shell: false,
    },
  );
  if (cleanup.status !== 0) {
    process.stderr.write(cleanup.stdout ?? "");
    process.stderr.write(cleanup.stderr ?? "");
    throw new Error("R0 Windows emulator child cleanup failed");
  }
}

for (const requiredPath of [cloudGate, firebaseCli, compiler]) {
  if (!existsSync(requiredPath)) {
    throw new Error(
      `required local R0 tool is absent: ${path.relative(backendRoot, requiredPath)}`,
    );
  }
}

await assertPortsFree();

for (const [script, cwd] of [
  [cloudGate, backendRoot],
  [compiler, functionsRoot],
]) {
  const result = spawnSync(process.execPath, [script], {
    cwd,
    stdio: "inherit",
    shell: false,
  });
  if (result.status !== 0) {
    throw new Error(`R0 prerequisite failed: ${path.basename(script)}`);
  }
}

const loadStartedAt = Date.now();
let loadTimeout;
const loadedFunctions = await Promise.race([
  import(pathToFileURL(functionEntry).href),
  new Promise((_, reject) => {
    loadTimeout = setTimeout(
      () => reject(new Error("R0 ESM function discovery exceeded 120 seconds")),
      120_000,
    );
  }),
]);
clearTimeout(loadTimeout);
if (typeof loadedFunctions.r0ToolchainProbe !== "function") {
  throw new Error("R0 function entry does not export r0ToolchainProbe");
}
const boundedCallableExports = Object.keys(loadedFunctions)
  .filter((name) => name.endsWith("V1") && name !== "r0ToolchainProbe")
  .sort();
const expectedBoundedCallableExports = [
  "cancelInternalBookingV1",
  "createInternalBookingV1",
  "reconfirmInternalBookingV1",
  "getEventAvailabilityV1",
  "getMyBookingV1",
  "establishIdentitySessionV1",
  "refreshIdentitySessionV1",
  "recoverIdentitySessionsV1",
  "releaseMissedReconfirmationsV1",
  "consumeEventBookingOutboxV1",
  "retryEventBookingProjectionDeliveriesV1",
  "listMyBookingsV1",
  // C1: default-off, Emulator-only Media entry approved by the owner.
  "mediaCommandV1",
  "mediaQueryV1",
  "uploadMediaBytesV1",
  // C3: default-off, Emulator-only Event authoring through Content, approved by the owner.
  "contentCommandV1",
  "contentQueryV1",
  // E2: default-off, Emulator-only Discover read and Content effect trigger.
  "discoverQueryV1",
  "consumeContentEffectV1",
  // F1: default-off, Emulator-only Notifications inbox and Booking-effect trigger.
  "notificationsQueryV1",
  "notificationsCommandV1",
  "consumeNotificationEffectV1",
  // D2: default-off, Emulator-only delivery gate, Media-fact trigger and sweeps.
  "mediaDeliveryV1",
  "consumeMediaEffectV1",
  "reconcileMediaReferencesV1",
].sort();
if (
  JSON.stringify(boundedCallableExports) !==
  JSON.stringify(expectedBoundedCallableExports)
) {
  throw new Error(
    `Emulator must expose exactly the approved bounded v1 callables: ${boundedCallableExports.join(",")}`,
  );
}
process.stdout.write(
  `R0 ESM function entry loaded in ${Date.now() - loadStartedAt}ms.\n`,
);

// The compiler above finishes before emulators:exec. Inner commands never build.
const logDir = mkdtempSync(path.join(tmpdir(), "recharge-emulator-tests-"));
const emulatorLog = path.join(logDir, "emulator.log");
process.stdout.write(`Emulator logs: ${logDir}\n`);
const insideCommand = loadEvidenceMode
  ? `cd functions && "${process.execPath}" --test --experimental-test-isolation=none lib/test/emulator/booking_load_evidence.test.js`
  : `cd functions && "${process.execPath}" ../scripts/run-emulator-test-groups.mjs`;

const child = spawn(
  process.execPath,
  [
    firebaseCli,
    "emulators:exec",
    "--project",
    "demo-recharge",
    "--only",
    "auth,functions,firestore,storage,pubsub",
    insideCommand,
  ],
  {
    cwd: backendRoot,
    env: {
      ...process.env,
      CI: "true",
      FUNCTIONS_EMULATOR: "true",
      FUNCTIONS_DISCOVERY_TIMEOUT: "30",
      GCLOUD_PROJECT: "demo-recharge",
      R0_EMULATOR_GROUP: groupName ?? "",
      R0_EMULATOR_LOG_DIR: logDir,
    },
    stdio: ["ignore", "pipe", "pipe"],
    shell: false,
  },
);

for (const stream of [child.stdout, child.stderr]) {
  stream.on("data", (chunk) => {
    appendFileSync(emulatorLog, chunk);
    process.stdout.write(chunk);
  });
}
let timedOut = false;
// Per-group measured bounds plus startup/shutdown allowances; load mode retains its bound.
const timeoutMs = loadEvidenceMode ? 900_000 : suiteTimeoutMs(selectedGroups);
const timeout = setTimeout(() => {
  timedOut = true;
  if (process.platform === "win32" && child.pid !== undefined) {
    spawnSync("taskkill.exe", ["/pid", String(child.pid), "/t", "/f"], {
      shell: false,
    });
  } else child.kill("SIGTERM");
}, timeoutMs);
let exitCode;
try {
  exitCode = await new Promise((resolve, reject) => {
    child.once("error", reject);
    child.once("close", (code) => resolve(code ?? 1));
  });
} finally {
  clearTimeout(timeout);
  cleanupWindowsListeners();
}
if (timedOut || exitCode !== 0) {
  throw new Error(
    `Firebase Emulator suite failed or was inconclusive: exit ${exitCode}, timedOut=${timedOut}; logs ${logDir}`,
  );
}
