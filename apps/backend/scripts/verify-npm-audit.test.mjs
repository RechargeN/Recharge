import assert from "node:assert/strict";
import { test } from "node:test";
import { evaluateAudit } from "./verify-npm-audit.mjs";

function report(vulnerabilities = {}) {
  const counts = { info: 0, low: 0, moderate: 0, high: 0, critical: 0 };
  for (const value of Object.values(vulnerabilities)) counts[value.severity]++;
  return {
    code: counts.high + counts.critical ? 1 : 0,
    report: {
      auditReportVersion: 2,
      vulnerabilities,
      metadata: { vulnerabilities: counts },
    },
  };
}
function fixture() {
  return {
    now: new Date("2026-10-18T00:00:00Z"),
    production: report(),
    full: report({
      braces: {
        severity: "high",
        nodes: ["node_modules/braces"],
        via: [
          {
            name: "braces",
            dependency: "braces",
            severity: "high",
            range: "<=3.0.3",
            url: "https://github.com/advisories/GHSA-vfj7-8cjw-p6xm",
          },
        ],
      },
      chokidar: {
        severity: "high",
        nodes: ["node_modules/chokidar"],
        via: ["braces"],
      },
      "firebase-tools": {
        severity: "high",
        nodes: ["node_modules/firebase-tools"],
        via: ["chokidar"],
      },
    }),
    lock: {
      lockfileVersion: 3,
      packages: {
        "": {
          dependencies: { app: "1.0.0" },
          devDependencies: { "firebase-tools": "15.34.0" },
        },
        "node_modules/app": { version: "1.0.0" },
        "node_modules/firebase-tools": {
          version: "15.34.0",
          dev: true,
          dependencies: { chokidar: "3.6.0" },
        },
        "node_modules/chokidar": {
          version: "3.6.0",
          dev: true,
          dependencies: { braces: "3.0.3" },
        },
        "node_modules/braces": { version: "3.0.3", dev: true },
      },
    },
    policy: {
      defect: "DEF-05",
      advisory: "GHSA-vfj7-8cjw-p6xm",
      package: "braces",
      via: "firebase-tools",
      cliVersion: "15.34.0",
      createdAt: "2026-10-17T00:00:00Z",
      expiresAt: "2026-11-16T00:00:00Z",
      status: "approved",
      approvedBy: "owner-test-fixture",
      approvedAt: "2026-10-17T12:00:00Z",
    },
    versions: ["2.3.2", "3.0.2", "3.0.3"],
  };
}

