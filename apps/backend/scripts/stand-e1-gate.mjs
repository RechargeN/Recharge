import assert from "node:assert/strict";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const standCli = path.join(here, "emulator-stand.mjs");
const seedCli = path.join(here, "stand-seed.mjs");
const moderateCli = path.join(here, "stand-moderate.mjs");

function exec(script, args) {
  const result = spawnSync(process.execPath, [script, ...args], {
    encoding: "utf8",
    shell: false,
    env: process.env,
  });
  return {
    status: result.status,
    output: (result.stdout ?? "") + (result.stderr ?? ""),
  };
}

function run(script, args) {
  const result = exec(script, args);
  if (result.status !== 0) {
    throw new Error(
      `${path.basename(script)} ${args.join(" ")} failed:\n${result.output}`,
    );
  }
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

const catalog = (...args) => lastJson(run(seedCli, ["catalog", ...args]));
const fixture = (...args) =>
  lastJson(run(seedCli, ["moderation-fixture", ...args]));
const moderate = (...args) => lastJson(run(moderateCli, args));
const digest = () => {
  const match = /^digest ([0-9a-f]{64})$/m.exec(run(seedCli, ["digest"]));
  if (!match) throw new Error("digest output missing");
  return match[1];
};
const listed = (page, contentId) =>
  page.items.some((item) => item.contentId === contentId);

/**
 * E1 local Catalog gate. The stand command calls the Catalog application layer
 * directly; since E2 the Emulator-only Content effect trigger may have delivered
 * first, so every step asserts the outcome (listed, synced, idempotent), never
 * which path applied a fact. It proves projection of the
 * seeded Content Event, repeat delivery, reconciliation, a moderation hide that
 * removes an Event from the Feed, and an isolated rebuild with atomic
 * activation and rollback. Local Emulator only; it resets the stand data
 * first, so it needs an explicit --yes.
 */
export function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-e1-gate.mjs --yes",
    );
  }
  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  let failure;
  try {
    step("verified stop", () => run(standCli, ["stop"]));
    step("reset", () => run(standCli, ["reset", "--yes"]));
    step("start", () => run(standCli, ["start"]));
    step("seed", () => run(seedCli, ["seed"]));
    step("verify seed invariants", () => run(seedCli, ["verify"]));
    const seeded = step("seeded Content Event from the manifest", () =>
      lastJson(run(seedCli, ["manifest"])),
    ).contentEvent.contentId;
    const before = step("digest before the Catalog", digest);

    step("delivery (trigger or manual) projects the seeded Event", () => {
      const report = catalog("deliver");
      assert.equal(report.stoppedAt, null);
      assert.equal(report.synced, true);
      const page = catalog("feed");
      assert.ok(listed(page, seeded));
      assert.equal(page.freshness.projection, "fresh");
      for (const item of page.items)
        assert.equal(item.availability, "not_connected");
    });
    step("the Catalog is derived: the seed digest is unchanged", () =>
      assert.equal(digest(), before),
    );
    step(
      "a repeated delivery processes nothing; reconciliation is complete",
      () => {
        assert.equal(catalog("deliver").processed, 0);
        const report = catalog("reconcile");
        assert.equal(report.complete, true, JSON.stringify(report.findings));
      },
    );

    const other = step("another Event is published through Content", () => {
      const submitted = fixture("submit", "creator", "studio");
      const approved = moderate(
        "approve",
        submitted.submissionId,
        "--reason",
        "e1 gate: approved",
      );
      assert.equal(approved.data.receipt.outcome, "applied");
      assert.equal(
        fixture("publish", "creator", submitted.submissionId).published,
        true,
      );
      catalog("deliver");
      assert.ok(listed(catalog("feed"), submitted.contentId));
      return submitted.contentId;
    });
    step("a moderation hide removes it from the Feed", () => {
      const restricted = moderate(
        "restrict",
        other,
        "--reason",
        "e1 gate: restricted",
      );
      assert.equal(restricted.data.receipt.outcome, "applied");
      catalog("deliver");
      const page = catalog("feed");
      assert.equal(listed(page, other), false);
      assert.ok(listed(page, seeded));
      const details = catalog("details", other);
      assert.deepEqual(
        [details.state, details.reason],
        ["excluded", "restricted"],
      );
    });

    step("rebuild, atomic activation and rollback", () => {
      const active = catalog("status").setId;
      const rebuilt = catalog("rebuild");
      assert.equal(rebuilt.complete, true, JSON.stringify(rebuilt.findings));
      assert.equal(
        catalog("feed").projectionSetId,
        active,
        "not served before activation",
      );
      const activated = catalog("activate", rebuilt.setId, active);
      assert.equal(activated.ok, true, JSON.stringify(activated));
      const page = catalog("feed");
      assert.equal(page.projectionSetId, rebuilt.setId);
      assert.ok(listed(page, seeded));
      assert.equal(listed(page, other), false);
      const rolledBack = catalog("rollback", rebuilt.setId);
      assert.equal(rolledBack.ok, true, JSON.stringify(rolledBack));
      assert.equal(catalog("feed").projectionSetId, active);
    });
    step("seed invariants still hold", () => run(seedCli, ["verify"]));
  } catch (error) {
    failure = error;
  } finally {
    try {
      step("verified stop", () => run(standCli, ["stop"]));
    } catch (error) {
      failure ??= error;
    }
  }
  if (failure) throw failure;
  process.stdout.write(
    "E1 local Catalog gate passed (local Emulator only; manual delivery idempotent next to the E2 trigger, Event only, test-only config and ranking, Booking availability not connected; no cloud index or UI claim)\n",
  );
}

if (
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
