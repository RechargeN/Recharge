import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  clamdVersion,
  cvdCertFile,
  cvdCerts,
  databaseSetProblems,
  debCertsPath,
  freshclamInvocation,
  inspectionMarkdown,
  noticePattern,
  officialAllowance,
  parseSigtoolInfo,
  requiredDatabases,
  scopeArgs,
  scopeLimits,
  versionProbePort,
  watched,
} from "./media-tools-linux.mjs";
import { openPoints, readStage, stageFile } from "./stand-d1-linux-gate.mjs";
import { clamdConf, readLock } from "./media-tools.mjs";

const MiB = 1024 * 1024;

test("sigtool --info: version, build time, signatures and the signature check", () => {
  const info = parseSigtoolInfo(
    [
      "File: daily.cvd",
      "Build time: 08 Oct 2026 09:21 +0000",
      "Version: 27800",
      "Signatures: 2071234",
      "Functionality level: 90",
      "Builder: raynman",
      "MD5: 0123456789abcdef0123456789abcdef",
      "Digital signature: AbCd",
      "Verification OK.",
    ].join("\n"),
  );
  assert.deepEqual(info, {
    buildTime: "08 Oct 2026 09:21 +0000",
    version: 27800,
    signatures: 2071234,
    functionalityLevel: 90,
    builder: "raynman",
    verified: true,
  });
  assert.equal(parseSigtoolInfo("Version: 1\n").verified, false);
});

test("license notices inside a database are found by name", () => {
  for (const name of [
    "COPYING",
    "COPYING.txt",
    "LICENSE",
    "NOTICE.md",
    "README",
  ])
    assert.ok(noticePattern.test(name), name);
  for (const name of ["daily.info", "main.hdb", "bytecode.cbc"])
    assert.equal(noticePattern.test(name), false, name);
});

test("a cgroup scope: hard memory cap, no swap, task cap, no secret on the command line", () => {
  const args = scopeArgs({
    unit: "recharge-media-tools-x",
    limits: scopeLimits.service,
    uid: 1001,
    gid: 1001,
    env: { HOME: "/home/runner", RECHARGE_TOOLS_SECRETS_FILE: "/tmp/s.json" },
    exe: "/usr/bin/node",
    args: ["host.js"],
  });
  assert.deepEqual(args.slice(0, 3), ["-n", "systemd-run", "--scope"]);
  assert.ok(args.includes(`MemoryMax=${768 * MiB}`));
  assert.ok(args.includes("MemorySwapMax=0"));
  assert.ok(args.includes(`TasksMax=${scopeLimits.service.tasksMax}`));
  assert.ok(args.includes("--uid=1001") && args.includes("--gid=1001"));
  const command = args.slice(args.indexOf("--") + 1);
  assert.deepEqual(command, [
    "/usr/bin/env",
    "HOME=/home/runner",
    "RECHARGE_TOOLS_SECRETS_FILE=/tmp/s.json",
    "/usr/bin/node",
    "host.js",
  ]);
  assert.equal(
    args.some((arg) => /TOKEN=/u.test(arg)),
    false,
  );
  assert.ok(
    scopeLimits.clamd.memoryMax >= 2048 * MiB,
    "room for the official databases",
  );
});

const inspection = {
  databases: [
    {
      name: "daily.cvd",
      version: 27800,
      buildTime: "x",
      signatures: 1,
      verified: true,
      bytes: 10,
      sha256: "a".repeat(64),
      copying: true,
      notices: [],
    },
    {
      name: "main.cvd",
      version: 62,
      buildTime: "y",
      signatures: 2,
      verified: false,
      bytes: 20,
      sha256: "b".repeat(64),
      copying: false,
      notices: [],
    },
    {
      name: "bytecode.cvd",
      version: 339,
      buildTime: "z",
      signatures: 3,
      verified: true,
      bytes: 30,
      sha256: "d".repeat(64),
      copying: true,
      notices: [],
    },
  ],
};
const sound = (db) => ({ ...db, verified: true, copying: true });

