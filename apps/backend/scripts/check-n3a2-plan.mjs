import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

import { inventoryDigest } from "./check-n3b-plan.mjs";

// Independent check of a serialized N3a.2 plan (terraform show -json); no
// Terraform or cloud execution. Everything that exists stays no-op/read; the
// only creates are the runtime-media account (manifest) and its exact grants:
// records and media objects without delete, the Firebase user reader, the
// tools secret and invoker on the two N3b services.
export { inventoryDigest };
const project = "recharge-dev-n2a01";
const member = `serviceAccount:runtime-media@${project}.iam.gserviceaccount.com`;
const creates = new Map([
  [
    'module.runtime_identities.google_service_account.account["runtime-media"]',
    { accountId: "runtime-media" },
  ],
  ["terraform_data.n3a2_guard[0]", {}],
  [
    "google_project_iam_custom_role.n3a2_data[0]",
    {
      permissions: [
        "datastore.databases.get",
        "datastore.entities.create",
        "datastore.entities.get",
        "datastore.entities.list",
        "datastore.entities.update",
      ],
    },
  ],
  [
    "google_project_iam_custom_role.n3a2_objects[0]",
    { permissions: ["storage.objects.create", "storage.objects.get"] },
  ],
  [
    "google_project_iam_member.n3a2_data[0]",
    {
      role: `projects/${project}/roles/devMediaChainData`,
      condition: `resource.name == "projects/${project}/databases/(default)"`,
    },
  ],
  [
    "google_storage_bucket_iam_member.n3a2_objects[0]",
    {
      role: `projects/${project}/roles/devMediaObjectWriter`,
      bucket: `${project}-media`,
    },
  ],
  [
    "google_project_iam_member.n3a2_auth[0]",
    { role: `projects/${project}/roles/devIdentityFirebaseVerifier` },
  ],
  [
    "google_secret_manager_secret_iam_member.n3a2_tools_token[0]",
    {
      role: "roles/secretmanager.secretAccessor",
      secretId: "MEDIA_TOOLS_TOKEN",
    },
  ],
  [
    'google_cloud_run_v2_service_iam_member.n3a2_invoker["media-scanner"]',
    { role: "roles/run.invoker", name: "media-scanner" },
  ],
  [
    'google_cloud_run_v2_service_iam_member.n3a2_invoker["media-processor"]',
    { role: "roles/run.invoker", name: "media-processor" },
  ],
]);

export function checkN3a2Plan(plan, expected) {
  const errors = [];
  const vars = plan?.variables ?? {};
  if (expected.projectId !== project)
    errors.push("N3a.2 targets recharge-dev-n2a01 only");
  if (vars.project_id?.value !== expected.projectId)
    errors.push("project mismatch");
  if (vars.n3a2_enabled?.value !== true || vars.n3b_enabled?.value !== true)
    errors.push("N3a.2 plan must set n3a2_enabled and keep n3b_enabled");
  if (vars.release_commit_sha?.value !== expected.commitSha)
    errors.push("source mismatch");
  if (inventoryDigest(plan) !== expected.inventorySha256)
    errors.push("reviewed inventory mismatch");
  const seen = new Set();
  for (const c of plan.resource_changes ?? []) {
    const actions = c.change?.actions ?? [];
    const after = c.change?.after ?? {};
    if (
      actions.length !== 1 ||
      !["create", "read", "no-op"].includes(actions[0])
    )
      errors.push(`forbidden action ${actions.join("+")}: ${c.address}`);
    if (actions[0] !== "create") continue;
    const rule = creates.get(c.address);
    if (rule === undefined) {
      errors.push(`unreviewed create: ${c.address}`);
      continue;
    }
    seen.add(c.address);
    const target = after.project ?? after.project_id;
    if (target && target !== project)
      errors.push(`foreign target: ${c.address}`);
    if (rule.accountId && after.account_id !== rule.accountId)
      errors.push(`account differs: ${c.address}`);
    if (
      rule.permissions &&
      JSON.stringify([...(after.permissions ?? [])].sort()) !==
        JSON.stringify(rule.permissions)
    )
      errors.push(`role permissions differ: ${c.address}`);
    if (rule.role) {
      if (after.role !== rule.role || after.member !== member)
        errors.push(`IAM mismatch: ${c.address}`);
      if (
        (after.condition?.[0]?.expression ?? null) !== (rule.condition ?? null)
      )
        errors.push(`IAM condition mismatch: ${c.address}`);
      if (rule.bucket && after.bucket !== rule.bucket)
        errors.push(`IAM mismatch: ${c.address}`);
      if (rule.secretId && after.secret_id !== rule.secretId)
        errors.push(`IAM mismatch: ${c.address}`);
      if (rule.name && after.name !== rule.name)
        errors.push(`IAM mismatch: ${c.address}`);
    }
  }
  for (const address of creates.keys())
    if (!seen.has(address)) errors.push(`reviewed create missing: ${address}`);
  return errors;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try {
    const plan = JSON.parse(readFileSync(process.argv[2], "utf8"));
    if (process.argv[3] === "--digest")
      process.stdout.write(inventoryDigest(plan) + "\n");
    else {
      const errors = checkN3a2Plan(
        plan,
        JSON.parse(readFileSync(process.argv[3], "utf8")),
      );
      if (errors.length) {
        process.stderr.write(errors.join("; ") + "\n");
        process.exitCode = 1;
      } else
        process.stdout.write(
          "Exact reviewed N3a.2 inventory verified locally; no apply authority granted.\n",
        );
    }
  } catch {
    process.stderr.write("Missing or invalid private plan/review input.\n");
    process.exitCode = 1;
  }
}
