import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";

import {
  ErrorWindow,
  classify,
  percentile,
  summarize,
  thresholds,
  verdict,
} from "./n4c-load-driver.mjs";
import { actorId, actorRecords, syntheticEvent } from "./n4c-load-seed.mjs";

test("seed: actors and events carry the synthetic prefixes the load ingress accepts", () => {
  const now = new Date("2026-11-17T10:00:00.000Z");
  const handle = "a".repeat(43);
  const record = actorRecords(7, handle, now);
  assert.equal(actorId(7), "n4cload0007");
  assert.match(record.uid, /^n4cload[0-9]{4}$/u);
  assert.equal(record.session.firebaseUid, record.uid);
  assert.equal(record.session.userId, record.account.userId);
  assert.equal(
    record.session.handleHash,
    createHash("sha256").update(handle, "utf8").digest("hex"),
  );
  assert.equal(
    record.accessSnapshot.sessionId,
    record.sessionContext.sessionId,
  );
  assert.deepEqual(record.accessSnapshot.capabilityIds, [
    "booking.self_service",
  ]);
  assert.ok(Date.parse(record.accessSnapshot.expiresAtUtc) > now.getTime());
  const event = syntheticEvent("run1", "pool03", 10, now);
  assert.ok(event.occurrenceId.startsWith("occ_n4cload_"));
  assert.equal(event.totalCapacity, 10);
  assert.ok(Date.parse(event.registrationWindow.opensAt) < now.getTime());
  assert.ok(Date.parse(event.registrationWindow.closesAt) > now.getTime());
});

test("driver: percentiles are taken from the samples, never averaged", () => {
  const sorted = Array.from({ length: 100 }, (_, i) => i + 1);
  assert.equal(percentile(sorted, 50), 50);
  assert.equal(percentile(sorted, 95), 95);
  assert.equal(percentile(sorted, 99), 99);
  assert.equal(percentile([], 95), null);
  assert.equal(percentile([7], 99), 7);
});

test("driver: a typed refusal is not a failure; transport and retryable replies are", () => {
  assert.equal(classify(200, { kind: "succeeded" }).outcome, "ok");
  assert.equal(classify(200, { kind: "found" }).outcome, "ok");
  const soldOut = classify(200, {
    kind: "rejected",
    error: { code: "sold_out" },
  });
  assert.deepEqual([soldOut.outcome, soldOut.code], ["refused", "sold_out"]);
  const limited = classify(200, {
    kind: "retryableFailure",
    error: { code: "rate_limited", details: { retryAfterSeconds: 4 } },
  });
  assert.deepEqual(
    [limited.outcome, limited.code, limited.retryAfterSeconds],
    ["failed", "rate_limited", 4],
  );
  assert.deepEqual(classify(429, null), {
    outcome: "failed",
    code: "http_429",
  });
  assert.deepEqual(classify(0, null), { outcome: "failed", code: "http_0" });
});

test("driver: the error window stops a run only above 20 % over enough samples", () => {
  const window = new ErrorWindow();
  for (let i = 0; i < 40; i += 1) window.add(1_000 + i, true);
  assert.equal(window.tripped(), false); // fewer than the minimum number of samples
  for (let i = 0; i < 200; i += 1) window.add(2_000 + i, false);
  assert.equal(window.tripped(), false); // 40 of 240
  for (let i = 0; i < 40; i += 1) window.add(3_000 + i, true);
  assert.equal(window.tripped(), true); // 80 of 280
  window.add(3_000 + thresholds.errorWindowMs + 5_000, false);
  assert.equal(window.tripped(), false); // old samples left the window
});

test("driver: the verdict needs p95, success ratio, rate and exact pool sales", () => {
  const records = [
    ...Array.from({ length: 99 }, () => ({
      op: "create",
      ms: 400,
      retries: 0,
      outcome: "ok",
      code: "succeeded",
      http: 200,
    })),
    {
      op: "create",
      ms: 2_400,
      retries: 3,
      outcome: "failed",
      code: "http_429",
      http: 429,
    },
  ];
  const byOperation = summarize(records);
  assert.equal(byOperation.create.p95Ms, 400);
  assert.equal(byOperation.create.p99Ms, 400);
  assert.equal(byOperation.create.maxMs, 2_400);
  assert.equal(byOperation.create.retries, 3);
  const report = {
    phases: [
      {
        phase: "sustained",
        targetRatePerSecond: 5,
        achievedRatePerSecond: 4.9,
        byOperation,
      },
      {
        phase: "pool",
        oversellTotal: 0,
        rounds: [
          { confirmed: 10, capacity: 10 },
          { confirmed: 9, capacity: 10 },
        ],
      },
    ],
  };
  const result = verdict(report);
  assert.equal(result.sustained.p95WithinTarget, true);
  assert.equal(result.sustained.successWithinTarget, false); // 99 % < 99.9 %
  assert.equal(result.sustained.rateReached, true);
  assert.equal(result.pool.oversellTotal, 0);
  assert.equal(result.pool.everyRoundSoldExactlyCapacity, false);
});
