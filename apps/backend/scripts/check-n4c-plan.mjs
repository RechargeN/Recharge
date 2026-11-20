import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

import { inventoryDigest } from "./check-n3b-plan.mjs";
import { isReviewedProject } from "./runtime-projects.mjs";

// Independent check of a serialized N4c plan (terraform show -json); no
// Terraform or cloud execution. Everything that exists stays no-op/read; the
// only creates are the exact grants of the existing runtime-booking account:
// Firestore records on the default database (with delete, owner decision
// 2026-11-16) and the Firebase user reader. dev or staging, never production.
export { inventoryDigest };
const permissions = [
  "datastore.databases.get",
  "datastore.entities.create",
  "datastore.entities.delete",
  "datastore.entities.get",
  "datastore.entities.list",
  "datastore.entities.update",
];

function reviewedCreates(project) {
  return new Map([
    ["terraform_data.n4c_guard[0]", {}],
    ["google_project_iam_custom_role.n4c_data[0]", { permissions }],
    [
      "google_project_iam_member.n4c_data[0]",
      {
        role: `projects/${project}/roles/devBookingData`,
        condition: `resource.name == "projects/${project}/databases/(default)"`,
      },
    ],
    [
      "google_project_iam_member.n4c_auth[0]",
      { role: `projects/${project}/roles/devIdentityFirebaseVerifier` },
    ],
  ]);
}

/** Round 2 (owner approval 2026-11-19): only the Eventarc receiver grant. */
function roundTwoCreates() {
  return new Map([
    [
      "google_project_iam_member.n4c_eventarc[0]",
      { role: "roles/eventarc.eventReceiver" },
    ],
  ]);
}

/**
 * Round 3 (owner approval 2026-11-19): Eventarc invokes the two trigger
 * services as runtime-booking, so it may invoke exactly those two Cloud Run
 * services; no project-level grant.
 */
const invokerServices = new Map([
  [
    "google_cloud_run_v2_service_iam_member.n4c_invoker_effects[0]",
    "consumecontenteffectv1",
  ],
  [
    "google_cloud_run_v2_service_iam_member.n4c_invoker_outbox[0]",
    "consumeeventbookingoutboxv1",
  ],
]);
function roundThreeCreates() {
  return new Map(
    [...invokerServices].map(([address, name]) => [
      address,
      { role: "roles/run.invoker", serviceName: name },
    ]),
  );
}

export function checkN4cPlan(plan, expected) {
  const errors = [];
  const vars = plan?.variables ?? {};
  const project = expected.projectId;
  if (!isReviewedProject(project))
    return ["N4c targets the reviewed dev or staging project only"];
  const member = `serviceAccount:runtime-booking@${project}.iam.gserviceaccount.com`;
  const creates =
    expected.round === 3
      ? roundThreeCreates()
      : expected.round === 2
        ? roundTwoCreates()
        : reviewedCreates(project);
  if (vars.project_id?.value !== project) errors.push("project mismatch");
  if (vars.n4c_enabled?.value !== true || vars.n2c_enabled?.value !== true)
    errors.push("N4c plan must set n4c_enabled and keep n2c_enabled");
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
    }
    if (
      rule.serviceName !== undefined &&
      (after.name !== rule.serviceName || after.location !== "europe-west1")
    )
      errors.push(`invoker target mismatch: ${c.address}`);
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
      const errors = checkN4cPlan(
        plan,
        JSON.parse(readFileSync(process.argv[3], "utf8")),
      );
      if (errors.length) {
        process.stderr.write(errors.join("; ") + "\n");
        process.exitCode = 1;
      } else
        process.stdout.write(
          "Exact reviewed N4c inventory verified locally; no apply authority granted.\n",
        );
    }
  } catch {
    process.stderr.write("Missing or invalid private plan/review input.\n");
    process.exitCode = 1;
  }
}
