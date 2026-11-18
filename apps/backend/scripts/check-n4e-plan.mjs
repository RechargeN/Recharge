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
/** Round 2 (owner request 2026-11-18, alert noise): two creates, in-place updates of the existing
 * N4e policies and probes only; nothing is removed. */
export const roundTwoCreates = Object.freeze([
  "google_monitoring_alert_policy.n4e_latency_fast_burn[0]",
  'google_monitoring_uptime_check_config.n4e["booking_read"]',
]);
const roundTwoUpdatable =
  /^google_monitoring_(alert_policy\.n4e_[a-z_]+(\[0\]|\["(50|75)"\])|uptime_check_config\.n4e\["(booking|session)"\])$/u;
const channelAddress = "google_monitoring_notification_channel.budget_email";
/** Round 3 (owner decision 2026-11-18): the dedicated alert mailbox as a second channel on the
 * two Critical policies, plus its own delivery-test policy. Nothing else changes. */
export const roundThreeCreates = Object.freeze([
  "google_monitoring_notification_channel.n4e_alerts[0]",
  "google_monitoring_alert_policy.n4e_alert_channel_test[0]",
]);
const roundThreeUpdatable =
  /^google_monitoring_alert_policy\.n4e_(fast_burn|probe)\[0\]$/u;
const mailboxAddress = "google_monitoring_notification_channel.n4e_alerts[0]";

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
  if (
    expected.round === 4 &&
    JSON.stringify(channel?.change?.actions) !== '["update"]'
  )
    errors.push("round 4 must repoint the main e-mail channel");
  const expectedCreates =
    expected.round === 4
      ? []
      : expected.round === 3
        ? roundThreeCreates
        : expected.round === 2
          ? roundTwoCreates
          : target === devProject
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
    const roundTwoUpdate =
      expected.round === 2 &&
      actions.length === 1 &&
      actions[0] === "update" &&
      roundTwoUpdatable.test(c.address);
    const roundThreeUpdate =
      expected.round === 3 &&
      actions.length === 1 &&
      actions[0] === "update" &&
      roundThreeUpdatable.test(c.address);
    // Round 4 (owner 2026-11-18: "all information goes to the mailbox"): the main e-mail channel is
    // repointed in place to the reviewed mailbox, and the two Critical policies drop the now
    // duplicate second channel. No creates, no deletes, the channel keeps its name.
    const roundFourUpdate =
      expected.round === 4 &&
      actions.length === 1 &&
      actions[0] === "update" &&
      (c.address === channelAddress || roundThreeUpdatable.test(c.address));
    if (roundFourUpdate && c.address === channelAddress) {
      if (
        after.type !== "email" ||
        !expected.alertEmail ||
        after.labels?.email_address !== expected.alertEmail ||
        c.change?.before?.name !== after.name
      )
        errors.push(
          "the main channel may only be repointed to the reviewed mailbox",
        );
    } else if (roundFourUpdate) {
      if (
        JSON.stringify(after.notification_channels ?? []) !==
        JSON.stringify([channelName])
      )
        errors.push(
          `Critical policy must notify the main channel exactly once: ${c.address}`,
        );
    }
    if (roundThreeUpdate) {
      // The owner's channel stays; the mailbox name may be unknown until apply.
      const known = (after.notification_channels ?? []).filter(Boolean);
      const unknown = c.change?.after_unknown?.notification_channels;
      if (
        (unknown !== true && !known.includes(channelName)) ||
        known.some((n) => n !== channelName) ||
        (after.notification_channels ?? []).length > 2
      )
        errors.push(
          `Critical policy keeps the owner's channel plus the mailbox only: ${c.address}`,
        );
    }
    if (
      !roundTwoUpdate &&
      !roundThreeUpdate &&
      !roundFourUpdate &&
      (actions.length !== 1 ||
        !["create", "read", "no-op"].includes(actions[0]))
    )
      errors.push(`forbidden action ${actions.join("+")}: ${c.address}`);
    if (roundTwoUpdate && c.type === "google_monitoring_alert_policy") {
      const channels = after.notification_channels ?? [];
      if (
        channels.length > 1 ||
        (channels.length === 1 && channelName && channels[0] !== channelName)
      )
        errors.push(`policy may notify only the e-mail channel: ${c.address}`);
    }
    if (actions[0] !== "create") continue;
    if (!expectedCreates.includes(c.address)) {
      errors.push(`unreviewed create: ${c.address}`);
      continue;
    }
    seen.add(c.address);
    if (after.project && after.project !== target)
      errors.push(`foreign target: ${c.address}`);
    if (c.address === mailboxAddress) {
      if (
        after.type !== "email" ||
        !expected.alertEmail ||
        after.labels?.email_address !== expected.alertEmail
      )
        errors.push("the mailbox channel must be the reviewed e-mail address");
      continue;
    }
    if (
      c.address ===
        "google_monitoring_alert_policy.n4e_alert_channel_test[0]" &&
      (after.notification_channels ?? []).includes(channelName)
    ) {
      errors.push("the delivery test must not notify the owner's channel");
      continue;
    }
    if (c.type === "google_monitoring_alert_policy") {
      const channels = after.notification_channels ?? [];
      // The channel name is known before apply: it already exists.
      if (
        // Owner rule 2026-11-18: a Warning policy has no channel; a Critical one
        // has exactly the staging e-mail channel.
        channels.length > 1 ||
        (channels.length === 1 && channelName && channels[0] !== channelName)
      )
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
