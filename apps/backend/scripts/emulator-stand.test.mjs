import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  assertIdentity,
  assertProjectEvidence,
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
