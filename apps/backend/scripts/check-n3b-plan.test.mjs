import test from "node:test";
import assert from "node:assert/strict";

import { checkN3bPlan, inventoryDigest } from "./check-n3b-plan.mjs";

const project = "recharge-dev-n2a01";
const sa = (name) =>
  `serviceAccount:${name}@${project}.iam.gserviceaccount.com`;
const email = (name) => `${name}@${project}.iam.gserviceaccount.com`;
const digest = `sha256:${"a".repeat(64)}`;
const image = `europe-west1-docker.pkg.dev/${project}/media-tools/media-tools@${digest}`;
const operatorEmail = "operator@example.invalid";

function change(address, type, after, actions = ["create"]) {
  return { address, type, change: { actions, after } };
}

const bucket = (name) => ({
  project,
  name,
  public_access_prevention: "enforced",
  uniform_bucket_level_access: true,
  force_destroy: false,
  lifecycle_rule: [],
  deletion_policy: "PREVENT",
});

function phase1() {
  return [
    change("google_project.dev", "google_project", { project_id: project }, [
      "no-op",
    ]),
    change("terraform_data.n3b_guard[0]", "terraform_data", {}),
    change(
      'google_project_service.n3b["cloudscheduler.googleapis.com"]',
      "google_project_service",
      { project },
    ),
    ...[
      "media-tools-build",
      "media-tools-scanner",
      "media-tools-processor",
      "clamav-mirror",
    ].map((name) =>
      change(
        `google_service_account.n3b["${name}"]`,
        "google_service_account",
        {
          project,
          account_id: name,
          deletion_policy: "PREVENT",
        },
      ),
    ),
    change(
      "google_artifact_registry_repository.n3b_media_tools[0]",
      "google_artifact_registry_repository",
      {
        project,
        repository_id: "media-tools",
        cleanup_policies: [],
        docker_config: [{ immutable_tags: true }],
        vulnerability_scanning_config: [{ enablement_config: "DISABLED" }],
      },
    ),
    change(
      "google_storage_bucket.n3b_clamav_mirror[0]",
      "google_storage_bucket",
      bucket(`${project}-clamav-mirror`),
    ),
    change(
      "google_storage_bucket.n3b_build_staging[0]",
      "google_storage_bucket",
      bucket(`${project}-media-tools-build`),
    ),
    change(
      'module.n3b_secret.google_secret_manager_secret.reference["MEDIA_TOOLS_TOKEN"]',
      "google_secret_manager_secret",
      { project, secret_id: "MEDIA_TOOLS_TOKEN" },
    ),
    change(
      "google_project_iam_custom_role.n3b_mirror_writer[0]",
      "google_project_iam_custom_role",
      {
        project,
        permissions: [
          "storage.objects.list",
          "storage.objects.create",
          "storage.objects.get",
        ],
      },
    ),
    change(
      "google_project_iam_member.n3b_build_logging[0]",
      "google_project_iam_member",
      {
        project,
        role: "roles/logging.logWriter",
        member: sa("media-tools-build"),
        condition: [],
      },
    ),
    change(
      "google_artifact_registry_repository_iam_member.n3b_build_push[0]",
      "google_artifact_registry_repository_iam_member",
      {
        project,
        repository: "media-tools",
        role: "roles/artifactregistry.writer",
        member: sa("media-tools-build"),
      },
    ),
    change(
      "google_storage_bucket_iam_member.n3b_build_source[0]",
      "google_storage_bucket_iam_member",
      {
        bucket: `${project}-media-tools-build`,
        role: "roles/storage.objectViewer",
        member: sa("media-tools-build"),
      },
    ),
    change(
      "google_storage_bucket_iam_member.n3b_scanner_mirror[0]",
      "google_storage_bucket_iam_member",
      {
        bucket: `${project}-clamav-mirror`,
        role: "roles/storage.objectViewer",
        member: sa("media-tools-scanner"),
      },
    ),
    change(
      "google_storage_bucket_iam_member.n3b_mirror_writer[0]",
      "google_storage_bucket_iam_member",
      {
        bucket: `${project}-clamav-mirror`,
        role: `projects/${project}/roles/devClamavMirrorWriter`,
        member: sa("clamav-mirror"),
      },
    ),
    ...["media-tools-scanner", "media-tools-processor"].map((name) =>
      change(
        `google_secret_manager_secret_iam_member.n3b_token["${name}"]`,
        "google_secret_manager_secret_iam_member",
        {
          project,
          role: "roles/secretmanager.secretAccessor",
          member: sa(name),
        },
      ),
    ),
  ];
}

