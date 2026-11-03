import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
export const repoRoot = path.resolve(here, "..", "..", "..");
export const mobileRoot = path.join(repoRoot, "apps", "mobile");
export const bridgePort = 8765;
/** Ports the phone reaches on its own loopback through `adb reverse`. */
export const reversedPorts = [9099, 5001, bridgePort];
export const appPackage = "com.recharge.app.recharge";

/**
 * The stand commands a client may run through the bridge: exactly the
 * `StandBackend` reads and owner-path fixtures of the mobile stand tests.
 * Reset, seed of the base stand, digest and the delivery/reconcile operator
 * steps stay with the gate.
 */
const seedCommands = new Set([
  "bookings",
  "content-draft",
  "media-readiness",
  "session-fixture",
  "page-access",
  "notifications",
  "manifest",
  "catalog",
  "place",
  "session",
  "activity",
  "rental",
  "collection",
  "class-workshop",
  "find-people",
  "find-people-fixture",
  "scenario",
  "route",
]);
const scripts = new Set(["stand-seed.mjs", "stand-moderate.mjs"]);
const writers = new Set(["A", "B", "device"]);
const readers = new Set(["A", "B", "gate", "device"]);
const pointName = /^[a-z0-9][a-z0-9.-]{0,63}$/;
const fixtureRoot = "test/fixtures/media/";
const maxBody = 64 * 1024;

/** Refusal of a malformed or not allowlisted bridge request. */
export class BridgeRefusal extends Error {}

/** Validates one `/stand` request; returns the script and its arguments. */
export function standRequest(body) {
  if (body === null || typeof body !== "object" || Array.isArray(body))
    throw new BridgeRefusal("body must be an object");
  const { script, args } = body;
  if (!scripts.has(script)) throw new BridgeRefusal("script not allowed");
  if (
    !Array.isArray(args) ||
    args.length === 0 ||
    args.length > 16 ||
    !args.every((arg) => typeof arg === "string" && arg.length <= 512)
  )
    throw new BridgeRefusal("args must be 1-16 strings");
  if (script === "stand-seed.mjs" && !seedCommands.has(args[0]))
    throw new BridgeRefusal(`stand command ${args[0]} not allowed`);
  return { script, args };
}

/** Resolves an allowlisted media fixture under apps/mobile, or refuses. */
export function fixturePath(relative, root = mobileRoot) {
  if (
    typeof relative !== "string" ||
    !relative.startsWith(fixtureRoot) ||
    relative.includes("..") ||
    relative.includes("\\") ||
    !/^[A-Za-z0-9_./-]+$/.test(relative)
  )
    throw new BridgeRefusal("fixture path not allowed");
  const resolved = path.resolve(root, relative);
  if (!resolved.startsWith(path.resolve(root, fixtureRoot)))
    throw new BridgeRefusal("fixture path not allowed");
  return resolved;
}

/** Validates a rendezvous point; `write` limits who may arrive. */
export function rendezvousPoint(who, name, write) {
  if (!(write ? writers : readers).has(who))
    throw new BridgeRefusal("rendezvous party not allowed");
  if (typeof name !== "string" || !pointName.test(name))
    throw new BridgeRefusal("rendezvous name not allowed");
  return `${who}.${name}.json`;
}

/** Runs a stand script on this PC, the way a host test would. */
export function runStandScript({ script, args }) {
  const result = spawnSync(
    process.execPath,
    [path.join(here, script), ...args],
    {
      encoding: "utf8",
      env: process.env,
      timeout: 180_000,
    },
  );
  return {
    exitCode: result.status ?? 1,
    stdout: result.stdout ?? "",
    stderr: result.stderr ?? (result.error ? String(result.error) : ""),
  };
}

async function readBody(req) {
  let body = "";
  for await (const chunk of req) {
    body += chunk;
    if (body.length > maxBody) throw new BridgeRefusal("body too large");
  }
  return body;
}

/**
 * The loopback bridge of the device gates. The phone reaches it only on its
 * own 127.0.0.1 through `adb reverse`; it listens on the PC's 127.0.0.1 only.
 * It carries no authority: stand commands are the same allowlisted scripts a
 * host test runs, fixtures are read-only repository media, and rendezvous
 * points are JSON files in the gate's own directory. Every request is logged
 * (method, route, command, status) without bodies.
 */
