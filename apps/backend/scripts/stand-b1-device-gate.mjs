import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import {
  adb,
  adbExecutable,
  appPackage,
  deviceEnvDefine,
  flutterOnDevice,
  mobileRoot,
  removeReversedPorts,
  repoRoot,
  reversePorts,
  startDeviceBridge,
} from "./stand-device-bridge.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const functionsDir = path.join(here, "..", "functions");
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");
const e2Gate = path.join(here, "stand-e2-gate.mjs");
const parts = ["core", "route", "route-background", "media", "release"];
const usage =
  "WARNING: this permanently deletes the stand data folder. Usage: stand-b1-device-gate.mjs --yes --device <serial> [--part core|route|route-background|media|release] [--out <new directory>]";

/** `--yes --device <serial> [--part <part>] [--out <dir>]`, or a refusal. */
export function parseArgs(args) {
  const options = { part: "core" };
  const rest = [...args];
  if (rest.shift() !== "--yes") throw new Error(usage);
  while (rest.length > 0) {
    const flag = rest.shift();
    const value = rest.shift();
    if (value === undefined || value.startsWith("--")) throw new Error(usage);
    if (flag === "--device") options.serial = value;
    else if (flag === "--part") options.part = value;
    else if (flag === "--out") options.out = value;
    else throw new Error(usage);
  }
  if (!options.serial || !/^[A-Za-z0-9._:-]+$/.test(options.serial))
    throw new Error(usage);
  if (!parts.includes(options.part)) throw new Error(usage);
  return options;
}

/**
 * Stops unless the device is attached as `device` (not `unauthorized`,
 * `offline` or absent) and the checkout is clean; returns the facts recorded
 * for the run. `exec(command, args)` returns `{status, output}`.
 */
export function preconditions(serial, exec) {
  const listed = exec("adb", ["devices", "-l"]);
  const line = listed.output
    .split(/\r?\n/)
    .find((value) => value.split(/\s+/)[0] === serial);
  if (!line)
    throw new Error(
      `device ${serial} is not attached (adb devices -l); stop and report`,
    );
  const state = line.split(/\s+/)[1];
  if (state !== "device")
    throw new Error(`device ${serial} is ${state}; stop and report`);
  const dirty = exec("git", ["status", "--porcelain"]);
  if (dirty.status !== 0 || dirty.output.trim() !== "")
    throw new Error(
      "the checkout is not clean; B1-device runs one exact commit",
    );
  const sha = exec("git", ["rev-parse", "HEAD"]).output.trim();
  const prop = (name) =>
    exec("adb", ["-s", serial, "shell", "getprop", name]).output.trim();
  return {
    serial,
    sha,
    adbLine: line.trim(),
    model: prop("ro.product.model"),
    android: prop("ro.build.version.release"),
    sdk: prop("ro.build.version.sdk"),
    fingerprint: prop("ro.build.fingerprint"),
  };
}

function exec(command, args, options = {}) {
  const resolved = command === "adb" ? adbExecutable() : command;
  const result = spawnSync(resolved, args, {
    encoding: "utf8",
    shell: false,
    env: process.env,
    cwd: repoRoot,
    ...options,
  });
  return {
    status: result.status,
    output: (result.stdout ?? "") + (result.stderr ?? ""),
  };
}

function run(script, args) {
  const result = exec(process.execPath, [script, ...args]);
  if (result.status !== 0)
    throw new Error(
      `${path.basename(script)} ${args.join(" ")} failed:\n${result.output}`,
    );
  return result.output;
}

