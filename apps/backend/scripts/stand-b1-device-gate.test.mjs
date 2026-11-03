import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { test } from "node:test";
import { parseArgs, preconditions, routeGpx } from "./stand-b1-device-gate.mjs";
import {
  BridgeRefusal,
  deviceEnvDefine,
  fixturePath,
  rendezvousPoint,
  standRequest,
  startDeviceBridge,
} from "./stand-device-bridge.mjs";

const serial = "RFCW91QHWWJ";

function fakeExec({ devices, dirty = "", sha = "a".repeat(40) }) {
  return (command, args) => {
    if (command === "adb" && args[0] === "devices")
      return { status: 0, output: devices };
    if (command === "git" && args[0] === "status")
      return { status: 0, output: dirty };
    if (command === "git" && args[0] === "rev-parse")
      return { status: 0, output: `${sha}\n` };
    if (command === "adb" && args.includes("getprop"))
      return { status: 0, output: `${args.at(-1)}-value\n` };
    throw new Error(`unexpected ${command} ${args.join(" ")}`);
  };
}

test("arguments need --yes and an exact device; parts are closed", () => {
  assert.deepEqual(parseArgs(["--yes", "--device", serial]), {
    part: "core",
    serial,
  });
  assert.equal(
    parseArgs(["--yes", "--device", serial, "--part", "route"]).part,
    "route",
  );
  for (const args of [
    [],
    ["--device", serial],
    ["--yes"],
    ["--yes", "--device"],
    ["--yes", "--device", "bad serial"],
    ["--yes", "--device", serial, "--part", "cloud"],
    ["--yes", "--device", serial, "--lan", "1"],
  ])
    assert.throws(
      () => parseArgs(args),
      /Usage: stand-b1-device-gate/,
      JSON.stringify(args),
    );
});

test("a missing, unauthorized or offline device stops the gate", () => {
  const header = "List of devices attached\n";
  assert.throws(
    () => preconditions(serial, fakeExec({ devices: header })),
    /not attached/,
  );
  for (const state of ["unauthorized", "offline"])
    assert.throws(
      () =>
        preconditions(
          serial,
          fakeExec({ devices: `${header}${serial}  ${state} usb:1\n` }),
        ),
      new RegExp(`is ${state}`),
    );
  assert.throws(
    () =>
      preconditions(serial, fakeExec({ devices: `${header}OTHER device\n` })),
    /not attached/,
  );
});

test("a dirty checkout stops the gate; a ready device records its facts", () => {
  const devices = `List of devices attached\n${serial}  device product:a34xeea model:SM_A346B\n`;
  assert.throws(
    () => preconditions(serial, fakeExec({ devices, dirty: " M x\n" })),
    /not clean/,
  );
  const facts = preconditions(serial, fakeExec({ devices }));
  assert.equal(facts.sha, "a".repeat(40));
  assert.equal(facts.model, "ro.product.model-value");
  assert.match(facts.adbLine, /^RFCW91QHWWJ\s+device/);
});

test("the bridge allowlists stand commands", () => {
  assert.deepEqual(
    standRequest({ script: "stand-seed.mjs", args: ["bookings", "staff"] }),
    {
      script: "stand-seed.mjs",
      args: ["bookings", "staff"],
    },
  );
  assert.ok(standRequest({ script: "stand-moderate.mjs", args: ["queue"] }));
  for (const body of [
    null,
    [],
    { script: "emulator-stand.mjs", args: ["reset", "--yes"] },
    { script: "stand-seed.mjs", args: ["seed"] },
    { script: "stand-seed.mjs", args: ["digest"] },
    { script: "stand-seed.mjs", args: ["handoff", "reconcile"] },
    { script: "stand-seed.mjs", args: [] },
    { script: "stand-seed.mjs", args: ["bookings", 1] },
    { script: "../x.mjs", args: ["bookings"] },
  ])
    assert.throws(
      () => standRequest(body),
      BridgeRefusal,
      JSON.stringify(body),
    );
});

test("fixtures are read-only media under apps/mobile/test/fixtures/media", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "b1-device-fixture-"));
  assert.equal(
    fixturePath("test/fixtures/media/stand_cover.png", root),
    path.resolve(root, "test/fixtures/media/stand_cover.png"),
  );
  for (const relative of [
    "test/fixtures/media/../../../pubspec.yaml",
    "lib/main.dart",
    "/etc/passwd",
    "test\\fixtures\\media\\x.png",
    "test/fixtures/media/x y.png",
    undefined,
  ])
    assert.throws(
      () => fixturePath(relative, root),
      BridgeRefusal,
      String(relative),
    );
});