test("the inspection report names a missing COPYING and a failed check", () => {
  const markdown = inspectionMarkdown(
    {
      deb: { size: 1, sha256: "c".repeat(64) },
      gpg: { signingKeyFingerprint: "F".repeat(40) },
      clamd: "ClamAV 1.5.4",
      certs: { file: "clamav.crt", size: 1976, sha256: "d".repeat(64) },
    },
    inspection,
    [
      {
        name: "@img/sharp-libvips-linux-x64",
        version: "1.3.4",
        license: "LGPL-3.0-or-later",
        notices: [],
      },
    ],
  );
  assert.match(markdown, /\| main\.cvd \| 62 .*\| FAILED \|.*\| NOT FOUND \|/u);
  assert.match(
    markdown,
    /CVD certificate: `usr\/local\/etc\/certs\/clamav\.crt` from the \.deb, 1976 bytes, SHA-256 `d{64}`/u,
  );
  assert.match(
    markdown,
    /@img\/sharp-libvips-linux-x64@1\.3\.4 \(LGPL-3\.0-or-later\)/u,
  );
  assert.deepEqual(openPoints(inspection), [
    'main.cvd: the signature check did not report "Verification OK"',
    "main.cvd: no COPYING file inside the database",
  ]);
  assert.deepEqual(
    openPoints({ databases: inspection.databases.map(sound) }),
    [],
  );
});

/** A child that grows `dir` by `bytes` in one write and exits with `code` at once. */
function burst(dir, bytes, code = 0) {
  return [
    process.execPath,
    [
      "-e",
      'require("node:fs").writeFileSync(process.argv[1], Buffer.alloc(Number(process.argv[2]))); process.exit(Number(process.argv[3]));',
      path.join(dir, `burst-${bytes}`),
      String(bytes),
      String(code),
    ],
  ];
}

test("freshclam budget: growth over the allowance is refused at exit even with exit code 0", async () => {
  const allowance = 64 * 1024;
  const over = fs.mkdtempSync(path.join(os.tmpdir(), "d1l-budget-"));
  // One write, then exit 0 well before the 500 ms poll: only the final check sees it.
  await assert.rejects(
    watched(...burst(over, allowance + 1), {}, over, allowance),
    (error) => {
      assert.match(
        error.message,
        /download budget exceeded: 65537 bytes, allowance 65536/u,
      );
      assert.equal(error.grown, allowance + 1);
      return true;
    },
  );
  const exact = fs.mkdtempSync(path.join(os.tmpdir(), "d1l-budget-"));
  assert.equal(
    await watched(...burst(exact, allowance), {}, exact, allowance),
    allowance,
  );
  const failed = fs.mkdtempSync(path.join(os.tmpdir(), "d1l-budget-"));
  await assert.rejects(
    watched(...burst(failed, 10, 3), {}, failed, allowance),
    (error) => {
      assert.match(error.message, /exited 3/u);
      assert.equal(error.grown, 10);
      return true;
    },
  );
});

test("freshclam budget: its own cap, never more than the D1-L budget leaves", () => {
  const linux = { budgetBytes: 700, officialDatabaseBudgetBytes: 400 };
  assert.equal(officialAllowance(linux, { totalBytes: 0 }), 400);
  assert.equal(officialAllowance(linux, { totalBytes: 650 }), 50);
  for (const totalBytes of [700, 750])
    assert.throws(
      () => officialAllowance(linux, { totalBytes }),
      /no download budget left for the official databases/u,
    );
  const { linux: locked } = readLock();
  assert.equal(
    officialAllowance(locked, { totalBytes: 0 }),
    locked.officialDatabaseBudgetBytes,
  );
});

test("official databases: main, daily and bytecode each exactly once, as .cvd or .cld", () => {
  assert.deepEqual(requiredDatabases, ["main", "daily", "bytecode"]);
  assert.deepEqual(
    databaseSetProblems(["bytecode.cvd", "daily.cld", "main.cvd"]),
    [],
  );
  assert.deepEqual(databaseSetProblems(["daily.cld", "main.cvd"]), [
    "bytecode: missing (neither bytecode.cvd nor bytecode.cld)",
  ]);
  assert.deepEqual(
    databaseSetProblems(["bytecode.cvd", "daily.cvd", "daily.cld", "main.cvd"]),
    ["daily: both daily.cvd and daily.cld; expected one"],
  );
  assert.deepEqual(databaseSetProblems([]), [
    "main: missing (neither main.cvd nor main.cld)",
    "daily: missing (neither daily.cvd nor daily.cld)",
    "bytecode: missing (neither bytecode.cvd nor bytecode.cld)",
  ]);
  // A gate report without bytecode is an open point even when the rest is sound.
  const withoutBytecode = {
    databases: inspection.databases
      .filter((db) => db.name !== "bytecode.cvd")
      .map(sound),
  };
  assert.deepEqual(openPoints(withoutBytecode), [
    "bytecode: missing (neither bytecode.cvd nor bytecode.cld)",
  ]);
});

