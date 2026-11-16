import test from "node:test";
import assert from "node:assert/strict";

import { checkN4cPlan, inventoryDigest } from "./check-n4c-plan.mjs";

const change = (address, type, after, actions = ["create"]) => ({
  address,
  type,
  change: { actions, after },
});

function changes(project) {
  const member = `serviceAccount:runtime-booking@${project}.iam.gserviceaccount.com`;
  return [
    change("google_project.dev", "google_project", { project_id: project }, [
      "no-op",
    ]),
    change(
      'module.runtime_identities.google_service_account.account["runtime-booking"]',
      "google_service_account",
      { project, account_id: "runtime-booking" },
      ["no-op"],
    ),
    change("terraform_data.n4c_guard[0]", "terraform_data", {}),
    change(
      "google_project_iam_custom_role.n4c_data[0]",
      "google_project_iam_custom_role",
      {
        project,
        permissions: [
          "datastore.entities.update",
          "datastore.entities.delete",
          "datastore.databases.get",
          "datastore.entities.create",
          "datastore.entities.get",
          "datastore.entities.list",
        ],
      },
    ),
    change(
      "google_project_iam_member.n4c_data[0]",
      "google_project_iam_member",
      {
        project,
        role: `projects/${project}/roles/devBookingData`,
        member,
        condition: [
          {
            expression: `resource.name == "projects/${project}/databases/(default)"`,
          },
        ],
      },
    ),
    change(
      "google_project_iam_member.n4c_auth[0]",
      "google_project_iam_member",
      {
        project,
        role: `projects/${project}/roles/devIdentityFirebaseVerifier`,
        member,
      },
    ),
  ];
}
const plan = (project, resourceChanges) => ({
  variables: {
    project_id: { value: project },
    n4c_enabled: { value: true },
    n2c_enabled: { value: true },
    release_commit_sha: { value: "a".repeat(40) },
  },
  resource_changes: resourceChanges,
});
const expected = (project, p) => ({
  projectId: project,
  commitSha: "a".repeat(40),
  inventorySha256: inventoryDigest(p),
});
const check = (project, mutate = () => {}) => {
  const c = changes(project);
  mutate(c);
  const p = plan(project, c);
  return checkN4cPlan(p, expected(project, p));
};
const find = (c, address) => c.find((x) => x.address === address).change.after;
const dev = "recharge-dev-n2a01";

test("the reviewed N4c inventory passes for dev and for staging", () => {
  assert.deepEqual(check(dev), []);
  assert.deepEqual(check("recharge-staging-y9y2y"), []);
});

test("no wider role, no foreign member, no extra grant, nothing removed", () => {
  assert.match(
    check(dev, (c) =>
      find(c, "google_project_iam_custom_role.n4c_data[0]").permissions.push(
        "datastore.databases.update",
      ),
    ).join(),
    /permissions differ/u,
  );
  assert.match(
    check(dev, (c) => {
      find(c, "google_project_iam_member.n4c_auth[0]").member = "allUsers";
    }).join(),
    /IAM mismatch/u,
  );
  assert.match(
    check(dev, (c) => {
      find(c, "google_project_iam_member.n4c_data[0]").condition = [];
    }).join(),
    /condition mismatch/u,
  );
  assert.match(
    check(dev, (c) =>
      c.push(
        change(
          "google_project_iam_member.extra[0]",
          "google_project_iam_member",
          { role: "roles/owner", member: "user:someone@example.invalid" },
        ),
      ),
    ).join(),
    /unreviewed create/u,
  );
  assert.match(
    check(dev, (c) => {
      c[0].change.actions = ["delete"];
    }).join(),
    /forbidden action delete/u,
  );
  assert.match(
    check(dev, (c) => {
      c[1].change.actions = ["update"];
    }).join(),
    /forbidden action update/u,
  );
  assert.match(
    check(dev, (c) => c.splice(4, 1)).join(),
    /reviewed create missing/u,
  );
});

test("only a reviewed project, with N4c enabled", () => {
  const p = plan(dev, changes(dev));
  p.variables.n4c_enabled.value = false;
  assert.match(
    checkN4cPlan(p, expected(dev, p)).join(),
    /must set n4c_enabled/u,
  );
  const q = plan(dev, changes(dev));
  assert.match(
    checkN4cPlan(q, {
      ...expected(dev, q),
      projectId: "recharge-prod",
    }).join(),
    /reviewed dev or staging project only/u,
  );
  // A staging plan checked against the dev expectation is refused.
  const s = plan("recharge-staging-y9y2y", changes("recharge-staging-y9y2y"));
  assert.match(checkN4cPlan(s, expected(dev, s)).join(), /project mismatch/u);
});
