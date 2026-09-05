import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { createServer } from "node:net";
import { fileURLToPath, pathToFileURL } from "node:url";

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
const bookingExports = Object.keys(loadedFunctions)
  .filter((name) => name.endsWith("V1") && name !== "r0ToolchainProbe")
  .sort();
const expectedBookingExports = [
  "cancelInternalBookingV1",
  "createInternalBookingV1",
  "getEventAvailabilityV1",
  "getMyBookingV1",
  "listMyBookingsV1",
];
if (JSON.stringify(bookingExports) !== JSON.stringify(expectedBookingExports)) {
  throw new Error(
    `RAW-C must expose exactly five Booking v1 callables: ${bookingExports.join(",")}`,
  );
}
process.stdout.write(
  `R0 ESM function entry loaded in ${Date.now() - loadStartedAt}ms.\n`,
);

// Both Windows cmd.exe and POSIX sh support this form. Running from the
// package root keeps fixture/schema resolution identical to standalone gates.
const insideCommand = "cd functions && npm run test:emulator:inside";

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
    },
    stdio: "inherit",
    shell: false,
  },
);

const timeout = setTimeout(() => {
  if (process.platform === "win32" && child.pid !== undefined) {
    spawnSync("taskkill.exe", ["/pid", String(child.pid), "/t", "/f"], {
      shell: false,
    });
  } else {
    child.kill("SIGTERM");
  }
}, 600_000);

const exitCode = await new Promise((resolve, reject) => {
  child.once("error", reject);
  child.once("exit", (code) => resolve(code ?? 1));
});
clearTimeout(timeout);
cleanupWindowsListeners();

if (exitCode !== 0) {
  throw new Error(
    `Firebase emulator suite failed or was inconclusive: exit ${exitCode}`,
  );
}

process.stdout.write(
  "Firebase emulator R0, RAW-C transaction, contention, security, cleanup and default-deny gates passed.\n",
);
