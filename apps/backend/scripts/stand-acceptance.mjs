import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
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

function digest() {
  const match = /^digest ([0-9a-f]{64})$/m.exec(run(seedCli, ["digest"]));
  if (!match) throw new Error("digest output missing");
  return match[1];
}

/**
 * Local acceptance gate for A2. It resets the stand data, so it needs an
 * explicit --yes and a stopped stand; it never touches anything else.
 */
export function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-acceptance.mjs --yes",
    );
  }
  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  step("verified stop", () => run(standCli, ["stop"]));
  step("reset", () => run(standCli, ["reset", "--yes"]));
  step("start", () => run(standCli, ["start"]));
  step("seed", () => run(seedCli, ["seed"]));
  step("verify invariants", () => run(seedCli, ["verify"]));
  const first = step("digest of the first seed", digest);

  step("stop (export)", () => run(standCli, ["stop"]));
  step("start (import)", () => run(standCli, ["start"]));
  step("verify invariants after import", () => run(seedCli, ["verify"]));
  const imported = step("digest after import", digest);
  if (imported !== first) throw new Error("export/import changed the state");

  step("stop", () => run(standCli, ["stop"]));
  step("reset", () => run(standCli, ["reset", "--yes"]));
  step("start", () => run(standCli, ["start"]));
  step("seed again", () => run(seedCli, ["seed"]));
  step("verify invariants", () => run(seedCli, ["verify"]));
  const second = step("digest of the second seed", digest);
  if (second !== first)
    throw new Error("seed, reset, seed is not deterministic");
  step("stop", () => run(standCli, ["stop"]));
  process.stdout.write(
    `A2 acceptance passed: normalized state ${first}\n(local Emulator only; no cloud, device or LAN claim)\n`,
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
