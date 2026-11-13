import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

import { inventoryDigest } from "./check-n3b-plan.mjs";

// N4a (owner-approved 2026-11-13): independent policy check of a serialized
// staging bootstrap plan (terraform show -json). No Terraform or cloud call.
// The staging root is a reviewed copy of dev, so the check is a policy over
// every change instead of a second address list: create/read/no-op only, the
// staging project only, no delete permission or automatic deletion, no basic
// role or public member, budget €5 as an alert, Cloud Run 0..1 instance.
export { inventoryDigest };
export const stagingProject = "recharge-staging-y9y2y";
const basicRoles = new Set(["roles/owner", "roles/editor", "roles/viewer"]);
const publicMembers = new Set(["allUsers", "allAuthenticatedUsers"]);
const googleAgents =
  /^serviceAccount:(service-[0-9]+@[a-z-]+\.iam\.gserviceaccount\.com|billing-budget-alert@system\.gserviceaccount\.com|[0-9]+-compute@developer\.gserviceaccount\.com)$/u;

function memberOk(member, role) {
  if (typeof member !== "string") return true; // unknown until apply
  if (publicMembers.has(member)) return false;
  if (member.startsWith("serviceAccount:"))
    return (
      member.endsWith(`@${stagingProject}.iam.gserviceaccount.com`) ||
      googleAgents.test(member)
    );
  // The owner's own account: only to invoke the two tool services (N3b smoke).
  if (member.startsWith("user:")) return role === "roles/run.invoker";
  return false;
}

export function checkN4aPlan(plan, expected) {
  const errors = [];
  const vars = plan?.variables ?? {};
  if (expected.projectId !== stagingProject)
    errors.push("N4a targets recharge-staging-y9y2y only");
  if (vars.project_id?.value !== stagingProject)
    errors.push("project mismatch");
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
    if (actions[0] !== "create") continue;
    const target = after.project ?? after.project_id;
    if (typeof target === "string" && target !== stagingProject)
      errors.push(`foreign project: ${c.address}`);
    if (typeof after.role === "string" && basicRoles.has(after.role))
      errors.push(`basic role: ${c.address}`);
    if ("member" in after && !memberOk(after.member, after.role))
      errors.push(`member not allowed: ${c.address}`);
    if (
      Array.isArray(after.permissions) &&
      after.permissions.some((p) => /\.delete$|\.purge$/u.test(p))
    )
      errors.push(`delete permission: ${c.address}`);
    if (c.type === "google_storage_bucket") {
      const deletes = (after.lifecycle_rule ?? []).some((rule) =>
        (rule.action ?? []).some((a) => a.type === "Delete"),
      );
      if (deletes) errors.push(`automatic deletion: ${c.address}`);
    }
    if (c.type === "google_firestore_field" && after.ttl_config?.length)
      errors.push(`TTL field: ${c.address}`);
    if (c.type === "google_billing_budget") {
      const units = after.amount?.[0]?.specified_amount?.[0]?.units;
      const currency = after.amount?.[0]?.specified_amount?.[0]?.currency_code;
      if (
        String(units) !== "5" ||
        (currency !== undefined && currency !== "EUR")
      )
        errors.push(`budget is not €5: ${c.address}`);
    }
    if (c.type === "google_cloud_run_v2_service") {
      const scaling = after.template?.[0]?.scaling?.[0] ?? {};
      if (
        (scaling.min_instance_count ?? 0) !== 0 ||
        (scaling.max_instance_count ?? 1) > 1
      )
        errors.push(`Cloud Run scaling beyond 0..1: ${c.address}`);
    }
    if (c.type === "google_project" && after.deletion_policy !== "PREVENT")
      errors.push(`project deletion not prevented: ${c.address}`);
  }
  return errors;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try {
    const plan = JSON.parse(readFileSync(process.argv[2], "utf8"));
    if (process.argv[3] === "--digest")
      process.stdout.write(inventoryDigest(plan) + "\n");
    else {
      const errors = checkN4aPlan(
        plan,
        JSON.parse(readFileSync(process.argv[3], "utf8")),
      );
      if (errors.length) {
        process.stderr.write(errors.join("; ") + "\n");
        process.exitCode = 1;
      } else
        process.stdout.write(
          "Staging plan passes the N4a policy locally; no apply authority granted.\n",
        );
    }
  } catch {
    process.stderr.write("Missing or invalid private plan/review input.\n");
    process.exitCode = 1;
  }
}
