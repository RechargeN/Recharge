import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

import { inventoryDigest } from "./check-n3b-plan.mjs";

// Independent check of a serialized N4e plan (terraform show -json); no
// Terraform or cloud execution. Staging only. Everything that exists stays
// no-op/read; the only creates are the reviewed monitoring resources, and every
// alert policy notifies the one existing staging e-mail channel.
export { inventoryDigest };
export const project = "recharge-staging-y9y2y";
export const devProject = "recharge-dev-n2a01";
const slos = [
  "auth-availability",
  "commands-availability",
  "reads-availability",
  "commands-latency",
  "reads-latency",
];
export const reviewedCreates = Object.freeze([
  "terraform_data.n4e_guard[0]",
  "google_monitoring_custom_service.n4e[0]",
  ...slos.map((id) => `google_monitoring_slo.n4e["${id}"]`),
  "google_monitoring_alert_policy.n4e_fast_burn[0]",
  "google_monitoring_alert_policy.n4e_slow_burn[0]",
  'google_monitoring_uptime_check_config.n4e["booking"]',
  'google_monitoring_uptime_check_config.n4e["session"]',
  "google_monitoring_alert_policy.n4e_probe[0]",
  "google_monitoring_alert_policy.n4e_server_errors[0]",
]);
/** Round 1 of the debt plan (2026-11-17): applied on top of the first 13. */
export const roundOneCreates = Object.freeze([
  'google_monitoring_alert_policy.n4e_budget_spent["50"]',
  'google_monitoring_alert_policy.n4e_budget_spent["75"]',
  "google_monitoring_alert_policy.n4e_telemetry_absent[0]",
  "google_monitoring_alert_policy.n4e_media_tools[0]",
]);
const backupSchedule = 'google_firestore_backup_schedule.n4e["daily"]';
const channelAddress = "google_monitoring_notification_channel.budget_email";

export function checkN4ePlan(plan, expected) {
  const errors = [];
  const vars = plan?.variables ?? {};
  // dev gets the same set in one plan (debt plan 2026-11-17); staging in two rounds.
  const target = expected.projectId;
  if (target !== project && target !== devProject)
    return ["N4e targets the reviewed dev or staging project only"];
  const host = `europe-west1-${target}.cloudfunctions.net`;
  if (vars.project_id?.value !== target) errors.push("project mismatch");
  if (vars.n4e_enabled?.value !== true)
    errors.push("N4e plan must set n4e_enabled");
  if (vars.release_commit_sha?.value !== expected.commitSha)
    errors.push("source mismatch");
  if (inventoryDigest(plan) !== expected.inventorySha256)
    errors.push("reviewed inventory mismatch");
  const changes = plan.resource_changes ?? [];
  const channel = changes.find((c) => c.address === channelAddress);
  const channelName =
    channel?.change?.after?.name ?? channel?.change?.before?.name;
  if (!channelName)
    errors.push("existing staging e-mail channel not in the plan");
  const expectedCreates =
    target === devProject
      ? [...reviewedCreates, ...roundOneCreates]
      : expected.round === 1
        ? roundOneCreates
        : reviewedCreates;
  if (expected.round === 1) {
    const schedule = changes.find((c) => c.address === backupSchedule);
    if (
      !schedule?.change?.importing ||
      JSON.stringify(schedule.change.actions) !== '["no-op"]'
    )
      errors.push("the backup schedule must be imported unchanged");
  }
  const seen = new Set();
  for (const c of changes) {
    const actions = c.change?.actions ?? [];
    const after = c.change?.after ?? {};
    if (
      actions.length !== 1 ||
      !["create", "read", "no-op"].includes(actions[0])
    )
      errors.push(`forbidden action ${actions.join("+")}: ${c.address}`);
    if (actions[0] !== "create") continue;
    if (!expectedCreates.includes(c.address)) {
      errors.push(`unreviewed create: ${c.address}`);
      continue;
    }
    seen.add(c.address);
    if (after.project && after.project !== target)
      errors.push(`foreign target: ${c.address}`);
    if (c.type === "google_monitoring_alert_policy") {
      const channels = after.notification_channels ?? [];
      // The channel name is known before apply: it already exists.
      if (channels.length !== 1 || (channelName && channels[0] !== channelName))
        errors.push(
          `policy must notify only the staging e-mail channel: ${c.address}`,
        );
      if (after.enabled !== true) errors.push(`policy disabled: ${c.address}`);
    }
    if (c.type === "google_monitoring_uptime_check_config") {
      const check = after.http_check?.[0] ?? {};
      const labels = after.monitored_resource?.[0]?.labels ?? {};
      if (
        labels.host !== host ||
        check.use_ssl !== true ||
        check.request_method !== "POST" ||
        JSON.stringify(
          (check.accepted_response_status_codes ?? []).map(
            (s) => s.status_value,
          ),
        ) !== "[401]"
      )
        errors.push(
          `probe must POST to the staging Functions host and expect 401: ${c.address}`,
        );
    }
    if (
      c.address === "google_monitoring_alert_policy.n4e_server_errors[0]" &&
      !String(
        after.conditions?.[0]?.condition_matched_log?.[0]?.filter ?? "",
      ).startsWith('resource.type="cloud_run_revision"')
    )
      errors.push("server-error alert must watch Cloud Run logs only");
  }
  for (const address of expectedCreates)
    if (!seen.has(address)) errors.push(`reviewed create missing: ${address}`);
  return errors;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try {
    const plan = JSON.parse(readFileSync(process.argv[2], "utf8"));
    if (process.argv[3] === "--digest")
      process.stdout.write(inventoryDigest(plan) + "\n");
    else {
      const errors = checkN4ePlan(
        plan,
        JSON.parse(readFileSync(process.argv[3], "utf8")),
      );
      if (errors.length) {
        process.stderr.write(errors.join("; ") + "\n");
        process.exitCode = 1;
      } else
        process.stdout.write(
          "Exact reviewed N4e inventory verified locally; no apply authority granted.\n",
        );
    }
  } catch {
    process.stderr.write("Missing or invalid private plan/review input.\n");
    process.exitCode = 1;
  }
}