function lastJson(output) {
  const line = output
    .trim()
    .split("\n")
    .filter((value) => value.trim().startsWith("{"))
    .pop();
  if (!line) throw new Error(`no JSON in output:\n${output}`);
  return JSON.parse(line);
}

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Waits for a rendezvous point of the app; stops early if `started` exits. */
async function point(directory, who, name, started, seconds = 900) {
  const file = path.join(directory, `${who}.${name}.json`);
  const deadline = Date.now() + seconds * 1000;
  while (!fs.existsSync(file)) {
    if (started && started.code !== undefined)
      throw new Error(
        `the app run ended (${started.code}) before ${who}.${name}; see ${started.log}`,
      );
    if (Date.now() > deadline) throw new Error(`${who} never reached ${name}`);
    await pause(250);
  }
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function arrive(directory, name, payload = {}) {
  const file = path.join(directory, `gate.${name}.json`);
  fs.writeFileSync(`${file}.tmp`, JSON.stringify(payload));
  fs.renameSync(`${file}.tmp`, file);
}

/** The app's pid on the phone, or "" when no process is running. */
function pid(serial) {
  return adb(serial, ["shell", "pidof", appPackage], {
    allowFail: true,
  }).trim();
}

async function gone(serial, what) {
  for (let i = 0; i < 40; i += 1) {
    if (pid(serial) === "") return;
    await pause(250);
  }
  throw new Error(`${what} did not end the app process`);
}

function home(serial) {
  adb(serial, ["shell", "input", "keyevent", "KEYCODE_HOME"]);
}

/** OS-style end of a background process; returns the pid it ended. */
async function osKill(serial) {
  home(serial);
  await pause(3000);
  const before = pid(serial);
  if (before === "") throw new Error("the app process was not running");
  adb(serial, ["shell", "am", "kill", appPackage]);
  await gone(serial, "am kill");
  return before;
}

async function userClose(serial) {
  const before = pid(serial);
  adb(serial, ["shell", "am", "force-stop", appPackage]);
  await gone(serial, "am force-stop");
  return before;
}

function freshStand(steps = ["seed", "verify"]) {
  run(standCli, ["stop"]);
  run(standCli, ["reset", "--yes"]);
  run(standCli, ["start"]);
  for (const step of steps) run(seedCli, step.split(" "));
}

function bookings(label) {
  return lastJson(run(seedCli, ["bookings", label]));
}

async function getJson(url) {
  const response = await fetch(url);
  return response.json();
}

/**
 * B1-device gate on a physical Android phone over USB. The local stand stays
 * on the PC loopback; the phone reaches Auth, Functions and the gate's bridge
 * on its own 127.0.0.1 through `adb reverse`. No LAN, cloud, real Google/Apple
 * Auth, push or iOS. Parts:
 * - core: binding guards, the debug APK cleartext policy (loopback only), native adapters, the app across
 *   background/return, `am kill` and `am force-stop` (Session, journal,
 *   Booking without duplicates), the B2 Booking UI, the C3 Create →
 *   publication UI, D4 import/rollback and E2 with the phone as client B and
 *   a PC client as A;
 * - route (needs an operator at the phone): the real location dialog, GPS
 *   recording and its recovery after `am kill`, the system GPX picker and
 *   export;
 * - route-background (operator): "Allow all the time" chosen in Settings
 *   starts background recording (B1D-ROUTE-BG-01) and the location
 *   foreground service runs while the app is in the background;
 * - media (operator): MEDIA-PICK-01 with the real Photo Picker and camera;
 *   kept copies have no EXIF/GPS; no media-read permission is requested;
 * - release: the release APK refuses cleartext (no debug network config,
 *   no usesCleartextTraffic, target 28+), is not debuggable and starts on
 *   the phone; its permissions are recorded.
 * Each part writes a JSON ledger (steps, device facts, bridge requests).
 */
export async function main(args) {
  const options = parseArgs(args);
  const { serial, part } = options;
  const facts = preconditions(serial, exec);
  const work =
    options.out ??
    fs.mkdtempSync(path.join(os.tmpdir(), "recharge-b1-device-"));
  fs.mkdirSync(work, { recursive: true });
  assert.equal(fs.readdirSync(work).length, 0, `--out ${work} must be empty`);
  const rendezvous = path.join(work, "rendezvous");
  fs.mkdirSync(rendezvous);
  const ledger = {
    part,
    facts,
    startedUtc: new Date().toISOString(),
    steps: [],
  };
  const save = () =>
    fs.writeFileSync(
      path.join(work, `b1-device-${part}.json`),
      JSON.stringify(ledger, null, 2),
    );
  const step = async (name, action) => {
    process.stdout.write(`- ${name}\n`);
    const entry = { name, startedUtc: new Date().toISOString() };
    ledger.steps.push(entry);
    try {
      entry.result = (await action()) ?? null;
      entry.status = "passed";
    } catch (error) {
      entry.status = "failed";
      entry.error = error.message;
      throw error;
    } finally {
      entry.endedUtc = new Date().toISOString();
      save();
    }
    return entry.result;
  };
  const device = (variables) =>
    deviceEnvDefine({
      RECHARGE_B1_STAND: "1",
      RECHARGE_STAND_BRIDGE: "1",
      ...variables,
    });
  const onPhone = (file, defines, name) =>
    flutterOnDevice(file, serial, {
      defines,
      log: path.join(work, `${name}.log`),
    });
  const passOnPhone = async (file, defines, name) => {
    const started = onPhone(file, defines, name);
    const code = await started.exited;
    if (code !== 0)
      throw new Error(`${file} exited ${code}; see ${started.log}`);
    return { log: path.basename(started.log) };
  };
  let bridge;
  let failure;
  try {
    process.stdout.write(
      `  device ${facts.model} Android ${facts.android} (${facts.fingerprint}) at ${facts.sha}\n`,
    );
    bridge = await startDeviceBridge({ rendezvous });
    await step("adb reverse of Auth, Functions and the bridge", () => ({
      reverse: reversePorts(serial),
    }));
    if (part === "core") await core();
    else if (part === "route") await route();
    else if (part === "media") await media();
    else if (part === "route-background") await routeBackground();
    else await release();
  } catch (error) {
    failure = error;
  } finally {
    try {
      if (bridge) {
        ledger.bridgeRequests = bridge.requests;
        await bridge.close();
      }
      ledger.reverseAfter = removeReversedPorts(serial);
      if (["core", "release"].includes(part)) run(standCli, ["stop"]);
    } catch (error) {
      failure ??= error;
    }
    ledger.endedUtc = new Date().toISOString();
    ledger.result = failure ? `failed: ${failure.message}` : "passed";
    save();
  }
  if (failure) throw failure;
  process.stdout.write(
    `B1-device ${part} passed on ${facts.model} ${serial} at ${facts.sha} (USB, adb reverse to the PC loopback stand; no LAN, cloud, real Google/Apple Auth, push or iOS claim). Ledger: ${path.join(work, `b1-device-${part}.json`)}\n`,
  );

  async function core() {
    await step("build the Functions the stand loads", () => {
      const result = exec(
        process.execPath,
        [path.join("node_modules", "typescript", "bin", "tsc"), "-p", "."],
        { cwd: functionsDir },
      );
      if (result.status !== 0) throw new Error(`tsc failed:\n${result.output}`);
    });
    await step("fresh demo-recharge stand, seed and invariants", () =>
      freshStand(),
    );
    await step("project identity and loaded emulators", async () => ({
      status: run(standCli, ["status"]).trim(),
      emulators: await getJson("http://127.0.0.1:4400/emulators"),
    }));
    await step("binding guards and loopback on the phone", () =>
      passOnPhone("integration_test/b1_device_guards_test.dart", [], "guards"),
    );
    await step("debug APK: cleartext only to 127.0.0.1 (native stacks)", () => {
      const apk = path.join(
        mobileRoot,
        "build",
        "app",
        "outputs",
        "flutter-apk",
        "app-debug.apk",
      );
      const dump = exec(aaptPath(), [
        "dump",
        "xmltree",
        apk,
        "res/xml/local_emulator_network_security.xml",
      ]);
      if (dump.status !== 0) throw new Error(`aapt failed: ${dump.output}`);
      return {
        domains: loopbackOnlyCleartext(dump.output),
        apkSha256: crypto
          .createHash("sha256")
          .update(fs.readFileSync(apk))
          .digest("hex"),
      };
    });
    await step("native firebase_auth and secure Session adapters", () =>
      passOnPhone(
        "integration_test/booking_session_adapters_stand_test.dart",
        ["RECHARGE_B1_PLATFORM=true"],
        "native-adapters",
      ),
    );
    await step(
      "lifecycle: background/return, am kill, am force-stop",
      async () => {
        const seeded = bookings("staff");
        adb(serial, ["shell", "pm", "clear", appPackage], { allowFail: true });
        const defines = (phase) => [
          "RECHARGE_TEST_BOOKING_ENTRY=true",
          device({ RECHARGE_B1_PHASE: String(phase) }),
        ];
        const result = {};
        const one = onPhone(
          "integration_test/b1_device_lifecycle_test.dart",
          defines(1),
          "lifecycle-1",
        );
        await point(rendezvous, "device", "background", one);
        home(serial);
        await pause(4000);
        result.backgroundPid = pid(serial);
        adb(serial, [
          "shell",
          "monkey",
          "-p",
          appPackage,
          "-c",
          "android.intent.category.LAUNCHER",
          "1",
        ]);
        arrive(rendezvous, "foreground");
        const killed = await point(rendezvous, "device", "kill", one);
        result.lifecycleStates = killed.states;
        result.osKilledPid = await osKill(serial);
        await one.stop();
        const two = onPhone(
          "integration_test/b1_device_lifecycle_test.dart",
          defines(2),
          "lifecycle-2",
        );
        await point(rendezvous, "device", "force-stop", two);
        result.userClosedPid = await userClose(serial);
        await two.stop();
        const three = onPhone(
          "integration_test/b1_device_lifecycle_test.dart",
          defines(3),
          "lifecycle-3",
        );
        const code = await three.exited;
        if (code !== 0)
          throw new Error(`phase 3 exited ${code}; see ${three.log}`);
        await point(rendezvous, "device", "done");
        const after = bookings("staff");
        assert.equal(
          after.total,
          seeded.total + 1,
          "one Booking for one intent",
        );
        assert.equal(after.active, 0);
        return { ...result, seeded, after };
      },
    );
    await step("B2 Event Booking UI on the phone (fresh stand)", async () => {
      freshStand();
      const log = await passOnPhone(
        "integration_test/b1_device_booking_ui_test.dart",
        ["RECHARGE_TEST_BOOKING_ENTRY=true", device({})],
        "b2-booking-ui",
      );
      const final = bookings("staff");
      // As stand-b2-gate.mjs: one seeded cancelled booking plus seven intents.
      assert.deepEqual(
        { total: final.total, active: final.active },
        { total: 8, active: 0 },
      );
      return { ...log, final };
    });
    await step(
      "C3 Create → cover → moderation → publication UI on the phone",
      async () => {
        freshStand();
        const log = await passOnPhone(
          "integration_test/b1_device_event_publication_ui_test.dart",
          ["RECHARGE_TEST_EVENT_PUBLICATION=true", device({})],
          "c3-publication-ui",
        );
        run(seedCli, ["verify"]);
        return log;
      },
    );
    await step(
      "D4 local import, lost answers and rollback on the phone",
      async () => {
        freshStand(["seed", "place seed"]);
        const log = await passOnPhone(
          "integration_test/b1_device_local_import_test.dart",
          [device({})],
          "d4-local-import",
        );
        run(seedCli, ["verify"]);
        run(seedCli, ["place", "verify"]);
        return log;
      },
    );
    // The E2 gate runs its own stand and its own bridge on the same port.
    await bridge.close();
    ledger.bridgeRequests = bridge.requests;
    bridge = undefined;
    await step("E2 two users: the phone as client B, a PC client as A", () => {
      const result = exec(process.execPath, [
        e2Gate,
        "--yes",
        "--android",
        serial,
      ]);
      fs.writeFileSync(path.join(work, "e2-two-users.log"), result.output);
      if (result.status !== 0)
        throw new Error("E2 with the phone failed; see e2-two-users.log");
      return { log: "e2-two-users.log" };
    });
  }

  async function route() {
    const gpx = path.join(work, "recharge-b1-device.gpx");
    fs.writeFileSync(gpx, routeGpx());
    const digest = crypto
      .createHash("sha256")
      .update(fs.readFileSync(gpx))
      .digest("hex");
    const target = "/sdcard/Download/recharge-b1-device.gpx";
    await step("push the GPX the operator will pick", () => {
      adb(serial, ["push", gpx, target]);
      return { target, sha256: digest };
    });
    const operator = (text) => process.stdout.write(`OPERATOR: ${text}\n`);
    try {
      adb(serial, ["shell", "pm", "clear", appPackage], { allowFail: true });
      const defines = (phase) => [device({ RECHARGE_B1_PHASE: String(phase) })];
      await step("real location dialog, recording, am kill", async () => {
        const one = onPhone(
          "integration_test/b1_device_route_test.dart",
          defines(1),
          "route-1",
        );
        await point(rendezvous, "device", "permission-dialog", one);
        operator(
          "allow location for Recharge in the Android dialog (While using the app)",
        );
        await point(rendezvous, "device", "walk", one);
        operator(
          "walk a few metres with the phone until two GPS fixes are recorded",
        );
        const recorded = await point(rendezvous, "device", "kill", one);
        const killedPid = await osKill(serial);
        await one.stop();
        return { samples: recorded.samples, killedPid };
      });
      await step(
        "recovery without auto-resume, GPX picker and export",
        async () => {
          const two = onPhone(
            "integration_test/b1_device_route_test.dart",
            defines(2),
            "route-2",
          );
          await point(rendezvous, "device", "gpx-picker", two);
          operator(
            "in the file picker open Downloads and choose recharge-b1-device.gpx",
          );
          const picked = await point(rendezvous, "device", "gpx-picked", two);
          assert.equal(
            picked.sha256,
            digest,
            "the picked bytes are the pushed GPX",
          );
          await point(rendezvous, "device", "gpx-export", two);
          operator("export: save the file (or share it) and return to the app");
          const code = await two.exited;
          if (code !== 0)
            throw new Error(`phase 2 exited ${code}; see ${two.log}`);
          const done = await point(rendezvous, "device", "done");
          return { picked, ...done };
        },
      );
    } finally {
      adb(serial, ["shell", "rm", "-f", target], { allowFail: true });
    }
  }

  async function routeBackground() {
    const operator = (text) => process.stdout.write(`OPERATOR: ${text}\n`);
    adb(serial, ["shell", "pm", "clear", appPackage], { allowFail: true });
    await step(
      'while-in-use, Settings "all the time", background start',
      async () => {
        const run = onPhone(
          "integration_test/b1_device_route_background_test.dart",
          [],
          "route-background",
        );
        await point(rendezvous, "device", "foreground-dialog", run);
        operator("allow location for Recharge: While using the app");
        const settings = await Promise.race([
          point(rendezvous, "device", "settings", run).then(() => true),
          point(rendezvous, "device", "background", run).then(() => false),
        ]);
        if (settings)
          operator(
            "in Settings open Permissions → Location → Allow all the time, then return to the app",
          );
        const trace = await point(rendezvous, "device", "background", run);
        home(serial);
        await pause(20000);
        const services = adb(
          serial,
          ["shell", "dumpsys", "activity", "services", appPackage],
          { allowFail: true },
        );
        const foregroundService =
          /isForeground=true/.test(services) &&
          /foregroundServiceType=0x0*8\b|location/i.test(services);
        adb(serial, [
          "shell",
          "monkey",
          "-p",
          appPackage,
          "-c",
          "android.intent.category.LAUNCHER",
          "1",
        ]);
        arrive(rendezvous, "foreground");
        const code = await run.exited;
        if (code !== 0)
          throw new Error(
            `route-background test exited ${code}; see ${run.log}`,
          );
        const done = await point(rendezvous, "device", "done");
        assert.ok(
          foregroundService,
          "a location foreground service ran in the background",
        );
        return { trace, done, foregroundService };
      },
    );
  }

  async function media() {
    const fixture = path.join(
      mobileRoot,
      "test",
      "fixtures",
      "media",
      "b1_device_exif_gps.jpg",
    );
    const folder = "/sdcard/Pictures/RechargeB1";
    const target = `${folder}/recharge-b1-exif.jpg`;
    const operator = (text) => process.stdout.write(`OPERATOR: ${text}\n`);
    const scan = (file) =>
      adb(
        serial,
        [
          "shell",
          "am",
          "broadcast",
          "-a",
          "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
          "-d",
          `file://${file}`,
        ],
        { allowFail: true },
      );
    await step("push the EXIF/GPS photo the operator will pick", () => {
      adb(serial, ["shell", "mkdir", "-p", folder]);
      adb(serial, ["push", fixture, target]);
      scan(target);
      return {
        target,
        sha256: crypto
          .createHash("sha256")
          .update(fs.readFileSync(fixture))
          .digest("hex"),
      };
    });
    try {
      await step(
        "system Photo Picker and camera; metadata-free copies",
        async () => {
          const run = onPhone(
            "integration_test/b1_device_media_pick_test.dart",
            [],
            "media",
          );
          await point(rendezvous, "device", "gallery", run);
          operator(
            "in the photo picker choose the RechargeB1 photo (gradient with squares)",
          );
          const picked = await point(
            rendezvous,
            "device",
            "gallery-picked",
            run,
          );
          await point(rendezvous, "device", "camera", run);
          operator("take any photo with the camera and confirm it");
          const code = await run.exited;
          if (code !== 0)
            throw new Error(`media test exited ${code}; see ${run.log}`);
          const done = await point(rendezvous, "device", "done");
          return { picked, ...done };
        },
      );
      // `flutter test` uninstalls the app when it ends, so the installed
      // package is gone by now: read the APK that ran on the phone instead.
      await step("no media-read permission in the APK that ran", () => {
        const apk = path.join(
          mobileRoot,
          "build",
          "app",
          "outputs",
          "flutter-apk",
          "app-debug.apk",
        );
        const dump = exec(aaptPath(), ["dump", "permissions", apk]);
        if (dump.status !== 0) throw new Error(`aapt failed: ${dump.output}`);
        const requested = mediaReadPermissionsAbsent(dump.output);
        return {
          apkSha256: crypto
            .createHash("sha256")
            .update(fs.readFileSync(apk))
            .digest("hex"),
          requested,
        };
      });
    } finally {
      adb(serial, ["shell", "rm", "-rf", folder], { allowFail: true });
      scan(target);
    }
  }

  async function release() {
    await step("build the release APK", () => {
      const result = exec(
        process.platform === "win32" ? "cmd.exe" : "flutter",
        process.platform === "win32"
          ? ["/c", "flutter", "build", "apk", "--release"]
          : ["build", "apk", "--release"],
        { cwd: mobileRoot },
      );
      fs.writeFileSync(path.join(work, "release-build.log"), result.output);
      if (result.status !== 0)
        throw new Error("release build failed; see release-build.log");
    });
    const apk = path.join(
      mobileRoot,
      "build",
      "app",
      "outputs",
      "flutter-apk",
      "app-release.apk",
    );
    // Plugins (maps, firebase_auth) bring INTERNET, so the release boundary is
    // the code (releaseMode → productionDisabled) plus a platform that refuses
    // cleartext: no debug network config, no usesCleartextTraffic, target 28+.
    await step("release APK: no cleartext, not debuggable", () => {
      const permissions = exec(aaptPath(), ["dump", "permissions", apk]).output;
      const manifest = exec(aaptPath(), [
        "dump",
        "xmltree",
        apk,
        "AndroidManifest.xml",
      ]).output;
      const files = exec(aaptPath(), ["list", apk]).output;
      releaseManifestChecks(manifest, files);
      return {
        sha256: crypto
          .createHash("sha256")
          .update(fs.readFileSync(apk))
          .digest("hex"),
        permissions: permissions
          .split(/\r?\n/)
          .filter((line) => line.includes("permission")),
      };
    });
    await step("release APK installs and starts on the phone", async () => {
      adb(serial, ["uninstall", appPackage], { allowFail: true });
      adb(serial, ["install", apk]);
      adb(serial, ["logcat", "-c"]);
      adb(serial, [
        "shell",
        "monkey",
        "-p",
        appPackage,
        "-c",
        "android.intent.category.LAUNCHER",
        "1",
      ]);
      await pause(10000);
      const running = pid(serial);
      const crashes = adb(serial, ["logcat", "-d", "-b", "crash"], {
        allowFail: true,
      });
      await userClose(serial);
      adb(serial, ["uninstall", appPackage], { allowFail: true });
      assert.notEqual(running, "", "the release app is running");
      assert.doesNotMatch(
        crashes,
        new RegExp(appPackage.replaceAll(".", "\\.")),
      );
      return { pid: running };
    });
  }
}

function aaptPath() {
  const tools = path.join(
    process.env.LOCALAPPDATA ?? "",
    "Android",
    "Sdk",
    "build-tools",
  );
  const versions = fs.existsSync(tools) ? fs.readdirSync(tools).sort() : [];
  const latest = versions.at(-1);
  const candidate = latest
    ? path.join(
        tools,
        latest,
        process.platform === "win32" ? "aapt.exe" : "aapt",
      )
    : "";
  return fs.existsSync(candidate) ? candidate : "aapt";
}

/**
 * Reads `aapt dump xmltree` of the debug network security config: the base
 * config refuses cleartext and the only cleartext domain is exactly
 * 127.0.0.1 without subdomains. Returns the domains or throws.
 */
export function loopbackOnlyCleartext(xmltree) {
  const lines = xmltree.split(/\r?\n/).map((line) => line.trim());
  const at = (element) =>
    lines.findIndex((line) => line.startsWith(`E: ${element} `));
  const base = at("base-config");
  const domainConfig = at("domain-config");
  if (base < 0 || domainConfig < 0)
    throw new Error("network security config not found");
  if (lines[base + 1] !== "A: cleartextTrafficPermitted=(type 0x12)0x0")
    throw new Error("the base config must refuse cleartext");
  if (
    lines[domainConfig + 1] !==
    "A: cleartextTrafficPermitted=(type 0x12)0xffffffff"
  )
    throw new Error("unexpected domain-config shape");
  const domains = lines
    .filter((line) => line.startsWith('C: "'))
    .map((line) => line.slice(4, -1));
  if (domains.length !== 1 || domains[0] !== "127.0.0.1")
    throw new Error(
      `cleartext domains must be exactly 127.0.0.1, got ${domains.join(", ")}`,
    );
  if (
    lines.some((line) => line === "A: includeSubdomains=(type 0x12)0xffffffff")
  )
    throw new Error("subdomains must not be included");
  return domains;
}

/**
 * Release APK (`aapt dump xmltree … AndroidManifest.xml` and `aapt list`):
 * no network security config or debug config resource, no
 * usesCleartextTraffic=true, not debuggable, targetSdkVersion 28 or higher
 * (cleartext refused by default on Android 9+). Returns the target SDK.
 */
export function releaseManifestChecks(manifest, files) {
  if (/networkSecurityConfig/.test(manifest))
    throw new Error("release must not carry a network security config");
  if (/local_emulator_network_security/.test(files))
    throw new Error("release must not package the debug network config");
  if (/usesCleartextTraffic\([^)]*\)=\(type 0x12\)0xffffffff/.test(manifest))
    throw new Error("release must not allow cleartext traffic");
  if (/debuggable\([^)]*\)=\(type 0x12\)0xffffffff/.test(manifest))
    throw new Error("release must not be debuggable");
  const target = /targetSdkVersion\([^)]*\)=\(type 0x10\)0x([0-9a-f]+)/.exec(
    manifest,
  );
  if (!target) throw new Error("targetSdkVersion not found");
  const sdk = Number.parseInt(target[1], 16);
  if (sdk < 28)
    throw new Error(`targetSdkVersion ${sdk} allows cleartext by default`);
  return sdk;
}

