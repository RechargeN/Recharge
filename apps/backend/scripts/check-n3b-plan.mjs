import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

// Independent check of a serialized N3b plan (terraform show -json); no Terraform
// or cloud execution. Everything that exists stays no-op/read (nothing is updated,
// replaced or deleted); every create is a reviewed N3b address with the reviewed
// shape: private IAM-gated Cloud Run at 0..1 instances pinned to the recorded
// digest, append-only buckets and repository without cleanup, resource-level
// grants only, and never a secret value, key or allUsers.
const n3bAddress =
  /^(terraform_data\.n3b_guard|google_project_service\.n3b|google_service_account\.n3b|google_artifact_registry_repository\.n3b_media_tools|google_storage_bucket\.n3b_(clamav_mirror|build_staging)|module\.n3b_secret\.google_secret_manager_secret\.reference|google_project_iam_custom_role\.n3b_mirror_writer|google_project_iam_member\.n3b_build_logging|google_artifact_registry_repository_iam_member\.n3b_build_push|google_storage_bucket_iam_member\.n3b_(build_source|scanner_mirror|mirror_writer)|google_secret_manager_secret_iam_member\.n3b_token|google_cloud_run_v2_service\.n3b|google_cloud_run_v2_service_iam_member\.n3b_operator|google_cloud_run_v2_job\.n3b_mirror|google_cloud_run_v2_job_iam_member\.n3b_mirror_schedule|google_cloud_scheduler_job\.n3b_mirror)(\[.*\])?$/u;
const neverTypes =
  /secret_manager_secret_version|service_account_key|_iam_policy$|_iam_binding$|iam_audit_config|billing_account_iam|cloudfunctions2?_function|google_cloud_run_service$|cloud_run_v2_worker_pool|cloudbuild_trigger|^google_compute_|vpc_access_connector|container_analysis|binary_authorization/u;
const project = "recharge-dev-n2a01";
const sa = (name) =>
  `serviceAccount:${name}@${project}.iam.gserviceaccount.com`;
const accounts = [
  "media-tools-build",
  "media-tools-scanner",
  "media-tools-processor",
  "clamav-mirror",
];
const fixedIam = {
  "google_project_iam_member.n3b_build_logging[0]": {
    role: "roles/logging.logWriter",
    member: sa("media-tools-build"),
  },
  "google_artifact_registry_repository_iam_member.n3b_build_push[0]": {
    role: "roles/artifactregistry.writer",
    member: sa("media-tools-build"),
    repository: "media-tools",
  },
  "google_storage_bucket_iam_member.n3b_build_source[0]": {
    role: "roles/storage.objectViewer",
    member: sa("media-tools-build"),
    bucket: `${project}-media-tools-build`,
  },
  "google_storage_bucket_iam_member.n3b_scanner_mirror[0]": {
    role: "roles/storage.objectViewer",
    member: sa("media-tools-scanner"),
    bucket: `${project}-clamav-mirror`,
  },
  "google_storage_bucket_iam_member.n3b_mirror_writer[0]": {
    role: `projects/${project}/roles/devClamavMirrorWriter`,
    member: sa("clamav-mirror"),
    bucket: `${project}-clamav-mirror`,
  },
  'google_secret_manager_secret_iam_member.n3b_token["media-tools-scanner"]': {
    role: "roles/secretmanager.secretAccessor",
    member: sa("media-tools-scanner"),
  },
  'google_secret_manager_secret_iam_member.n3b_token["media-tools-processor"]':
    {
      role: "roles/secretmanager.secretAccessor",
      member: sa("media-tools-processor"),
    },
  "google_cloud_run_v2_job_iam_member.n3b_mirror_schedule[0]": {
    role: "roles/run.invoker",
    member: sa("clamav-mirror"),
  },
};
const services = {
  'google_cloud_run_v2_service.n3b["media-scanner"]': {
    account: "media-tools-scanner",
    memory: "4Gi",
    concurrency: 2,
    timeout: "60s",
    mode: "scanner",
  },
  'google_cloud_run_v2_service.n3b["media-processor"]': {
    account: "media-tools-processor",
    memory: "1Gi",
    concurrency: 1,
    timeout: "30s",
    mode: "processor",
  },
};
const publicMembers = /^(allUsers|allAuthenticatedUsers)$/u;

