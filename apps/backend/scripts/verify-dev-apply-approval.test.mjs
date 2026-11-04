import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import test from "node:test";
import { verifyDevApplyApproval } from "./verify-dev-apply-approval.mjs";

const digest = (bytes) => createHash("sha256").update(bytes).digest("hex");
const planBytes = Buffer.from("synthetic test plan; never Terraform input");
const manifestBytes = Buffer.from("synthetic test manifest");
const commitSha = "a".repeat(40);
const projectId = "recharge-dev-selftest0";
const now = new Date("2026-11-04T12:00:00Z");
const approval = () => ({
  schemaVersion: 1,
  status: "approved",
  environment: "dev",
  projectId,
  commitSha,
  manifestSha256: digest(manifestBytes),
  savedPlanSha256: digest(planBytes),
  operations: ["apply"],
  owner: "test",
  ownerApprovalEvidenceRef: "synthetic-only",
  recordRef: "synthetic-not-authority",
  dataScope: "synthetic",
  push: false,
  merge: false,
  marketActivation: false,
  destroy: false,
  serviceAccountKeyCreation: false,
  issuedAtUtc: "2026-11-04T11:00:00Z",
  expiresAtUtc: "2026-11-04T13:00:00Z",
});
const check = (record = approval(), overrides = {}) =>
  verifyDevApplyApproval({
    approval: record,
    planBytes,
    manifestBytes,
    commitSha,
    projectId,
    now,
    ...overrides,
  });

test("exact current approval passes only the local binding checkpoint", () =>
  assert.deepEqual(check(), []));
for (const [label, mutation] of [
  ["plan-only record", { operations: ["plan"] }],
  ["unrelated operation", { operations: ["apply", "destroy"] }],
  ["expired record", { expiresAtUtc: now.toISOString() }],
  ["future record", { issuedAtUtc: "2026-11-05T00:00:00Z" }],
  ["foreign environment", { environment: "stage" }],
  ["wrong project", { projectId: "recharge-dev-other0" }],
  ["wrong plan", { savedPlanSha256: "0".repeat(64) }],
  ["wrong manifest", { manifestSha256: "0".repeat(64) }],
  ["wrong source", { commitSha: "b".repeat(40) }],
  ["no actual evidence reference", { ownerApprovalEvidenceRef: "" }],
  ["real data", { dataScope: "real" }],
  ["key creation", { serviceAccountKeyCreation: true }],
  ["destroy", { destroy: true }],
  ["activation", { marketActivation: true }],
])
  test(`rejects ${label}`, () =>
    assert.ok(check({ ...approval(), ...mutation }).length));
test("rejects changed saved-plan bytes", () =>
  assert.ok(
    check(approval(), { planBytes: Buffer.from("changed") }).includes(
      "saved plan mismatch",
    ),
  ));
test("rejects non-dev target and short source SHA", () =>
  assert.ok(
    check(approval(), {
      projectId: "recharge-prod-never",
      commitSha: "1234567",
    }).length >= 2,
  ));
test("malformed/missing approval fails closed", () =>
  assert.ok(check(null).length));
