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
 * D3.3 Rental / Equipment publication gate
 * (RENTAL_D3_3_PUBLICATION_AMENDMENT.md §6). The stand's Rental is published
 * through Content only (empty draft, cover and gallery through Media, the body
 * confirmed and attested by the publishing user, staff approval, owner
 * publish) under its own flag, which only `stand-seed.mjs rental seed`
 * enables, with the TEST-ONLY Emulator Rental policy. A Rental seed
 * interrupted after the first gallery photo and resumed must reach exactly the
 * state of a clean seed, and a repeated seed must reuse it. `rental verify`
 * checks the pointer, the media, the Catalog exclusion and the Booking
 * handoff. Then the mobile Rental path runs on this PC against the stand: the
 * controller test and the UI test with the default-off define. Real Media
 * delivery with the D1 tools is not repeated (Media and D2 do not depend on
 * the type). Local Emulator only; it resets the stand data first, so it needs
 * --yes.
 */
export async function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-d3-3-gate.mjs --yes",
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
    assert.match(run(seedCli, ["seed"]), /^seeded /m);
  };
  let failure;
  try {
    step("fresh stand with the base seed", fresh);
    step("clean Rental seed (through Content)", () =>
      assert.match(run(seedCli, ["rental", "seed"]), /^seeded rental=/m),
    );
    step("verify Rental invariants", () => run(seedCli, ["rental", "verify"]));
    const clean = step("digest of the clean seed", digest);
    step("fresh stand with the base seed", fresh);
    step(
      "Rental seed interrupted after the first gallery photo (test hook)",
      () => {
        const interrupted = exec(seedCli, ["rental", "seed"], {
          STAND_SEED_INTERRUPT_AFTER: "gallery-1",
        });
        assert.notEqual(interrupted.status, 0);
        assert.match(
          interrupted.output,
          /interrupted: stand rental seed interrupted after gallery-1/,
        );
      },
    );
    step("Rental seed resumes from its idempotent commands", () =>
      assert.match(run(seedCli, ["rental", "seed"]), /^seeded rental=/m),
    );
    step("verify Rental invariants", () => run(seedCli, ["rental", "verify"]));
    const resumed = step("digest of the resumed seed", digest);
    assert.equal(
      resumed,
      clean,
      "a resumed Rental seed must equal a clean seed",
    );
    step("a repeated Rental seed reuses the result", () =>
      assert.match(run(seedCli, ["rental", "seed"]), /^reused rental=/m),
    );
    assert.equal(step("digest after the repeat", digest), clean);

    step("flutter test Rental publication (controller, real stand)", () =>
      flutter(["test/backend_local/rental_publication_stand_test.dart"]),
    );
    step("flutter test Rental publication (UI, define on)", () =>
      flutter(
        ["test/backend_local/rental_publication_ui_stand_test.dart"],
        ["RECHARGE_TEST_RENTAL_PUBLICATION=true"],
      ),
    );
    step("base and Rental invariants still hold", () => {
      run(seedCli, ["verify"]);
      run(seedCli, ["rental", "verify"]);
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
    "D3.3 Rental publication gate passed (local Emulator and PC host only; BCK-20 taxonomy revision, TEST-ONLY Rental policy (not accepted), Rental activation closed, fake scanner/processor on the stand, test-only staff registry; Catalog excludes Rental (OD-04); no device, LAN or cloud claim)\n",
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
