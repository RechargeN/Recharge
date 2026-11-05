import test from "node:test";
import assert from "node:assert/strict";
import { inspectReceipt } from "./wait-dev-budget-delivery.mjs";

const query = {
  projectId: "recharge-dev-selftest0",
  budgetName: "billingAccounts/test/budgets/one",
  channelName: "projects/recharge-dev-selftest0/notificationChannels/one",
};
const now = new Date("2026-11-05T00:00:00Z");
const receipt = {
  schemaVersion: 1,
  ...query,
  budgetConfigurationVerified: true,
  channelDeliveryVerified: true,
  ownerAcknowledged: true,
  ownerAckEvidenceRef: "synthetic-test-only",
  deliveredAtUtc: "2026-11-04T23:59:00Z",
  testKind: "monitoring-channel-delivery",
};
test("current exact-channel delivery and real-ack reference passes", () =>
  assert.equal(inspectReceipt(query, receipt, now), true));
for (const [label, change] of [
  ["missing receipt", null],
  ["no owner ack", { ownerAcknowledged: false }],
  ["no delivery", { channelDeliveryVerified: false }],
  ["no budget verification", { budgetConfigurationVerified: false }],
  ["wrong project", { projectId: "recharge-dev-other0" }],
  ["wrong budget", { budgetName: "billingAccounts/test/budgets/other" }],
  [
    "wrong channel",
    { channelName: "projects/recharge-dev-other0/notificationChannels/one" },
  ],
  ["stale", { deliveredAtUtc: "2026-11-04T20:00:00Z" }],
  ["future", { deliveredAtUtc: "2026-11-05T01:00:00Z" }],
  ["configuration-only", { testKind: "configuration-only" }],
  ["no actual evidence ref", { ownerAckEvidenceRef: "" }],
])
  test(`rejects ${label}`, () =>
    assert.equal(
      inspectReceipt(
        query,
        change === null ? null : { ...receipt, ...change },
        now,
      ),
      false,
    ));
test("non-dev query fails even with otherwise matching receipt", () =>
  assert.equal(
    inspectReceipt(
      { ...query, projectId: "recharge-prod-never" },
      receipt,
      now,
    ),
    false,
  ));