// The one existing-resource update N3b may carry (owner decision 2026-11-07):
// Firebase Auth email/anonymous sign-in, enabled by hand in the console, goes
// back to the reviewed N2c state (disabled). Nothing else may differ.
const reviewedUpdates = {
  "google_identity_platform_config.n2c[0]": {
    paths: new Set([
      "sign_in[0].email[0].enabled",
      "sign_in[0].email[0].password_required",
      "sign_in[0].anonymous[0].enabled",
    ]),
    check: (after) => {
      const signIn = after.sign_in?.[0] ?? {};
      return (
        signIn.email?.[0]?.enabled === false &&
        signIn.anonymous?.[0]?.enabled === false &&
        signIn.phone_number?.[0]?.enabled === false
      );
    },
  },
  // Image roll to the recorded digest (2026-11-07: clamd LogFile fix). Only the
  // image may change; the full service/job shape is checked below as for a create.
  ...Object.fromEntries(
    [
      'google_cloud_run_v2_service.n3b["media-scanner"]',
      'google_cloud_run_v2_service.n3b["media-processor"]',
    ].map((address) => [
      address,
      {
        paths: new Set(["template[0].containers[0].image"]),
        check: (after, expected) =>
          after.template?.[0]?.containers?.[0]?.image === expected.image,
      },
    ]),
  ),
  "google_cloud_run_v2_job.n3b_mirror[0]": {
    paths: new Set(["template[0].template[0].containers[0].image"]),
    check: (after, expected) =>
      after.template?.[0]?.template?.[0]?.containers?.[0]?.image ===
      expected.image,
  },
};

/** True when Terraform marks the path (or a parent) as known only after apply. */
function unknownAt(unknown, path) {
  let node = unknown;
  for (const token of path.match(/[^.[\]]+/gu) ?? []) {
    if (node === true) return true;
    if (node === null || typeof node !== "object") return false;
    node = node[/^\d+$/u.test(token) ? Number(token) : token];
  }
  return node === true;
}

function differingPaths(before, after, prefix = "", out = []) {
  if (
    Array.isArray(before) &&
    Array.isArray(after) &&
    before.length === after.length
  ) {
    before.forEach((item, index) =>
      differingPaths(item, after[index], `${prefix}[${index}]`, out),
    );
  } else if (
    before !== null &&
    after !== null &&
    typeof before === "object" &&
    typeof after === "object" &&
    !Array.isArray(before) &&
    !Array.isArray(after)
  ) {
    for (const key of new Set([...Object.keys(before), ...Object.keys(after)]))
      differingPaths(
        before[key],
        after[key],
        prefix ? `${prefix}.${key}` : key,
        out,
      );
  } else if (JSON.stringify(before) !== JSON.stringify(after)) out.push(prefix);
  return out;
}

/** An update is allowed only when the review lists it and its diff is exactly the reviewed one. */
function reviewedUpdate(c, expected) {
  const rule = reviewedUpdates[c.address];
  if (!rule || !(expected.allowedUpdates ?? []).includes(c.address))
    return false;
  // Computed attributes that refresh on apply are not configuration changes.
  const paths = differingPaths(
    c.change?.before ?? {},
    c.change?.after ?? {},
  ).filter((item) => !unknownAt(c.change?.after_unknown ?? {}, item));
  return (
    paths.length > 0 &&
    paths.every((item) => rule.paths.has(item)) &&
    rule.check(c.change.after, expected)
  );
}

export function inventoryDigest(plan) {
  const inventory = (plan.resource_changes ?? [])
    .map(({ address, type, change }) => ({
      address,
      type,
      actions: change.actions,
    }))
    .sort((a, b) => a.address.localeCompare(b.address));
  return createHash("sha256").update(JSON.stringify(inventory)).digest("hex");
}

