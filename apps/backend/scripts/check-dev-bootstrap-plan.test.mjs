import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { checkBootstrapPlan } from "./check-dev-bootstrap-plan.mjs";
const projectId = "recharge-dev-selftest0";
const resource = (address, type, after) => ({
  address,
  type,
  change: { actions: ["create"], after },
});
const fixture = () => ({
  variables: {
    project_id: { value: projectId },
    billing_account_id: { value: "test" },
    manifest_sha256: { value: "manifest" },
    release_commit_sha: { value: "commit" },
  },
  resource_changes: [
    resource("firebase", "google_firebase_project", { project: projectId }),
    resource("publisher", "google_pubsub_topic_iam_member", {
      project: projectId,
      role: "roles/pubsub.publisher",
      member: "serviceAccount:billing-budget-alerts@system.gserviceaccount.com",
    }),
    resource("wif", "google_iam_workload_identity_pool_provider", {
      project: projectId,
      disabled: true,
      attribute_condition: "false",
    }),
  ],
});
const expected = (p) => ({
  projectId,
  billingAccountId: "test",
  manifestSha256: "manifest",
  commitSha: "commit",
  inventorySha256: createHash("sha256")
    .update(
      JSON.stringify(
        p.resource_changes
          .map(({ address, type, change }) => ({
            address,
            type,
            actions: change.actions,
          }))
          .sort((a, b) => a.address.localeCompare(b.address)),
      ),
    )
    .digest("hex"),
});
test("matching offline inventory passes", () => {
  const p = fixture();
  assert.deepEqual(checkBootstrapPlan(p, expected(p)), []);
});
for (const [name, mutate] of [
  [
    "stage target",
    (p) => (p.variables.project_id.value = "recharge-stage-test"),
  ],
  [
    "foreign project",
    (p) => (p.resource_changes[0].change.after.project = "other"),
  ],
  ["billing drift", (p) => (p.variables.billing_account_id.value = "other")],
  [
    "new resource",
    (p) =>
      p.resource_changes.push(
        resource("surprise", "google_storage_bucket", {}),
      ),
  ],
  ["destroy", (p) => (p.resource_changes[0].change.actions = ["delete"])],
  [
    "replacement",
    (p) => (p.resource_changes[0].change.actions = ["delete", "create"]),
  ],
  ["enabled WIF", (p) => (p.resource_changes[2].change.after.disabled = false)],
  [
    "weaker WIF",
    (p) => (p.resource_changes[2].change.after.attribute_condition = "true"),
  ],
  [
    "wrong publisher",
    (p) => (p.resource_changes[1].change.after.member = "allUsers"),
  ],
  [
    "key",
    (p) =>
      p.resource_changes.push(
        resource("key", "google_service_account_key", {}),
      ),
  ],
])
  test(`rejects ${name}`, () => {
    const p = fixture(),
      e = expected(p);
    mutate(p);
    assert.ok(checkBootstrapPlan(p, e).length);
  });
