import assert from "node:assert/strict";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");

function exec(script, args, extraEnv = {}) {
  const result = spawnSync(process.execPath, [script, ...args], {
    encoding: "utf8",
    shell: false,
    env: { ...process.env, ...extraEnv },
  });
  return {
    status: result.status,
    output: (result.stdout ?? "") + (result.stderr ?? ""),
  };
}

function run(script, args, extraEnv) {
  const result = exec(script, args, extraEnv);
  if (result.status !== 0) {
    throw new Error(
      `${path.basename(script)} ${args.join(" ")} failed:\n${result.output}`,
    );
  }
  return result.output;
}

function digest() {
  const match = /^digest ([0-9a-f]{64})$/m.exec(run(seedCli, ["digest"]));
  if (!match) throw new Error("digest output missing");
  return match[1];
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
 * D4 local→server import gate (LOCAL_IMPORT_D4_AMENDMENT.md §7). On a fresh
 * stand with the base seed and the D3.1 Place seed (which enables Place
 * authoring and provides the Page), the mobile import runs on this PC against
 * the stand: an interrupted create whose answer was lost resumes into the same
 * server draft after a restart, lost receipts and a repeated import never
 * create a second draft (Content returns the author's draft for the import
 * source), and the local original is removed only after verification,
 * explicit confirmation and the recovery period. Local Emulator only; it
 * resets the stand data first, so it needs --yes.
 */
export async function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-d4-gate.mjs --yes",
    );
  }
  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  let failure;
  try {
    step("fresh stand with the base seed", () => {
      run(standCli, ["stop"]);
      run(standCli, ["reset", "--yes"]);
      run(standCli, ["start"]);
      assert.match(run(seedCli, ["seed"]), /^seeded /m);
    });
    step("Place seed (enables Place authoring, provides the Page)", () =>
      assert.match(run(seedCli, ["place", "seed"]), /^seeded place=/m),
    );
    step("flutter test local import (controller, real stand)", () =>
      flutter(["test/backend_local/local_import_stand_test.dart"]),
    );
    step("base and Place invariants still hold", () => {
      run(seedCli, ["verify"]);
      run(seedCli, ["place", "verify"]);
    });
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
    "D4 local import gate passed (local Emulator and PC host only; one server draft per author and import source, resume after a lost answer, guarded removal of the local original; fake scanner/processor on the stand; no device, LAN or cloud claim)\n",
  );
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
