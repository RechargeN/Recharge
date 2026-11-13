import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../../..");
function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    stdio: "inherit",
    shell: false,
    windowsHide: true,
    timeout: 240000,
    ...options,
  });
  if (result.error || result.status !== 0)
    throw new Error(
      `${path.basename(command)} ${args.join(" ")} failed: ${result.error?.message ?? result.status}`,
    );
}
function cli(file, args, env) {
  run(process.execPath, [path.join(here, file), ...args], { env });
}
// Local-only gate; the existing stand CLI checks project, paths and process ownership.
// Build is completed before any live Emulator process is started.
export function main(args) {
  const linkedPlace =
    args.length === 2 && args[0] === "--yes" && args[1] === "--linked-place";
  if (!linkedPlace && (args.length !== 1 || args[0] !== "--yes"))
    throw new Error(
      "Usage: stand-d3-8-gate.mjs --yes [--linked-place] (resets only the verified demo-recharge stand data)",
    );
  const env = {
    ...process.env,
    RECHARGE_TEST_ACTIVITY_CATALOG: "true",
    RECHARGE_TEST_ACTIVITY_LINKED_PLACE: linkedPlace ? "true" : "false",
    RECHARGE_B1_STAND: "1",
    RECHARGE_REPO_ROOT: root,
    RECHARGE_NODE: process.execPath,
  };
  let failure;
  try {
    cli("emulator-stand.mjs", ["stop"], env);
    run(
      process.execPath,
      ["node_modules/typescript/bin/tsc", "--pretty", "false"],
      { cwd: path.join(root, "apps/backend/functions"), env },
    );
    cli("emulator-stand.mjs", ["reset", "--yes"], env);
    cli("emulator-stand.mjs", ["start"], env);
    cli("emulator-stand.mjs", ["status"], env);
    cli("stand-seed.mjs", ["seed"], env);
    if (linkedPlace) cli("stand-seed.mjs", ["place", "seed"], env);
    cli("stand-seed.mjs", ["activity", "seed"], env);
    const args = [
      "test",
      "--no-pub",
      "--dart-define=RECHARGE_TEST_DISCOVER_CATALOG=true",
      "--dart-define=RECHARGE_TEST_ACTIVITY_CATALOG=true",
      ...(linkedPlace
        ? [
            "--dart-define=RECHARGE_TEST_ACTIVITY_LINKED_PLACE=true",
            "test/backend_local/activity_linked_place_stand_test.dart",
          ]
        : ["test/backend_local/activity_catalog_stand_test.dart"]),
    ];
    run(
      process.platform === "win32" ? "cmd.exe" : "flutter",
      process.platform === "win32" ? ["/c", "flutter", ...args] : args,
      { cwd: path.join(root, "apps/mobile"), env },
    );
    cli("stand-seed.mjs", ["verify"], env);
  } catch (error) {
    failure = error;
  } finally {
    try {
      cli("emulator-stand.mjs", ["stop"], env);
    } catch (error) {
      failure ??= error;
    }
  }
  if (failure) throw failure;
  process.stdout.write(
    linkedPlace
      ? "D3.9 linked Place gate passed: real Catalog picker, Activity publication/Activate, Place restriction/restore; verified stop; no device or production claim.\n"
      : "D3.8 Activity Catalog gate passed: real local Feed/Search/Map/Details and existing renderer; no device or production claim.\n",
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
