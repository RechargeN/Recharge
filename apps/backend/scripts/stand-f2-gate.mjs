import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "..", "..", "..");
const functionsDir = path.join(here, "..", "functions");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");
const moderateCli = path.join(here, "stand-moderate.mjs");

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

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
/** Set when a client exits early: every rendezvous wait stops at once. */
const abort = { reason: null };

/** Waits for a client's rendezvous point; the deadline is the only wait. */
async function point(directory, who, name, seconds = 600) {
  const file = path.join(directory, `${who}.${name}.json`);
  const deadline = Date.now() + seconds * 1000;
  while (!fs.existsSync(file)) {
    if (abort.reason !== null) throw new Error(abort.reason);
    if (Date.now() > deadline)
      throw new Error(`client ${who} never reached ${name}`);
    await pause(250);
  }
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function arrive(directory, name, payload) {
  const file = path.join(directory, `gate.${name}.json`);
  fs.writeFileSync(`${file}.tmp`, JSON.stringify(payload));
  fs.renameSync(`${file}.tmp`, file);
}

/**
 * One independent client: its own `flutter test` process, stand user, Session,
 * installation id and journals (each run creates its own temp directories).
 */
function client(role, rendezvous, pageId, logDirectory) {
  const args = [
    "test",
    "--no-pub",
    "--dart-define=RECHARGE_TEST_BOOKING_ENTRY=true",
    "--dart-define=RECHARGE_TEST_NOTIFICATIONS_INBOX=true",
    "test/backend_local/f2_client_test.dart",
  ];
  const env = {
    ...process.env,
    RECHARGE_B1_STAND: "1",
    RECHARGE_REPO_ROOT: repoRoot,
    RECHARGE_NODE: process.execPath,
    RECHARGE_E2_ROLE: role,
    RECHARGE_E2_RENDEZVOUS: rendezvous,
    RECHARGE_E2_PAGE_ID: pageId,
  };
  const cwd = path.join(repoRoot, "apps", "mobile");
  const log = fs.createWriteStream(
    path.join(logDirectory, `client-${role}.log`),
  );
  const child =
    process.platform === "win32"
      ? spawn("cmd.exe", ["/c", "flutter", ...args], { cwd, env })
      : spawn("flutter", args, { cwd, env });
  child.stdout.pipe(log);
  child.stderr.pipe(log);
  return new Promise((resolve) => child.on("close", (code) => resolve(code)));
}

/**
 * F2 gate: two independent local clients on one shared stand (no reset between
 * them). The organizer (A, seeded Creator) creates a one-time Event and a
 * two-date Event through Create; staff approves at the rendezvous; the
 * participant (B, seeded viewer) books two seats of the first and one date of
 * the second. A moves the first Event twice through the real Create
 * coordinator (same occurrence and Booking ids) and removes the booked date of
 * the second; B sees each change by Refresh and in the inbox, reconfirms, has
 * a stale answer refused and sees the cancellation reason. The gate then
 * checks reconciliation and the stored allocation/usage invariants.
 * Evidence of two independent test clients on this PC, not of two phones.
 */
export async function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-f2-gate.mjs --yes",
    );
  }
  const step = async (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "recharge-f2-gate-"));
  const rendezvous = path.join(work, "rendezvous");
  fs.mkdirSync(rendezvous);
  let failure;
  try {
    await step("build the Functions the stand loads", () => {
      const result = exec(
        process.execPath,
        [path.join("node_modules", "typescript", "bin", "tsc"), "-p", "."],
        { cwd: functionsDir },
      );
      if (result.status !== 0) throw new Error(`tsc failed:\n${result.output}`);
    });
    await step("verified stop", () => run(standCli, ["stop"]));
    await step("reset", () => run(standCli, ["reset", "--yes"]));
    await step("start", () => run(standCli, ["start"]));
    await step("seed", () => run(seedCli, ["seed"]));
    await step("verify seed invariants", () => run(seedCli, ["verify"]));
    const page = (
      await step("organizer Page (seeded Creator)", () =>
        lastJson(run(seedCli, ["manifest"])),
      )
    ).contentEvent.pageId;
    await step("switch the default-off F1 and F2 flags on", () => {
      run(seedCli, ["notifications", "flags", "on", "all"]);
      run(seedCli, ["booking-actions", "flags", "on", "reconfirm"]);
    });

    const clients = await step("start both clients in parallel", () => [
      client("A", rendezvous, page, work),
      client("B", rendezvous, page, work),
    ]);
    // A client that fails, or exits before the last approval, stops the waits
    // at once instead of letting the gate sit out its rendezvous deadline.
    let approvalsDone = false;
    for (const [index, role] of ["A", "B"].entries())
      void clients[index].then((code) => {
        if ((code !== 0 || !approvalsDone) && abort.reason === null)
          abort.reason = `client ${role} exited (${code}) during the staff approvals; see ${path.join(work, `client-${role}.log`)}`;
      });
    const approve = (name, gatePoint) =>
      step(`staff approves at ${name}`, async () => {
        const submitted = await point(rendezvous, "A", name, 900);
        for (const submissionId of submitted.submissionIds) {
          const answer = lastJson(
            run(moderateCli, [
              "approve",
              submissionId,
              "--reason",
              `f2 gate: organizer ${name} is fine`,
            ]),
          );
          assert.equal(answer.data.receipt.outcome, "applied");
        }
        arrive(rendezvous, gatePoint, { name });
      });
    await approve("submitted", "approved");
    await approve("resubmitted-1", "approved-1");
    await approve("resubmitted-2", "approved-2");
    await approve("resubmitted-3", "approved-3");
    approvalsDone = true;
    const codes = await step("both clients finish", () => Promise.all(clients));
    for (const [index, role] of ["A", "B"].entries()) {
      const log = fs.readFileSync(
        path.join(work, `client-${role}.log`),
        "utf8",
      );
      process.stdout.write(
        log
          .split("\n")
          .filter((line) =>
            /All tests passed|Some tests failed|\[E\]|Expected|Actual/.test(
              line,
            ),
          )
          .map((line) => `  client ${role}: ${line.trim()}\n`)
          .join(""),
      );
      assert.equal(
        codes[index],
        0,
        `client ${role} failed; see ${path.join(work, `client-${role}.log`)}`,
      );
    }
    await step("handoff reconciliation is complete", () => {
      const report = lastJson(run(seedCli, ["handoff", "reconcile"]));
      assert.equal(report.complete, true, JSON.stringify(report.findings));
    });
    await step("Notifications reconciliation is complete", async () => {
      let report;
      for (let attempt = 0; attempt < 30; attempt += 1) {
        report = lastJson(run(seedCli, ["notifications", "reconcile"]));
        if (report.complete === true) return;
        await pause(2_000);
      }
      throw new Error(
        `Notifications never reconciled: ${JSON.stringify(report)}`,
      );
    });
    await step("allocation, usage, outbox and inbox invariants hold", () => {
      const report = lastJson(run(seedCli, ["booking-actions", "invariants"]));
      assert.equal(report.ok, true, JSON.stringify(report.problems));
    });
    await step("no Booking delivery is dead-lettered", () => {
      const report = lastJson(run(seedCli, ["handoff", "reconcile"]));
      assert.equal(
        report.findings.some(
          (finding) => finding.code === "delivery_dead_letter",
        ),
        false,
      );
    });
  } catch (error) {
    failure = error;
  } finally {
    try {
      await step("verified stop", () => run(standCli, ["stop"]));
    } catch (error) {
      failure ??= error;
    }
  }
  if (failure) throw failure;
  fs.rmSync(work, { recursive: true, force: true });
  process.stdout.write(
    "F2 gate passed (local Emulator and PC host only; two independent flutter test clients; reschedule through Create with stable occurrence and Booking ids, reconfirmation, stale answer refused, removed date cancelled; local 2A model; D05/D07 notice and deadline-window rules stay open; no device, LAN or cloud claim)\n",
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
