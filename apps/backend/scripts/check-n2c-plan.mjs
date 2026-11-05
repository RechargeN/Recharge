import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

// Independent check of a serialized N2c plan (terraform show -json); no Terraform
// or cloud execution. Existing N2b objects may only be no-op/read; every create
// must be a reviewed N2c address; Functions stay with the Firebase CLI; secret
// values, debug tokens and OAuth client secrets never appear.
const n2cAddress =
  /^(terraform_data\.n2c_guard|google_project_service\.n2c|google_identity_platform_config\.n2c|google_apikeys_key\.n2c_android|google_firebase_android_app\.n2c_dev|module\.n2c_secret\.google_secret_manager_secret\.reference|google_project_iam_custom_role\.n2c_(auth_verify|session_data)|google_project_iam_member\.n2c_(runtime_auth|runtime_database|build_logging|build_source|build_artifacts)|google_secret_manager_secret_iam_member\.n2c_runtime_ingress)(\[.*\])?$/u;
const neverTypes =
  /secret_manager_secret_version|service_account_key|app_check_debug_token|default_supported_idp_config|inbound_saml_config|oauth_idp_config|cloudfunctions2?_function|cloud_run_v2_service|_iam_policy$|_iam_binding$|iam_audit_config|billing_account_iam/u;
const runtimeMember =
  "serviceAccount:runtime-identity@recharge-dev-n2a01.iam.gserviceaccount.com";
const buildMember =
  "serviceAccount:420479958348-compute@developer.gserviceaccount.com";
const fixed = {
  "google_secret_manager_secret_iam_member.n2c_runtime_ingress[0]": {
    role: "roles/secretmanager.secretAccessor",
    member: runtimeMember,
  },
  "google_project_iam_member.n2c_build_logging[0]": {
    role: "roles/logging.logWriter",
    member: buildMember,
  },
  "google_project_iam_member.n2c_build_source[0]": {
    role: "roles/storage.objectViewer",
    member: buildMember,
    condition:
      'resource.name.startsWith("projects/_/buckets/gcf-v2-sources-420479958348-europe-west1")',
  },
  "google_project_iam_member.n2c_build_artifacts[0]": {
    role: "roles/artifactregistry.writer",
    member: buildMember,
    condition:
      'resource.name.startsWith("projects/recharge-dev-n2a01/locations/europe-west1/repositories/gcf-artifacts")',
  },
  "google_project_iam_member.n2c_runtime_database[0]": {
    member: runtimeMember,
    condition:
      'resource.name == "projects/recharge-dev-n2a01/databases/(default)"',
  },
  "google_project_iam_member.n2c_runtime_auth[0]": { member: runtimeMember },
};

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

export function checkN2cPlan(plan, expected) {
  const errors = [];
  const vars = plan?.variables ?? {};
  if (expected.projectId !== "recharge-dev-n2a01")
    errors.push("N2c targets recharge-dev-n2a01 only");
  if (vars.project_id?.value !== expected.projectId)
    errors.push("project mismatch");
  if (vars.n2c_enabled?.value !== true)
    errors.push("N2c plan must set n2c_enabled");
  if (vars.release_commit_sha?.value !== expected.commitSha)
    errors.push("source mismatch");
  if (inventoryDigest(plan) !== expected.inventorySha256)
    errors.push("reviewed inventory mismatch");
  for (const c of plan.resource_changes ?? []) {
    const actions = c.change?.actions ?? [];
    const after = c.change?.after ?? {};
    if (
      actions.length !== 1 ||
      !["create", "read", "no-op"].includes(actions[0])
    )
      errors.push(`forbidden action ${actions.join("+")}: ${c.address}`);
    if (actions[0] === "create" && !n2cAddress.test(c.address))
      errors.push(`unreviewed create: ${c.address}`);
    if (neverTypes.test(c.type))
      errors.push(`forbidden resource type: ${c.address}`);
    const project = after.project ?? after.project_id;
    if (actions[0] === "create" && project && project !== expected.projectId)
      errors.push(`foreign target: ${c.address}`);
    const rule = fixed[c.address];
    if (rule) {
      if (
        (rule.role && after.role !== rule.role) ||
        after.member !== rule.member ||
        (after.condition?.[0]?.expression ?? null) !== (rule.condition ?? null)
      )
        errors.push(`IAM mismatch: ${c.address}`);
    } else if (/iam_member$/u.test(c.type) && actions[0] === "create")
      errors.push(`unreviewed IAM grant: ${c.address}`);
    if (c.type === "google_identity_platform_config") {
      const signIn = after.sign_in?.[0] ?? {};
      if (
        signIn.email?.[0]?.enabled !== false ||
        signIn.anonymous?.[0]?.enabled !== false ||
        signIn.phone_number?.[0]?.enabled !== false
      )
        errors.push("only console-enabled Google sign-in may exist");
    }
    if (c.type === "google_apikeys_key") {
      const apps =
        after.restrictions?.[0]?.android_key_restrictions?.[0]
          ?.allowed_applications ?? [];
      if (
        apps.length !== 1 ||
        apps[0].package_name !== "com.recharge.app.recharge.dev"
      )
        errors.push("API key must be restricted to the dev package");
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
      const errors = checkN2cPlan(
        plan,
        JSON.parse(readFileSync(process.argv[3], "utf8")),
      );
      if (errors.length) {
        process.stderr.write(errors.join("; ") + "\n");
        process.exitCode = 1;
      } else
        process.stdout.write(
          "Exact reviewed N2c inventory verified locally; no apply authority granted.\n",
        );
    }
  } catch {
    process.stderr.write("Missing or invalid private plan/review input.\n");
    process.exitCode = 1;
  }
}
