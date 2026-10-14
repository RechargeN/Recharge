import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");

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

/**
 * B1-local gate. It starts a fresh seeded stand, runs the mobile Session
 * lifecycle tests against it on this PC (loopback only, no device, no LAN, no
 * cloud) and always stops the stand. It resets the stand data first, so it
 * needs an explicit --yes.
 */
export function main(args) {
  if (args.length === 3 && args[0] === "--yes" && args[1] === "--android") {
    return import("./stand-b1-platform-gate.mjs").then(({ platformGate }) =>
      platformGate(args[2]),
    );
  }
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-mobile-gate.mjs --yes",
    );
  }
  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  let failure;
  try {
    step("verified stop", () => run(standCli, ["stop"]));
    step("reset", () => run(standCli, ["reset", "--yes"]));
    step("start", () => run(standCli, ["start"]));
    step("seed", () => run(seedCli, ["seed"]));
    step("verify seed invariants", () => run(seedCli, ["verify"]));
    // Only the B1 suite: every slice gate runs its own files on its own fresh
    // seed. Running the whole directory would also run the B2/C1/C3 suites on
    // one seed, exhaust the per-Account Session budget and need their defines.
    step("flutter test B1 Session lifecycle", () => {
      const flutterArgs = [
        "test",
        "--no-pub",
        "test/backend_local/booking_session_lifecycle_stand_test.dart",
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
    "B1-local gate passed (local Emulator and PC host only; no physical device, LAN, cloud or Auth plugin claim)\n",
  );
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    await main(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
