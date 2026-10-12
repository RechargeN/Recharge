import { spawn, spawnSync } from "node:child_process";
import {
  appendFileSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const emulatorTestGroups = Object.freeze([
  {
    name: "platform",
    baselineMs: 10741,
    timeoutMs: 120000,
    tasks: [
      ["lib/test/emulator/r0_emulator_isolation.test.js"],
      ["lib/test/emulator/rules_default_deny.test.js"],
      ["lib/test/emulator/identity_authority_repository.test.js"],
    ],
  },
  {
    name: "booking",
    baselineMs: 105889,
    timeoutMs: 240000,
    tasks: [
      ["lib/test/emulator/event_booking_projection.test.js"],
      ["lib/test/emulator/event_booking_delivery_scheduler.test.js"],
      ["lib/test/emulator/booking_create.test.js"],
      ["lib/test/emulator/booking_cancel.test.js"],
      ["lib/test/emulator/booking_reconfirm.test.js"],
      ["lib/test/emulator/booking_reconfirmation_deadline_worker.test.js"],
      ["lib/test/emulator/booking_queries.test.js"],
      ["lib/test/emulator/booking_contention.test.js"],
      ["lib/test/emulator/booking_security.test.js"],
      ["lib/test/emulator/booking_abuse_controls.test.js"],
      ["lib/test/emulator/booking_full_integration_flow.test.js"],
    ],
  },
  {
    name: "content-media",
    baselineMs: 158509,
    timeoutMs: 330000,
    tasks: [
      ["lib/test/emulator/content_emulator_guard.test.js"],
      ["lib/test/emulator/content_firestore_repository.test.js"],
      ["lib/test/emulator/content_concurrency.test.js"],
      ["lib/test/emulator/content_recovery.test.js"],
      ["lib/test/emulator/content_rules_default_deny.test.js"],
      ["lib/test/emulator/media_emulator_flow.test.js"],
      ["lib/test/emulator/moderation_emulator_flow.test.js"],
      ["lib/test/emulator/content_event_emulator_flow.test.js"],
      ["lib/test/emulator/catalog_emulator_flow.test.js"],
      ["lib/test/emulator/activity_catalog_emulator_flow.test.js"],
      ["lib/test/emulator/discover_query_emulator_flow.test.js"],
      ["lib/test/emulator/content_effect_delivery_emulator.test.js"],
      ["lib/test/emulator/content_transition_guard.test.js"],
    ],
  },
  {
    name: "handoff-notifications",
    baselineMs: 233842,
    timeoutMs: 450000,
    tasks: [
      ["lib/test/emulator/event_booking_handoff_emulator.test.js"],
      ["lib/test/emulator/booking_notification_effects.test.js"],
      ["lib/test/emulator/notifications_rules_default_deny.test.js"],
      ["lib/test/emulator/notifications_inbox_emulator_flow.test.js"],
      ["lib/test/emulator/notifications_unavailability.test.js"],
      ["lib/test/emulator/notifications_privacy_emulator.test.js"],
      ["lib/test/emulator/booking_reconfirmation_deadline_clock.test.js"],
      ["lib/test/emulator/booking_action_races.test.js"],
    ],
  },
  {
    name: "place-activity",
    baselineMs: 148173,
    timeoutMs: 300000,
    tasks: [
      ["lib/test/emulator/media_delivery_callable.test.js"],
      ["lib/test/emulator/content_place_callable.test.js"],
      ["lib/test/emulator/content_place_emulator_flow.test.js"],
      ["lib/test/emulator/content_activity_callable.test.js"],
      ["lib/test/emulator/content_activity_emulator_flow.test.js"],
    ],
  },
  {
    // D3.4: Collection / Guide through Content with Catalog-owned membership.
    name: "collection",
    baselineMs: 192200,
    timeoutMs: 390000,
    tasks: [
      ["lib/test/emulator/content_collection_callable.test.js"],
      ["lib/test/emulator/content_collection_emulator_flow.test.js"],
    ],
  },
  {
    name: "rules-reference",
    baselineMs: 6749,
    timeoutMs: 120000,
    tasks: [
      [
        "--test",
        "--experimental-test-isolation=none",
        "lib/test/emulator/r1_*.test.js",
        "lib/test/rules/*.test.js",
        "lib/test/reference_data/emulator/*.test.js",
      ],
    ],
  },
]);

export function selectGroups(name) {
  if (name === undefined) return emulatorTestGroups;
  const selected = emulatorTestGroups.filter((group) => group.name === name);
  if (selected.length !== 1) throw new Error(`unknown Emulator group: ${name}`);
  return selected;
}
export function suiteTimeoutMs(groups) {
  // Separate budgets: startup 180 s, shutdown/cleanup 60 s.
  return 240_000 + groups.reduce((sum, group) => sum + group.timeoutMs, 0);
}
async function runTask(args, options) {
  const child = spawn(process.execPath, args, {
    cwd: options.cwd,
    env: process.env,
    shell: false,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let timedOut = false;
  let error;
  const timer = setTimeout(() => {
    timedOut = true;
    if (process.platform === "win32" && child.pid !== undefined) {
      const killed = spawnSync(
        "taskkill.exe",
        ["/pid", String(child.pid), "/t", "/f"],
        { shell: false },
      );
      if (killed.status !== 0) child.kill();
    } else child.kill("SIGKILL");
  }, options.remainingMs);
  for (const stream of [child.stdout, child.stderr])
    stream.on("data", (chunk) => {
      appendFileSync(options.log, chunk);
      options.onOutput?.(chunk);
    });
  child.on("error", (cause) => {
    error = cause.message;
  });
  const code = await new Promise((resolve) =>
    child.once("close", (code) => resolve(code ?? 1)),
  );
  clearTimeout(timer);
  return {
    code: timedOut || error ? 1 : code,
    timedOut,
    ...(error ? { error } : {}),
  };
}
export async function runGroups(groups, options) {
  mkdirSync(options.logDir, { recursive: true });
  const results = [];
  // Shared state: groups and their tasks are strictly sequential.
  for (const group of groups) {
    const started = Date.now();
    const log = path.join(options.logDir, `${group.name}.log`);
    writeFileSync(log, `Group ${group.name}; timeout ${group.timeoutMs} ms\n`);
    const tasks = [];
    for (const args of group.tasks) {
      const remainingMs = group.timeoutMs - (Date.now() - started);
      if (remainingMs <= 0) {
        appendFileSync(
          log,
          `NOT RUN (group deadline): node ${args.join(" ")}\n`,
        );
        tasks.push({ args, code: 1, timedOut: true, notRun: true });
        continue;
      }
      appendFileSync(log, `\nnode ${args.join(" ")}\n`);
      const taskStarted = Date.now();
      const result = await runTask(args, { ...options, log, remainingMs });
      appendFileSync(
        log,
        `RESULT exit=${result.code}, timedOut=${result.timedOut}${result.error ? `, error=${result.error}` : ""}\n`,
      );
      tasks.push({ args, ms: Date.now() - taskStarted, ...result });
    }
    const output = readFileSync(log, "utf8");
    const count = (label) =>
      [...output.matchAll(new RegExp(`^# ${label} (\\d+)`, "gm"))].reduce(
        (sum, match) => sum + Number(match[1]),
        0,
      );
    const result = {
      name: group.name,
      ms: Date.now() - started,
      timeoutMs: group.timeoutMs,
      log,
      code: tasks.some((task) => task.code !== 0) ? 1 : 0,
      tests: count("tests"),
      passed: count("pass"),
      failed: count("fail"),
      skipped: count("skipped"),
      tasks,
    };
    results.push(result);
    options.onOutput?.(
      Buffer.from(
        `\nEMULATOR GROUP ${group.name}: ${result.code === 0 ? "PASS" : "FAIL"}, ${result.ms} ms, log ${log}\n`,
      ),
    );
    writeFileSync(
      path.join(options.logDir, "summary.json"),
      JSON.stringify(
        {
          complete:
            results.length === groups.length &&
            results.every((group) => group.tasks.every((task) => !task.notRun)),
          code: results.some((item) => item.code !== 0) ? 1 : 0,
          groups: results,
        },
        null,
        2,
      ) + "\n",
    );
  }
  return results.some((result) => result.code !== 0) ? 1 : 0;
}
async function main() {
  if (process.argv.length !== 2)
    throw new Error("group selection belongs to the outer Emulator runner");
  if (
    process.env.GCLOUD_PROJECT !== "demo-recharge" ||
    process.env.FUNCTIONS_EMULATOR !== "true"
  )
    throw new Error("test groups require the local demo-recharge Emulator");
  for (const name of [
    "FIRESTORE_EMULATOR_HOST",
    "FIREBASE_AUTH_EMULATOR_HOST",
    "FIREBASE_STORAGE_EMULATOR_HOST",
  ])
    if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env[name] ?? ""))
      throw new Error(`local Emulator endpoint required: ${name}`);
  if (!process.env.R0_EMULATOR_LOG_DIR)
    throw new Error("outer runner must supply R0_EMULATOR_LOG_DIR");
  process.exitCode = await runGroups(
    selectGroups(process.env.R0_EMULATOR_GROUP || undefined),
    {
      cwd: path.resolve(
        path.dirname(fileURLToPath(import.meta.url)),
        "../functions",
      ),
      logDir: process.env.R0_EMULATOR_LOG_DIR,
      onOutput: (chunk) => process.stdout.write(chunk),
    },
  );
}
if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
)
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
