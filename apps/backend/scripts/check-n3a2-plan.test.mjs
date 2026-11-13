import test from "node:test";
import assert from "node:assert/strict";

import { checkN3a2Plan, inventoryDigest } from "./check-n3a2-plan.mjs";

const project = "recharge-dev-n2a01";
const member = `serviceAccount:runtime-media@${project}.iam.gserviceaccount.com`;
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
      'module.runtime_identities.google_service_account.account["runtime-media"]',
      "google_service_account",
      { project, account_id: "runtime-media" },
    ),
    change("terraform_data.n3a2_guard[0]", "terraform_data", {}),
    change(
      "google_project_iam_custom_role.n3a2_data[0]",
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
      "google_project_iam_custom_role.n3a2_objects[0]",
      "google_project_iam_custom_role",
      {
        project,
        permissions: ["storage.objects.get", "storage.objects.create"],
      },
    ),
    change(
      "google_project_iam_member.n3a2_data[0]",
      "google_project_iam_member",
      {
        project,
        role: `projects/${project}/roles/devMediaChainData`,
        member,
        condition: [
          {
            expression: `resource.name == "projects/${project}/databases/(default)"`,
          },
        ],
      },
    ),
    change(
      "google_storage_bucket_iam_member.n3a2_objects[0]",
      "google_storage_bucket_iam_member",
      {
        bucket: `${project}-media`,
        role: `projects/${project}/roles/devMediaObjectWriter`,
        member,
      },
    ),
    change(
      "google_project_iam_member.n3a2_auth[0]",
      "google_project_iam_member",
      {
        project,
        role: `projects/${project}/roles/devIdentityFirebaseVerifier`,
        member,
      },
    ),
    change(
      "google_secret_manager_secret_iam_member.n3a2_tools_token[0]",
      "google_secret_manager_secret_iam_member",
      {
        project,
        secret_id: "MEDIA_TOOLS_TOKEN",
        role: "roles/secretmanager.secretAccessor",
        member,
      },
    ),
    ...["media-scanner", "media-processor"].map((name) =>
      change(
        `google_cloud_run_v2_service_iam_member.n3a2_invoker["${name}"]`,
        "google_cloud_run_v2_service_iam_member",
        { project, name, role: "roles/run.invoker", member },
      ),
    ),
  ];
}
const plan = (resourceChanges) => ({
  variables: {
    project_id: { value: project },
    n3a2_enabled: { value: true },
    n3b_enabled: { value: true },
    release_commit_sha: { value: "a".repeat(40) },
  },
  resource_changes: resourceChanges,
});
const check = (mutate = () => {}) => {
  const c = changes();
  mutate(c);
  const p = plan(c);
  return checkN3a2Plan(p, {
    projectId: project,
    commitSha: "a".repeat(40),
    inventorySha256: inventoryDigest(p),
  });
};
const find = (c, address) => c.find((x) => x.address === address).change.after;

test("the reviewed N3a.2 inventory passes", () => {
  assert.deepEqual(check(), []);
});

test("no delete permission, no foreign member, no extra grant, nothing updated", () => {
  assert.match(
    check((c) =>
      find(c, "google_project_iam_custom_role.n3a2_data[0]").permissions.push(
        "datastore.entities.delete",
      ),
    ).join(),
    /permissions differ/u,
  );
  assert.match(
    check((c) =>
      find(
        c,
        "google_project_iam_custom_role.n3a2_objects[0]",
      ).permissions.push("storage.objects.delete"),
    ).join(),
    /permissions differ/u,
  );
  assert.match(
    check((c) => {
      find(c, "google_storage_bucket_iam_member.n3a2_objects[0]").member =
        "allUsers";
    }).join(),
    /IAM mismatch/u,
  );
  assert.match(
    check((c) => {
      find(c, "google_project_iam_member.n3a2_data[0]").condition = [];
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
      c[0].change.actions = ["update"];
    }).join(),
    /forbidden action update/u,
  );
  assert.match(check((c) => c.splice(5, 1)).join(), /reviewed create missing/u);
});
