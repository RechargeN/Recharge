import test from "node:test";
import assert from "node:assert/strict";
import { inspectReceipt } from "./wait-dev-budget-delivery.mjs";

const query = {
  projectId: "recharge-dev-selftest0",
  budgetName: "billingAccounts/test/budgets/one",
  topicName: "projects/recharge-dev-selftest0/topics/dev-budget-events",
  subscriptionName:
    "projects/recharge-dev-selftest0/subscriptions/dev-budget-evidence",
  channelName: "projects/recharge-dev-selftest0/notificationChannels/one",
};
const now = new Date("2026-11-05T00:00:00Z");
const receipt = {
  schemaVersion: 2,
  ...query,
  budgetPubsubMessageVerified: true,
  budgetMessageId: "synthetic-message-id",
  budgetMessage: {
    messageId: "synthetic-message-id",
    publishTime: "2026-11-04T23:58:00Z",
    attributes: {
      billingAccountId: "test",
      budgetId: "one",
      schemaVersion: "1.0",
    },
    data: Buffer.from(
      JSON.stringify({
        currencyCode: "EUR",
        budgetAmount: 5,
        budgetDisplayName: "budget-guardrail-dev",
      }),
    ).toString("base64"),
  },
  budgetMessageEvidenceRef: "synthetic-fixture-not-cloud-evidence",
  budgetMessagePublishedAtUtc: "2026-11-04T23:58:00Z",
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
  [
    "forged wrong-budget message",
    { budgetMessage: { attributes: { budgetId: "other" } } },
  ],
  ["old schema", { schemaVersion: 1 }],
  ["missing budget message", { budgetPubsubMessageVerified: false }],
  ["missing message ID", { budgetMessageId: "" }],
  ["missing message evidence", { budgetMessageEvidenceRef: "" }],
  ["wrong topic", { topicName: "projects/other/topics/other" }],
  [
    "wrong subscription",
    { subscriptionName: "projects/other/subscriptions/other" },
  ],
  [
    "stale budget message",
    { budgetMessagePublishedAtUtc: "2026-10-28T00:00:00Z" },
  ],
  [
    "future budget message",
    { budgetMessagePublishedAtUtc: "2026-11-06T00:00:00Z" },
  ],
  ["no owner ack", { ownerAcknowledged: false }],
  ["no delivery", { channelDeliveryVerified: false }],
  ["no budget verification", { budgetConfigurationVerified: false }],
  ["wrong project", { projectId: "recharge-dev-other0" }],
  ["wrong budget", { budgetName: "billingAccounts/test/budgets/other" }],
  [
    "wrong channel",
    { channelName: "projects/recharge-dev-other0/notificationChannels/one" },
  ],
  ["stale", { deliveredAtUtc: "2026-10-28T20:00:00Z" }],
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
