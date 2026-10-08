import assert from "node:assert/strict";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");
const functionsDir = path.join(here, "..", "functions");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");

function exec(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    shell: false,
    env: process.env,
    ...options,
  });
  return {
    status: result.status,
    output: (result.stdout ?? "") + (result.stderr ?? ""),
  };
}

function run(script, args) {
  const result = exec(process.execPath, [script, ...args]);
  if (result.status !== 0) {
    throw new Error(
      `${path.basename(script)} ${args.join(" ")} failed:\n${result.output}`,
    );
  }
  return result.output;
}

function lastJson(output) {
  const line = output
    .trim()
    .split("\n")
    .filter((value) => value.trim().startsWith("{"))
    .pop();
  if (!line) throw new Error(`no JSON in output:\n${output}`);
  return JSON.parse(line);
}

const pause = (ms) =>
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

/** Polls a real read until it holds; the deadline is the only wait. */
function eventually(what, read, done, seconds = 90) {
  const deadline = Date.now() + seconds * 1000;
  for (;;) {
    const value = read();
    if (done(value)) return value;
    if (Date.now() > deadline) throw new Error(`timed out waiting for ${what}`);
    pause(500);
  }
}

function flutter(files, defines = []) {
  const args = [
    "test",
    "--no-pub",
    ...defines.map((define) => `--dart-define=${define}`),
    ...files,
  ];
  const env = {
    ...process.env,
    RECHARGE_B1_STAND: "1",
    RECHARGE_REPO_ROOT: repoRoot,
    RECHARGE_NODE: process.execPath,
  };
  const cwd = path.join(repoRoot, "apps", "mobile");
  const result =
    process.platform === "win32"
      ? spawnSync("cmd.exe", ["/c", "flutter", ...args], {
          cwd,
          env,
          stdio: "inherit",
        })
      : spawnSync("flutter", args, { cwd, env, stdio: "inherit" });
  if (result.status !== 0) throw new Error("flutter test failed");
}

/**
 * E2a Discover gate. The Functions build under test is the one the stand
 * loads. With the stand flags on, the Emulator-only Content effect trigger
 * projects the seeded Content Event without any manual delivery; then the
 * mobile Discover adapters run on this PC against the stand: a Creator
 * publishes through the C3 path and another user with another Session reads
 * Feed, Search and Details as one revision, and loses it after the owner hides
 * it. Local Emulator only; it resets the stand data first, so it needs --yes.
 */
export function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-e2a-gate.mjs --yes",
    );
  }
  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  let failure;
  try {
    step("build the Functions the stand loads", () => {
      const result = exec(
        process.execPath,
        [path.join("node_modules", "typescript", "bin", "tsc"), "-p", "."],
        { cwd: functionsDir },
      );
      if (result.status !== 0) throw new Error(`tsc failed:\n${result.output}`);
    });
    step("verified stop", () => run(standCli, ["stop"]));
    step("reset", () => run(standCli, ["reset", "--yes"]));
    step("start", () => run(standCli, ["start"]));
    step("seed", () => run(seedCli, ["seed"]));
    step("verify seed invariants", () => run(seedCli, ["verify"]));
    const seeded = step("seeded Content Event from the manifest", () =>
      lastJson(run(seedCli, ["manifest"])),
    ).contentEvent.contentId;
    step(
      "the trigger projects the seeded Event without manual delivery",
      () => {
        const page = eventually(
          "the Content effect trigger",
          () => lastJson(run(seedCli, ["catalog", "feed"])),
          (value) =>
            value.kind === "succeeded" &&
            value.items.some((item) => item.contentId === seeded),
        );
        assert.equal(page.freshness.projection, "fresh");
      },
    );
    step(
      "flutter test Discover over the Catalog (real adapters, two users)",
      () => flutter(["test/backend_local/discover_catalog_stand_test.dart"]),
    );
    step("Catalog reconciliation is complete after the run", () => {
      const report = lastJson(run(seedCli, ["catalog", "reconcile"]));
      assert.equal(report.complete, true, JSON.stringify(report.findings));
    });
    step("seed invariants still hold", () => run(seedCli, ["verify"]));
  } catch (error) {
    failure = error;
  } finally {
    try {
      step("verified stop", () => run(standCli, ["stop"]));
    } catch (error) {
      failure ??= error;
    }
  }
  if (failure) throw failure;
  process.stdout.write(
    "E2a Discover gate passed (local Emulator and PC host only; Emulator-only discoverQueryV1 and Content effect trigger, Event only, Booking availability not connected; no Booking from Details, device, LAN or cloud claim)\n",
  );
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
