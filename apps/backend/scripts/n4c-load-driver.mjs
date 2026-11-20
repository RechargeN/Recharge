import { readFileSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

// N4c load driver (owner decisions 2026-11-16). Staging only, through the
// private load ingress `bookingLoadV1`: synthetic actors on synthetic events.
// Phases: pilot (cost recalculation), sustained, burst, popular pool.
// It measures p50/p95/p99, error ratio, retries, unknown outcomes and oversell,
// and stops itself on the agreed thresholds. It never raises a limit.
export const stagingProject = "recharge-staging-y9y2y";
export const thresholds = Object.freeze({
  maxRequestsPerRun: 20_000,
  errorRatio: 0.2,
  errorWindowMs: 60_000,
  errorWindowMinimum: 50,
  targetP95Ms: 1_500,
  targetSuccessRatio: 0.999,
});
export const phases = Object.freeze({
  pilot: { ratePerSecond: 2.5, seconds: 200 },
  sustained: { ratePerSecond: 5, seconds: 1_800 },
  burst: { ratePerSecond: 20, seconds: 60 },
  pool: { attempts: 50, capacity: 10, roundPauseMs: 10_000 },
});

export function percentile(sorted, p) {
  if (sorted.length === 0) return null;
  return sorted[
    Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)
  ];
}

/** ok: the operation did what a user wanted; refused: a typed domain refusal; failed: nothing usable. */
export function classify(http, result) {
  if (http !== 200 || typeof result !== "object" || result === null)
    return { outcome: "failed", code: `http_${http}` };
  const code = result.error?.code ?? result.kind;
  if (result.kind === "succeeded" || result.kind === "found")
    return { outcome: "ok", code: result.kind };
  if (result.kind === "retryableFailure")
    return {
      outcome: "failed",
      code,
      retryAfterSeconds: result.error?.details?.retryAfterSeconds,
    };
  return { outcome: "refused", code };
}

export class ErrorWindow {
  constructor(limits = thresholds) {
    this.limits = limits;
    this.samples = [];
  }

  add(atMs, failed) {
    this.samples.push([atMs, failed]);
    const cutoff = atMs - this.limits.errorWindowMs;
    while (this.samples.length > 0 && this.samples[0][0] < cutoff)
      this.samples.shift();
  }

  tripped() {
    if (this.samples.length < this.limits.errorWindowMinimum) return false;
    const failed = this.samples.filter(([, bad]) => bad).length;
    return failed / this.samples.length > this.limits.errorRatio;
  }
}