const service = (mode, account, memory, concurrency, timeout) => ({
  project,
  ingress: "INGRESS_TRAFFIC_ALL",
  invoker_iam_disabled: false,
  deletion_protection: true,
  template: [
    {
      service_account: email(account),
      max_instance_request_concurrency: concurrency,
      timeout,
      scaling: [{ min_instance_count: 0, max_instance_count: 1 }],
      vpc_access: [],
      containers: [
        {
          image,
          resources: [{ cpu_idle: true, limits: { cpu: "1", memory } }],
          env: [
            { name: "RECHARGE_TOOLS_MODE", value: mode, value_source: [] },
            {
              name: "RECHARGE_TOOLS_TOKEN",
              value: null,
              value_source: [
                {
                  secret_key_ref: [
                    { secret: "MEDIA_TOOLS_TOKEN", version: "latest" },
                  ],
                },
              ],
            },
          ],
        },
      ],
    },
  ],
});

function phase2() {
  const existing = phase1()
    .filter((c) => c.address !== "google_project.dev")
    .map((c) => ({ ...c, change: { ...c.change, actions: ["no-op"] } }));
  return [
    ...existing,
    change(
      'google_cloud_run_v2_service.n3b["media-scanner"]',
      "google_cloud_run_v2_service",
      service("scanner", "media-tools-scanner", "4Gi", 2, "60s"),
    ),
    change(
      'google_cloud_run_v2_service.n3b["media-processor"]',
      "google_cloud_run_v2_service",
      service("processor", "media-tools-processor", "1Gi", 1, "30s"),
    ),
    ...["media-scanner", "media-processor"].map((name) =>
      change(
        `google_cloud_run_v2_service_iam_member.n3b_operator["${name}"]`,
        "google_cloud_run_v2_service_iam_member",
        { project, role: "roles/run.invoker", member: `user:${operatorEmail}` },
      ),
    ),
    change("google_cloud_run_v2_job.n3b_mirror[0]", "google_cloud_run_v2_job", {
      project,
      name: "clamav-mirror",
      template: [
        {
          template: [
            {
              service_account: email("clamav-mirror"),
              max_retries: 1,
              timeout: "900s",
              containers: [
                { image, resources: [{ limits: { cpu: "1", memory: "2Gi" } }] },
              ],
            },
          ],
        },
      ],
    }),
    change(
      "google_cloud_run_v2_job_iam_member.n3b_mirror_schedule[0]",
      "google_cloud_run_v2_job_iam_member",
      { project, role: "roles/run.invoker", member: sa("clamav-mirror") },
    ),
    change(
      "google_cloud_scheduler_job.n3b_mirror[0]",
      "google_cloud_scheduler_job",
      {
        project,
        schedule: "17 4 * * 1,4",
        http_target: [
          {
            uri: `https://run.googleapis.com/v2/projects/${project}/locations/europe-west1/jobs/clamav-mirror:run`,
            oauth_token: [{ service_account_email: email("clamav-mirror") }],
          },
        ],
      },
    ),
  ];
}