test("the set check guards the download, the inspection and the start", () => {
  const source = fs.readFileSync(
    new URL("./media-tools-linux.mjs", import.meta.url),
    "utf8",
  );
  const body = (name) => {
    const from =
      source.indexOf(`export async function ${name}(`) + 1 ||
      source.indexOf(`export function ${name}(`) + 1;
    assert.ok(from > 0, name);
    const next = source.indexOf("\nexport ", from);
    return source.slice(from - 1, next === -1 ? undefined : next);
  };
  for (const name of [
    "fetchOfficialDatabases",
    "inspectDatabases",
    "startLinux",
  ])
    assert.match(body(name), /databaseSetProblems\(/u, name);
  assert.match(body("fetchOfficialDatabases"), /officialAllowance\(/u);
  assert.match(
    body("fetchOfficialDatabases"),
    /total > lock\.linux\.budgetBytes/u,
  );
});

test("the committed stage is inspect until the owner switches it", () => {
  assert.equal(JSON.parse(fs.readFileSync(stageFile, "utf8")).stage, "inspect");
  assert.equal(readStage([]), "inspect");
  assert.equal(readStage(["--stage=test"]), "test");
  assert.throws(() => readStage(["--stage=deploy"]), /unknown stage/u);
});

test("the Linux lock pins the .deb, the sharp packages and the budgets", () => {
  const { linux } = readLock();
  assert.equal(linux.runner, "ubuntu-24.04");
  assert.equal(linux.clamav.size, 105819396);
  assert.match(linux.clamav.sha256, /^[0-9a-f]{64}$/u);
  assert.deepEqual(
    linux.npm.map((pkg) => `${pkg.name}@${pkg.version} ${pkg.license}`),
    [
      "@img/sharp-linux-x64@0.35.5 Apache-2.0",
      "@img/sharp-libvips-linux-x64@1.3.4 LGPL-3.0-or-later",
    ],
  );
  assert.ok(linux.officialDatabaseBudgetBytes <= linux.budgetBytes);
});

test("the workflow: pinned actions, read-only, ubuntu-24.04, push on its own paths, nothing uploaded", () => {
  const workflow = fs.readFileSync(
    new URL("../../../.github/workflows/backend-d1-linux.yml", import.meta.url),
    "utf8",
  );
  const r0 = fs.readFileSync(
    new URL("../../../.github/workflows/backend-r0.yml", import.meta.url),
    "utf8",
  );
  for (const pin of r0.match(/uses: [^\s]+@[0-9a-f]{40}/gu) ?? [])
    assert.ok(workflow.includes(pin), pin);
  assert.match(workflow, /permissions:\n  contents: read\n/u);
  assert.match(workflow, /runs-on: ubuntu-24\.04/u);
  assert.match(workflow, /persist-credentials: false/u);
  for (const forbidden of [
    "upload-artifact",
    "actions/cache",
    "id-token",
    "workflow_dispatch",
    "ubuntu-latest",
    "firebase deploy",
  ])
    assert.equal(workflow.includes(forbidden), false, forbidden);
  assert.match(
    workflow,
    /paths:\n      - "\.github\/workflows\/backend-d1-linux\.yml"\n      - "apps\/backend\/ci\/d1-linux-stage\.json"\n/u,
  );
});

test("selftest probes stay reserved for the self-check on Linux too", () => {
  const linux = fs.readFileSync(
    new URL("./media-tools-linux.mjs", import.meta.url),
    "utf8",
  );
  const gate = fs.readFileSync(
    new URL("./stand-d1-linux-gate.mjs", import.meta.url),
    "utf8",
  );
  assert.equal(
    (linux.match(/selftestProbes: true/gu) ?? []).length,
    1,
    "only selftestLinux()",
  );
  assert.equal(gate.includes("selftestProbes: true"), false);
  assert.equal(gate.includes("--selftest-probes"), false);
});

/**
 * Drives clamdVersion with a recorded spawn: the probe the fetch step really
 * runs (run 38246774477 failed without a configuration file).
 */
function versionProbe(answer) {
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "d1-version-test-"));
  const tools = {
    clamd: "/opt/clamav/sbin/clamd",
    env: { LD_LIBRARY_PATH: "/x" },
  };
  const calls = [];
  const spawn = (command, args, options) => {
    const flag = args.find((arg) => arg.startsWith("--config-file="));
    const conf = flag?.slice("--config-file=".length);
    calls.push({
      command,
      args,
      options,
      conf,
      written:
        conf !== undefined && fs.existsSync(conf)
          ? fs.readFileSync(conf, "utf8")
          : null,
    });
    return answer();
  };
  const leftovers = () => fs.readdirSync(tmpRoot);
  return { tmpRoot, tools, calls, spawn, leftovers };
}

