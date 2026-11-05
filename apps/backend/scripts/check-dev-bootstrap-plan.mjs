import { pathToFileURL } from "node:url";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

// Independent check of the serialized plan; no Terraform or cloud execution.
export function checkBootstrapPlan(plan, expected) {
  const errors = [];
  const vars = plan?.variables ?? {};
  if (!/^recharge-dev-[a-z0-9]{4,20}$/u.test(expected.projectId ?? ""))
    errors.push("dev project required");
  if (vars.project_id?.value !== expected.projectId)
    errors.push("project mismatch");
  if (vars.billing_account_id?.value !== expected.billingAccountId)
    errors.push("billing mismatch");
  if (vars.manifest_sha256?.value !== expected.manifestSha256)
    errors.push("manifest mismatch");
  if (vars.release_commit_sha?.value !== expected.commitSha)
    errors.push("source mismatch");
  const changes = plan.resource_changes ?? [];
  const inventory = changes
    .map(({ address, type, change }) => ({
      address,
      type,
      actions: change.actions,
    }))
    .sort((a, b) => a.address.localeCompare(b.address));
  const digest = createHash("sha256")
    .update(JSON.stringify(inventory))
    .digest("hex");
  if (digest !== expected.inventorySha256)
    errors.push("reviewed inventory mismatch");
  for (const c of changes) {
    const actions = c.change?.actions ?? [];
    if (!(
      actions.length === 1 && ["create", "read", "no-op"].includes(actions[0])
    ))
      errors.push(`forbidden action: ${c.address}`);
    if (
      /service_account_key|google_project_iam|google_billing_account_iam/u.test(
        c.type,
      )
    )
      errors.push(`forbidden resource: ${c.address}`);
    const project = c.change?.after?.project ?? c.change?.after?.project_id;
    if (project && project !== expected.projectId)
      errors.push(`foreign target: ${c.address}`);
  }
  const byType = (type) => changes.filter((c) => c.type === type);
  if (byType("google_firebase_project").length !== 1)
    errors.push("Firebase registration missing");
  const pub = byType("google_pubsub_topic_iam_member");
  if (
    pub.length !== 1 ||
    pub[0].change.after.role !== "roles/pubsub.publisher" ||
    pub[0].change.after.member !==
      "serviceAccount:billing-budget-alerts@system.gserviceaccount.com"
  )
    errors.push("budget publisher mismatch");
  const wif = byType("google_iam_workload_identity_pool_provider");
  if (
    wif.length !== 1 ||
    wif[0].change.after.disabled !== true ||
    wif[0].change.after.attribute_condition !== "false"
  )
    errors.push("WIF must remain disabled");
  return errors;
}
if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try {
    const errors = checkBootstrapPlan(
      JSON.parse(readFileSync(process.argv[2], "utf8")),
      JSON.parse(readFileSync(process.argv[3], "utf8")),
    );
    if (errors.length) {
      process.stderr.write(errors.join("; ") + "\n");
      process.exitCode = 1;
    } else
      process.stdout.write(
        "Exact reviewed bootstrap inventory verified locally; no apply authority granted.\n",
      );
  } catch {
    process.stderr.write("Missing or invalid private plan/review input.\n");
    process.exitCode = 1;
  }
}
