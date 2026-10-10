import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { verifyRunning } from "./emulator-stand.mjs";

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
  "stand_main.js",
);
const commands = new Set([
  "seed",
  "verify",
  "digest",
  "session-fixture",
  "bookings",
  "content-draft",
  "media-readiness",
  "moderation-fixture",
  "manifest",
  "catalog",
  "handoff",
  "booking-deliver",
  "creator-fixture",
  "notifications",
  "booking-actions",
  // D2: run the media availability consumers and sweeps once (no retention policy).
  "media-reconcile",
]);

export function standEnvironment(base) {
  const env = { ...base };
  // Never forward cloud selection to the seed process; the guard in the child
  // refuses a forbidden name, so a polluted shell fails closed instead of leaking.
  env.GCLOUD_PROJECT = "demo-recharge";
  env.GOOGLE_CLOUD_PROJECT = "demo-recharge";
  env.FUNCTIONS_EMULATOR = "true";
  env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
  env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
  env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:9199";
  return env;
}

export async function main(args) {
  if (!commands.has(args[0])) {
    throw new Error(
      "Usage: stand-seed.mjs seed | verify | digest [--out <new file>] | session-fixture ...",
    );
  }
  if (!fs.existsSync(entry)) {
    throw new Error(
      "Seed is not built; run `npm run build` in apps/backend/functions.",
    );
  }
  // Project identity, process identity and listener ownership are verified, not just open ports.
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
