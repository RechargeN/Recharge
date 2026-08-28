import { spawn, spawnSync } from "node:child_process";
import {
  cp,
  mkdtemp,
  mkdir,
  readFile,
  readdir,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import { existsSync } from "node:fs";
import { createServer } from "node:net";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const functionsRoot = path.join(backendRoot, "functions");
const tempPrefix = path.join(functionsRoot, ".raw-body-probe-");
const cloudGate = path.join(
  backendRoot,
  "scripts",
  "verify-no-cloud-context.mjs",
);
const toolchainGate = path.join(backendRoot, "scripts", "verify-toolchain.mjs");
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
const compiledProbe = path.join(
  functionsRoot,
  "lib",
  "test",
  "emulator",
  "booking_callable_raw_body_probe.js",
);
const compiledClient = path.join(
  functionsRoot,
  "lib",
  "test",
  "emulator",
  "booking_callable_raw_body_probe_client.js",
);
const functionsPort = 5101;

function assertContainedTemporaryPath(candidate) {
  const resolvedRoot = path.resolve(functionsRoot);
  const resolved = path.resolve(candidate);
  const relative = path.relative(resolvedRoot, resolved);
  if (
    relative.length === 0 ||
    relative.startsWith("..") ||
    path.isAbsolute(relative) ||
    !path.basename(resolved).startsWith(".raw-body-probe-")
  ) {
    throw new Error(`Refusing unsafe RAW-B temporary path: ${resolved}`);
  }
  return resolved;
}

async function removeTemporarySource(candidate) {
  const validated = assertContainedTemporaryPath(candidate);
  await rm(validated, { force: true, recursive: true });
  if (existsSync(validated))
    throw new Error("RAW-B temporary source survived cleanup");
}

async function assertPortFree() {
  await new Promise((resolve, reject) => {
    const server = createServer();
    server.once("error", (error) => {
      reject(
        new Error(`RAW-B loopback port ${functionsPort} is unavailable`, {
          cause: error,
        }),
      );
    });
    server.listen(functionsPort, "127.0.0.1", () => {
      server.close((error) =>
        error === undefined ? resolve() : reject(error),
      );
    });
  });
}

function runPrerequisite(script, cwd) {
  const result = spawnSync(process.execPath, [script], {
    cwd,
    stdio: "inherit",
    shell: false,
  });
  if (result.status !== 0)
    throw new Error(`RAW-B prerequisite failed: ${path.basename(script)}`);
}

async function verifyCleanupFailurePath() {
  const candidate = assertContainedTemporaryPath(await mkdtemp(tempPrefix));
  try {
    await writeFile(
      path.join(candidate, "induced-failure.marker"),
      "test-only\n",
      "utf8",
    );
    throw new Error("intentional RAW-B cleanup self-test");
  } catch (error) {
    if (
      !(error instanceof Error) ||
      error.message !== "intentional RAW-B cleanup self-test"
    ) {
      throw error;
    }
  } finally {
    await removeTemporarySource(candidate);
  }
}

async function createTemporarySource() {
  const temporaryRoot = assertContainedTemporaryPath(await mkdtemp(tempPrefix));
  try {
    const supportTarget = path.join(temporaryRoot, "test", "support");
    const emulatorTarget = path.join(temporaryRoot, "test", "emulator");
    await mkdir(emulatorTarget, { recursive: true });
    await cp(
      path.join(functionsRoot, "lib", "test", "support"),
      supportTarget,
      {
        recursive: true,
      },
    );
    await cp(
      compiledProbe,
      path.join(emulatorTarget, path.basename(compiledProbe)),
    );

    const normalizedFunctionsRoot = pathToFileURL(functionsRoot).href;
    await writeFile(
      path.join(temporaryRoot, "index.js"),
      [
        `process.chdir(${JSON.stringify(functionsRoot)});`,
        `const probe = await import(${JSON.stringify(
          new URL(
            "./test/emulator/booking_callable_raw_body_probe.js",
            pathToFileURL(`${temporaryRoot}${path.sep}`),
          ).href,
        )});`,
        "export const bookingRawBodyProbeV1 = probe.bookingRawBodyProbeV1;",
        `if (typeof bookingRawBodyProbeV1 !== "function") throw new Error(${JSON.stringify(
          `RAW-B probe export failed from ${normalizedFunctionsRoot}`,
        )});`,
        "",
      ].join("\n"),
      "utf8",
    );
    await writeFile(
      path.join(temporaryRoot, "package.json"),
      `${JSON.stringify(
        {
          name: "recharge-raw-body-probe-temporary",
          private: true,
          type: "module",
          main: "index.js",
          engines: { node: "22" },
          dependencies: { "firebase-functions": "7.3.2" },
        },
        null,
        2,
      )}\n`,
      "utf8",
    );
    await writeFile(
      path.join(temporaryRoot, "firebase.json"),
      `${JSON.stringify(
        {
          functions: { source: ".", runtime: "nodejs22" },
          emulators: {
            functions: { host: "127.0.0.1", port: functionsPort },
            ui: { enabled: false },
            singleProjectMode: true,
          },
        },
        null,
        2,
      )}\n`,
      "utf8",
    );
    await writeFile(
      path.join(temporaryRoot, "run-client.mjs"),
      `await import(${JSON.stringify(pathToFileURL(compiledClient).href)});\n`,
      "utf8",
    );
    return temporaryRoot;
  } catch (error) {
    await removeTemporarySource(temporaryRoot);
    throw error;
  }
}

function stopOwnedProcessTree(child) {
  if (child.pid === undefined) return;
  if (process.platform === "win32") {
    spawnSync("taskkill.exe", ["/pid", String(child.pid), "/t", "/f"], {
      shell: false,
    });
  } else {
    child.kill("SIGTERM");
  }
}

for (const requiredPath of [cloudGate, toolchainGate, firebaseCli, compiler]) {
  if (!existsSync(requiredPath)) {
    throw new Error(
      `required local RAW-B tool is absent: ${path.relative(backendRoot, requiredPath)}`,
    );
  }
}

runPrerequisite(cloudGate, backendRoot);
runPrerequisite(toolchainGate, functionsRoot);
runPrerequisite(compiler, functionsRoot);
for (const output of [compiledProbe, compiledClient]) {
  if (!(await stat(output)).isFile())
    throw new Error(`RAW-B compiled output is absent: ${output}`);
}
await assertPortFree();
await verifyCleanupFailurePath();

let temporaryRoot;
let child;
try {
  temporaryRoot = await createTemporarySource();
  const configPath = path.join(temporaryRoot, "firebase.json");
  const clientCommand = `${JSON.stringify(process.execPath)} ${JSON.stringify(
    path.join(temporaryRoot, "run-client.mjs"),
  )}`;
  child = spawn(
    process.execPath,
    [
      firebaseCli,
      "emulators:exec",
      "--config",
      configPath,
      "--project",
      "demo-recharge",
      "--only",
      "functions",
      clientCommand,
    ],
    {
      cwd: backendRoot,
      env: {
        ...process.env,
        CI: "true",
        FIREBASE_CLI_DISABLE_UPDATE_CHECK: "true",
        FUNCTIONS_EMULATOR: "true",
        FUNCTIONS_DISCOVERY_TIMEOUT: "30",
        GCLOUD_PROJECT: "demo-recharge",
        HTTP_PROXY: "http://127.0.0.1:9",
        HTTPS_PROXY: "http://127.0.0.1:9",
        NO_PROXY: "127.0.0.1,localhost",
      },
      stdio: "inherit",
      shell: false,
    },
  );

  let timedOut = false;
  const timeout = setTimeout(() => {
    timedOut = true;
    stopOwnedProcessTree(child);
  }, 300_000);
  let exitCode;
  try {
    exitCode = await new Promise((resolve, reject) => {
      child.once("error", reject);
      child.once("exit", (code) => resolve(code ?? 1));
    });
  } finally {
    clearTimeout(timeout);
  }
  child = undefined;
  if (timedOut) throw new Error("RAW-B emulator probe exceeded 300 seconds");
  if (exitCode !== 0)
    throw new Error(`RAW-B emulator probe failed: exit ${exitCode}`);
} finally {
  if (child !== undefined) stopOwnedProcessTree(child);
  if (temporaryRoot !== undefined) await removeTemporarySource(temporaryRoot);
  await assertPortFree();
}

const trackedProductEntry = await readFile(
  path.join(functionsRoot, "src", "index.ts"),
  "utf8",
);
const trackedPackage = await readFile(
  path.join(functionsRoot, "package.json"),
  "utf8",
);
if (
  trackedProductEntry.includes("bookingRawBodyProbeV1") ||
  trackedPackage.includes("bookingRawBodyProbeV1")
)
  throw new Error(
    "RAW-B probe leaked into a tracked product entry or package manifest",
  );
const leftovers = (
  await readdir(functionsRoot, { withFileTypes: true })
).filter(
  (entry) => entry.isDirectory() && entry.name.startsWith(".raw-body-probe-"),
);
if (leftovers.length > 0)
  throw new Error(
    `RAW-B temporary sources survived cleanup: ${leftovers.length}`,
  );
process.stdout.write(
  "RAW-B disposable callable emulator probe passed and cleaned up.\n",
);