test("clamd --version gets a written clamdConf through --config-file, then the directory is gone", () => {
  const probe = versionProbe(() => ({
    status: 0,
    stdout: "ClamAV 1.5.4/27800/Thu Oct  9 09:21:00 2026\n",
    stderr: "",
  }));
  try {
    const version = clamdVersion(probe.tools, {
      spawn: probe.spawn,
      tmpRoot: probe.tmpRoot,
    });
    assert.equal(version, "ClamAV 1.5.4/27800/Thu Oct  9 09:21:00 2026");
    assert.equal(probe.calls.length, 1);
    const [call] = probe.calls;
    assert.equal(call.command, probe.tools.clamd);
    assert.deepEqual(call.args, [`--config-file=${call.conf}`, "--version"]);
    assert.equal(call.options.env, probe.tools.env);
    assert.equal(path.basename(call.conf), "clamd.conf");
    assert.equal(
      path.dirname(path.dirname(call.conf)),
      probe.tmpRoot,
      "the configuration lives in a fresh directory under tmpRoot",
    );
    assert.equal(
      call.written,
      clamdConf(path.dirname(call.conf), versionProbePort),
      "the file passed to clamd is exactly clamdConf",
    );
    assert.deepEqual(
      probe.leftovers(),
      [],
      "the temporary directory is removed",
    );
  } finally {
    fs.rmSync(probe.tmpRoot, { recursive: true, force: true });
  }
});

test("a failing clamd --version keeps exit code and output and still cleans up", () => {
  const probe = versionProbe(() => ({
    status: 1,
    stdout: "",
    stderr:
      "ERROR: Can't open/parse the config file /usr/local/etc/clamd.conf\n",
  }));
  try {
    assert.throws(
      () =>
        clamdVersion(probe.tools, {
          spawn: probe.spawn,
          tmpRoot: probe.tmpRoot,
        }),
      /clamd --version exited 1: ERROR: Can't open\/parse the config file/u,
    );
    assert.equal(
      probe.calls[0].written !== null,
      true,
      "the file existed during the call",
    );
    assert.deepEqual(probe.leftovers(), []);
  } finally {
    fs.rmSync(probe.tmpRoot, { recursive: true, force: true });
  }
});

test("clamd that cannot start, dies by signal or throws still leaves no directory", () => {
  const cases = [
    [
      () => ({
        error: new Error("spawn ENOENT"),
        status: null,
        stdout: "",
        stderr: "",
      }),
      /could not start: spawn ENOENT/u,
    ],
    [
      () => ({ status: null, signal: "SIGKILL", stdout: "", stderr: "" }),
      /exited by signal SIGKILL: \(no output\)/u,
    ],
    [
      () => {
        throw new Error("spawn threw");
      },
      /spawn threw/u,
    ],
  ];
  for (const [answer, expected] of cases) {
    const probe = versionProbe(answer);
    try {
      assert.throws(
        () =>
          clamdVersion(probe.tools, {
            spawn: probe.spawn,
            tmpRoot: probe.tmpRoot,
          }),
        expected,
      );
      assert.deepEqual(probe.leftovers(), []);
    } finally {
      fs.rmSync(probe.tmpRoot, { recursive: true, force: true });
    }
  }
});

test("the fetch step asks clamd for its version only through clamdVersion", () => {
  const linux = fs.readFileSync(
    new URL("./media-tools-linux.mjs", import.meta.url),
    "utf8",
  );
  assert.equal(
    /tools\.clamd,\s*\[\s*["']--version["']/u.test(linux),
    false,
    "no clamd --version without a configuration file",
  );
  assert.match(linux, /const version = clamdVersion\(tools\);/u);
});

/** A fake extracted .deb root; `shape` builds its certificate directory. */
function debRoot(shape) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "d1-certs-test-"));
  shape(path.join(root, ...debCertsPath), root);
  return root;
}

