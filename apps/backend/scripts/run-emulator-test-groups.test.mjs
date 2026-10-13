import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  emulatorTestGroups,
  runGroups,
  selectGroups,
  suiteTimeoutMs,
} from "./run-emulator-test-groups.mjs";
const here = path.dirname(fileURLToPath(import.meta.url));
const functionsRoot = path.resolve(here, "../functions");
function cleanup(logDir) {
  assert.equal(path.dirname(path.resolve(logDir)), path.resolve(tmpdir()));
  assert.match(path.basename(logDir), /^recharge-runner-(failure|timeout)-/);
  rmSync(logDir, { recursive: true, force: true });
}

void test("all 40 original invocations, flags, globs and their order are retained", () => {
  const tasks = emulatorTestGroups.flatMap((group) => group.tasks);
  assert.equal(tasks.length, 46);
  // Added after the snapshot: D3.8 Activity Catalog, the D3.3 Rental group,
  // the D3.4 Collection group and the D4.1 import group.
  const added = new Set([
    "lib/test/emulator/activity_catalog_emulator_flow.test.js",
    "lib/test/emulator/content_rental_callable.test.js",
    "lib/test/emulator/content_rental_emulator_flow.test.js",
    "lib/test/emulator/content_collection_callable.test.js",
    "lib/test/emulator/content_collection_emulator_flow.test.js",
    "lib/test/emulator/content_local_import_rollback.test.js",
  ]);
  const originalTasks = tasks.filter((task) => !added.has(task[0]));
  assert.equal(originalTasks.length, 40);
  // Snapshot of the complete b1e678a test:emulator:inside sequence, excluding its build.
  assert.equal(
    createHash("sha256").update(JSON.stringify(originalTasks)).digest("hex"),
    "7ce9aef4557f70cfd78c2e7c77f1559a52ec3fd6fa743dd7bc3fe8b672576394",
  );
});
void test("group selection is explicit and every measured bound has headroom", () => {
  assert.equal(selectGroups().length, 9);
  for (const group of emulatorTestGroups) {
    assert.deepEqual(selectGroups(group.name), [group]);
    assert.ok(group.timeoutMs >= group.baselineMs * 1.75 + 30_000);
  }
  assert.throws(() => selectGroups("missing"), /unknown Emulator group/);
  assert.equal(
    suiteTimeoutMs(selectGroups()),
    240_000 + emulatorTestGroups.reduce((sum, g) => sum + g.timeoutMs, 0),
  );
});
void test("inside scripts contain no build and named scripts launch the outer runner", () => {
  const { scripts } = JSON.parse(
    readFileSync(path.join(functionsRoot, "package.json"), "utf8"),
  );
  for (const [name, command] of Object.entries(scripts))
    if (name.endsWith(":inside") && name.includes("emulator"))
      assert.doesNotMatch(command, /\bbuild\b|\btsc\b/);
  assert.doesNotMatch(scripts["test:booking:load:inside"], /\bbuild\b|\btsc\b/);
  for (const group of emulatorTestGroups)
    assert.equal(
      scripts[`test:emulator:${group.name}`],
      `node ../scripts/run-emulator-tests.mjs --group ${group.name}`,
    );
});
void test("an invalid group fails before building or starting Emulator", () => {
  const result = spawnSync(
    process.execPath,
    [path.join(here, "run-emulator-tests.mjs"), "--group", "missing"],
    { encoding: "utf8" },
  );
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /unknown Emulator group/);
  assert.doesNotMatch(result.stdout, /Cloud-context|Starting emulators/);
});
void test("failure is nonzero, later tasks run serially, and each group has a log", async () => {
  const logDir = mkdtempSync(path.join(tmpdir(), "recharge-runner-failure-"));
  try {
    const marker = path.join(logDir, "marker");
    const groups = [
      {
        name: "first",
        timeoutMs: 5000,
        tasks: [
          [
            "-e",
            `require('fs').writeFileSync(${JSON.stringify(marker)},'first'); console.log('first stdout'); console.error('first stderr'); process.exit(7)`,
          ],
        ],
      },
      {
        name: "second",
        timeoutMs: 5000,
        tasks: [
          [
            "-e",
            `const fs=require('fs'); if(fs.readFileSync(${JSON.stringify(marker)},'utf8')!=='first')process.exit(8); console.log('# tests 1\\n# pass 1\\n# fail 0\\n# skipped 0')`,
          ],
        ],
      },
    ];
    assert.equal(await runGroups(groups, { cwd: logDir, logDir }), 1);
    const summary = JSON.parse(
      readFileSync(path.join(logDir, "summary.json"), "utf8"),
    );
    assert.equal(summary.complete, true);
    assert.deepEqual(
      summary.groups.map((g) => g.code),
      [1, 0],
    );
    assert.equal(summary.groups[0].tasks[0].code, 7);
    assert.equal(summary.groups[1].passed, 1);
    assert.match(
      readFileSync(path.join(logDir, "first.log"), "utf8"),
      /first stdout/,
    );
    assert.match(
      readFileSync(path.join(logDir, "first.log"), "utf8"),
      /first stderr/,
    );
    assert.match(
      readFileSync(path.join(logDir, "second.log"), "utf8"),
      /# pass 1/,
    );
  } finally {
    cleanup(logDir);
  }
});
void test("a hung task times out and remaining work is reported as failed or executed", async () => {
  const logDir = mkdtempSync(path.join(tmpdir(), "recharge-runner-timeout-"));
  try {
    const groups = [
      {
        name: "hung",
        timeoutMs: 500,
        tasks: [
          ["-e", "setInterval(()=>{},1000)"],
          ["-e", "process.exit(0)"],
        ],
      },
      {
        name: "after",
        timeoutMs: 5000,
        tasks: [["-e", "console.log('after timeout')"]],
      },
    ];
    assert.equal(await runGroups(groups, { cwd: logDir, logDir }), 1);
    const summary = JSON.parse(
      readFileSync(path.join(logDir, "summary.json"), "utf8"),
    );
    assert.equal(summary.complete, false);
    assert.equal(summary.groups[0].tasks[0].timedOut, true);
    assert.equal(summary.groups[0].tasks[1].notRun, true);
    assert.equal(summary.groups[1].code, 0);
    assert.match(
      readFileSync(path.join(logDir, "after.log"), "utf8"),
      /after timeout/,
    );
  } finally {
    cleanup(logDir);
  }
});
