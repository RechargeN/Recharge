import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  assertIdentity,
  assertProjectEvidence,
  descendants,
  processTree,
  remainingAfterStop,
  sameProcess,
  validateReset,
  project,
  ports,
} from "./emulator-stand.mjs";
const id = {
  pid: 42,
  started: "2026-10-05T10:00:00Z",
  executable: "C:\\node.exe",
  command: "supervisor run-123",
};
test("exact process identity", () => assertIdentity(id, id, "run-123"));
for (const [name, actual] of [
  ["missing PID", null],
  ["PID reused", { ...id, started: "later" }],
  ["foreign executable", { ...id, executable: "C:\\foreign.exe" }],
  ["foreign run ID", { ...id, command: "other" }],
  ["wrong PID", { ...id, pid: 43 }],
])
  test(name + " refuses without killing", () =>
    assert.throws(() => assertIdentity(actual, id, "run-123")),
  );
const cli = {
  pid: 7,
  started: "now",
  executable: "C:\\node.exe",
  command: "--project demo-recharge --config config-run.json",
};
const s = { cli, config: "config-run.json" };
const map = Object.fromEntries(
  Object.entries(ports)
    .filter(([k]) => k !== "logging")
    .map(([k, port]) => [
      k,
      { host: "127.0.0.1", port, listen: [{ address: "127.0.0.1" }] },
    ]),
);
test("project + CLI + locator + hub + five services", () =>
  assertProjectEvidence(s, cli, { pid: 7 }, { pid: 7 }, map));
test("foreign project despite open ports refuses", () =>
  assert.throws(() =>
    assertProjectEvidence(
      s,
      { ...cli, command: "--project real-project config-run.json" },
      { pid: 7 },
      { pid: 7 },
      map,
    ),
  ));
test("foreign hub refuses", () =>
  assert.throws(() =>
    assertProjectEvidence(s, cli, { pid: 7 }, { pid: 8 }, map),
  ));
test("LAN listener refuses", () =>
  assert.throws(() =>
    assertProjectEvidence(
      s,
      cli,
      { pid: 7 },
      { pid: 7 },
      { ...map, auth: { ...map.auth, listen: [{ address: "0.0.0.0" }] } },
    ),
  ));
test("missing service refuses", () =>
  assert.throws(() =>
    assertProjectEvidence(
      s,
      cli,
      { pid: 7 },
      { pid: 7 },
      { ...map, storage: undefined },
    ),
  ));
test("reset exact marked folder only", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "a1-reset-"));
  const target = path.join(dir, "data");
  fs.mkdirSync(target);
  try {
    validateReset(target, target, project);
    assert.throws(() => validateReset(dir, target, project));
    assert.throws(() => validateReset(target, target, "real-project"));
    const link = path.join(dir, "link");
    fs.symlinkSync(
      target,
      link,
      process.platform === "win32" ? "junction" : "dir",
    );
    assert.throws(() => validateReset(link, link, project));
    fs.unlinkSync(link);
  } finally {
    fs.rmdirSync(target);
    fs.rmdirSync(dir);
  }
});

test(
  "Windows stop rechecks start time and handles multiple identities",
  { skip: process.platform !== "win32" },
  async () => {
    const { spawn } = await import("node:child_process");
    const { getProcess, stopOwnedProcesses } =
      await import("./emulator-stand.mjs");
    const children = [0, 1].map(() =>
      spawn(process.execPath, ["-e", "setInterval(()=>{},1000)"], {
        stdio: "ignore",
        windowsHide: true,
      }),
    );
    await new Promise((resolve) => setTimeout(resolve, 300));
    const identities = children.map((child) => getProcess(child.pid));
    try {
      assert.throws(() =>
        stopOwnedProcesses([
          { ...identities[0], started: "2000-01-01T00:00:00Z" },
        ]),
      );
      assert.ok(getProcess(children[0].pid));
      assert.ok(getProcess(children[1].pid));
      stopOwnedProcesses(identities);
      assert.equal(getProcess(children[0].pid), undefined);
      assert.equal(getProcess(children[1].pid), undefined);
    } finally {
      for (const child of children) {
        try {
          child.kill();
        } catch {}
      }
    }
  },
);

test("project prefix is not project identity", () =>
  assert.throws(() =>
    assertProjectEvidence(
      s,
      { ...cli, command: "--project demo-recharge-other config-run.json" },
      { pid: 7 },
      { pid: 7 },
      map,
    ),
  ));
test("reset refuses a junction in parent path", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "a1-junction-"));
  const real = path.join(dir, "real");
  const link = path.join(dir, "linked");
  fs.mkdirSync(real);
  fs.mkdirSync(path.join(real, "data"));
  try {
    fs.symlinkSync(
      real,
      link,
      process.platform === "win32" ? "junction" : "dir",
    );
    const target = path.join(link, "data");
    assert.throws(() => validateReset(target, target, project));
  } finally {
    if (fs.existsSync(link)) fs.unlinkSync(link);
    fs.rmdirSync(path.join(real, "data"));
    fs.rmdirSync(real);
    fs.rmdirSync(dir);
  }
});

test("service port owned by foreign process refuses even with project responses", async () => {
  const { assertListenerOwnership } = await import("./emulator-stand.mjs");
  const listeners = Object.values(ports).map((port) => ({
    host: "127.0.0.1",
    port,
    pid: 7,
  }));
  assertListenerOwnership(listeners, [7]);
  assert.throws(() =>
    assertListenerOwnership(
      [{ ...listeners[0], pid: 8 }, ...listeners.slice(1)],
      [7],
    ),
  );
  assert.throws(() =>
    assertListenerOwnership(
      [{ ...listeners[0], host: "0.0.0.0" }, ...listeners.slice(1)],
      [7],
    ),
  );
});

