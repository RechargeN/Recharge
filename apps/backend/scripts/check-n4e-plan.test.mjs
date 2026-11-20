import test from "node:test";
import assert from "node:assert/strict";

import {
  checkN4ePlan,
  inventoryDigest,
  project,
  reviewedCreates,
  roundOneCreates,
  roundTwoCreates,
  roundThreeCreates,
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

test("round 2: in-place policy and probe updates, two creates, nothing removed", () => {
  const list = [
    changes()[0],
    change(
      "google_monitoring_alert_policy.n4e_slow_burn[0]",
      "google_monitoring_alert_policy",
      { project, notification_channels: [], enabled: true },
      ["update"],
    ),
    change(
      'google_monitoring_uptime_check_config.n4e["booking"]',
      "google_monitoring_uptime_check_config",
      { project },
      ["update"],
    ),
    ...roundTwoCreates.map((address) => {
      const type = address.split(".")[0];
      const after = { project };
      if (type === "google_monitoring_alert_policy")
        Object.assign(after, { notification_channels: [], enabled: true });
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
            { labels: { host: `europe-west1-${project}.cloudfunctions.net` } },
          ],
        });
      return change(address, type, after);
    }),
  ];
  const p = plan(list);
  assert.deepEqual(checkN4ePlan(p, { ...expected(p), round: 2 }), []);
  const removed = plan([
    ...list,
    change(
      "google_monitoring_alert_policy.n4e_probe[0]",
      "google_monitoring_alert_policy",
      {},
      ["delete"],
    ),
  ]);
  assert.match(
    checkN4ePlan(removed, { ...expected(removed), round: 2 }).join(),
    /forbidden action delete/u,
  );
  const replaced = plan([
    ...list,
    change(
      'google_monitoring_uptime_check_config.n4e["session"]',
      "google_monitoring_uptime_check_config",
      {},
      ["delete", "create"],
    ),
  ]);
  assert.match(
    checkN4ePlan(replaced, { ...expected(replaced), round: 2 }).join(),
    /forbidden action delete\+create/u,
  );
  const foreign = plan([
    ...list,
    change("google_project_iam_member.x[0]", "google_project_iam_member", {}, [
      "update",
    ]),
  ]);
  assert.match(
    checkN4ePlan(foreign, { ...expected(foreign), round: 2 }).join(),
    /forbidden action update/u,
  );
});

test("round 3: the alert mailbox on the two Critical policies only, with its own delivery test", () => {
  const mailbox = "alerts@example.invalid";
  const update = (address, channels, unknown) => ({
    address,
    type: "google_monitoring_alert_policy",
    change: {
      actions: ["update"],
      after: { project, enabled: true, notification_channels: channels },
      after_unknown: unknown ? { notification_channels: unknown } : {},
      before: { project, notification_channels: [channel] },
    },
  });
  const list = (overrides = {}) => [
    changes()[0],
    update(
      "google_monitoring_alert_policy.n4e_fast_burn[0]",
      [channel, null],
      [false, true],
    ),
    update("google_monitoring_alert_policy.n4e_probe[0]", undefined, true),
    change(roundThreeCreates[0], "google_monitoring_notification_channel", {
      project,
      type: "email",
      labels: { email_address: overrides.email ?? mailbox },
    }),
    change(roundThreeCreates[1], "google_monitoring_alert_policy", {
      project,
      enabled: true,
      notification_channels: overrides.testChannels,
    }),
  ];
  const run = (l, extra = {}) => {
    const p = plan(l);
    return checkN4ePlan(p, {
      ...expected(p),
      round: 3,
      alertEmail: mailbox,
      ...extra,
    }).join();
  };
  assert.equal(run(list()), "");
  assert.match(
    run(list({ email: "someone@else.invalid" })),
    /reviewed e-mail address/u,
  );
  assert.match(
    run(list(), { alertEmail: undefined }),
    /reviewed e-mail address/u,
  );
  assert.match(
    run(list({ testChannels: [channel] })),
    /must not notify the owner's channel/u,
  );
  const dropped = list();
  dropped[1] = update(
    "google_monitoring_alert_policy.n4e_fast_burn[0]",
    [],
    undefined,
  );
  assert.match(run(dropped), /keeps the owner's channel/u);
  assert.match(
    run([
      ...list(),
      update("google_monitoring_alert_policy.n4e_slow_burn[0]", [channel]),
    ]),
    /forbidden action update/u,
  );
});

test("round 4: the main channel repointed in place to the mailbox, Critical policies notify it once", () => {
  const mailbox = "alerts@example.invalid";
  const main = (email, name = channel) => ({
    address: "google_monitoring_notification_channel.budget_email",
    type: "google_monitoring_notification_channel",
    change: {
      actions: ["update"],
      before: {
        project,
        name: channel,
        type: "email",
        labels: { email_address: "owner@example.invalid" },
      },
      after: { project, name, type: "email", labels: { email_address: email } },
    },
  });
  const policy = (address, channels) => ({
    address,
    type: "google_monitoring_alert_policy",
    change: {
      actions: ["update"],
      before: { project, notification_channels: [channel, "x"] },
      after: { project, enabled: true, notification_channels: channels },
    },
  });
  const list = (email = mailbox, channels = [channel]) => [
    main(email),
    policy("google_monitoring_alert_policy.n4e_fast_burn[0]", channels),
    policy("google_monitoring_alert_policy.n4e_probe[0]", channels),
  ];
  const run = (l) => {
    const p = plan(l);
    return checkN4ePlan(p, {
      ...expected(p),
      round: 4,
      alertEmail: mailbox,
    }).join();
  };
  assert.equal(run(list()), "");
  const gate = {
    address: "terraform_data.budget_delivery_gate",
    type: "terraform_data",
    change: { actions: ["update"], before: {}, after: {} },
  };
  assert.equal(run([...list(), gate]), "");
  assert.match(
    run([
      ...list(),
      { ...gate, change: { ...gate.change, actions: ["delete", "create"] } },
    ]),
    /forbidden action delete\+create/u,
  );
  assert.match(
    run(list("someone@else.invalid")),
    /repointed to the reviewed mailbox/u,
  );
  assert.match(run(list(mailbox, [channel, "x"])), /exactly once/u);
  assert.match(
    run([
      main(mailbox, "projects/p/notificationChannels/999"),
      ...list().slice(1),
    ]),
    /repointed/u,
  );
  assert.match(
    run(list().slice(1).concat([changes()[0]])),
    /must repoint the main e-mail channel/u,
  );
  assert.match(
    run([
      ...list(),
      policy("google_monitoring_alert_policy.n4e_slow_burn[0]", []),
    ]),
    /forbidden action update/u,
  );
});
