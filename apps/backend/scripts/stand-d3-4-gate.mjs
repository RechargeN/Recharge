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
 * D3.4 Collection / Guide publication gate
 * (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md §7). The stand runs with
 * `RECHARGE_TEST_COLLECTION_MEMBERSHIP=true`, so Content asks the
 * Catalog-owned evaluator about every item. Three member Places and the
 * Collection that references them are published through Content only (empty
 * draft, cover through Media, the full body, staff approval, owner publish)
 * under their own flags, which only `stand-seed.mjs collection seed` enables.
 * A Collection seed interrupted after the second member and resumed must reach
 * exactly the state of a clean seed, and a repeated seed must reuse it.
 * `collection verify` checks the pointer, the member references, the cover,
 * the Catalog exclusion (no Collection model) and the Booking handoff. Then the
 * mobile Collection path runs on this PC against the stand: the controller
 * test (with the Catalog picker) and the UI test with the default-off define.
 * Local Emulator only; it resets the stand data first, so it needs --yes.
 */
export async function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-d3-4-gate.mjs --yes",
    );
  }
  // Inherited by the stand (Functions) and by every seed process.
  process.env.RECHARGE_TEST_COLLECTION_MEMBERSHIP = "true";
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
    step("clean Collection seed (members and Collection through Content)", () =>
      assert.match(
        run(seedCli, ["collection", "seed"]),
        /^seeded collection=/m,
      ),
    );
    step("verify Collection invariants", () =>
      run(seedCli, ["collection", "verify"]),
    );
    const clean = step("digest of the clean seed", digest);
    step("fresh stand with the base seed", fresh);
    step(
      "Collection seed interrupted after the second member (test hook)",
      () => {
        const interrupted = exec(seedCli, ["collection", "seed"], {
          STAND_SEED_INTERRUPT_AFTER: "member-2",
        });
        assert.notEqual(interrupted.status, 0);
        assert.match(
          interrupted.output,
          /interrupted: stand collection seed interrupted after member-2/,
        );
      },
    );
    step("Collection seed resumes from its idempotent commands", () =>
      assert.match(
        run(seedCli, ["collection", "seed"]),
        /^seeded collection=/m,
      ),
    );
    step("verify Collection invariants", () =>
      run(seedCli, ["collection", "verify"]),
    );
    const resumed = step("digest of the resumed seed", digest);
    assert.equal(
      resumed,
      clean,
      "a resumed Collection seed must equal a clean seed",
    );
    step("a repeated Collection seed reuses the result", () =>
      assert.match(
        run(seedCli, ["collection", "seed"]),
        /^reused collection=/m,
      ),
    );
    assert.equal(step("digest after the repeat", digest), clean);

    step("flutter test Collection publication (controller, real stand)", () =>
      flutter(["test/backend_local/collection_publication_stand_test.dart"]),
    );
    step("flutter test Collection publication (UI, define on)", () =>
      flutter(
        ["test/backend_local/collection_publication_ui_stand_test.dart"],
        ["RECHARGE_TEST_COLLECTION_PUBLICATION=true"],
      ),
    );
    step("base and Collection invariants still hold", () => {
      run(seedCli, ["verify"]);
      run(seedCli, ["collection", "verify"]);
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
    "D3.4 Collection publication gate passed (local Emulator and PC host only; Catalog-owned membership over the Content owner source, canonical taxonomy pairs, fake scanner/processor on the stand, test-only staff registry; Catalog excludes Collection (OD-04, no Collection model); no device, LAN or cloud claim)\n",
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