test("a reused parent PID never adopts older processes into the stand tree", () => {
  // 2026-10-10: a Functions worker got PID 1176, the PID of the boot-time smss
  // whose children csrss and winlogon (and theirs) still name it as parent.
  const proc = (pid, parent, started, executable) => ({
    pid,
    parent,
    started,
    executable,
  });
  const all = [
    proc(1204, 1176, "2026-10-10T06:15:16Z", null),
    proc(1264, 1176, "2026-10-10T06:15:16Z", null),
    proc(1820, 1264, "2026-10-10T06:15:17Z", null),
    proc(3276, 1488, "2026-10-10T06:18:09Z", "C:\node.exe"),
    proc(8504, 3276, "2026-10-10T06:18:55Z", "C:\java.exe"),
    proc(1176, 3276, "2026-10-10T06:21:56Z", "C:\node.exe"),
    proc(4000, 1176, "2026-10-10T06:22:00Z", "C:\node.exe"),
  ];
  assert.deepEqual(
    descendants(all, 3276)
      .map((item) => item.pid)
      .sort((left, right) => left - right),
    [1176, 4000, 8504],
  );
  // An unknown start time adopts nothing.
  assert.deepEqual(descendants(all, 9999), []);
});

test("an unknown start time makes a process doubtful: not stopped, still reported", () => {
  const proc = (pid, parent, started, executable = "C:\\node.exe") => ({
    pid,
    parent,
    started,
    executable,
  });
  const all = [
    proc(10, 1, "2026-10-10T06:18:00Z"),
    proc(11, 10, "2026-10-10T06:18:05Z"),
    proc(12, 10, null),
    proc(13, 12, "2026-10-10T06:18:09Z"),
    proc(14, 10, "2026-10-10T06:00:00Z"),
  ];
  const tree = processTree(all, 10);
  assert.deepEqual(
    tree.owned.map((item) => item.pid),
    [11],
  );
  // 12 has no start time, so its child 13 cannot be proven either; 14 is older
  // than the process holding PID 10 and is not the stand's at all.
  assert.deepEqual(tree.doubtful.map((item) => item.pid).sort(), [12, 13]);
});

test("a stop is verified by PID and creation time, never by PID alone", () => {
  const owned = [
    { pid: 11, parent: 10, started: "2026-10-10T06:18:05Z", executable: "n" },
  ];
  const doubtful = [{ pid: 12, parent: 10, started: null, executable: "j" }];
  const record = { recordedAtUtc: "2026-10-10T06:25:00Z", owned, doubtful };
  const pids = (live) =>
    remainingAfterStop(record, live).map((item) => item.pid);
  assert.deepEqual(pids([]), []);
  // The very same owned process (PID and creation time) is still running.
  assert.deepEqual(pids([{ ...owned[0] }]), [11]);
  // PID 11 now belongs to a process created after the stop record: reused, not ours.
  assert.deepEqual(
    pids([{ pid: 11, parent: 99, started: "2026-10-10T06:30:00Z" }]),
    [],
  );
  // A doubtful process cannot be told apart while its creation time is unknown
  // or no later than the record: the stop stays unverified.
  assert.deepEqual(pids([{ pid: 12, parent: 10, started: null }]), [12]);
  assert.deepEqual(
    pids([{ pid: 12, parent: 77, started: "2026-10-10T06:20:00Z" }]),
    [12],
  );
  // Created after the record: a reused PID that blocks nothing.
  assert.deepEqual(
    pids([{ pid: 12, parent: 77, started: "2026-10-10T06:31:00Z" }]),
    [],
  );
  // Without a record time every doubtful PID still alive blocks.
  assert.deepEqual(
    remainingAfterStop({ owned: [], doubtful }, [
      { pid: 12, parent: 77, started: "2026-10-10T06:31:00Z" },
    ]).map((item) => item.pid),
    [12],
  );
});

test("a recorded supervisor or CLI is alive only as itself, never by PID alone", () => {
  const recorded = { pid: 1488, started: "2026-10-10T06:18:08Z" };
  assert.equal(
    sameProcess(recorded, { pid: 1488, started: "2026-10-10T06:18:08.000Z" }),
    true,
  );
  // The PID now belongs to a younger process: start, stop and reset go on.
  assert.equal(
    sameProcess(recorded, { pid: 1488, started: "2026-10-10T07:00:00Z" }),
    false,
  );
  assert.equal(sameProcess(recorded, undefined), false);
  assert.equal(
    sameProcess(recorded, { pid: 1489, started: recorded.started }),
    false,
  );
});

test("owned processes are listed children first, so no wrapper dies before its child", () => {
  // 2026-10-10 R2: stopping the Pub/Sub cmd wrapper before its java left the
  // java running on 8085; the verified stop caught it.
  const proc = (pid, parent, started) => ({
    pid,
    parent,
    started,
    executable: "x",
  });
  const all = [
    proc(23252, 1, "2026-10-10T07:40:00Z"),
    proc(25848, 23252, "2026-10-10T07:40:01Z"),
    proc(5952, 23252, "2026-10-10T07:41:25Z"),
    proc(20996, 5952, "2026-10-10T07:41:25Z"),
    proc(19724, 20996, "2026-10-10T07:41:26Z"),
  ];
  const order = processTree(all, 23252).owned.map((item) => item.pid);
  assert.ok(order.indexOf(19724) < order.indexOf(20996), order.join(","));
  assert.ok(order.indexOf(20996) < order.indexOf(5952), order.join(","));
  assert.deepEqual(
    [...order].sort((left, right) => left - right),
    [5952, 19724, 20996, 25848],
  );
});
