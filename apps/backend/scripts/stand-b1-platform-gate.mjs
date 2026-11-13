import http from "node:http";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../../..");
function run(name, args) {
  const result = spawnSync(process.execPath, [path.join(here, name), ...args], {
    encoding: "utf8",
    env: process.env,
  });
  if (result.status !== 0)
    throw new Error(`${name}: ${result.stderr}${result.stdout}`);
  return result.stdout;
}
export async function platformGate(device) {
  let server;
  try {
    run("emulator-stand.mjs", ["stop"]);
    const build = spawnSync(
      process.execPath,
      [
        path.join(
          repo,
          "apps/backend/functions/node_modules/typescript/bin/tsc",
        ),
      ],
      {
        cwd: path.join(repo, "apps/backend/functions"),
        stdio: "inherit",
        env: process.env,
      },
    );
    if (build.status !== 0)
      throw new Error("Backend build failed before Emulator start");
    run("emulator-stand.mjs", ["reset", "--yes"]);
    run("emulator-stand.mjs", ["start"]);
    run("stand-seed.mjs", ["seed"]);
    run("stand-seed.mjs", ["verify"]);
    server = http.createServer(async (req, res) => {
      try {
        if (req.method !== "POST" || req.url !== "/session-fixture")
          throw new Error("Refused route");
        let body = "";
        for await (const chunk of req) {
          body += chunk;
          if (body.length > 1024) throw new Error("Too large");
        }
        const args = JSON.parse(body);
        if (
          !Array.isArray(args) ||
          args[1] !== "viewer" ||
          !["expired", "revoke-active"].includes(args[0]) ||
          !args.every((x) => typeof x === "string") ||
          args.length !== (args[0] === "expired" ? 3 : 2)
        )
          throw new Error("Refused fixture");
        const output = run("stand-seed.mjs", ["session-fixture", ...args]);
        const json = output
          .trim()
          .split("\n")
          .filter((x) => x.trim().startsWith("{"))
          .at(-1);
        if (!json) throw new Error("No fixture response");
        res.writeHead(200, { "content-type": "application/json" });
        res.end(json);
      } catch (error) {
        res.writeHead(400);
        res.end(error.message);
      }
    });
    await new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(8765, "127.0.0.1", resolve);
    });
    const args = [
      "test",
      "--no-pub",
      "integration_test/booking_session_adapters_stand_test.dart",
      "-d",
      device,
      "--dart-define=RECHARGE_B1_PLATFORM=true",
    ];
    const code = await new Promise((resolve, reject) => {
      const child =
        process.platform === "win32"
          ? spawn("cmd.exe", ["/c", "flutter", ...args], {
              cwd: path.join(repo, "apps/mobile"),
              env: process.env,
              stdio: "inherit",
            })
          : spawn("flutter", args, {
              cwd: path.join(repo, "apps/mobile"),
              env: process.env,
              stdio: "inherit",
            });
      child.once("error", reject);
      child.once("exit", resolve);
    });
    if (code !== 0) throw new Error(`Native B1 Flutter exit ${code}`);
    console.log(
      "B1 native adapters passed: Android Emulator, no UI or physical-device claim",
    );
  } finally {
    if (server) await new Promise((resolve) => server.close(resolve));
    run("emulator-stand.mjs", ["stop"]);
  }
}
