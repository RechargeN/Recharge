// D2 gate (docs/product/MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md §11): the D2
// unit and integration tests, then the Emulator flow with a real cover from the
// D1 local tools (L1 test mode): delivery through the gate, a staff restriction
// and its lift while Content did not run, suppression, the publisher's
// confirmation, Catalog rebuild and rollback, and both sweeps with the
// explicitly test-only retention policy. Local Windows evidence only; signed
// URLs, CDN and client caches stay F2a.
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { start, stop, toolsRoot } from "./media-tools.mjs";

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
const instance = "d2-gate";

/** The D2 tests (and the guards D2 changed) that run without an Emulator. */
export const inProcessTests = Object.freeze([
  "lib/test/unit/media/media_revocation_epoch.test.js",
  "lib/test/unit/content/publication_pointer_media.test.js",
  "lib/test/unit/catalog/catalog_media_suppression.test.js",
  "lib/test/integration/media_delivery_gate.test.js",
  "lib/test/integration/content_media_availability.test.js",
  "lib/test/integration/moderation_media_restriction.test.js",
  "lib/test/integration/media_orphan_sweep.test.js",
  "lib/test/integration/media_security.test.js",
  "lib/test/integration/content_publication_security.test.js",
]);
export const emulatorFlow =
  "lib/test/emulator/media_late_restriction_flow.test.js";
/** T1, T2, T3, T8, T10: every one must pass, none may be skipped. */
export const emulatorFlowTests = 5;

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
    Number(new RegExp(`^# ${name} (\\d+)$`, "mu").exec(output)?.[1] ?? NaN);
  return {
    tests: value("tests"),
    pass: value("pass"),
    fail: value("fail"),
    skipped: value("skipped"),
  };
}

export async function main(args) {
  if (!args.includes("--yes")) fail("Usage: stand-d2-gate.mjs --yes");
  await step("build", () => run([compiler, "-p", "."], { cwd: functionsDir }));
  await step("no cloud context", () =>
    run([path.join(backend, "scripts", "verify-no-cloud-context.mjs")], {
      cwd: backend,
    }),
  );
  await step("D2 unit and integration tests (no Emulator)", () => {
    const result = counts(
      run(["--test", "--experimental-test-isolation=none", ...inProcessTests], {
        cwd: functionsDir,
      }),
    );
    if (result.fail !== 0 || result.skipped !== 0 || !(result.pass > 0))
      fail(`in-process tests: ${JSON.stringify(result)}`);
    process.stdout.write(`  ${result.pass} passed\n`);
  });
  let running = false;
  try {
    await step("start the local tools in L1 test mode", async () => {
      await start({ instance, standSignaturesOnly: true });
      running = true;
    });
    await step(
      "Emulator flow: delivery, restriction, suppression, confirmation, rebuild, sweeps",
      () => {
        const output = run(
          [
            firebaseCli,
            "emulators:exec",
            "--project",
            "demo-recharge",
            "--only",
            "auth,firestore,storage",
            `cd functions && node ${emulatorFlow}`,
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
        if (
          result.fail !== 0 ||
          result.skipped !== 0 ||
          result.pass !== emulatorFlowTests
        ) {
          process.stdout.write(output);
          fail(`Emulator flow: ${JSON.stringify(result)}`);
        }
        process.stdout.write(`  ${result.pass} passed\n`);
      },
    );
  } finally {
    if (running)
      await step("stop the local tools (verified)", () => stop({ instance }));
  }
  process.stdout.write(
    [
      "D2 gate passed: Windows-local Emulator evidence.",
      "  delivery: refused at once after a restriction and after its lift until the publisher confirms",
      "  Content: suppression by state, idempotent; Catalog rebuild and rollback keep it",
      "  sweeps: R1 by state; R2 deletes only with the test-only retention policy",
      "  not covered here: signed URLs, CDN, client cache (F2a); cloud; mobile",
      "",
    ].join("\n"),
  );
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`stand-d2-gate: ${error.message}\n`);
    process.exitCode = 1;
  });