function plan(changes, imageDigest = "") {
  return {
    variables: {
      project_id: { value: project },
      n2c_enabled: { value: true },
      n3b_enabled: { value: true },
      n3b_image_digest: { value: imageDigest },
      release_commit_sha: { value: "a".repeat(40) },
    },
    resource_changes: changes,
  };
}

function expectedFor(p, extra = {}) {
  return {
    projectId: project,
    commitSha: "a".repeat(40),
    inventorySha256: inventoryDigest(p),
    ...extra,
  };
}

const phase2Expected = (p) =>
  expectedFor(p, { imageDigest: digest, image, operatorEmail });

test("phase 1 and phase 2 reviewed shapes pass", () => {
  const one = plan(phase1());
  assert.deepEqual(checkN3bPlan(one, expectedFor(one)), []);
  const two = plan(phase2(), digest);
  assert.deepEqual(checkN3bPlan(two, phase2Expected(two)), []);
});

function mutated(mutate, phase = 2) {
  const changes = phase === 2 ? phase2() : phase1();
  mutate(changes);
  const p = plan(changes, phase === 2 ? digest : "");
  return checkN3bPlan(p, phase === 2 ? phase2Expected(p) : expectedFor(p));
}
const find = (changes, address) =>
  changes.find((c) => c.address === address).change.after;
const scanner = 'google_cloud_run_v2_service.n3b["media-scanner"]';

test("services: min instances, public ingress settings, image and size are pinned", () => {
  assert.match(
    mutated((c) => {
      find(c, scanner).template[0].scaling[0].min_instance_count = 1;
    }).join(),
    /scale 0\.\.1/u,
  );
  assert.match(
    mutated((c) => {
      find(c, scanner).invoker_iam_disabled = true;
    }).join(),
    /IAM-gated/u,
  );
  assert.match(
    mutated((c) => {
      find(c, scanner).template[0].containers[0].image =
        "europe-west1-docker.pkg.dev/x/media-tools/media-tools:latest";
    }).join(),
    /recorded digest/u,
  );
  assert.match(
    mutated((c) => {
      find(c, scanner).template[0].containers[0].resources[0].cpu_idle = false;
    }).join(),
    /billing mode/u,
  );
  assert.match(
    mutated((c) => {
      find(c, scanner).template[0].containers[0].env[1] = {
        name: "RECHARGE_TOOLS_TOKEN",
        value: "f".repeat(64),
      };
    }).join(),
    /secret reference/u,
  );
});

test("IAM: public principals, other operators and unreviewed grants are refused", () => {
  assert.match(
    mutated((c) => {
      find(
        c,
        'google_cloud_run_v2_service_iam_member.n3b_operator["media-scanner"]',
      ).member = "allUsers";
    }).join(),
    /public principal/u,
  );
  assert.match(
    mutated((c) => {
      find(
        c,
        'google_cloud_run_v2_service_iam_member.n3b_operator["media-scanner"]',
      ).member = "user:someone@example.invalid";
    }).join(),
    /operator only/u,
  );
  assert.match(
    mutated((c) => {
      find(c, "google_project_iam_member.n3b_build_logging[0]").role =
        "roles/editor";
    }, 1).join(),
    /IAM mismatch/u,
  );
  assert.match(
    mutated((c) => {
      c.push(
        change(
          "google_project_iam_member.n3b_extra[0]",
          "google_project_iam_member",
          { project, role: "roles/storage.admin", member: sa("clamav-mirror") },
        ),
      );
    }, 1).join(),
    /unreviewed create.*unreviewed IAM grant/u,
  );
});

