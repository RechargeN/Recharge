import os from "node:os";
import { createHash } from "node:crypto";
import assert from "node:assert/strict";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");

function execCommand(script, args, extraEnv = {}) {
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

function runCommand(script, args, extraEnv) {
  const result = execCommand(script, args, extraEnv);
  if (result.status !== 0) {
    throw new Error(
      `${path.basename(script)} ${args.join(" ")} failed:\n${result.output}`,
    );
  }
  return result.output;
}

function digestState() {
  const match = /^digest ([0-9a-f]{64})$/m.exec(
    runCommand(seedCli, ["digest"]),
  );
  if (!match) throw new Error("digest output missing");
  return match[1];
}

function runFlutter(files, defines = []) {
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

/** D3.5: owner-command Session seed, clean/resumed/repeated equality,
 * real mobile controller/UI, verified stop and cleanup of this worktree stand. */
export async function main(args, hooks = {}) {
  const run = hooks.run ?? runCommand;
  const exec = hooks.exec ?? execCommand;
  const digest = hooks.digest ?? digestState;
  const flutter = hooks.flutter ?? runFlutter;
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-d3-5-gate.mjs --yes",
    );
  }
  // emulator-stand's default storage is shared across worktrees. T1 must
  // never reset another worktree's exported fixtures.
  const previousLocalAppData = process.env.LOCALAPPDATA;
  const previousPath = process.env.PATH;
  process.env.PATH = [
    path.dirname(process.execPath),
    ...(process.env.JAVA_HOME ? [path.join(process.env.JAVA_HOME, "bin")] : []),
    previousPath ?? "",
  ].join(path.delimiter);
  process.env.LOCALAPPDATA = path.join(
    os.tmpdir(),
    "recharge-t1-stand-" +
      createHash("sha256").update(repoRoot).digest("hex").slice(0, 16),
  );
  // Inherited by the stand (Functions) and by every seed process.

  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  const fresh = () => {
    run(standCli, ["stop"]);
    run(standCli, ["reset", "--yes"]);
    run(standCli, ["start"]);
    assert.match(run(seedCli, ["seed"]), /^seeded /m);
  };
  let failure;
  try {
    step("fresh stand with the base seed", fresh);
    step("clean Session seed through Content", () =>
      assert.match(run(seedCli, ["session", "seed"]), /^seeded session=/m),
    );
    step("verify Session invariants", () =>
      run(seedCli, ["session", "verify"]),
    );
    const clean = step("digest of the clean seed", digest);
    step("fresh stand with the base seed", fresh);
    step("Session seed interrupted after body binding (test hook)", () => {
      const interrupted = exec(seedCli, ["session", "seed"], {
        STAND_SEED_INTERRUPT_AFTER: "bind",
      });
      assert.notEqual(interrupted.status, 0);
      assert.match(
        interrupted.output,
        /interrupted: stand session seed interrupted after bind/,
      );
    });
    step("Session seed resumes from its idempotent commands", () =>
      assert.match(run(seedCli, ["session", "seed"]), /^seeded session=/m),
    );
    step("verify Session invariants", () =>
      run(seedCli, ["session", "verify"]),
    );
    const resumed = step("digest of the resumed seed", digest);
    assert.equal(
      resumed,
      clean,
      "a resumed Session seed must equal a clean seed",
    );
    step("a repeated Session seed reuses the result", () =>
      assert.match(run(seedCli, ["session", "seed"]), /^reused session=/m),
    );
    assert.equal(step("digest after the repeat", digest), clean);

    step("flutter test Session publication (controller, real stand)", () =>
      flutter(["test/backend_local/session_publication_stand_test.dart"]),
    );
    step("flutter test Session publication (UI, define on)", () =>
      flutter(
        ["test/backend_local/session_publication_ui_stand_test.dart"],
        ["RECHARGE_TEST_SESSION_PUBLICATION=true"],
      ),
    );
    step("base and Session invariants still hold", () => {
      run(seedCli, ["verify"]);
      run(seedCli, ["session", "verify"]);
    });
  } catch (error) {
    failure = error;
  } finally {
    try {
      step("verified stop", () => run(standCli, ["stop"]));
      step("cleanup this worktree stand fixtures", () =>
        run(standCli, ["reset", "--yes"]),
      );
    } catch (error) {
      failure ??= error;
    }
  }
  if (previousPath === undefined) delete process.env.PATH;
  else process.env.PATH = previousPath;
  if (previousLocalAppData === undefined) delete process.env.LOCALAPPDATA;
  else process.env.LOCALAPPDATA = previousLocalAppData;
  if (failure) throw failure;
  process.stdout.write(
    "D3.5 Session publication gate passed (local Emulator and PC host only; external booking URL, no Booking authority, fake scanner/processor and test-only staff registry; Catalog/Discover excluded; no device, staging or production claim)\n",
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
