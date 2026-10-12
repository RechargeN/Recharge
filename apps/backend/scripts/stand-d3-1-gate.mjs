import assert from "node:assert/strict";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { start, stop, toolsRoot } from "./media-tools.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");
const functionsDir = path.join(here, "..", "functions");
const firebaseCli = path.join(
  functionsDir,
  "node_modules",
  "firebase-tools",
  "lib",
  "bin",
  "firebase.js",
);
const toolsInstance = "d3-1-gate";
/** P15: real Place photo delivery; every one must pass, none may be skipped. */
const deliveryFlow = "lib/test/emulator/content_place_media_delivery.test.js";
const deliveryFlowTests = 4;

/** node:test summary counters from TAP output. */
function counts(output) {
  const value = (name) =>
    Number(new RegExp(`^# ${name} (\\d+)$`, "mu").exec(output)?.[1] ?? NaN);
  return {
    pass: value("pass"),
    fail: value("fail"),
    skipped: value("skipped"),
  };
}

/**
 * P15 with the D1 local tools (L1 test mode): real variant bytes of a Place
 * photo before a restriction, refused after it and after its lift without the
 * publisher's activation, real bytes again after the activation. Runs on its
 * own Emulator suite (auth, firestore, storage) while the stand is stopped.
 */
async function realDelivery(contentType = "place") {
  const instance =
    contentType === "activity" ? "d10-activity-gate" : toolsInstance;
  let running = false;
  try {
    await start({ instance, standSignaturesOnly: true });
    running = true;
    const result = spawnSync(
      process.execPath,
      [
        firebaseCli,
        "emulators:exec",
        "--project",
        "demo-recharge",
        "--only",
        "auth,firestore,storage",
        `cd functions && "${process.execPath}" ${deliveryFlow}`,
      ],
      {
        cwd: path.join(here, ".."),
        encoding: "utf8",
        shell: false,
        maxBuffer: 64 * 1024 * 1024,
        env: {
          ...process.env,
          CI: "true",
          RECHARGE_MEDIA_DELIVERY_CONTENT_TYPE: contentType,
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
    const output = `${result.stdout ?? ""}${result.stderr ?? ""}`;
    const tally = counts(output);
    if (
      result.status !== 0 ||
      tally.fail !== 0 ||
      tally.skipped !== 0 ||
      tally.pass !== deliveryFlowTests
    ) {
      process.stdout.write(output);
      throw new Error(`${contentType} delivery flow: ${JSON.stringify(tally)}`);
    }
    process.stdout.write(`  ${tally.pass} passed\n`);
  } finally {
    if (running) await stop({ instance });
  }
}

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
 * D3.1 Place publication gate (PLACE_D3_1_PUBLICATION_AMENDMENT.md §7). The
 * stand's Place is published through Content only (empty draft, cover and
 * gallery through Media, the body with the server's author, staff approval,
 * owner publish) under its own flag, which only `stand-seed.mjs place seed`
 * enables. A Place seed interrupted after the first gallery photo and resumed
 * must reach exactly the state of a clean seed, and a repeated seed must reuse
 * it. `place verify` checks the pointer, the media, the Catalog exclusion and
 * the Booking handoff. Then the mobile Place path runs on this PC against the
 * stand: the controller test and the UI test with the default-off define.
 * Local Emulator only; it resets the stand data first, so it needs --yes.
 */
export async function main(args) {
  const activityOnly =
    args.length === 2 &&
    args[0] === "--yes" &&
    args[1] === "--activity-delivery-only";
  if (!activityOnly && (args.length !== 1 || args[0] !== "--yes")) {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-d3-1-gate.mjs --yes [--activity-delivery-only]",
    );
  }
  if (activityOnly) {
    run(standCli, ["stop"], {
      LOCALAPPDATA:
        process.env.RECHARGE_D10_STAND_LOCALAPPDATA ?? process.env.LOCALAPPDATA,
    });
    const built = spawnSync(
      process.execPath,
      [
        path.join(functionsDir, "node_modules/typescript/bin/tsc"),
        "--pretty",
        "false",
      ],
      { cwd: functionsDir, stdio: "inherit", shell: false },
    );
    if (built.error || built.status !== 0)
      throw new Error(
        "Activity delivery build failed before live tools/Emulator start",
      );
    await realDelivery("activity");
    process.stdout.write(
      "D10 Activity real-photo delivery: 4/4; L1 Windows-local; tools stopped; no F2a/device/production claim.\n",
    );
    return;
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
    step("stop the stand (its ports are needed)", () =>
      run(standCli, ["stop"]),
    );
    await step(
      "Place photo delivery with the real local tools (L1): bytes, refusal, lift, activation",
      realDelivery,
    );
    step("fresh stand with the base seed", fresh);
    step("clean Place seed (through Content)", () =>
      assert.match(run(seedCli, ["place", "seed"]), /^seeded place=/m),
    );
    step("verify Place invariants", () => run(seedCli, ["place", "verify"]));
    const clean = step("digest of the clean seed", digest);
    step("fresh stand with the base seed", fresh);
    step(
      "Place seed interrupted after the first gallery photo (test hook)",
      () => {
        const interrupted = exec(seedCli, ["place", "seed"], {
          STAND_SEED_INTERRUPT_AFTER: "gallery-1",
        });
        assert.notEqual(interrupted.status, 0);
        assert.match(
          interrupted.output,
          /interrupted: stand place seed interrupted after gallery-1/,
        );
      },
    );
    step("Place seed resumes from its idempotent commands", () =>
      assert.match(run(seedCli, ["place", "seed"]), /^seeded place=/m),
    );
    step("verify Place invariants", () => run(seedCli, ["place", "verify"]));
    const resumed = step("digest of the resumed seed", digest);
    assert.equal(
      resumed,
      clean,
      "a resumed Place seed must equal a clean seed",
    );
    step("a repeated Place seed reuses the result", () =>
      assert.match(run(seedCli, ["place", "seed"]), /^reused place=/m),
    );
    assert.equal(step("digest after the repeat", digest), clean);

    step("flutter test Place publication (controller, real stand)", () =>
      flutter(["test/backend_local/place_publication_stand_test.dart"]),
    );
    step("flutter test Place publication (UI, define on)", () =>
      flutter(
        ["test/backend_local/place_publication_ui_stand_test.dart"],
        ["RECHARGE_TEST_PLACE_PUBLICATION=true"],
      ),
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
    "D3.1 Place publication gate passed (local Emulator and PC host only; Emulator Place taxonomy fixture, real Place photo delivery with the D1 tools in L1 test mode, fake scanner/processor on the stand, test-only staff registry; Catalog excludes Place (OD-04); no device, LAN or cloud claim)\n",
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