test("nothing is deleted, cleaned up or updated; no secret value or key", () => {
  assert.match(
    mutated((c) => {
      find(
        c,
        "google_artifact_registry_repository.n3b_media_tools[0]",
      ).cleanup_policies = [{ id: "keep-2" }];
    }, 1).join(),
    /keep every image/u,
  );
  assert.match(
    mutated((c) => {
      find(c, "google_storage_bucket.n3b_clamav_mirror[0]").lifecycle_rule = [
        { action: [{ type: "Delete" }] },
      ];
    }, 1).join(),
    /append-only/u,
  );
  assert.match(
    mutated((c) => {
      find(
        c,
        "google_project_iam_custom_role.n3b_mirror_writer[0]",
      ).permissions.push("storage.objects.delete");
    }, 1).join(),
    /append-only/u,
  );
  assert.match(
    mutated((c) => {
      c[0].change.actions = ["delete", "create"];
    }, 1).join(),
    /forbidden action delete\+create/u,
  );
  assert.match(
    mutated((c) => {
      c.push(
        change(
          "module.n3b_secret.google_secret_manager_secret_version.value[0]",
          "google_secret_manager_secret_version",
          { secret_data: "x" },
        ),
      );
    }, 1).join(),
    /forbidden resource type/u,
  );
});

test("inputs: digest, project and inventory must match the review", () => {
  const two = plan(phase2(), digest);
  assert.match(
    checkN3bPlan(two, {
      ...phase2Expected(two),
      imageDigest: `sha256:${"b".repeat(64)}`,
    }).join(),
    /image digest mismatch/u,
  );
  assert.match(
    checkN3bPlan(two, { ...phase2Expected(two), inventorySha256: "0" }).join(),
    /inventory mismatch/u,
  );
  assert.match(
    checkN3bPlan(two, {
      ...phase2Expected(two),
      projectId: "recharge-prod",
    }).join(),
    /recharge-dev-n2a01 only/u,
  );
});

const identityUpdate = (afterSignIn, extra = {}) => ({
  address: "google_identity_platform_config.n2c[0]",
  type: "google_identity_platform_config",
  change: {
    actions: ["update"],
    before: {
      project,
      authorized_domains: ["a"],
      sign_in: [
        {
          email: [{ enabled: true, password_required: false }],
          anonymous: [{ enabled: true }],
          phone_number: [{ enabled: false }],
        },
      ],
    },
    after: {
      project,
      authorized_domains: ["a"],
      sign_in: [afterSignIn],
      ...extra,
    },
    after_unknown: {},
  },
});
const disabled = {
  email: [{ enabled: false, password_required: true }],
  anonymous: [{ enabled: false }],
  phone_number: [{ enabled: false }],
};

test("the one reviewed update: console-enabled email/anonymous sign-in goes back to disabled", () => {
  const changes = [...phase1(), identityUpdate(disabled)];
  const p = plan(changes);
  assert.deepEqual(
    checkN3bPlan(p, {
      ...expectedFor(p),
      allowedUpdates: ["google_identity_platform_config.n2c[0]"],
    }),
    [],
  );
  // Not listed in the review: refused.
  assert.match(
    checkN3bPlan(p, expectedFor(p)).join(),
    /forbidden action update/u,
  );
});

test("the reviewed update cannot enable anything or touch other fields", () => {
  for (const change of [
    identityUpdate({ ...disabled, anonymous: [{ enabled: true }] }),
    identityUpdate({ ...disabled, phone_number: [{ enabled: true }] }),
    identityUpdate(disabled, { authorized_domains: ["a", "evil.example"] }),
  ]) {
    const p = plan([...phase1(), change]);
    assert.match(
      checkN3bPlan(p, {
        ...expectedFor(p),
        allowedUpdates: ["google_identity_platform_config.n2c[0]"],
      }).join(),
      /forbidden action update/u,
    );
  }
});

test("the provider's empty string for an unset secret value is accepted; a literal is not", () => {
  assert.deepEqual(
    mutated((c) => {
      find(c, scanner).template[0].containers[0].env[1].value = "";
    }),
    [],
  );
  assert.match(
    mutated((c) => {
      find(c, scanner).template[0].containers[0].env[1].value = "0".repeat(64);
    }).join(),
    /secret reference/u,
  );
});