/**
 * `aapt dump permissions`: MEDIA-PICK-01 asks for no media-read permission
 * (Photo Picker) and needs no CAMERA (system camera app). An empty dump is
 * an error, never a pass. Returns the requested permissions.
 */
export function mediaReadPermissionsAbsent(dump) {
  const requested = [...dump.matchAll(/uses-permission: name='([^']+)'/g)].map(
    (match) => match[1],
  );
  if (!requested.includes("android.permission.INTERNET"))
    throw new Error("no permission list read from the APK");
  for (const forbidden of [
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VISUAL_USER_SELECTED",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.CAMERA",
  ])
    if (requested.includes(forbidden))
      throw new Error(`${forbidden} must not be requested`);
  return requested;
}

/** A short synthetic track in Riga, written fresh for each run. */
export function routeGpx() {
  const points = [
    [56.9496, 24.1052],
    [56.9501, 24.1067],
    [56.9509, 24.1081],
    [56.9517, 24.1094],
  ];
  const trkpts = points
    .map(
      ([lat, lon], i) =>
        `      <trkpt lat="${lat}" lon="${lon}"><ele>${8 + i}</ele></trkpt>`,
    )
    .join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="recharge-b1-device-gate" xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>B1-device synthetic track</name>
    <trkseg>
${trkpts}
    </trkseg>
  </trk>
</gpx>
`;
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