test("only the exact advisory and its propagated dev CLI findings can be excepted", () => {
  assert.deepEqual(evaluateAudit(fixture()), {
    exceptionUsed: true,
    reviewOnly: false,
  });
});
test("production high/critical never receive an exception", () => {
  for (const severity of ["high", "critical"]) {
    const x = fixture();
    x.production = report({
      braces: {
        severity,
        nodes: ["node_modules/braces"],
        via: x.full.report.vulnerabilities.braces.via,
      },
    });
    assert.throws(() => evaluateAudit(x), /Production audit is strict/);
  }
});
test("braces in production is rejected even if production audit reports no advisory", () => {
  const x = fixture();
  x.lock.packages["node_modules/app"].dependencies = { chokidar: "3.6.0" };
  assert.throws(() => evaluateAudit(x), /production graph/);
  const y = fixture();
  y.lock.packages["node_modules/braces"].dev = false;
  assert.throws(() => evaluateAudit(y), /production graph/);
});
test("a second path to a hoisted braces outside CLI is rejected", () => {
  const x = fixture();
  x.lock.packages[""].devDependencies.other = "1.0.0";
  x.lock.packages["node_modules/other"] = {
    version: "1.0.0",
    dev: true,
    dependencies: { chokidar: "3.6.0" },
  };
  assert.throws(() => evaluateAudit(x), /outside firebase-tools/);
});
test("another high/critical advisory cannot hide behind a propagated CLI finding", () => {
  for (const severity of ["high", "critical"]) {
    const x = fixture();
    x.full.report.vulnerabilities.braces.via.push({
      name: "braces",
      dependency: "braces",
      severity,
      url: "https://github.com/advisories/GHSA-another-advisory",
      range: "*",
    });
    assert.throws(() => evaluateAudit(x), /Unapproved high\/critical/);
  }
});
test("advisory identity, package, range and severity cannot silently broaden", () => {
  for (const [key, value] of [
    ["name", "other"],
    ["dependency", "other"],
    ["range", "*"],
    ["severity", "critical"],
  ]) {
    const x = fixture();
    x.full.report.vulnerabilities.braces.via[0][key] = value;
    assert.throws(() => evaluateAudit(x), /Unapproved high\/critical/);
  }
});
test("expiry, future dates and a window beyond 30 days fail closed", () => {
  for (const now of ["2026-11-16T00:00:00Z", "2026-11-17T00:00:00Z", "invalid"])
    assert.throws(
      () => evaluateAudit({ ...fixture(), now: new Date(now) }),
      /expired or date window/,
    );
  const x = fixture();
  x.policy.expiresAt = "2026-11-17T00:00:00Z";
  assert.throws(() => evaluateAudit(x), /expired or date window/);
});
test("a new stable release outside the advisory range disables the exception", () => {
  for (const version of ["3.0.4", "3.1.0", "4.0.0", "3.0.4-beta.1"])
    assert.throws(
      () => evaluateAudit({ ...fixture(), versions: [version] }),
      /remove exception/,
    );
  assert.throws(
    () => evaluateAudit({ ...fixture(), versions: null }),
    /Upstream version check failed/,
  );
});
test("proposed policy defaults to failure; local review cannot be used in CI", () => {
  const x = fixture();
  x.policy.status = "proposed";
  x.policy.approvedBy = null;
  x.policy.approvedAt = null;
  assert.throws(() => evaluateAudit(x), /Owner approval pending/);
  assert.deepEqual(evaluateAudit({ ...x, reviewProposal: true }), {
    exceptionUsed: true,
    reviewOnly: true,
  });
  assert.throws(
    () => evaluateAudit({ ...x, reviewProposal: true, ci: true }),
    /forbidden in CI/,
  );
});
test("malformed reports, unknown propagation, graph drift and unexpected npm failures reject", () => {
  const cases = [
    (x) => {
      x.full.code = 2;
    },
    (x) => {
      x.full.code = 0;
    },
    (x) => {
      x.full.report.error = { code: "network" };
    },
    (x) => {
      x.full.report.metadata.vulnerabilities.high = 0;
    },
    (x) => {
      x.full.report.vulnerabilities.chokidar.via = ["missing"];
    },
    (x) => {
      x.full.report.vulnerabilities.braces.nodes = [
        "node_modules/elsewhere/braces",
      ];
    },
    (x) => {
      x.lock.packages["node_modules/firebase-tools"].version = "15.35.0";
    },
    (x) => {
      delete x.lock.packages["node_modules/chokidar"];
    },
    (x) => {
      x.lock.packages["node_modules/chokidar"].dependencies.loop = "1";
      x.lock.packages["node_modules/loop"] = {
        dependencies: { braces: "3.0.3" },
      };
      x.lock.packages[""].dependencies.loop = "1";
    },
  ];
  for (const mutate of cases) {
    const x = fixture();
    mutate(x);
    assert.throws(() => evaluateAudit(x));
  }
});
test("clean strict audits need no exception approval", () => {
  const x = fixture();
  x.full = report();
  x.policy.status = "proposed";
  assert.deepEqual(evaluateAudit(x), {
    exceptionUsed: false,
    reviewOnly: false,
  });
});

test("installed optional extra roots are traced without inheriting CLI provenance", () => {
  const x = fixture();
  x.installedExtraRoots = ["optional-artifact"];
  x.lock.packages["node_modules/optional-artifact"] = {
    version: "1.0.0",
    optional: true,
  };
  assert.equal(evaluateAudit(x).exceptionUsed, true);
  x.lock.packages["node_modules/optional-artifact"].dependencies = {
    chokidar: "3.6.0",
  };
  assert.throws(() => evaluateAudit(x), /outside firebase-tools/);
  assert.throws(
    () => evaluateAudit({ ...fixture(), installedExtraRoots: ["braces"] }),
    /outside firebase-tools/,
  );
});
