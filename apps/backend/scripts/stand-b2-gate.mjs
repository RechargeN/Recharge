import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");
// A smaller B2_GATE_RUNS is for debugging only and never counts as the gate.
const runs = Number(process.env.B2_GATE_RUNS ?? 3);
// Five scenarios each create exactly one booking and cancel it; the seed holds
// one cancelled booking for the staff user. Any duplicate raises the total.
const expectedTotal = 6;

function run(script, args) {
  const result = spawnSync(process.execPath, [script, ...args], {
    encoding: "utf8",
    shell: false,
    env: process.env,
  });
  const output = (result.stdout ?? "") + (result.stderr ?? "");
  if (result.status !== 0) {
    throw new Error(
      `${path.basename(script)} ${args.join(" ")} failed:\n${output}`,
    );
  }
  return output;
}

function counts() {
  const line = run(seedCli, ["bookings", "staff"])
    .trim()
    .split("\n")
    .reverse()
    .find((value) => value.startsWith("{"));
  return JSON.parse(line);
}

/**
 * B2-local gate: the integration UI test passes three times in a row, each
 * time on a freshly reset and seeded stand, and the backend itself confirms
 * that no run left a duplicate or an active booking. Loopback PC host only.
 * It resets the stand data, so it needs an explicit --yes.
 */
export function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-b2-gate.mjs --yes",
    );
  }
  let failure;
  try {
    for (let index = 1; index <= runs; index += 1) {
      const step = (name, action) => {
        process.stdout.write(`- run ${index}/${runs}: ${name}\n`);
        return action();
      };
      step("verified stop", () => run(standCli, ["stop"]));
      step("reset", () => run(standCli, ["reset", "--yes"]));
      step("start", () => run(standCli, ["start"]));
      step("seed", () => run(seedCli, ["seed"]));
      step("verify seed invariants", () => run(seedCli, ["verify"]));
      step("flutter test event booking UI", () => {
        const flutterArgs = [
          "test",
          "--no-pub",
          "--dart-define=RECHARGE_TEST_BOOKING_ENTRY=true",
          "test/backend_local/event_booking_ui_stand_test.dart",
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
            ? spawnSync("cmd.exe", ["/c", "flutter", ...flutterArgs], {
                cwd,
                env,
                stdio: "inherit",
              })
            : spawnSync("flutter", flutterArgs, { cwd, env, stdio: "inherit" });
        if (result.status !== 0) throw new Error("flutter test failed");
      });
      const final = step("backend booking counts", counts);
      if (final.active !== 0 || final.total !== expectedTotal) {
        throw new Error(
          `unexpected bookings after run ${index}: ${JSON.stringify(final)} (expected active 0, total ${expectedTotal})`,
        );
      }
    }
  } catch (error) {
    failure = error;
  } finally {
    try {
      run(standCli, ["stop"]);
    } catch (error) {
      failure ??= error;
    }
  }
  if (failure) throw failure;
  process.stdout.write(
    `B2-local ${runs === 3 ? "gate" : "DEBUG run (not the gate)"} passed ${runs}/3 (local Emulator and PC host only; no physical device, LAN, cloud or plugin claim)\n`,
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
