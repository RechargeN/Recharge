import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { StringDecoder } from "node:string_decoder";
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
const seconds = (ms) => `${(ms / 1000).toFixed(1)} s`;
/** Set when a client exits early: every rendezvous wait stops at once. */
const abort = { reason: null };
/** How long one client may take to compile and load its test. */
const loadSeconds = 600;
/** `E2Rendezvous.waitFor`'s default: how long a client waits for its peer. */
const peerWaitSeconds = 300;
/** What client B needs after loading to reach `booked`, the point A awaits. */
const reserveSeconds = 60;

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
 * Follows a client's machine report (`--file-reporter json:`), one JSON event
 * per line, as the file grows. Bytes are decoded as a stream and only complete
 * lines are parsed, so an event split between two reads is never half-seen.
 * Returns "loaded" once the hidden `loading <path>` test (no groups) is done
 * with `success`: by then that `flutter test` process has written everything
 * it shares with the other client under apps/mobile (native assets manifest,
 * unit test assets, the test_cache kernel, the plugin registrant). An error
 * on that test, any other result, or the end of the run before it is
 * "failed"; until then "loading".
 */
function machineReport(file) {
  const decoder = new StringDecoder("utf8");
  const loading = new Set();
  const buffer = Buffer.alloc(64 * 1024);
  let offset = 0;
  let pending = "";
  let state = "loading";
  return () => {
    if (state !== "loading" || !fs.existsSync(file)) return state;
    const fd = fs.openSync(file, "r");
    try {
      let size;
      while ((size = fs.readSync(fd, buffer, 0, buffer.length, offset)) > 0) {
        offset += size;
        pending += decoder.write(buffer.subarray(0, size));
      }
    } finally {
      fs.closeSync(fd);
    }
    const lines = pending.split("\n");
    pending = lines.pop();
    for (const line of lines) {
      if (state !== "loading" || line.trim() === "") continue;
      let event;
      try {
        event = JSON.parse(line);
      } catch {
        throw new Error(`${file} is not a JSON test report: ${line}`);
      }
      if (
        event.type === "testStart" &&
        event.test.groupIDs.length === 0 &&
        event.test.name.startsWith("loading ")
      )
        loading.add(event.test.id);
      else if (event.type === "error" && loading.has(event.testID))
        state = "failed";
      else if (event.type === "testDone" && loading.has(event.testID))
        state = event.result === "success" ? "loaded" : "failed";
      else if (event.type === "done") state = "failed";
    }
    return state;
  };
}

/**
 * Waits until a client's machine report shows its test loaded. `limit()`
 * returns the deadline and its message; it is read on every poll, because
 * client B's limit depends on client A's rendezvous wait.
 */
async function loaded(started, rendezvous, limit) {
  for (;;) {
    const state = started.report();
    if (state === "loaded") {
      started.loadedAt = Date.now();
      started.loadedBy = "machine report";
      return;
    }
    if (state === "failed" || started.code !== undefined)
      throw new Error(
        `client ${started.role} did not load its test (${started.code === undefined ? "load failed" : `exited ${started.code}`}); see ${started.log}`,
      );
    if (abort.reason !== null) throw new Error(abort.reason);
    // Arriving is test code, so a client at a rendezvous point has loaded,
    // even when the reporter has not flushed (or we have not read) that yet.
    const arrived = fs
      .readdirSync(rendezvous)
      .filter((name) => name.startsWith(`${started.role}.`));
    if (arrived.length > 0) {
      started.loadedAt = Math.min(
        ...arrived.map(
          (name) => fs.statSync(path.join(rendezvous, name)).mtimeMs,
        ),
      );
      started.loadedBy = "rendezvous point; machine report not read yet";
      return;
    }
    const [deadline, message] = limit();
    if (Date.now() > deadline) throw new Error(message);
    await pause(250);
  }
}

/**
 * Prints when each client started, loaded its test and exited and when each
 * side reached each rendezvous point (file times), then the first meeting:
 * client A waiting at `waits` until client B reached `meets`.
 */
function timeline(rendezvous, clients, waits, meets) {
  const zero = clients[0].started;
  const at = (time) => `+${seconds(time - zero)}`;
  const rows = [];
  for (const started of clients) {
    rows.push([started.started, `client ${started.role} started`]);
    if (started.loadedAt !== undefined)
      rows.push([started.loadedAt, `client ${started.role} loaded its test`]);
    if (started.endedAt !== undefined)
      rows.push([
        started.endedAt,
        `client ${started.role} exited (${started.code})`,
      ]);
  }
  const reached = new Map();
  for (const name of fs.readdirSync(rendezvous)) {
    if (!name.endsWith(".json")) continue;
    const time = fs.statSync(path.join(rendezvous, name)).mtimeMs;
    const [who, ...point] = name.slice(0, -".json".length).split(".");
    reached.set(`${who}.${point.join(".")}`, time);
    rows.push([
      time,
      `${who === "gate" ? "gate" : `client ${who}`} at ${point.join(".")}`,
    ]);
  }
  rows.sort((left, right) => left[0] - right[0]);
  for (const [time, what] of rows)
    process.stdout.write(`  ${at(time).padStart(9)}  ${what}\n`);
  const waited = reached.get(`A.${waits}`);
  const met = reached.get(`B.${meets}`);
  process.stdout.write(
    waited === undefined || met === undefined
      ? `  meeting: client A at ${waits} and client B at ${meets} never met\n`
      : met < waited
        ? `  meeting: client B reached ${meets} at ${at(met)}, before client A waited at ${waits} (${at(waited)})\n`
        : `  meeting: client A waited at ${waits} from ${at(waited)}, client B reached ${meets} at ${at(met)} (${seconds(met - waited)} of A's ${peerWaitSeconds} s)\n`,
  );
  if (clients.length === 2) {
    const ends = clients
      .map((started) => started.endedAt)
      .filter((time) => time !== undefined);
    process.stdout.write(
      `  overlap: both clients ran from ${at(clients[1].started)} (B started) to ${ends.length === 0 ? "now" : at(Math.min(...ends))} (first exit)\n`,
    );
  }
}

