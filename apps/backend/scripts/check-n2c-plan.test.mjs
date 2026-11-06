import test from "node:test";
import assert from "node:assert/strict";

import { checkN2cPlan, inventoryDigest } from "./check-n2c-plan.mjs";

const project = "recharge-dev-n2a01";
const runtime =
  "serviceAccount:runtime-identity@recharge-dev-n2a01.iam.gserviceaccount.com";
const build =
  "serviceAccount:420479958348-compute@developer.gserviceaccount.com";

function change(address, type, after, actions = ["create"]) {
  return { address, type, change: { actions, after } };
}

function plan(extra = []) {
  return {
    variables: {
      project_id: { value: project },
      n2c_enabled: { value: true },
      release_commit_sha: { value: "a".repeat(40) },
    },
    resource_changes: [
      change("google_project.dev", "google_project", { project_id: project }, [
        "no-op",
      ]),
      change("terraform_data.n2c_guard[0]", "terraform_data", {}),
      change(
        'google_project_service.n2c["run.googleapis.com"]',
        "google_project_service",
        { project },
      ),
      change(
        "google_identity_platform_config.n2c[0]",
        "google_identity_platform_config",
        {
          project,
          sign_in: [
            {
              email: [{ enabled: false }],
              anonymous: [{ enabled: false }],
              phone_number: [{ enabled: false }],
            },
          ],
        },
      ),
      change("google_apikeys_key.n2c_android[0]", "google_apikeys_key", {
        project,
        restrictions: [
          {
            android_key_restrictions: [
              {
                allowed_applications: [
                  { package_name: "com.recharge.app.recharge.dev" },
                ],
              },
            ],
          },
        ],
      }),
      change(
        "google_project_iam_member.n2c_runtime_auth[0]",
        "google_project_iam_member",
        { project, member: runtime },
      ),
      change(
        "google_project_iam_member.n2c_build_source[0]",
        "google_project_iam_member",
        {
          project,
          role: "roles/storage.objectViewer",
          member: build,
          condition: [
            {
              expression:
                'resource.name.startsWith("projects/_/buckets/gcf-v2-sources-420479958348-europe-west1")',
            },
          ],
        },
      ),
      change(
        "google_secret_manager_secret_iam_member.n2c_runtime_ingress[0]",
        "google_secret_manager_secret_iam_member",
        {
          project,
          role: "roles/secretmanager.secretAccessor",
          member: runtime,
        },
      ),
      ...extra,
    ],
  };
}

function expected(p) {
  return {
    projectId: project,
    commitSha: "a".repeat(40),
    inventorySha256: inventoryDigest(p),
  };
}

test("reviewed N2c infrastructure plan passes", () => {
  const p = plan();
  assert.deepEqual(checkN2cPlan(p, expected(p)), []);
});

test("updates, deletes and unreviewed creates are refused", () => {
  for (const extra of [
    change("google_project.dev", "google_project", { project_id: project }, [
      "update",
    ]),
    change(
      "module.firestore.google_firestore_database.default[0]",
      "google_firestore_database",
      { project },
      ["delete", "create"],
    ),
    change("google_pubsub_topic.extra", "google_pubsub_topic", { project }),
    change("google_project_iam_member.extra", "google_project_iam_member", {
      project,
      role: "roles/editor",
      member: build,
    }),
  ]) {
    const p = plan([extra]);
    assert.notDeepEqual(checkN2cPlan(p, expected(p)), []);
  }
});

test("Terraform-managed Functions, secret values, debug tokens and OAuth secrets never pass", () => {
  for (const type of [
    "google_cloudfunctions2_function",
    "google_cloud_run_v2_service",
    "google_secret_manager_secret_version",
    "google_firebase_app_check_debug_token",
    "google_identity_platform_default_supported_idp_config",
    "google_project_iam_binding",
  ]) {
    const p = plan([change(`${type}.x`, type, { project })]);
    assert.ok(
      checkN2cPlan(p, expected(p)).some((e) =>
        e.includes("forbidden resource type"),
      ),
      type,
    );
  }
});

test("IAM drift, dropped conditions, enabled sign-in and wide keys are refused", () => {
  const wrongMember = plan();
  wrongMember.resource_changes[5].change.after.member =
    "user:someone@example.com";
  assert.notDeepEqual(checkN2cPlan(wrongMember, expected(wrongMember)), []);
  const unconditioned = plan();
  delete unconditioned.resource_changes[6].change.after.condition;
  assert.notDeepEqual(checkN2cPlan(unconditioned, expected(unconditioned)), []);
  const phone = plan();
  phone.resource_changes[3].change.after.sign_in[0].phone_number[0].enabled = true;
  assert.notDeepEqual(checkN2cPlan(phone, expected(phone)), []);
  const key = plan();
  key.resource_changes[4].change.after.restrictions = [];
  assert.notDeepEqual(checkN2cPlan(key, expected(key)), []);
  const tampered = plan();
  assert.deepEqual(
    checkN2cPlan(tampered, {
      ...expected(tampered),
      inventorySha256: "0".repeat(64),
    }),
    ["reviewed inventory mismatch"],
  );
});

test("only an exact owner-reviewed delete passes; repository-level AR grant is checked", () => {
  const oldGrant = change(
    "google_project_iam_member.n2c_build_artifacts[0]",
    "google_project_iam_member",
    { project, role: "roles/artifactregistry.writer", member: build },
    ["delete"],
  );
  const repoGrant = change(
    "google_artifact_registry_repository_iam_member.n2c_build_artifacts[0]",
    "google_artifact_registry_repository_iam_member",
    { project, role: "roles/artifactregistry.writer", member: build },
  );
  const p = plan([oldGrant, repoGrant]);
  assert.notDeepEqual(checkN2cPlan(p, expected(p)), []);
  assert.deepEqual(
    checkN2cPlan(p, {
      ...expected(p),
      allowedDeletes: ["google_project_iam_member.n2c_build_artifacts[0]"],
    }),
    [],
  );
  const other = plan([
    change(
      "module.firestore.google_firestore_database.default[0]",
      "google_firestore_database",
      { project },
      ["delete"],
    ),
  ]);
  assert.notDeepEqual(
    checkN2cPlan(other, {
      ...expected(other),
      allowedDeletes: ["google_project_iam_member.n2c_build_artifacts[0]"],
    }),
    [],
  );
  const wide = plan([
    {
      ...repoGrant,
      change: {
        actions: ["create"],
        after: { project, role: "roles/artifactregistry.admin", member: build },
      },
    },
  ]);
  assert.notDeepEqual(checkN2cPlan(wide, expected(wide)), []);
});
