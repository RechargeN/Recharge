import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const advisory = "https://github.com/advisories/GHSA-vfj7-8cjw-p6xm";
const severities = ["info", "low", "moderate", "high", "critical"];
const high = (severity) => ["high", "critical"].includes(severity);
const fail = (message) => {
  throw new Error(message);
};
const record = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);

function audit(result, label) {
  const report = result?.report;
  if (
    ![0, 1].includes(result?.code) ||
    !record(report) ||
    report.error ||
    report.auditReportVersion !== 2 ||
    !record(report.vulnerabilities) ||
    !record(report.metadata?.vulnerabilities)
  )
    fail(`${label}: invalid audit result`);
  for (const severity of severities) {
    const count = report.metadata.vulnerabilities[severity];
    if (!Number.isSafeInteger(count) || count < 0)
      fail(`${label}: invalid severity counts`);
    const actual = Object.values(report.vulnerabilities).filter(
      (v) => v.severity === severity,
    ).length;
    if (actual !== count) fail(`${label}: inconsistent severity counts`);
  }
  for (const v of Object.values(report.vulnerabilities)) {
    if (
      !record(v) ||
      !severities.includes(v.severity) ||
      !Array.isArray(v.via) ||
      !v.via.length ||
      !Array.isArray(v.nodes) ||
      !v.nodes.length
    )
      fail(`${label}: malformed vulnerability`);
  }
  const elevated =
    report.metadata.vulnerabilities.high +
    report.metadata.vulnerabilities.critical;
  if (result.code !== (elevated ? 1 : 0))
    fail(`${label}: exit code disagrees with high threshold`);
  return report;
}

// Resolve the frozen Node dependency graph, including hoisted/optional/peer edges.
// A shared node is visited separately through CLI and through any other root.
export function bracesScope(lock, extraRoots = []) {
  if (lock?.lockfileVersion !== 3 || !record(lock.packages?.[""]))
    fail("Unsupported package lock");
  const packages = lock.packages;
  function resolve(from, name) {
    if (!/^(?:@[a-z0-9_.-]+\/)?[a-z0-9_.-]+$/i.test(name))
      fail("Invalid dependency name");
    for (let at = from; ;) {
      const candidate = `${at ? at + "/" : ""}node_modules/${name}`;
      if (Object.hasOwn(packages, candidate)) return candidate;
      if (!at) return null;
      const index = at.lastIndexOf("/node_modules/");
      at = index < 0 ? "" : at.slice(0, index);
    }
  }
  function walk(production) {
    if (extraRoots.includes("braces"))
      fail("braces has a dependency path outside firebase-tools");
    const queue = [
        { at: "", cli: false },
        ...(!production
          ? extraRoots.map((name) => ({ at: resolve("", name), cli: false }))
          : []),
      ],
      visited = new Set(),
      found = [];
    while (queue.length) {
      const { at, cli } = queue.pop();
      if (visited.has(`${at}:${cli}`)) continue;
      visited.add(`${at}:${cli}`);
      if (visited.size > 30000) fail("Dependency graph exceeds review bound");
      const p = packages[at];
      if (!record(p) || p.link) fail("Unresolved dependency node");
      const deps = {
        ...p.dependencies,
        ...p.optionalDependencies,
        ...(!at && !production ? p.devDependencies : {}),
        ...p.peerDependencies,
      };
      for (const name of Object.keys(deps)) {
        const target = resolve(at, name);
        if (!target) {
          if (
            Object.hasOwn(p.optionalDependencies ?? {}, name) ||
            p.peerDependenciesMeta?.[name]?.optional
          )
            continue;
          fail(`Unresolved required dependency: ${name}`);
        }
        const throughCli = cli || name === "firebase-tools";
        if (name === "braces")
          found.push({
            node: target,
            cli: throughCli,
            dev: packages[target].dev === true,
          });
        queue.push({ at: target, cli: throughCli });
      }
    }
    return found;
  }
  return { production: walk(true), full: walk(false) };
}

