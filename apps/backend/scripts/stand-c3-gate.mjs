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
 * C3 Event publication gate. The stand's Event is created through the Content
 * path (Creator draft, Media cover, staff approval, owner publish); a seed that
 * is interrupted and resumed must reach exactly the state of a clean seed, and
 * a repeated seed must reuse it. Then the mobile publication path runs on this
 * PC against the stand: the controller test and the UI test with the
 * default-off define. Local Emulator only; it resets the stand data first, so
 * it needs an explicit --yes.
 */
export function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-c3-gate.mjs --yes",
    );
  }
  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  const fresh = () => {
    run(standCli, ["stop"]);
    run(standCli, ["reset", "--yes"]);
    run(standCli, ["start"]);
  };
  let failure;
  try {
    step("fresh stand", fresh);
    step("clean seed (Event through Content)", () =>
      assert.match(run(seedCli, ["seed"]), /^seeded /m),
    );
    step("verify seed invariants", () => run(seedCli, ["verify"]));
    const clean = step("digest of the clean seed", digest);

    step("fresh stand", fresh);
    step("seed interrupted after the cover binding (test hook)", () => {
      const interrupted = exec(seedCli, ["seed"], {
        STAND_SEED_INTERRUPT_AFTER: "bind",
      });
      assert.notEqual(interrupted.status, 0);
      assert.match(
        interrupted.output,
        /interrupted: stand seed interrupted after bind/,
      );
    });
    step("seed resumes from its idempotent commands", () =>
      assert.match(run(seedCli, ["seed"]), /^reused /m),
    );
    step("verify seed invariants", () => run(seedCli, ["verify"]));
    const resumed = step("digest of the resumed seed", digest);
    assert.equal(resumed, clean, "a resumed seed must equal a clean seed");
    step("a repeated seed reuses the result", () =>
      assert.match(run(seedCli, ["seed"]), /^reused /m),
    );
    assert.equal(step("digest after the repeat", digest), clean);
    step("manifest records the Content Event", () => {
      const manifest = JSON.parse(
        run(seedCli, ["manifest"])
          .trim()
          .split("\n")
          .filter((line) => line.trim().startsWith("{"))
          .pop(),
      );
      assert.ok(manifest.contentEvent.publishedRevisionId);
    });

    step("flutter test Event publication (controller, real stand)", () =>
      flutter(["test/backend_local/event_publication_stand_test.dart"]),
    );
    step("flutter test Event publication (UI, define on)", () =>
      flutter(
        ["test/backend_local/event_publication_ui_stand_test.dart"],
        ["RECHARGE_TEST_EVENT_PUBLICATION=true"],
      ),
    );
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
    "C3 Event publication gate passed (local Emulator and PC host only; synthetic reference data, fake scanner/processor, test-only staff registry; no Booking bridge, no device, LAN or cloud claim)\n",
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