test("rendezvous points: who may write, who may read, safe names", () => {
  assert.equal(rendezvousPoint("device", "kill", true), "device.kill.json");
  assert.equal(
    rendezvousPoint("gate", "foreground", false),
    "gate.foreground.json",
  );
  assert.throws(
    () => rendezvousPoint("gate", "approved.B", true),
    BridgeRefusal,
  );
  for (const name of ["", "../x", "A/B", "UPPER", "x".repeat(70)])
    assert.throws(
      () => rendezvousPoint("device", name, true),
      BridgeRefusal,
      name,
    );
});

test("the bridge serves loopback only, logs requests and keeps points as files", async () => {
  const rendezvous = fs.mkdtempSync(path.join(os.tmpdir(), "b1-device-rv-"));
  const calls = [];
  const bridge = await startDeviceBridge({
    rendezvous,
    port: 0,
    run: (request) => {
      calls.push(request);
      return { exitCode: 0, stdout: '{"total":1,"active":0}\n', stderr: "" };
    },
  });
  try {
    const base = `http://127.0.0.1:${bridge.port}`;
    const stand = await fetch(`${base}/stand`, {
      method: "POST",
      body: JSON.stringify({
        script: "stand-seed.mjs",
        args: ["bookings", "staff"],
      }),
    });
    assert.equal(stand.status, 200);
    assert.equal((await stand.json()).exitCode, 0);
    assert.deepEqual(calls, [
      { script: "stand-seed.mjs", args: ["bookings", "staff"] },
    ]);

    const refused = await fetch(`${base}/stand`, {
      method: "POST",
      body: JSON.stringify({ script: "stand-seed.mjs", args: ["seed"] }),
    });
    assert.equal(refused.status, 400);
    assert.equal(calls.length, 1, "a refused command never runs");

    const point = `${base}/rendezvous?who=device&name=kill`;
    assert.equal((await fetch(point)).status, 404);
    const put = await fetch(point, {
      method: "PUT",
      body: '{"sessionId":"s"}',
    });
    assert.equal(put.status, 204);
    assert.deepEqual(
      JSON.parse(
        fs.readFileSync(path.join(rendezvous, "device.kill.json"), "utf8"),
      ),
      {
        sessionId: "s",
      },
    );
    assert.equal(await (await fetch(point)).text(), '{"sessionId":"s"}');
    assert.equal(
      (
        await fetch(`${base}/rendezvous?who=gate&name=x`, {
          method: "PUT",
          body: "{}",
        })
      ).status,
      400,
    );
    assert.equal(
      (
        await fetch(`${base}/rendezvous?who=device&name=bad`, {
          method: "PUT",
          body: "nope",
        })
      ).status,
      400,
    );
    assert.equal((await fetch(`${base}/anything`)).status, 404);
    assert.ok(
      bridge.requests.every((entry) => !("body" in entry)),
      "no bodies are logged",
    );
    assert.equal(bridge.requests.length, 8);
  } finally {
    await bridge.close();
  }
});

test("the device define is base64url JSON of strings", () => {
  const define = deviceEnvDefine({
    RECHARGE_B1_STAND: "1",
    RECHARGE_E2_ROLE: "B",
  });
  const [name, value] = define.split(/=(.*)/s);
  assert.equal(name, "RECHARGE_DEVICE_ENV");
  assert.match(value, /^[A-Za-z0-9_-]+$/);
  assert.deepEqual(
    JSON.parse(Buffer.from(value, "base64url").toString("utf8")),
    {
      RECHARGE_B1_STAND: "1",
      RECHARGE_E2_ROLE: "B",
    },
  );
  assert.throws(
    () => deviceEnvDefine({ RECHARGE_B1_PHASE: 1 }),
    /must be a string/,
  );
});

test("the synthetic GPX is a small GPX 1.1 track in Riga", () => {
  const gpx = routeGpx();
  assert.match(
    gpx,
    /^<\?xml version="1.0" encoding="UTF-8"\?>\n<gpx version="1.1"/,
  );
  assert.equal(gpx.match(/<trkpt /g).length, 4);
  assert.doesNotMatch(gpx, /<!DOCTYPE|<!ENTITY/);
});