export async function startDeviceBridge({
  rendezvous,
  run = runStandScript,
  port = bridgePort,
  root = mobileRoot,
} = {}) {
  const requests = [];
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://127.0.0.1");
    const entry = { method: req.method, route: url.pathname };
    const reply = (status, body = "", type = "application/json") => {
      entry.status = status;
      requests.push(entry);
      res.writeHead(status, { "content-type": type });
      res.end(body);
    };
    try {
      if (req.method === "POST" && url.pathname === "/stand") {
        const request = standRequest(JSON.parse(await readBody(req)));
        entry.command = `${request.script} ${request.args[0]}`;
        const result = run(request);
        entry.exitCode = result.exitCode;
        reply(200, JSON.stringify(result));
      } else if (req.method === "POST" && url.pathname === "/session-fixture") {
        // The existing native B1 test's fixture route (viewer only).
        const args = JSON.parse(await readBody(req));
        if (
          !Array.isArray(args) ||
          args[1] !== "viewer" ||
          !["expired", "revoke-active"].includes(args[0]) ||
          !args.every((x) => typeof x === "string") ||
          args.length !== (args[0] === "expired" ? 3 : 2)
        )
          throw new BridgeRefusal("fixture not allowed");
        entry.command = `session-fixture ${args[0]}`;
        const result = run({
          script: "stand-seed.mjs",
          args: ["session-fixture", ...args],
        });
        const json = result.stdout
          .trim()
          .split("\n")
          .filter((line) => line.trim().startsWith("{"))
          .at(-1);
        if (result.exitCode !== 0 || !json)
          return reply(400, "fixture failed", "text/plain");
        reply(200, json);
      } else if (req.method === "GET" && url.pathname === "/fixture") {
        const file = fixturePath(url.searchParams.get("path"), root);
        entry.command = `fixture ${path.basename(file)}`;
        reply(200, fs.readFileSync(file), "application/octet-stream");
      } else if (url.pathname === "/rendezvous" && rendezvous) {
        const write = req.method === "PUT";
        if (!write && req.method !== "GET")
          throw new BridgeRefusal("method not allowed");
        const name = rendezvousPoint(
          url.searchParams.get("who"),
          url.searchParams.get("name"),
          write,
        );
        entry.command = `${req.method === "PUT" ? "arrive" : "read"} ${name}`;
        const file = path.join(rendezvous, name);
        if (write) {
          const body = await readBody(req);
          JSON.parse(body);
          fs.writeFileSync(`${file}.tmp`, body);
          fs.renameSync(`${file}.tmp`, file);
          reply(204);
        } else if (fs.existsSync(file)) {
          reply(200, fs.readFileSync(file, "utf8"));
        } else {
          reply(404);
        }
      } else {
        reply(404, "unknown route", "text/plain");
      }
    } catch (error) {
      entry.refused = error instanceof BridgeRefusal ? error.message : "error";
      reply(400, entry.refused, "text/plain");
    }
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", resolve);
  });
  return {
    port: server.address().port,
    requests,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

/** The `RECHARGE_DEVICE_ENV` define: base64url JSON of string pairs. */
export function deviceEnvDefine(variables) {
  for (const [key, value] of Object.entries(variables))
    if (typeof value !== "string") throw new Error(`${key} must be a string`);
  return `RECHARGE_DEVICE_ENV=${Buffer.from(JSON.stringify(variables)).toString("base64url")}`;
}

/** One adb call against the device; throws on failure unless `allowFail`. */
export function adb(serial, args, { allowFail = false, adbPath } = {}) {
  const result = spawnSync(
    adbPath ?? adbExecutable(),
    ["-s", serial, ...args],
    {
      encoding: "utf8",
    },
  );
  const output = (result.stdout ?? "") + (result.stderr ?? "");
  if (result.status !== 0 && !allowFail)
    throw new Error(`adb ${args.join(" ")} failed: ${output}`);
  return output.trim();
}

/** adb from PATH, else the default Windows SDK location. */
export function adbExecutable() {
  if (process.env.RECHARGE_ADB) return process.env.RECHARGE_ADB;
  const sdk =
    process.env.ANDROID_HOME ??
    process.env.ANDROID_SDK_ROOT ??
    (process.env.LOCALAPPDATA
      ? path.join(process.env.LOCALAPPDATA, "Android", "Sdk")
      : undefined);
  const candidate = sdk
    ? path.join(
        sdk,
        "platform-tools",
        process.platform === "win32" ? "adb.exe" : "adb",
      )
    : undefined;
  return candidate && fs.existsSync(candidate) ? candidate : "adb";
}

/** Keeps the stand ports on the phone's loopback; returns `reverse --list`. */
export function reversePorts(serial, options) {
  for (const port of reversedPorts)
    adb(serial, ["reverse", `tcp:${port}`, `tcp:${port}`], options);
  return adb(serial, ["reverse", "--list"], options);
}

export function removeReversedPorts(serial, options) {
  for (const port of reversedPorts)
    adb(serial, ["reverse", "--remove", `tcp:${port}`], {
      ...options,
      allowFail: true,
    });
  return adb(serial, ["reverse", "--list"], { ...options, allowFail: true });
}

/**
 * Starts `flutter test <file> -d <serial>` in apps/mobile; the console goes to
 * `log`. Returns the child, its exit promise and a `stop()` for a process the
 * gate ended on purpose.
 */
export function flutterOnDevice(
  file,
  serial,
  { defines = [], log, extra = [] },
) {
  const args = [
    "test",
    "--no-pub",
    ...extra,
    "-d",
    serial,
    ...defines.map((define) => `--dart-define=${define}`),
    file,
  ];
  const output = fs.createWriteStream(log);
  const child =
    process.platform === "win32"
      ? spawn("cmd.exe", ["/c", "flutter", ...args], { cwd: mobileRoot })
      : spawn("flutter", args, { cwd: mobileRoot });
  child.stdout.pipe(output);
  child.stderr.pipe(output);
  const started = { child, log };
  started.exited = new Promise((resolve) =>
    child.on("close", (code) => {
      started.code = code;
      resolve(code);
    }),
  );
  started.stop = () => {
    if (started.code !== undefined) return started.exited;
    if (process.platform === "win32")
      spawnSync("taskkill", ["/pid", String(child.pid), "/t", "/f"]);
    else child.kill("SIGKILL");
    return started.exited;
  };
  return started;
}