function checkService(address, after, expected, errors) {
  const rule = services[address];
  const template = after.template?.[0] ?? {};
  const container = template.containers?.[0] ?? {};
  const resources = container.resources?.[0] ?? {};
  const scaling = template.scaling?.[0] ?? {};
  const env = Object.fromEntries(
    (container.env ?? []).map((item) => [item.name, item]),
  );
  if (
    after.ingress !== "INGRESS_TRAFFIC_ALL" ||
    after.invoker_iam_disabled !== false ||
    after.deletion_protection !== true
  )
    errors.push(`service must stay IAM-gated and protected: ${address}`);
  if (scaling.min_instance_count !== 0 || scaling.max_instance_count !== 1)
    errors.push(`service must scale 0..1: ${address}`);
  if (
    resources.cpu_idle !== true ||
    resources.limits?.cpu !== "1" ||
    resources.limits?.memory !== rule.memory ||
    template.max_instance_request_concurrency !== rule.concurrency ||
    template.timeout !== rule.timeout
  )
    errors.push(`service size or billing mode differs: ${address}`);
  if (container.image !== expected.image)
    errors.push(`service image is not the recorded digest: ${address}`);
  if (
    template.service_account !==
    `${rule.account}@${project}.iam.gserviceaccount.com`
  )
    errors.push(`service identity differs: ${address}`);
  if (
    env.RECHARGE_TOOLS_MODE?.value !== rule.mode ||
    // The provider renders an unset value as ""; only a secret reference may carry it.
    ![null, ""].includes(env.RECHARGE_TOOLS_TOKEN?.value) ||
    env.RECHARGE_TOOLS_TOKEN?.value_source?.[0]?.secret_key_ref?.[0]?.secret !==
      "MEDIA_TOOLS_TOKEN"
  )
    errors.push(`service mode or secret reference differs: ${address}`);
  if ((template.vpc_access ?? []).length > 0)
    errors.push(`unreviewed VPC access: ${address}`);
}