test("DEF-08: the CVD certificate comes from the .deb as a plain, readable, non-empty file", () => {
  const pem = "-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n";
  const root = debRoot((dir) => {
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, cvdCertFile), pem);
  });
  try {
    const certs = cvdCerts(root);
    assert.equal(certs.dir, path.join(root, "usr", "local", "etc", "certs"));
    assert.equal(certs.file, "clamav.crt");
    assert.equal(certs.size, Buffer.byteLength(pem));
    assert.equal(certs.sha256, createHash("sha256").update(pem).digest("hex"));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("DEF-08: a missing, empty, non-file or linked certificate stops the gate", () => {
  const cases = [
    ["no directory", () => {}, /does not exist in the ClamAV \.deb/u],
    [
      "no clamav.crt",
      (dir) => fs.mkdirSync(dir, { recursive: true }),
      /CVD certificates missing: .*clamav\.crt/u,
    ],
    [
      "empty clamav.crt",
      (dir) => {
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(path.join(dir, cvdCertFile), "");
      },
      /is empty/u,
    ],
    [
      "clamav.crt is a directory",
      (dir) => fs.mkdirSync(path.join(dir, cvdCertFile), { recursive: true }),
      /is not a plain file/u,
    ],
    [
      "the certificate directory is a link",
      (dir, root) => {
        const elsewhere = path.join(root, "elsewhere");
        fs.mkdirSync(elsewhere, { recursive: true });
        fs.writeFileSync(path.join(elsewhere, cvdCertFile), "x");
        fs.mkdirSync(path.dirname(dir), { recursive: true });
        fs.symlinkSync(elsewhere, dir, "junction");
      },
      /is not a plain directory/u,
    ],
  ];
  for (const [name, shape, expected] of cases) {
    const root = debRoot(shape);
    try {
      assert.throws(() => cvdCerts(root), expected, name);
    } finally {
      fs.rmSync(root, { recursive: true, force: true });
    }
  }
});

test("DEF-08: freshclam gets the .deb certificates as CVD_CERTS_DIR and in its configuration", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "d1-freshclam-test-"));
  try {
    const tools = {
      freshclam: "/opt/clamav/bin/freshclam",
      certs: "/tmp/Recharge/tools/clamav-1.5.4-linux/usr/local/etc/certs",
      env: { LD_LIBRARY_PATH: "/opt/clamav/lib", PATH: "/usr/bin" },
    };
    const dir = path.join(root, "official-db");
    const run = freshclamInvocation(tools, { dir, root });
    assert.equal(run.command, tools.freshclam);
    assert.deepEqual(run.args, [`--config-file=${run.conf}`, "--stdout"]);
    assert.equal(
      run.args.some((arg) => arg.includes("cvdcertsdir")),
      false,
      "--cvdcertsdir is not added without evidence",
    );
    assert.equal(run.options.env.CVD_CERTS_DIR, tools.certs);
    assert.equal(run.options.env.LD_LIBRARY_PATH, tools.env.LD_LIBRARY_PATH);
    assert.equal(run.options.env.PATH, tools.env.PATH);
    assert.equal(path.dirname(run.conf), root);
    const conf = fs.readFileSync(run.conf, "utf8").split("\n");
    assert.ok(conf.includes(`DatabaseDirectory ${dir}`));
    assert.ok(conf.includes(`CVDCertsDirectory ${tools.certs}`));
    assert.equal(
      conf.filter((line) => line.startsWith("CVDCertsDirectory")).length,
      1,
    );
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("DEF-08: freshclam runs only through freshclamInvocation and certificates are never optional", () => {
  const linux = fs.readFileSync(
    new URL("./media-tools-linux.mjs", import.meta.url),
    "utf8",
  );
  assert.equal(
    (linux.match(/tools\.freshclam\b/gu) ?? []).length,
    1,
    "tools.freshclam is used only to build the invocation",
  );
  assert.match(
    linux,
    /const freshclam = freshclamInvocation\(tools, \{ dir \}\);/u,
  );
  assert.match(
    linux,
    /freshclam\.command,\s*freshclam\.args,\s*freshclam\.options,/u,
  );
  assert.match(linux, /const certsFile = cvdCerts\(root\);/u);
  assert.equal(/let certs = null/u.test(linux), false);
});