export function summarize(records) {
  const byOp = {};
  for (const r of records) {
    const op = (byOp[r.op] ??= {
      latencies: [],
      outcomes: {},
      codes: {},
      http: {},
      retries: 0,
    });
    op.latencies.push(r.ms);
    op.outcomes[r.outcome] = (op.outcomes[r.outcome] ?? 0) + 1;
    op.codes[r.code] = (op.codes[r.code] ?? 0) + 1;
    op.http[r.http] = (op.http[r.http] ?? 0) + 1;
    op.retries += r.retries;
  }
  const out = {};
  for (const [name, op] of Object.entries(byOp)) {
    const sorted = op.latencies.sort((a, b) => a - b);
    const total = sorted.length;
    out[name] = {
      operations: total,
      p50Ms: percentile(sorted, 50),
      p95Ms: percentile(sorted, 95),
      p99Ms: percentile(sorted, 99),
      maxMs: sorted[total - 1] ?? null,
      outcomes: op.outcomes,
      codes: op.codes,
      http: op.http,
      retries: op.retries,
      failedRatio: total === 0 ? 0 : (op.outcomes.failed ?? 0) / total,
    };
  }
  return out;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

class Driver {
  constructor({ url, token, seed, runLabel }) {
    this.url = url;
    this.token = token;
    this.seed = seed;
    this.runLabel = runLabel;
    this.requests = 0;
    this.sequence = 0;
    this.window = new ErrorWindow();
    this.stop = null;
    this.unknown = { injected: 0, resolved: 0, mismatched: 0 };
  }

  id(prefix) {
    this.sequence += 1;
    return `${prefix}_${this.runLabel}_${this.sequence}`;
  }

  async post(callable, actor, data, abortAfterMs) {
    if (this.requests >= thresholds.maxRequestsPerRun) {
      this.stop ??= "request budget of the run reached";
      return { http: 0, result: null, ms: 0, aborted: false, skipped: true };
    }
    this.requests += 1;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), abortAfterMs ?? 30_000);
    const started = performance.now();
    try {
      const response = await fetch(this.url, {
        method: "POST",
        signal: controller.signal,
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.token}`,
        },
        body: JSON.stringify({
          callable,
          loadActor: actor.uid,
          data: { ...data, sessionContext: actor.sessionContext },
        }),
      });
      let result = null;
      try {
        result = (await response.json()).result ?? null;
      } catch {
        result = null;
      }
      return {
        http: response.status,
        result,
        ms: performance.now() - started,
        aborted: false,
      };
    } catch {
      return {
        http: 0,
        result: null,
        ms: performance.now() - started,
        aborted: abortAfterMs !== undefined,
      };
    } finally {
      clearTimeout(timer);
    }
  }

  /** One user operation: retries with a new requestId and the same idempotency key. */
  async operation(
    records,
    op,
    callable,
    actor,
    build,
    { abortFirst = false } = {},
  ) {
    const started = performance.now();
    let last = { outcome: "failed", code: "not_sent", http: 0 };
    let result = null;
    let retries = 0;
    for (let attempt = 0; attempt < 4; attempt += 1) {
      const reply = await this.post(
        callable,
        actor,
        build(),
        abortFirst && attempt === 0 ? 80 : undefined,
      );
      if (reply.skipped) break;
      if (reply.aborted) {
        this.unknown.injected += 1;
        retries += 1;
        continue;
      }
      last = { ...classify(reply.http, reply.result), http: reply.http };
      result = reply.result;
      if (last.outcome !== "failed") break;
      retries += 1;
      await sleep(
        Math.min(5_000, (last.retryAfterSeconds ?? 0.5 * 2 ** attempt) * 1_000),
      );
    }
    const ms = performance.now() - started;
    records.push({
      op,
      ms,
      retries,
      outcome: last.outcome,
      code: last.code,
      http: last.http,
    });
    this.window.add(Date.now(), last.outcome === "failed");
    if (this.window.tripped()) this.stop ??= "error ratio above 20 % for 60 s";
    return { ...last, result };
  }

  createData(event, idempotencyKey) {
    return () => ({
      schemaVersion: 1,
      commandType: "createBooking",
      requestId: this.id("req"),
      idempotencyKey,
      occurredAgainstEventRevision: event.materialRevision,
      payload: {
        occurrenceId: event.occurrenceId,
        inventoryPoolId: event.poolId,
        channel: "onsite",
        participantUnits: 1,
        namedGuests: [],
      },
    });
  }

  cancel(records, actor, booking, op = "cancel") {
    const idempotencyKey = this.id("idem_cancel");
    return this.operation(
      records,
      op,
      "cancelInternalBookingV1",
      actor,
      () => ({
        schemaVersion: 1,
        commandType: "cancelBooking",
        requestId: this.id("req"),
        idempotencyKey,
        expectedBookingRevision: booking.revision,
        payload: { bookingId: booking.id, reasonCode: "user_request" },
      }),
    );
  }

  /** One step of the per-actor cycle: availability -> create -> read -> cancel. */
  async step(records, actor, event) {
    const state = (actor.state ??= {
      next: "availability",
      booking: null,
      creates: 0,
    });
    if (state.next === "availability") {
      await this.operation(
        records,
        "availability",
        "getEventAvailabilityV1",
        actor,
        () => ({
          schemaVersion: 1,
          queryType: "getEventAvailability",
          requestId: this.id("req"),
          payload: {
            eventId: event.eventId,
            occurrenceId: event.occurrenceId,
            channel: "onsite",
          },
        }),
      );
      state.next = "create";
    } else if (state.next === "create") {
      state.creates += 1;
      const idempotencyKey = this.id("idem_create");
      const probe = state.creates % 10 === 0; // every tenth create: a lost reply
      const made = await this.operation(
        records,
        "create",
        "createInternalBookingV1",
        actor,
        this.createData(event, idempotencyKey),
        { abortFirst: probe },
      );
      if (made.outcome === "ok") {
        state.booking = made.result.booking;
        if (probe) {
          // The client never saw the first reply: the same key must name the same Booking.
          const again = await this.operation(
            records,
            "createReplay",
            "createInternalBookingV1",
            actor,
            this.createData(event, idempotencyKey),
          );
          if (
            again.outcome === "ok" &&
            again.result.booking?.id === state.booking.id
          )
            this.unknown.resolved += 1;
          else this.unknown.mismatched += 1;
        }
        state.next = "read";
      } else state.next = "availability";
    } else if (state.next === "read") {
      await this.operation(records, "read", "getMyBookingV1", actor, () => ({
        schemaVersion: 1,
        queryType: "getMyBooking",
        requestId: this.id("req"),
        payload: { bookingId: state.booking.id },
      }));
      state.next = "cancel";
    } else {
      const done = await this.cancel(records, actor, state.booking);
      if (done.outcome !== "failed") state.booking = null;
      state.next = done.outcome === "failed" ? "cancel" : "availability";
    }
  }

  async paced(name, { ratePerSecond, seconds }) {
    const records = [];
    const event = this.seed.events.find((e) =>
      e.occurrenceId.endsWith("_open"),
    );
    const actors = this.seed.actors;
    const started = Date.now();
    const inFlight = new Set();
    const total = Math.round(ratePerSecond * seconds);
    let cursor = 0;
    let skipped = 0;
    for (let i = 0; i < total && this.stop === null; i += 1) {
      const due = started + (i * 1_000) / ratePerSecond;
      const wait = due - Date.now();
      if (wait > 0) await sleep(wait);
      let actor = null;
      for (let probe = 0; probe < actors.length; probe += 1) {
        const candidate = actors[(cursor + probe) % actors.length];
        if (!candidate.busy) {
          actor = candidate;
          cursor = (cursor + probe + 1) % actors.length;
          break;
        }
      }
      if (actor === null) {
        skipped += 1;
        continue;
      }
      actor.busy = true;
      const task = this.step(records, actor, event).finally(() => {
        actor.busy = false;
        inFlight.delete(task);
      });
      inFlight.add(task);
    }
    await Promise.all(inFlight);
    const elapsed = (Date.now() - started) / 1_000;
    return {
      phase: name,
      targetRatePerSecond: ratePerSecond,
      plannedSeconds: seconds,
      elapsedSeconds: Math.round(elapsed * 10) / 10,
      operations: records.length,
      achievedRatePerSecond: Math.round((records.length / elapsed) * 100) / 100,
      skippedTicksAllActorsBusy: skipped,
      byOperation: summarize(records),
      stoppedBy: this.stop,
    };
  }

  /** Every actor releases what the paced phases left, so no synthetic Booking stays active. */
  async drain() {
    const records = [];
    for (const actor of this.seed.actors)
      if (actor.state?.booking) {
        const done = await this.cancel(
          records,
          actor,
          actor.state.booking,
          "drainCancel",
        );
        if (done.outcome !== "failed") actor.state.booking = null;
      }
    return { phase: "drain", byOperation: summarize(records) };
  }

  async pool() {
    const { attempts, capacity, roundPauseMs } = phases.pool;
    const rounds = [];
    const records = [];
    const actors = this.seed.actors.slice(0, attempts);
    const events = this.seed.events.filter((e) =>
      /_pool\d\d$/u.test(e.occurrenceId),
    );
    for (const event of events) {
      if (this.stop !== null) break;
      const started = performance.now();
      const results = await Promise.all(
        actors.map((actor) =>
          this.operation(
            records,
            "poolCreate",
            "createInternalBookingV1",
            actor,
            this.createData(event, this.id("idem_pool")),
          ).then((made) => ({ actor, made })),
        ),
      );
      const won = results.filter((r) => r.made.outcome === "ok");
      const refusedCodes = {};
      for (const r of results.filter((x) => x.made.outcome !== "ok"))
        refusedCodes[r.made.code] = (refusedCodes[r.made.code] ?? 0) + 1;
      const availability = await this.operation(
        records,
        "poolAvailability",
        "getEventAvailabilityV1",
        actors[0],
        () => ({
          schemaVersion: 1,
          queryType: "getEventAvailability",
          requestId: this.id("req"),
          payload: {
            eventId: event.eventId,
            occurrenceId: event.occurrenceId,
            channel: "onsite",
          },
        }),
      );
      const oversell = Math.max(0, won.length - capacity);
      rounds.push({
        occurrenceId: event.occurrenceId,
        attempts: results.length,
        confirmed: won.length,
        capacity,
        oversell,
        notConfirmed: refusedCodes,
        availabilityAfter: availability.result?.availability ?? null,
        roundMs: Math.round(performance.now() - started),
      });
      if (oversell > 0) this.stop ??= `oversell on ${event.occurrenceId}`;
      for (const { actor, made } of won)
        await this.cancel(records, actor, made.result.booking, "poolCancel");
      await sleep(roundPauseMs);
    }
    return {
      phase: "pool",
      rounds,
      oversellTotal: rounds.reduce((sum, r) => sum + r.oversell, 0),
      byOperation: summarize(records),
      stoppedBy: this.stop,
    };
  }
}

export function verdict(report) {
  const paced = report.phases.filter(
    (p) => p.targetRatePerSecond !== undefined,
  );
  const pool = report.phases.find((p) => p.phase === "pool");
  const checks = {};
  for (const phase of paced) {
    const ops = Object.values(phase.byOperation);
    const total = ops.reduce((sum, op) => sum + op.operations, 0);
    const failed = ops.reduce((sum, op) => sum + (op.outcomes.failed ?? 0), 0);
    checks[phase.phase] = {
      worstP95Ms: Math.max(0, ...ops.map((op) => op.p95Ms ?? 0)),
      p95WithinTarget: ops.every(
        (op) => (op.p95Ms ?? 0) <= thresholds.targetP95Ms,
      ),
      successRatio: total === 0 ? null : (total - failed) / total,
      successWithinTarget:
        total > 0 && (total - failed) / total >= thresholds.targetSuccessRatio,
      rateReached:
        phase.achievedRatePerSecond >= phase.targetRatePerSecond * 0.95,
    };
  }
  if (pool)
    checks.pool = {
      oversellTotal: pool.oversellTotal,
      everyRoundSoldExactlyCapacity: pool.rounds.every(
        (r) => r.confirmed === r.capacity,
      ),
    };
  return checks;
}

async function main() {
  const [mode, seedFile, outFile] = process.argv.slice(2);
  const url = process.env.N4C_LOAD_URL ?? "";
  const token = process.env.N4C_LOAD_ID_TOKEN ?? "";
  if (!["pilot", "full"].includes(mode) || !seedFile || !outFile)
    throw new Error(
      "usage: node n4c-load-driver.mjs <pilot|full> <private-seed.json> <out.json>",
    );
  if (
    !url.startsWith(
      `https://europe-west1-${stagingProject}.cloudfunctions.net/`,
    ) ||
    token === ""
  )
    throw new Error(
      "staging load ingress URL and an identity token are required",
    );
  const seed = JSON.parse(readFileSync(seedFile, "utf8"));
  if (seed.projectId !== stagingProject)
    throw new Error("seed is not for staging");
  const driver = new Driver({
    url,
    token,
    seed,
    runLabel: `${seed.runId}${mode[0]}${Date.now() % 100_000}`,
  });
  const report = {
    schemaVersion: 1,
    projectId: stagingProject,
    runId: seed.runId,
    mode,
    startedAtUtc: new Date().toISOString(),
    actors: seed.actors.length,
    thresholds,
    phases: [],
  };
  const save = () =>
    writeFileSync(outFile, JSON.stringify(report, null, 2) + "\n");
  if (mode === "pilot")
    report.phases.push(await driver.paced("pilot", phases.pilot));
  else {
    report.phases.push(await driver.paced("sustained", phases.sustained));
    save();
    if (driver.stop === null) {
      await sleep(60_000); // let the per-actor rate windows clear
      report.phases.push(await driver.paced("burst", phases.burst));
      save();
    }
  }
  report.phases.push(await driver.drain());
  if (mode === "full" && driver.stop === null) {
    await sleep(60_000);
    report.phases.push(await driver.pool());
  }
  report.finishedAtUtc = new Date().toISOString();
  report.requests = driver.requests;
  report.unknownOutcomes = driver.unknown;
  report.stoppedBy = driver.stop;
  report.verdict = verdict(report);
  save();
  process.stdout.write(
    `${mode}: ${driver.requests} requests, stoppedBy=${driver.stop ?? "none"}\n`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href)
  main().catch((error) => {
    process.stderr.write(`n4c-load-driver: ${error.message}\n`);
    process.exitCode = 1;
  });
