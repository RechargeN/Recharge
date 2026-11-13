import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import {
  allowedHosts,
  cachedTarball,
  clamdConf,
  jobFlags,
  jobLimits,
  jobSource,
  keeperScript,
  main,
  ps,
  readableError,
  readLedger,
  readLock,
  remainingBudget,
  standDatabase,
  zipScript,
} from "./media-tools.mjs";

const MiB = 1024 * 1024;

test("the lock is L1 with a 300 MB budget and the stand database it records", () => {
  const lock = readLock();
  assert.equal(lock.mode, "L1");
  assert.equal(lock.budgetBytes, 300_000_000);
  assert.equal(lock.databases.official, null);
  assert.equal(
    lock.databases.stand.sha256,
    createHash("sha256").update(standDatabase()).digest("hex"),
  );
  assert.match(standDatabase(), /^Recharge\.Test\.Marker:0:\*:[0-9a-f]+\n$/u);
});

test("downloads reach only the manifest hosts", () => {
  assert.deepEqual([...allowedHosts].sort(), [
    "github.com",
    "nodejs.org",
    "objects.githubusercontent.com",
    "raw.githubusercontent.com",
    "release-assets.githubusercontent.com",
  ]);
  for (const artifact of Object.values(readLock().artifacts))
    assert.ok(allowedHosts.has(new URL(artifact.url).hostname), artifact.url);
});

test("the budget ledger counts every byte against the lock budget", () => {
  const file = path.join(
    fs.mkdtempSync(path.join(os.tmpdir(), "d1-ledger-")),
    "ledger.json",
  );
  assert.deepEqual(readLedger(file), { totalBytes: 0, entries: [] });
  assert.equal(remainingBudget({ budgetBytes: 300 }, { totalBytes: 120 }), 180);
});

test("a cached tarball is found by its SRI in the cacache content store", () => {
  const sri = readLock().npm[0].integrity;
  const hex = Buffer.from(sri.slice("sha512-".length), "base64").toString(
    "hex",
  );
  assert.equal(
    cachedTarball("C:\\cache", sri),
    path.join(
      "C:\\cache",
      "_cacache",
      "content-v2",
      "sha512",
      hex.slice(0, 2),
      hex.slice(2, 4),
      hex.slice(4),
    ),
  );
});

test("PowerShell CLIXML errors become readable text", () => {
  const clixml =
    '#< CLIXML\r\n<Objs Version="1.1.0.1"><S S="Error">unsafe path: a/../b_x000D__x000A_</S></Objs>';
  assert.equal(readableError(clixml), "unsafe path: a/../b");
});

test("the keeper job: limits of §4.2, kill on close, no breakaway", () => {
  assert.deepEqual(jobLimits.service, {
    processBytes: 768 * MiB,
    jobBytes: 1024 * MiB,
    processes: 3,
  });
  assert.deepEqual(jobLimits.clamd, {
    processBytes: 1024 * MiB,
    jobBytes: 1280 * MiB,
    processes: 2,
  });
  const flags = /info\.Basic\.LimitFlags = ([^;]+);/u.exec(jobSource)?.[1];
  const value = flags
    .split("|")
    .reduce((sum, part) => sum | Number(part.trim()), 0);
  assert.equal(value & jobFlags.killOnJobClose, jobFlags.killOnJobClose);
  assert.equal(
    value & jobFlags.dieOnUnhandledException,
    jobFlags.dieOnUnhandledException,
  );
  assert.equal(
    value &
      (jobFlags.processMemory | jobFlags.jobMemory | jobFlags.activeProcess),
    0x308,
  );
  assert.equal(value & (jobFlags.breakawayOk | jobFlags.silentBreakawayOk), 0);
  assert.match(
    keeperScript,
    /-NoNewWindow/u,
    "no extra console host inside the job",
  );
  assert.match(keeperScript, /JoinNew\(/u);
  assert.ok(
    keeperScript.indexOf("JoinNew(") < keeperScript.indexOf("Start-Process"),
    "join first",
  );
});

test("selftest probes are reserved for selftest", async () => {
  await assert.rejects(
    main(["start", "--selftest-probes"]),
    /reserved for selftest/u,
  );
  const script = fs.readFileSync(
    new URL("./media-tools.mjs", import.meta.url),
    "utf8",
  );
  const gate = fs.readFileSync(
    new URL("./stand-d1-gate.mjs", import.meta.url),
    "utf8",
  );
  assert.equal(gate.includes("selftestProbes: true"), false);
  assert.equal(gate.includes("--selftest-probes"), false);
  assert.equal(
    (script.match(/selftestProbes: true/gu) ?? []).length,
    1,
    "only selftest() sets it",
  );
});

test("clamd.conf: loopback, bounded, limits alert instead of passing", () => {
  const conf = clamdConf("C:\\run", 3310);
  for (const line of [
    "TCPSocket 3310",
    "TCPAddr 127.0.0.1",
    "MaxThreads 2",
    "StreamMaxLength 2M",
    "MaxRecursion 8",
    "MaxScanTime 10000",
    "AlertExceedsMax yes",
    "AlertBrokenMedia yes",
    "Bytecode no",
  ])
    assert.ok(conf.split("\n").includes(line), line);
});

test(
  "zip extraction refuses unsafe paths, oversized and crowded archives",
  { skip: process.platform === "win32" ? false : "uses Windows PowerShell" },
  () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "d1-zip-"));
    const make = (name, entries) =>
      ps(
        "Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem; " +
          `$f = [System.IO.File]::Open('${path.join(dir, name)}', 'Create'); $z = New-Object System.IO.Compression.ZipArchive($f, 'Create'); ` +
          entries
            .map(
              ([entry, size]) =>
                `$e = $z.CreateEntry('${entry}'); $s = $e.Open(); $s.Write((New-Object byte[] ${size}), 0, ${size}); $s.Dispose(); `,
            )
            .join("") +
          "$z.Dispose(); $f.Dispose()",
      );
    const extract = (name, maxBytes, maxEntries) =>
      ps(zipScript, {
        env: {
          RECHARGE_ZIP: path.join(dir, name),
          RECHARGE_DEST: path.join(dir, `out-${name}`),
          RECHARGE_MAX_BYTES: String(maxBytes),
          RECHARGE_MAX_ENTRIES: String(maxEntries),
        },
      });
    make("ok.zip", [["dir/a.txt", 10]]);
    make("dotdot.zip", [["dir/../../evil.txt", 10]]);
    make("drive.zip", [["C:/x.txt", 10]]);
    make("big.zip", [["a.bin", 200_000]]);
    make(
      "many.zip",
      Array.from({ length: 5 }, (_, i) => [`f${i}.txt`, 1]),
    );
    assert.deepEqual(JSON.parse(extract("ok.zip", 1000, 10)), {
      entries: 1,
      bytes: 10,
    });
    assert.throws(() => extract("dotdot.zip", 1000, 10), /unsafe path/u);
    assert.throws(() => extract("drive.zip", 1000, 10), /unsafe path/u);
    assert.throws(() => extract("big.zip", 100_000, 10), /declares/u);
    assert.throws(() => extract("many.zip", 1000, 4), /entries/u);
    assert.equal(
      fs.existsSync(path.join(dir, "out-dotdot.zip")),
      false,
      "nothing written",
    );
  },
);
