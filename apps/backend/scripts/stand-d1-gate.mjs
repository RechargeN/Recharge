// D1 gate (docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md): the Job Object
// self-check, the local tools in L1 test mode, the tool tests on the real
// sharp and ClamAV, and the Storage path on the Emulator. Local Windows
// evidence only; the Linux gate (EICAR, official databases, cgroup limits,
// native Linux build) stays open and this gate says so.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { selftest, start, stop, toolsRoot } from "./media-tools.mjs";

const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const functionsDir = path.join(backend, "functions");
const firebaseCli = path.join(
  functionsDir,
  "node_modules",
  "firebase-tools",
  "lib",
  "bin",
  "firebase.js",
);
const compiler = path.join(
  functionsDir,
  "node_modules",
  "typescript",
  "bin",
  "tsc",
);
const instance = "d1-gate";

function fail(message) {
  throw new Error(message);
}

async function step(name, action) {
  process.stdout.write(`- ${name}\n`);
  return action();
}

function run(args, options) {
  const result = spawnSync(process.execPath, args, {
    encoding: "utf8",
    shell: false,
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  });
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
  if (result.status !== 0) {
    process.stdout.write(output);
    fail(`${path.basename(args[0])} exited ${result.status}`);
  }
  return output;
}

/** node:test summary counters from TAP output. */
export function counts(output) {
  const value = (name) =>
    [...output.matchAll(new RegExp(`^# ${name} (\\d+)$`, "gmu"))].reduce(
      (sum, match) => sum + Number(match[1]),
      0,
    );
  return {
    tests: value("tests"),
    pass: value("pass"),
    fail: value("fail"),
    skipped: value("skipped"),
  };
}

export async function main(args) {
  if (!args.includes("--yes")) fail("Usage: stand-d1-gate.mjs --yes");
  await step("build", () => run([compiler, "-p", "."], { cwd: functionsDir }));
  await step("no cloud context", () =>
    run([path.join(backend, "scripts", "verify-no-cloud-context.mjs")], {
      cwd: backend,
    }),
  );
  await step("Job Object self-check J1–J6", () => selftest());
  let running = false;
  try {
    await step("start the local tools in L1 test mode", async () => {
      await start({ instance, standSignaturesOnly: true });
      running = true;
    });
    await step("tool tests on the real sharp and ClamAV", () => {
      const output = run(
        [
          "--test",
          "--experimental-test-isolation=none",
          "lib/test/media_tools/image_pipeline.test.js",
          "lib/test/media_tools/media_tools_host.test.js",
          "lib/test/media_tools/clamd_scan.test.js",
        ],
        { cwd: functionsDir },
      );
      const result = counts(output);
      const skippedEicar = /# SKIP Defender real-time protection active/u.test(
        output,
      );
      if (result.fail !== 0 || result.skipped !== 1 || !skippedEicar)
        fail(
          `tool tests: ${JSON.stringify(result)}; only the EICAR test may be skipped`,
        );
      process.stdout.write(
        `  ${result.pass} passed, EICAR skipped (Linux gate)\n`,
      );
    });
    await step("Storage path on the Emulator with the real tools", () => {
      const output = run(
        [
          firebaseCli,
          "emulators:exec",
          "--project",
          "demo-recharge",
          "--only",
          "auth,firestore,storage",
          "cd functions && node lib/test/emulator/media_real_tools_flow.test.js",
        ],
        {
          cwd: backend,
          env: {
            ...process.env,
            CI: "true",
            FUNCTIONS_EMULATOR: "true",
            GCLOUD_PROJECT: "demo-recharge",
            RECHARGE_MEDIA_TOOLS_ACCESS: path.join(
              toolsRoot,
              "run",
              instance,
              "access.json",
            ),
          },
        },
      );
      const result = counts(output);
      if (result.fail !== 0 || result.skipped !== 0 || result.pass !== 6)
        fail(`Storage path: ${JSON.stringify(result)}`);
      process.stdout.write(`  ${result.pass} passed\n`);
    });
  } finally {
    if (running)
      await step("stop the local tools (verified)", () => stop({ instance }));
  }
  const report = fs
    .readdirSync(path.join(toolsRoot, "run"))
    .filter((name) => name.endsWith(".selftest.json"))
    .sort()
    .at(-1);
  process.stdout.write(
    [
      "D1 gate passed: Windows-local verified.",
      "  scanner: ClamAV 1.5.4 with the stand test signature only (L1)",
      "  daily freshness: NOT APPLIED - official database absent (L1)",
      "  EICAR: not run here - Linux gate open",
      "  Linux: not verified - Linux gate open (native Linux build, cgroup memory limit)",
      `  Job Object self-check: ${report ?? "report missing"}`,
      "",
    ].join("\n"),
  );
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`stand-d1-gate: ${error.message}\n`);
    process.exitCode = 1;
  });
