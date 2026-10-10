// D1-L gate (docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md §15) on the CI
// runner ubuntu-24.04.
// - `inspect`: ClamAV .deb (SHA-256, GPG), the official databases through
//   freshclam, then versions, SHA-256, signature checks and every license
//   notice in the step summary. No test runs: the owner reads the report.
// - `test`: the same inspection, then the gate itself — self-check L1–L6, the
//   tool tests with the official databases (EICAR included) and the Storage
//   path on the Emulator. It stops before testing if main, daily or bytecode
//   is missing, or a database has no COPYING or fails its signature check.
//   An overrun of the download budget or an incomplete set fails both stages.
// The databases never leave the runner: nothing is committed, uploaded,
// cached or mirrored.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import { selftest, start, stop, toolsRoot } from "./media-tools.mjs";
import {
  databaseSetProblems,
  fetchLinux,
  fetchOfficialDatabases,
  inspectDatabases,
  inspectionMarkdown,
  npmNotices,
  writeSummary,
} from "./media-tools-linux.mjs";
import { counts } from "./stand-d1-gate.mjs";

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
export const stageFile = path.join(backend, "ci", "d1-linux-stage.json");
const instance = "d1-linux";

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
  process.stdout.write(output);
  if (result.status !== 0)
    fail(`${path.basename(args[0])} exited ${result.status}`);
  return output;
}

/** On Linux only the L1-specific checks may be skipped. */
function onlyL1Skips(output) {
  const skips = [...output.matchAll(/# SKIP (.*)$/gmu)].map(
    (match) => match[1],
  );
  const foreign = skips.filter((reason) => !reason.startsWith("L1 only"));
  if (foreign.length > 0)
    fail(`unexpected skips on the Linux gate: ${JSON.stringify(foreign)}`);
  return skips.length;
}

export function readStage(args) {
  const fromArgs = args
    .find((arg) => arg.startsWith("--stage="))
    ?.slice("--stage=".length);
  const stage =
    fromArgs ?? JSON.parse(fs.readFileSync(stageFile, "utf8")).stage;
  if (stage !== "inspect" && stage !== "test") fail(`unknown stage ${stage}`);
  return stage;
}

/**
 * What blocks testing: a missing or doubled main/daily/bytecode, a database
 * without COPYING or with a failed signature check.
 */
export function openPoints(inspection) {
  const points = databaseSetProblems(inspection.databases.map((db) => db.name));
  for (const db of inspection.databases) {
    if (!db.verified)
      points.push(
        `${db.name}: the signature check did not report "Verification OK"`,
      );
    if (!db.copying)
      points.push(`${db.name}: no COPYING file inside the database`);
  }
  return points;
}

export async function main(args) {
  if (!args.includes("--yes"))
    fail("Usage: stand-d1-linux-gate.mjs --yes [--stage=inspect|test]");
  if (process.platform !== "linux") fail("the D1-L gate runs on Linux only");
  const stage = readStage(args);
  process.stdout.write(`D1-L gate, stage ${stage}\n`);

  const fetched = await step(
    "ClamAV .deb: SHA-256, GPG, extracted without installing",
    () => fetchLinux(),
  );
  await step("official databases through freshclam (runner only)", () =>
    fetchOfficialDatabases(),
  );
  const inspection = await step(
    "inspect the databases and the license notices",
    () => {
      const result = inspectDatabases();
      writeSummary(inspectionMarkdown(fetched, result, npmNotices()));
      return result;
    },
  );
  const points = openPoints(inspection);
  writeSummary(
    points.length === 0
      ? "### Inspection: every database verified and carries COPYING\n"
      : `### Open points before testing\n${points.map((point) => `- ${point}`).join("\n")}\n`,
  );
  if (stage === "inspect") {
    process.stdout.write(
      "inspect stage complete: no test was run; the owner reads the report\n",
    );
    return;
  }
  if (points.length > 0) fail(`stopping before tests: ${points.join("; ")}`);

  await step("build", () => run([compiler, "-p", "."], { cwd: functionsDir }));
  await step("D1 unit tests and the Media guard", () =>
    run(
      [
        "--test",
        "--experimental-test-isolation=none",
        "lib/test/unit/media/clamd_protocol.test.js",
        "lib/test/unit/media/local_tools_protocol.test.js",
        "lib/test/unit/media/local_tools_client.test.js",
        "lib/test/unit/media/media_tool_limits.test.js",
        "lib/test/integration/media_security.test.js",
      ],
      { cwd: functionsDir },
    ),
  );
  await step("cgroup self-check L1–L6", () => selftest());
  let running = false;
  try {
    await step(
      "start the local tools with the official databases",
      async () => {
        await start({
          instance,
          standSignaturesOnly: false,
          databaseMode: "official",
        });
        running = true;
      },
    );
    await step(
      "tool tests: native Linux sharp, the service, ClamAV with official databases",
      () => {
        const output = run(
          [
            "--test",
            "--experimental-test-isolation=none",
            "lib/test/media_tools/image_pipeline.test.js",
            "lib/test/media_tools/media_tools_host.test.js",
            "lib/test/media_tools/clamd_scan.test.js",
          ],
          {
            cwd: functionsDir,
            env: {
              ...process.env,
              RECHARGE_MEDIA_TOOLS_DATABASE_MODE: "official",
            },
          },
        );
        const result = counts(output);
        const skipped = onlyL1Skips(output);
        if (result.fail !== 0 || result.skipped !== skipped || skipped !== 2)
          fail(`tool tests: ${JSON.stringify(result)}`);
      },
    );
    await step("Storage path on the Emulator, EICAR included", () => {
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
      if (result.fail !== 0 || result.skipped !== 0 || result.pass !== 7)
        fail(`Storage path: ${JSON.stringify(result)}`);
    });
  } finally {
    if (running)
      await step("stop the local tools (verified)", () => stop({ instance }));
  }
  const daily = inspection.databases.find((db) => db.name.startsWith("daily"));
  writeSummary(
    [
      "## D1-L gate passed: Linux CI verified",
      `- official databases: ${inspection.databases.map((db) => `${db.name} v${db.version}`).join(", ")}${daily ? ` (daily built ${daily.buildTime})` : ""}`,
      "- EICAR rejected by the official signatures, directly and through the Storage path",
      "- image pipeline on the native Linux build of sharp/libvips",
      "- memory capped by cgroup v2 scopes (self-check L1–L6)",
      "- OD-03/04/05 stay open; no Firebase deployment",
      "",
    ].join("\n"),
  );
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main(process.argv.slice(2)).catch((error) => {
    process.stderr.write(`stand-d1-linux-gate: ${error.message}\n`);
    process.exitCode = 1;
  });
