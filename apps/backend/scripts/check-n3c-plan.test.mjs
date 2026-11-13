import test from "node:test";
import assert from "node:assert/strict";

import { checkN3cPlan, inventoryDigest } from "./check-n3c-plan.mjs";

const project = "recharge-dev-n2a01";
const member = `serviceAccount:runtime-notifications@${project}.iam.gserviceaccount.com`;
const change = (address, type, after, actions = ["create"]) => ({
  address,
  type,
  change: { actions, after },
});

function changes() {
  return [
    change("google_project.dev", "google_project", { project_id: project }, [
      "no-op",
    ]),
    change(
      'module.runtime_identities.google_service_account.account["runtime-notifications"]',
      "google_service_account",
      { project, account_id: "runtime-notifications" },
    ),
    change("terraform_data.n3c_guard[0]", "terraform_data", {}),
    change(
      "google_project_iam_custom_role.n3c_data[0]",
      "google_project_iam_custom_role",
      {
        project,
        permissions: [
          "datastore.entities.update",
          "datastore.databases.get",
          "datastore.entities.create",
          "datastore.entities.get",
          "datastore.entities.list",
        ],
      },
    ),
    change(
      "google_project_iam_custom_role.n3c_fcm[0]",
      "google_project_iam_custom_role",
      { project, permissions: ["cloudmessaging.messages.create"] },
    ),
    change(
      "google_project_iam_member.n3c_data[0]",
      "google_project_iam_member",
      {
        project,
        role: `projects/${project}/roles/devNotificationsData`,
        member,
        condition: [
          {
            expression: `resource.name == "projects/${project}/databases/(default)"`,
          },
        ],
      },
    ),
    change(
      "google_project_iam_member.n3c_fcm[0]",
      "google_project_iam_member",
      {
        project,
        role: `projects/${project}/roles/devNotificationsFcmSender`,
        member,
      },
    ),
    change(
      "google_project_iam_member.n3c_auth[0]",
      "google_project_iam_member",
      {
        project,
        role: `projects/${project}/roles/devIdentityFirebaseVerifier`,
        member,
      },
    ),
  ];
}
const plan = (resourceChanges) => ({
  variables: {
    project_id: { value: project },
    n3c_enabled: { value: true },
    n2c_enabled: { value: true },
    release_commit_sha: { value: "a".repeat(40) },
  },
  resource_changes: resourceChanges,
});
const expected = (p) => ({
  projectId: project,
  commitSha: "a".repeat(40),
  inventorySha256: inventoryDigest(p),
});
const check = (mutate = () => {}) => {
  const c = changes();
  mutate(c);
  const p = plan(c);
  return checkN3cPlan(p, expected(p));
};
const find = (c, address) => c.find((x) => x.address === address).change.after;

test("the reviewed N3c inventory passes", () => {
  assert.deepEqual(check(), []);
});

test("no delete permission, no foreign member, no extra grant, nothing removed", () => {
  assert.match(
    check((c) =>
      find(c, "google_project_iam_custom_role.n3c_data[0]").permissions.push(
        "datastore.entities.delete",
      ),
    ).join(),
    /permissions differ/u,
  );
  assert.match(
    check((c) =>
      find(c, "google_project_iam_custom_role.n3c_fcm[0]").permissions.push(
        "firebase.projects.update",
      ),
    ).join(),
    /permissions differ/u,
  );
  assert.match(
    check((c) => {
      find(c, "google_project_iam_member.n3c_fcm[0]").member = "allUsers";
    }).join(),
    /IAM mismatch/u,
  );
  assert.match(
    check((c) => {
      find(c, "google_project_iam_member.n3c_data[0]").condition = [];
    }).join(),
    /condition mismatch/u,
  );
  assert.match(
    check((c) =>
      c.push(
        change(
          "google_project_iam_member.extra[0]",
          "google_project_iam_member",
          { role: "roles/owner", member },
        ),
      ),
    ).join(),
    /unreviewed create/u,
  );
  assert.match(
    check((c) => {
      c[0].change.actions = ["delete"];
    }).join(),
    /forbidden action delete/u,
  );
  assert.match(check((c) => c.splice(5, 1)).join(), /reviewed create missing/u);
});

test("only the dev project, with N3c enabled", () => {
  const p = plan(changes());
  p.variables.n3c_enabled.value = false;
  assert.match(checkN3cPlan(p, expected(p)).join(), /must set n3c_enabled/u);
  const q = plan(changes());
  assert.match(
    checkN3cPlan(q, { ...expected(q), projectId: "recharge-prod" }).join(),
    /recharge-dev-n2a01 only/u,
  );
});
