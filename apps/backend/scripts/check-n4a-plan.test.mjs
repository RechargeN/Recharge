import test from "node:test";
import assert from "node:assert/strict";

import { checkN4aPlan, inventoryDigest } from "./check-n4a-plan.mjs";

const project = "recharge-staging-y9y2y";
const change = (address, type, after, actions = ["create"]) => ({
  address,
  type,
  change: { actions, after },
});

function changes() {
  return [
    change("google_project.stage", "google_project", {
      project_id: project,
      deletion_policy: "PREVENT",
    }),
    change(
      "module.budget_alerts.google_billing_budget.budget[0]",
      "google_billing_budget",
      {
        amount: [{ specified_amount: [{ units: "5", currency_code: "EUR" }] }],
      },
    ),
    change(
      "google_project_iam_custom_role.n3c_data[0]",
      "google_project_iam_custom_role",
      {
        project,
        permissions: ["datastore.entities.create", "datastore.entities.get"],
      },
    ),
    change(
      "google_project_iam_member.n3c_data[0]",
      "google_project_iam_member",
      {
        project,
        role: `projects/${project}/roles/devNotificationsData`,
        member: `serviceAccount:runtime-notifications@${project}.iam.gserviceaccount.com`,
      },
    ),
    change(
      "google_pubsub_topic_iam_member.budget_publisher",
      "google_pubsub_topic_iam_member",
      {
        project,
        role: "roles/pubsub.publisher",
        member:
          "serviceAccount:billing-budget-alert@system.gserviceaccount.com",
      },
    ),
    change(
      'google_cloud_run_v2_service.n3b["media-scanner"]',
      "google_cloud_run_v2_service",
      {
        project,
        template: [
          { scaling: [{ min_instance_count: 0, max_instance_count: 1 }] },
        ],
      },
    ),
    change("google_storage_bucket.media", "google_storage_bucket", {
      project,
      lifecycle_rule: [],
    }),
  ];
}
const plan = (resourceChanges) => ({
  variables: {
    project_id: { value: project },
    release_commit_sha: { value: "a".repeat(40) },
  },
  resource_changes: resourceChanges,
});
const check = (mutate = () => {}) => {
  const c = changes();
  mutate(c);
  const p = plan(c);
  return checkN4aPlan(p, {
    projectId: project,
    commitSha: "a".repeat(40),
    inventorySha256: inventoryDigest(p),
  });
};
const find = (c, address) => c.find((x) => x.address === address).change.after;

test("a staging plan within the policy passes", () => {
  assert.deepEqual(check(), []);
});

test("delete, destroy, foreign project, basic role, public member and cost are refused", () => {
  const cases = [
    [
      (c) =>
        find(c, "google_project_iam_custom_role.n3c_data[0]").permissions.push(
          "datastore.entities.delete",
        ),
      /delete permission/u,
    ],
    [
      (c) => {
        c[0].change.actions = ["delete"];
      },
      /forbidden action delete/u,
    ],
    [
      (c) => {
        c[2].change.actions = ["delete", "create"];
      },
      /forbidden action/u,
    ],
    [
      (c) => {
        find(c, "google_storage_bucket.media").project = "recharge-dev-n2a01";
      },
      /foreign project/u,
    ],
    [
      (c) => {
        find(c, "google_project_iam_member.n3c_data[0]").role = "roles/editor";
      },
      /basic role/u,
    ],
    [
      (c) => {
        find(c, "google_project_iam_member.n3c_data[0]").member = "allUsers";
      },
      /member not allowed/u,
    ],
    [
      (c) => {
        find(c, "google_project_iam_member.n3c_data[0]").member =
          "serviceAccount:x@other.iam.gserviceaccount.com";
      },
      /member not allowed/u,
    ],
    [
      (c) => {
        find(c, "google_storage_bucket.media").lifecycle_rule = [
          { action: [{ type: "Delete" }] },
        ];
      },
      /automatic deletion/u,
    ],
    [
      (c) => {
        find(
          c,
          "module.budget_alerts.google_billing_budget.budget[0]",
        ).amount[0].specified_amount[0].units = "75";
      },
      /budget is not €5/u,
    ],
    [
      (c) => {
        find(
          c,
          'google_cloud_run_v2_service.n3b["media-scanner"]',
        ).template[0].scaling[0].min_instance_count = 1;
      },
      /scaling/u,
    ],
    [
      (c) => {
        find(c, "google_project.stage").deletion_policy = "DELETE";
      },
      /deletion not prevented/u,
    ],
  ];
  for (const [mutate, pattern] of cases)
    assert.match(check(mutate).join(), pattern);
});

test("only the staging project", () => {
  const p = plan(changes());
  assert.match(
    checkN4aPlan(p, {
      projectId: "recharge-dev-n2a01",
      commitSha: "a".repeat(40),
      inventorySha256: inventoryDigest(p),
    }).join(),
    /recharge-staging-y9y2y only/u,
  );
});
