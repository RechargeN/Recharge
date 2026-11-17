import test from "node:test";
import assert from "node:assert/strict";

import {
  checkN4ePlan,
  inventoryDigest,
  project,
  reviewedCreates,
  roundOneCreates,
} from "./check-n4e-plan.mjs";

const channel = `projects/${project}/notificationChannels/123`;
const change = (address, type, after, actions = ["create"], before = null) => ({
  address,
  type,
  change: { actions, after, before },
});
const typeOf = (address) => address.split(".")[0];

function changes() {
  return [
    change(
      "google_monitoring_notification_channel.budget_email",
      "google_monitoring_notification_channel",
      { project, name: channel },
      ["no-op"],
      { project, name: channel },
    ),
    ...reviewedCreates.map((address) => {
      const type = typeOf(address);
      const after = { project };
      if (type === "google_monitoring_alert_policy") {
        after.notification_channels = [channel];
        after.enabled = true;
        after.conditions = [
          {
            condition_matched_log: [
              {
                filter:
                  'resource.type="cloud_run_revision" AND severity>=ERROR',
              },
            ],
          },
        ];
      }
      if (type === "google_monitoring_uptime_check_config")
        Object.assign(after, {
          http_check: [
            {
              use_ssl: true,
              request_method: "POST",
              accepted_response_status_codes: [{ status_value: 401 }],
            },
          ],
          monitored_resource: [
            {
              labels: {
                host: `europe-west1-${project}.cloudfunctions.net`,
                project_id: project,
              },
            },
          ],
        });
      return change(address, type, after);
    }),
  ];
}
const plan = (resourceChanges) => ({
  variables: {
    project_id: { value: project },
    n4e_enabled: { value: true },
    release_commit_sha: { value: "a".repeat(40) },
  },
  resource_changes: resourceChanges,
});
const expected = (p) => ({
  projectId: project,
  commitSha: "a".repeat(40),
  inventorySha256: inventoryDigest(p),
});
const check = (mutate = () => {}) => {
  const c = changes();
  mutate(c);
  const p = plan(c);
  return checkN4ePlan(p, expected(p));
};
const find = (c, address) => c.find((x) => x.address === address).change.after;

test("the reviewed N4e inventory passes", () => {
  assert.deepEqual(check(), []);
  assert.equal(reviewedCreates.length, 13);
});

test("only the staging e-mail channel, enabled policies, 401 probes on the staging host", () => {
  assert.match(
    check((c) => {
      find(
        c,
        "google_monitoring_alert_policy.n4e_fast_burn[0]",
      ).notification_channels = ["projects/other/notificationChannels/9"];
    }).join(),
    /only the staging e-mail channel/u,
  );
  assert.match(
    check((c) => {
      find(c, "google_monitoring_alert_policy.n4e_slow_burn[0]").enabled =
        false;
    }).join(),
    /policy disabled/u,
  );
  assert.match(
    check((c) => {
      find(
        c,
        'google_monitoring_uptime_check_config.n4e["booking"]',
      ).monitored_resource[0].labels.host = "example.invalid";
    }).join(),
    /staging Functions host/u,
  );
  assert.match(
    check((c) => {
      find(
        c,
        "google_monitoring_alert_policy.n4e_server_errors[0]",
      ).conditions[0].condition_matched_log[0].filter = "severity>=ERROR";
    }).join(),
    /Cloud Run logs only/u,
  );
});

test("nothing else is created, changed or removed; staging only", () => {
  assert.match(
    check((c) =>
      c.push(
        change(
          "google_project_iam_member.extra[0]",
          "google_project_iam_member",
          {
            project,
            role: "roles/owner",
          },
        ),
      ),
    ).join(),
    /unreviewed create/u,
  );
  assert.match(
    check((c) => {
      c[0].change.actions = ["update"];
    }).join(),
    /forbidden action update/u,
  );
  assert.match(check((c) => c.splice(3, 1)).join(), /reviewed create missing/u);
  const p = plan(changes());
  assert.match(
    checkN4ePlan(p, { ...expected(p), projectId: "recharge-prod" }).join(),
    /dev or staging project only/u,
  );
});

test("round 1: only the four new policies, and the backup schedule imported unchanged", () => {
  const channelChange = changes()[0];
  const round = [
    channelChange,
    ...roundOneCreates.map((address) =>
      change(address, "google_monitoring_alert_policy", {
        project,
        notification_channels: [channel],
        enabled: true,
      }),
    ),
    {
      address: 'google_firestore_backup_schedule.n4e["daily"]',
      type: "google_firestore_backup_schedule",
      change: {
        actions: ["no-op"],
        importing: { id: "x" },
        after: { project },
      },
    },
  ];
  const p = plan(round);
  assert.deepEqual(checkN4ePlan(p, { ...expected(p), round: 1 }), []);
  const notImported = plan(
    round.map((c) =>
      c.type === "google_firestore_backup_schedule"
        ? { ...c, change: { ...c.change, importing: undefined } }
        : c,
    ),
  );
  assert.match(
    checkN4ePlan(notImported, { ...expected(notImported), round: 1 }).join(),
    /imported unchanged/u,
  );
  const recreated = plan([
    ...round,
    change(
      "google_monitoring_alert_policy.n4e_fast_burn[0]",
      "google_monitoring_alert_policy",
      { project, notification_channels: [channel], enabled: true },
    ),
  ]);
  assert.match(
    checkN4ePlan(recreated, { ...expected(recreated), round: 1 }).join(),
    /unreviewed create/u,
  );
});

test("dev: the full set (first apply plus round 1) in one plan, on the dev host", () => {
  const dev = "recharge-dev-n2a01";
  const devChannel = `projects/${dev}/notificationChannels/7`;
  const all = [...reviewedCreates, ...roundOneCreates];
  const list = [
    change(
      "google_monitoring_notification_channel.budget_email",
      "google_monitoring_notification_channel",
      { project: dev, name: devChannel },
      ["no-op"],
      { project: dev, name: devChannel },
    ),
    ...all.map((address) => {
      const type = address.split(".")[0];
      const after = { project: dev };
      if (type === "google_monitoring_alert_policy")
        Object.assign(after, {
          notification_channels: [devChannel],
          enabled: true,
          conditions: [
            {
              condition_matched_log: [
                { filter: 'resource.type="cloud_run_revision" AND x' },
              ],
            },
          ],
        });
      if (type === "google_monitoring_uptime_check_config")
        Object.assign(after, {
          http_check: [
            {
              use_ssl: true,
              request_method: "POST",
              accepted_response_status_codes: [{ status_value: 401 }],
            },
          ],
          monitored_resource: [
            { labels: { host: `europe-west1-${dev}.cloudfunctions.net` } },
          ],
        });
      return change(address, type, after);
    }),
  ];
  const p = {
    variables: {
      project_id: { value: dev },
      n4e_enabled: { value: true },
      release_commit_sha: { value: "a".repeat(40) },
    },
    resource_changes: list,
  };
  const exp = {
    projectId: dev,
    commitSha: "a".repeat(40),
    inventorySha256: inventoryDigest(p),
  };
  assert.deepEqual(checkN4ePlan(p, exp), []);
  list[2].change.after.monitored_resource = [
    { labels: { host: `europe-west1-${project}.cloudfunctions.net` } },
  ];
});