export function evaluateAudit({
  production,
  full,
  lock,
  policy,
  versions,
  now = new Date(),
  reviewProposal = false,
  ci = false,
  installedExtraRoots = [],
}) {
  const prod = audit(production, "Production");
  if (
    prod.metadata.vulnerabilities.high ||
    prod.metadata.vulnerabilities.critical
  )
    fail("Production audit is strict: high/critical found");
  const scope = bracesScope(lock, installedExtraRoots);
  if (scope.production.length || scope.full.some((row) => !row.dev))
    fail("braces is present in the production graph");
  if (scope.full.some((row) => !row.cli))
    fail("braces has a dependency path outside firebase-tools");
  const report = audit(full, "Full graph");
  function leaves(name, ancestors = new Set()) {
    const v = report.vulnerabilities[name];
    if (!v || ancestors.has(name)) fail("Invalid advisory propagation graph");
    const next = new Set([...ancestors, name]);
    return v.via.flatMap((via) => {
      if (typeof via === "string") return leaves(via, next);
      if (
        !record(via) ||
        !severities.includes(via.severity) ||
        typeof via.url !== "string"
      )
        fail("Malformed advisory leaf");
      return [via];
    });
  }
  let excepted = false;
  for (const [name, v] of Object.entries(report.vulnerabilities)) {
    const elevated = leaves(name).filter((via) => high(via.severity));
    if (
      high(v.severity) !== Boolean(elevated.length) ||
      v.severity === "critical"
    )
      fail(`Inconsistent or critical advisory: ${name}`);
    for (const via of elevated) {
      if (
        via.url !== advisory ||
        via.name !== "braces" ||
        via.dependency !== "braces" ||
        via.severity !== "high" ||
        via.range !== "<=3.0.3"
      )
        fail(`Unapproved high/critical advisory: ${via.url}`);
      excepted = true;
    }
  }
  if (!excepted) return { exceptionUsed: false, reviewOnly: false };
  const known = new Set(scope.full.map((row) => row.node));
  const nodes = report.vulnerabilities.braces?.nodes;
  if (
    !Array.isArray(nodes) ||
    !known.size ||
    nodes.length !== known.size ||
    new Set(nodes).size !== known.size ||
    !nodes.every((node) => known.has(node))
  )
    fail("Audit braces nodes do not match the reviewed dependency graph");
  if (
    lock.packages[""].devDependencies?.["firebase-tools"] !== "15.34.0" ||
    lock.packages["node_modules/firebase-tools"]?.version !== "15.34.0"
  )
    fail("Unreviewed Firebase CLI version");
  if (
    policy?.defect !== "DEF-05" ||
    policy.advisory !== "GHSA-vfj7-8cjw-p6xm" ||
    policy.package !== "braces" ||
    policy.via !== "firebase-tools" ||
    policy.cliVersion !== "15.34.0"
  )
    fail("Unreviewed exception policy");
  const created = Date.parse(policy.createdAt),
    expires = Date.parse(policy.expiresAt),
    current = now.getTime();
  if (
    ![created, expires, current].every(Number.isFinite) ||
    created > current ||
    expires <= created ||
    expires - created > 30 * 86400000 ||
    current >= expires
  )
    fail("Exception expired or date window invalid; recheck upstream");
  if (
    !Array.isArray(versions) ||
    !versions.length ||
    versions.some(
      (v) =>
        typeof v !== "string" ||
        !/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/.test(v),
    )
  )
    fail("Upstream version check failed");
  if (
    versions.some((v) => {
      const [major, minor, patch] = v.split(/[+-]/)[0].split(".").map(Number);
      return major > 3 || (major === 3 && (minor > 0 || patch > 3));
    })
  )
    fail(
      "Unaffected braces release published: remove exception and update dependencies",
    );
  if (reviewProposal && ci) fail("Proposal review mode is forbidden in CI");
  if (
    policy.status !== "approved" ||
    typeof policy.approvedBy !== "string" ||
    !policy.approvedBy.trim() ||
    !Number.isFinite(Date.parse(policy.approvedAt)) ||
    Date.parse(policy.approvedAt) > current
  ) {
    if (!(reviewProposal && !ci && policy.status === "proposed"))
      fail("Owner approval pending; exception is not active");
  }
  return { exceptionUsed: true, reviewOnly: policy.status !== "approved" };
}

function main() {
  const args = process.argv.slice(2);
  if (args.length && (args.length !== 1 || args[0] !== "--review-proposal"))
    fail("Usage: verify-npm-audit.mjs [--review-proposal]");
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), ".."),
    cwd = path.join(root, "functions");
  if (!process.env.npm_execpath) fail("Run through the locked npm");
  function npm(args) {
    const result = spawnSync(
      process.execPath,
      [process.env.npm_execpath, ...args],
      {
        cwd,
        encoding: "utf8",
        shell: false,
        timeout: 120000,
        maxBuffer: 16 * 1024 * 1024,
      },
    );
    if (result.error || result.signal || ![0, 1].includes(result.status))
      fail("npm command failed or timed out");
    let report;
    try {
      report = JSON.parse(result.stdout);
    } catch {
      fail("npm did not return valid JSON");
    }
    return { code: result.status, report };
  }
  const graph = npm(["ls", "--all", "--json"]);
  if (
    graph.code !== 0 ||
    graph.report.error ||
    graph.report.problems?.some(
      (problem) => !problem.startsWith("extraneous: "),
    )
  )
    fail("Installed dependency graph is invalid");
  const lock = JSON.parse(
    readFileSync(path.join(cwd, "package-lock.json"), "utf8"),
  );
  const declared = {
    ...lock.packages[""].dependencies,
    ...lock.packages[""].devDependencies,
    ...lock.packages[""].optionalDependencies,
  };
  const installedExtraRoots = [];
  for (const [name, installed] of Object.entries(
    graph.report.dependencies ?? {},
  )) {
    if (Object.hasOwn(declared, name)) continue;
    const locked = lock.packages[`node_modules/${name}`];
    // npm may report locked optional platform artifacts (e.g. sharp WASM) as
    // extraneous despite a successful frozen install. Trace those roots too;
    // they never acquire CLI provenance. Unknown/unlocked extras still fail.
    if (
      !installed.extraneous ||
      !locked?.optional ||
      installed.version !== locked.version
    )
      fail("Unreviewed installed dependency root");
    installedExtraRoots.push(name);
  }
  const production = npm([
    "audit",
    "--omit=dev",
    "--audit-level=high",
    "--json",
  ]);
  const full = npm(["audit", "--audit-level=high", "--json"]);
  const upstream = npm(["view", "braces", "versions", "--json"]);
  if (upstream.code !== 0) fail("Upstream check failed");
  const result = evaluateAudit({
    production,
    full,
    versions: upstream.report,
    lock,
    installedExtraRoots,
    policy: JSON.parse(
      readFileSync(
        path.join(root, "config/security/npm-audit-exception.json"),
        "utf8",
      ),
    ),
    reviewProposal: args[0] === "--review-proposal",
    ci:
      Boolean(process.env.GITHUB_ACTIONS) ||
      ![undefined, "", "0", "false"].includes(process.env.CI),
  });
  process.stdout.write(`${JSON.stringify(result)}\n`);
}

if (
  process.argv[1] &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url
) {
  try {
    main();
  } catch (error) {
    process.stderr.write(`Audit gate failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