/**
 * One independent client: its own `flutter test` process, stand user, Session,
 * installation id and journals (each run creates its own temp directories).
 * Next to its console log it writes a machine report, which the gate reads
 * to tell when its test has loaded.
 */
function client(role, rendezvous, pageId, logDirectory) {
  const log = path.join(logDirectory, `client-${role}.log`);
  const events = path.join(logDirectory, `client-${role}.events.jsonl`);
  const args = [
    "test",
    "--no-pub",
    `--file-reporter=json:${events}`,
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
  const output = fs.createWriteStream(log);
  const child =
    process.platform === "win32"
      ? spawn("cmd.exe", ["/c", "flutter", ...args], { cwd, env })
      : spawn("flutter", args, { cwd, env });
  child.stdout.pipe(output);
  child.stderr.pipe(output);
  const started = {
    role,
    log,
    events,
    started: Date.now(),
    report: machineReport(events),
  };
  started.exited = new Promise((resolve) =>
    child.on("close", (code) => {
      started.code = code;
      started.endedAt = Date.now();
      resolve(code);
    }),
  );
  return started;
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
 * Client B starts once client A's test has loaded: two `flutter test`
 * processes preparing at once race on the build files they share in
 * apps/mobile (Windows: PathExistsException on NativeAssetsManifest.json).
 * The tests themselves run side by side.
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
  const clients = [];
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

    // A client that fails, or exits before the last approval, stops the waits
    // at once instead of letting the gate sit out its rendezvous deadline.
    let approvalsDone = false;
    const start = (role) => {
      const started = client(role, rendezvous, page, work);
      clients.push(started);
      void started.exited.then((code) => {
        if ((code !== 0 || !approvalsDone) && abort.reason === null)
          abort.reason = `client ${role} exited (${code}) during the staff approvals; see ${started.log}`;
      });
      return started;
    };
    const clientA = await step(
      "start client A, wait until its test loads",
      async () => {
        const started = start("A");
        await loaded(started, rendezvous, () => [
          started.started + loadSeconds * 1000,
          `client A did not load its test within ${loadSeconds} s; see ${started.log}`,
        ]);
        process.stdout.write(
          `  client A loaded its test after ${seconds(started.loadedAt - started.started)} (${started.loadedBy})\n`,
        );
        return started;
      },
    );
    const clientB = await step("start client B", () => {
      const started = start("B");
      process.stdout.write(
        `  client B started ${seconds(started.started - clientA.loadedAt)} after client A loaded\n`,
      );
      return started;
    });
    // B loads while the gate serves A's approvals. A waits for B from
    // `published` on, so B must load while that wait still leaves it time to
    // book; a load that fails or misses this limit stops every wait at once.
    const waiting = path.join(rendezvous, "A.published.json");
    const bLoaded = loaded(clientB, rendezvous, () => {
      const cap = clientB.started + loadSeconds * 1000;
      if (!fs.existsSync(waiting))
        return [
          cap,
          `client B did not load its test within ${loadSeconds} s; see ${clientB.log}`,
        ];
      const end =
        fs.statSync(waiting).mtimeMs +
        (peerWaitSeconds - reserveSeconds) * 1000;
      return [
        Math.min(cap, end),
        `client B did not load its test while client A's ${peerWaitSeconds} s wait at published still had ${reserveSeconds} s left for B to book; see ${clientB.log}`,
      ];
    }).then(() =>
      process.stdout.write(
        `  client B loaded its test after ${seconds(clientB.loadedAt - clientB.started)} (${clientB.loadedBy}); ${
          fs.existsSync(waiting)
            ? `client A has waited at published for ${seconds(clientB.loadedAt - fs.statSync(waiting).mtimeMs)} of ${peerWaitSeconds} s`
            : "client A does not wait for client B yet"
        }\n`,
      ),
    );
    bLoaded.catch((error) => {
      abort.reason ??= error.message;
    });
    const exits = clients.map((started) => started.exited);
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
    await bLoaded;
    approvalsDone = true;
    const codes = await step("both clients finish", () => Promise.all(exits));
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
      if (clients.length > 0)
        await step("client timeline (after client A started)", () =>
          timeline(rendezvous, clients, "published", "booked"),
        );
    } catch (error) {
      failure ??= error;
    }
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
