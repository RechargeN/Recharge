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

// N4b: roll the media tools to a new reviewed digest (fix: own mirror bucket).
const digest = `sha256:${"b".repeat(64)}`;
const image = `europe-west1-docker.pkg.dev/${project}/media-tools/media-tools@${digest}`;
const oldImage = `europe-west1-docker.pkg.dev/${project}/media-tools/media-tools@sha256:${"a".repeat(64)}`;
const scanner = 'google_cloud_run_v2_service.n3b["media-scanner"]';
const processor = 'google_cloud_run_v2_service.n3b["media-processor"]';
const mirrorJob = "google_cloud_run_v2_job.n3b_mirror[0]";
const service = (img, extra = {}) => ({
  project,
  template: [
    {
      containers: [{ image: img }],
      scaling: [{ min_instance_count: 0, max_instance_count: 1 }],
      ...extra,
    },
  ],
});
const job = (img) => ({
  project,
  template: [{ template: [{ containers: [{ image: img }] }] }],
});
const roll = (address, type, before, after) => ({
  address,
  type,
  change: { actions: ["update"], before, after, after_unknown: {} },
});
function rollPlan(mutate = (c) => c) {
  const c = mutate([
    roll(
      scanner,
      "google_cloud_run_v2_service",
      service(oldImage),
      service(image),
    ),
    roll(
      processor,
      "google_cloud_run_v2_service",
      service(oldImage),
      service(image),
    ),
    roll(mirrorJob, "google_cloud_run_v2_job", job(oldImage), job(image)),
  ]);
  const p = plan(c);
  p.variables.n3b_image_digest = { value: digest };
  return p;
}
const rollExpected = (p, extra = {}) => ({
  projectId: project,
  commitSha: "a".repeat(40),
  inventorySha256: inventoryDigest(p),
  imageDigest: digest,
  image,
  ...extra,
});

test("N4b: an image-only roll of the three media tools to the recorded digest passes", () => {
  const p = rollPlan();
  assert.deepEqual(checkN4aPlan(p, rollExpected(p)), []);
});

test("N4b: any other update, field, image or registry is refused", () => {
  const cases = [
    // No reviewed digest: updates stay forbidden as before.
    [
      (c) => c,
      { imageDigest: undefined, image: undefined },
      /forbidden action update/u,
    ],
    // Another field changes with the image.
    [
      (c) => {
        c[0].change.after = service(image, { timeout: "600s" });
        return c;
      },
      {},
      /forbidden action update/u,
    ],
    // The image is not the recorded one.
    [
      (c) => {
        c[2].change.after = job(
          oldImage.replace("a".repeat(64), "c".repeat(64)),
        );
        return c;
      },
      {},
      /forbidden action update/u,
    ],
    // An update of anything else.
    [
      (c) => [
        ...c,
        roll(
          "google_storage_bucket.media",
          "google_storage_bucket",
          { project, labels: {} },
          { project, labels: { x: "y" } },
        ),
      ],
      {},
      /forbidden action update: google_storage_bucket.media/u,
    ],
  ];
  for (const [mutate, extra, pattern] of cases) {
    const p = rollPlan(mutate);
    assert.match(checkN4aPlan(p, rollExpected(p, extra)).join(), pattern);
  }
  // A digest from another project's registry is never a staging image.
  const p = rollPlan();
  assert.match(
    checkN4aPlan(
      p,
      rollExpected(p, {
        image: `europe-west1-docker.pkg.dev/recharge-dev-n2a01/media-tools/media-tools@${digest}`,
      }),
    ).join(),
    /staging repository image/u,
  );
  // The plan's digest variable must be the recorded one.
  const q = rollPlan();
  q.variables.n3b_image_digest = { value: `sha256:${"d".repeat(64)}` };
  assert.match(
    checkN4aPlan(q, rollExpected(q)).join(),
    /image digest mismatch/u,
  );
});