export function checkN3bPlan(plan, expected) {
  const errors = [];
  const vars = plan?.variables ?? {};
  if (expected.projectId !== project)
    errors.push("N3b targets recharge-dev-n2a01 only");
  if (vars.project_id?.value !== expected.projectId)
    errors.push("project mismatch");
  if (vars.n3b_enabled?.value !== true || vars.n2c_enabled?.value !== true)
    errors.push("N3b plan must set n3b_enabled and keep n2c_enabled");
  if (vars.release_commit_sha?.value !== expected.commitSha)
    errors.push("source mismatch");
  if ((vars.n3b_image_digest?.value ?? "") !== (expected.imageDigest ?? ""))
    errors.push("image digest mismatch");
  if (
    expected.imageDigest &&
    expected.image !==
      `europe-west1-docker.pkg.dev/${project}/media-tools/media-tools@${expected.imageDigest}`
  )
    errors.push("expected image must be the repository image at the digest");
  if (inventoryDigest(plan) !== expected.inventorySha256)
    errors.push("reviewed inventory mismatch");
  for (const c of plan.resource_changes ?? []) {
    const actions = c.change?.actions ?? [];
    const after = c.change?.after ?? {};
    const allowedUpdate =
      actions.length === 1 &&
      actions[0] === "update" &&
      reviewedUpdate(c, expected);
    if (
      !allowedUpdate &&
      (actions.length !== 1 ||
        !["create", "read", "no-op"].includes(actions[0]))
    )
      errors.push(`forbidden action ${actions.join("+")}: ${c.address}`);
    if (neverTypes.test(c.type))
      errors.push(`forbidden resource type: ${c.address}`);
    if (actions[0] !== "create" && !allowedUpdate) continue;
    if (actions[0] === "create" && !n3bAddress.test(c.address))
      errors.push(`unreviewed create: ${c.address}`);
    const target = after.project ?? after.project_id;
    if (target && target !== expected.projectId)
      errors.push(`foreign target: ${c.address}`);
    if (publicMembers.test(after.member ?? ""))
      errors.push(`public principal: ${c.address}`);
    const rule = fixedIam[c.address];
    if (rule) {
      if (
        after.role !== rule.role ||
        after.member !== rule.member ||
        (rule.bucket && after.bucket !== rule.bucket) ||
        (rule.repository && after.repository !== rule.repository) ||
        (after.condition ?? []).length > 0
      )
        errors.push(`IAM mismatch: ${c.address}`);
    } else if (c.type === "google_cloud_run_v2_service_iam_member") {
      if (
        after.role !== "roles/run.invoker" ||
        after.member !== `user:${expected.operatorEmail}`
      )
        errors.push(`invoker must be the operator only: ${c.address}`);
    } else if (/iam_member$/u.test(c.type))
      errors.push(`unreviewed IAM grant: ${c.address}`);
    if (c.type === "google_service_account") {
      const id = /\["([^"]+)"\]$/u.exec(c.address)?.[1];
      if (!accounts.includes(id) || after.deletion_policy !== "PREVENT")
        errors.push(`unreviewed service account: ${c.address}`);
    }
    if (c.type === "google_project_iam_custom_role") {
      const permissions = [...(after.permissions ?? [])].sort();
      if (
        JSON.stringify(permissions) !==
        JSON.stringify([
          "storage.objects.create",
          "storage.objects.get",
          "storage.objects.list",
        ])
      )
        errors.push("mirror role must stay append-only");
    }
    if (c.type === "google_storage_bucket") {
      if (
        after.public_access_prevention !== "enforced" ||
        after.uniform_bucket_level_access !== true ||
        after.force_destroy !== false ||
        (after.lifecycle_rule ?? []).length > 0 ||
        after.deletion_policy !== "PREVENT"
      )
        errors.push(`bucket must be private and append-only: ${c.address}`);
    }
    if (c.type === "google_artifact_registry_repository") {
      if (
        (after.cleanup_policies ?? []).length > 0 ||
        after.docker_config?.[0]?.immutable_tags !== true ||
        after.vulnerability_scanning_config?.[0]?.enablement_config !==
          "DISABLED" ||
        after.repository_id !== "media-tools"
      )
        errors.push(
          "repository must keep every image, immutable tags, no paid scanning",
        );
    }
    if (c.type === "google_cloud_run_v2_service") {
      if (!services[c.address]) errors.push(`unreviewed service: ${c.address}`);
      else checkService(c.address, after, expected, errors);
    }
    if (c.type === "google_cloud_run_v2_job") {
      const task = after.template?.[0]?.template?.[0] ?? {};
      const container = task.containers?.[0] ?? {};
      if (
        after.name !== "clamav-mirror" ||
        task.service_account !==
          `clamav-mirror@${project}.iam.gserviceaccount.com` ||
        container.image !== expected.image ||
        task.max_retries !== 1 ||
        task.timeout !== "900s" ||
        container.resources?.[0]?.limits?.memory !== "2Gi"
      )
        errors.push(`mirror job differs: ${c.address}`);
    }
    if (c.type === "google_cloud_scheduler_job") {
      const target = after.http_target?.[0] ?? {};
      if (
        after.schedule !== "17 4 * * 1,4" ||
        target.uri !==
          `https://run.googleapis.com/v2/projects/${project}/locations/europe-west1/jobs/clamav-mirror:run` ||
        target.oauth_token?.[0]?.service_account_email !==
          `clamav-mirror@${project}.iam.gserviceaccount.com`
      )
        errors.push(`schedule differs: ${c.address}`);
    }
  }
  return errors;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try {
    const plan = JSON.parse(readFileSync(process.argv[2], "utf8"));
    if (process.argv[3] === "--digest") {
      process.stdout.write(inventoryDigest(plan) + "\n");
    } else {
      const errors = checkN3bPlan(
        plan,
        JSON.parse(readFileSync(process.argv[3], "utf8")),
      );
      if (errors.length) {
        process.stderr.write(errors.join("; ") + "\n");
        process.exitCode = 1;
      } else
        process.stdout.write(
          "Exact reviewed N3b inventory verified locally; no apply authority granted.\n",
        );
    }
  } catch {
    process.stderr.write("Missing or invalid private plan/review input.\n");
    process.exitCode = 1;
  }
}
