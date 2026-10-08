import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { verifyRunning } from "./emulator-stand.mjs";
import { standEnvironment } from "./stand-seed.mjs";

// C2 staff script for the local demo-recharge stand. It holds no authority: the
// moderation service evaluates the Session and the stand staff registry on every
// call, and it changes Content only through Content's own verified path.
const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const entry = path.join(
  backend,
  "functions",
  "lib",
  "test",
  "stand",
  "stand_moderate_main.js",
);
const commands = new Set([
  "queue",
  "approve",
  "reject",
  "restrict",
  "withdraw",
  "restore",
  "receipt",
]);

export async function main(args) {
  if (!commands.has(args[0])) {
    throw new Error(
      "Usage: stand-moderate.mjs queue | approve|reject <submissionId> --reason <text> | restrict|withdraw <contentId> --reason <text> | restore <contentId> --decision <decisionId> --reason <text> | receipt <decisionId>  [--as <stand user>] [--key <idempotency key>]",
    );
  }
  if (!fs.existsSync(entry)) {
    throw new Error(
      "Moderation script is not built; run `npm run build` in apps/backend/functions.",
    );
  }
  await verifyRunning();
  const result = spawnSync(process.execPath, [entry, ...args], {
    cwd: path.join(backend, "functions"),
    env: standEnvironment(process.env),
    stdio: "inherit",
    shell: false,
  });
  if (result.status !== 0) process.exitCode = result.status ?? 1;
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
