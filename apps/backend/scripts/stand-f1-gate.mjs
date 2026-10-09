import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");
const functionsDir = path.join(here, "..", "functions");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");

function exec(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    shell: false,
    env: process.env,
    ...options,
  });
  return {
    status: result.status,
    output: (result.stdout ?? "") + (result.stderr ?? ""),
  };
}

function run(script, args) {
  const result = exec(process.execPath, [script, ...args]);
  if (result.status !== 0) {
    throw new Error(
      `${path.basename(script)} ${args.join(" ")} failed:\n${result.output}`,
    );
  }
  return result.output;
}

function lastJson(output) {
  const line = output
    .trim()
    .split("\n")
    .filter((value) => value.trim().startsWith("{"))
    .pop();
  if (!line) throw new Error(`no JSON in output:\n${output}`);
  return JSON.parse(line);
}

const notifications = (...args) =>
  lastJson(run(seedCli, ["notifications", ...args]));

/**
 * Reconciles until it reports complete: a trigger may still hold a claim on
 * an effect committed a moment ago. Bounded by attempts on a real condition.
 */
async function reconciledComplete() {
  let report;
  for (let attempt = 0; attempt < 30; attempt += 1) {
    report = notifications("reconcile");
    if (report.complete === true) return report;
    await new Promise((resolve) => setTimeout(resolve, 2_000));
  }
  throw new Error(`reconciliation never completed: ${JSON.stringify(report)}`);
}

/**
 * F1 gate: the Notifications inbox without push on a freshly reset and
 * seeded stand. The seed keeps every F1 flag off (B-gates are unchanged);
 * this gate switches them on, then one independent flutter test client books
 * the seeded Event, reads its server inbox through the real adapter and
 * Session, and cancels while the stand makes Notifications state unreadable.
 * The gate then proves reconciliation completes with one record per effect,
 * no dead letter, and that an erasure DSR over Booking and Notifications
 * completes and leaves the subject no inbox record.
 */
export async function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-f1-gate.mjs --yes",
    );
  }
  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "recharge-f1-gate-"));
  let failure;
  try {
    step("build the Functions the stand loads", () => {
      const result = exec(
        process.execPath,
        [path.join("node_modules", "typescript", "bin", "tsc"), "-p", "."],
        { cwd: functionsDir },
      );
      if (result.status !== 0) throw new Error(`tsc failed:\n${result.output}`);
    });
    step("verified stop", () => run(standCli, ["stop"]));
    step("reset", () => run(standCli, ["reset", "--yes"]));
    step("start", () => run(standCli, ["start"]));
    step("seed", () => run(seedCli, ["seed"]));
    step("verify seed invariants", () => run(seedCli, ["verify"]));
    step("seeded Booking outbox stays v1 and is never consumed", () => {
      const before = notifications("status");
      assert.equal(before.inboxItems, 0);
      assert.equal(
        Object.values(before.receipts).reduce((sum, value) => sum + value, 0),
        0,
      );
    });
    step("switch the default-off F1 flags on", () =>
      notifications("flags", "on", "all"),
    );
    step("flutter test F1 client", () => {
      const log = path.join(work, "client.log");
      const args = [
        "test",
        "--no-pub",
        "--dart-define=RECHARGE_TEST_BOOKING_ENTRY=true",
        "--dart-define=RECHARGE_TEST_NOTIFICATIONS_INBOX=true",
        "test/backend_local/notifications_inbox_client_test.dart",
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
          ? exec("cmd.exe", ["/c", "flutter", ...args], { cwd, env })
          : exec("flutter", args, { cwd, env });
      fs.writeFileSync(log, result.output);
      process.stdout.write(
        result.output
          .split("\n")
          .filter((line) =>
            /All tests passed|Some tests failed|\[E\]|Expected|Actual|skip/.test(
              line,
            ),
          )
          .map((line) => `  client: ${line.trim()}\n`)
          .join(""),
      );
      assert.equal(result.status, 0, `F1 client failed; see ${log}`);
      assert.match(result.output, /All tests passed/u);
      assert.doesNotMatch(
        result.output,
        /\bskip/iu,
        "the client must not skip",
      );
    });
    await step("reconciliation is complete with no dead letter", async () => {
      await reconciledComplete();
      const status = notifications("status");
      assert.equal(status.receipts.dead_lettered, 0);
      assert.equal(status.receipts.claimed, 0);
      assert.equal(status.receipts.retry_scheduled, 0);
    });
    step("the client user has exactly its two records", () => {
      const inbox = notifications("inbox", "staff");
      assert.deepEqual(inbox.items.map((item) => item.templateKey).sort(), [
        "booking.cancelled.byUser",
        "booking.confirmed",
      ]);
    });
    await step(
      "an erasure DSR over Booking and Notifications completes, nothing remains",
      async () => {
        const result = notifications(
          "privacy-erase",
          "viewer",
          "7a1f2b3c-4d5e-4f60-8a71-b2c3d4e5f607",
        );
        assert.equal(result.notifications, "succeeded");
        assert.equal(result.booking, "succeeded");
        assert.equal(result.requestStatus, "completed");
        await reconciledComplete();
        const inbox = notifications("inbox", "viewer");
        assert.deepEqual(inbox.items, []);
      },
    );
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
  fs.rmSync(work, { recursive: true, force: true });
  process.stdout.write(
    "F1 gate passed (local Emulator and PC host only; one flutter test client; Booking v2 obligations, inbox, preferences, templates, attempts, reconciliation, suppression and privacy; no FCM/APNs, email or SMS; no device, LAN or cloud claim)\n",
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
