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
    .reverse()
    .find((value) => value.trim().startsWith("{"));
  if (!line) throw new Error(`no JSON in output:\n${output}`);
  return JSON.parse(line);
}

const fixture = (args) =>
  lastJson(run(seedCli, ["moderation-fixture", ...args]));
/** The staff script; a refusal exits non-zero and still prints its JSON. */
const moderate = (args) => {
  const result = exec(moderateCli, args);
  return { status: result.status, json: lastJson(result.output) };
};

/**
 * C2 minimal moderation gate. It starts a fresh seeded stand and drives the
 * operator path end to end: staff script -> moderation service -> Content's own
 * verified disposition path, with the owner's actions through the owner
 * services. Local Emulator and PC host only; staff authority is the test-only
 * stand registry and Media uses the fake scanner/processor. It resets the stand
 * data first, so it needs an explicit --yes.
 */
export function main(args) {
  if (args.length !== 1 || args[0] !== "--yes") {
    throw new Error(
      "WARNING: this permanently deletes the stand data folder. Usage: stand-c2-gate.mjs --yes",
    );
  }
  const step = (name, action) => {
    process.stdout.write(`- ${name}\n`);
    return action();
  };
  const key = `gate-${Date.now()}`;
  let failure;
  try {
    step("verified stop", () => run(standCli, ["stop"]));
    step("reset", () => run(standCli, ["reset", "--yes"]));
    step("start", () => run(standCli, ["start"]));
    step("seed", () => run(seedCli, ["seed"]));
    step("verify seed invariants (staff registry)", () =>
      run(seedCli, ["verify"]),
    );

    const submitted = step("creator submits an Event with a Media cover", () =>
      fixture(["submit", "creator", "studio"]),
    );
    assert.equal(submitted.state, "under_review");

    step("queue: staff sees it; Creator and viewer are denied", () => {
      const queue = moderate(["queue"]);
      assert.equal(queue.status, 0);
      assert.ok(
        queue.json.data.pending.some(
          (item) => item.submissionId === submitted.submissionId,
        ),
      );
      for (const user of ["creator", "viewer"]) {
        const denied = moderate(["queue", "--as", user]);
        assert.notEqual(denied.status, 0);
        assert.equal(denied.json.code, "staff_denied");
      }
    });

    step(
      "approve needs staff and a reason; nothing changes without them",
      () => {
        for (const extra of [
          ["--as", "creator"],
          ["--as", "viewer"],
        ]) {
          const denied = moderate([
            "approve",
            submitted.submissionId,
            "--reason",
            "not allowed",
            ...extra,
          ]);
          assert.equal(denied.json.code, "staff_denied");
        }
        const empty = moderate(["approve", submitted.submissionId]);
        assert.equal(empty.json.code, "invalid_contract");
        const status = fixture(["status", submitted.contentId]);
        assert.equal(status.submissions[0].state, "under_review");
      },
    );

    const approved = step(
      "approve with a reason: decision, receipt, replay",
      () => {
        const first = moderate([
          "approve",
          submitted.submissionId,
          "--reason",
          "gate: cover and text are fine",
          "--key",
          `${key}-approve`,
        ]);
        assert.equal(first.status, 0, JSON.stringify(first.json));
        const { decision, receipt } = first.json.data;
        assert.equal(receipt.outcome, "applied");
        assert.equal(decision.target.submissionId, submitted.submissionId);
        assert.equal(decision.reason, "gate: cover and text are fine");
        assert.equal(receipt.staffUserId, decision.staffUserId);
        const replay = moderate([
          "approve",
          submitted.submissionId,
          "--reason",
          "gate: cover and text are fine",
          "--key",
          `${key}-approve`,
        ]);
        assert.equal(replay.json.data.decision.decisionId, decision.decisionId);
        const conflict = moderate([
          "approve",
          submitted.submissionId,
          "--reason",
          "a different reason",
          "--key",
          `${key}-approve`,
        ]);
        assert.equal(conflict.json.code, "idempotency_conflict");
        return decision;
      },
    );
    assert.ok(approved.decisionId);

    step("owner publishes the approved revision", () => {
      const published = fixture(["publish", "creator", submitted.submissionId]);
      assert.equal(published.published, true, JSON.stringify(published));
    });

    const restricted = step("restrict the published revision", () => {
      const result = moderate([
        "restrict",
        submitted.contentId,
        "--reason",
        "gate: misleading title",
      ]);
      assert.equal(result.status, 0, JSON.stringify(result.json));
      const { decision, receipt } = result.json.data;
      assert.equal(receipt.outcome, "applied");
      assert.ok(decision.target.publishedRevisionId);
      assert.ok(decision.target.pointerRevision >= 1);
      const status = fixture(["status", submitted.contentId]);
      assert.equal(status.pointer.visibility, "restricted");
      assert.equal(
        status.pointer.moderationHold.decisionId,
        decision.decisionId,
      );
      return decision;
    });

    step(
      "owner withdrawal is separate; restore lifts only the moderation hold",
      () => {
        assert.equal(
          fixture(["owner-withdraw", "creator", submitted.contentId]).withdrawn,
          true,
        );
        const restored = moderate([
          "restore",
          submitted.contentId,
          "--decision",
          restricted.decisionId,
          "--reason",
          "gate: title fixed",
        ]);
        assert.equal(restored.status, 0, JSON.stringify(restored.json));
        const status = fixture(["status", submitted.contentId]);
        assert.equal(status.pointer.moderationHold, null);
        assert.equal(status.pointer.ownerHold, "withdrawn");
        assert.equal(status.pointer.visibility, "withdrawn");
      },
    );

    step("a stale restore does not lift a newer decision", () => {
      const first = moderate([
        "restrict",
        submitted.contentId,
        "--reason",
        "gate: second look",
      ]);
      const second = moderate([
        "withdraw",
        submitted.contentId,
        "--reason",
        "gate: taken down by moderation",
      ]);
      assert.equal(first.status, 0);
      assert.equal(second.status, 0);
      const stale = moderate([
        "restore",
        submitted.contentId,
        "--decision",
        first.json.data.decision.decisionId,
        "--reason",
        "gate: stale restore",
      ]);
      assert.equal(stale.status, 2, JSON.stringify(stale.json));
      assert.equal(stale.json.data.receipt.outcome, "refused");
      assert.equal(
        stale.json.data.receipt.refusalCode,
        "moderation_decision_stale",
      );
      const status = fixture(["status", submitted.contentId]);
      assert.equal(
        status.pointer.moderationHold.decisionId,
        second.json.data.decision.decisionId,
      );
      assert.equal(status.pointer.moderationHold.kind, "withdrawn");
      const evidence = moderate([
        "receipt",
        second.json.data.decision.decisionId,
      ]);
      assert.equal(evidence.status, 0);
      assert.equal(
        evidence.json.data.decision.reason,
        "gate: taken down by moderation",
      );
      assert.equal(evidence.json.data.receipt.outcome, "applied");
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
    "C2 moderation gate passed (local Emulator and PC host only; test-only staff registry, fake scanner/processor, no Admin UI, reports, sanctions or appeals)\n",
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
