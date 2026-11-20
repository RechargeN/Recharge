import test from "node:test";
import assert from "node:assert/strict";

import { nextSwitchDocuments } from "./operations-switch.mjs";

const base = {
  project: "recharge-dev-n2a01",
  switchId: "abuse.booking.create.emergencyDisable",
  state: "open",
  nowUtc: "2026-11-18T12:00:00Z",
  decisionId: "decision_01",
};

test("dev and staging get the next revision in their own environment", () => {
  const first = nextSwitchDocuments(base);
  assert.equal(first.key, "dev:LV:abuse.booking.create.emergencyDisable");
  assert.equal(first.revision.revision, 1);
  assert.equal(first.revision.enabled, false, "open means not contained");
  assert.equal(first.revision.environmentId, "dev");
  assert.deepEqual(first.pointer, {
    key: first.key,
    activeRevision: 1,
    pointerRevision: 1,
  });
  const next = nextSwitchDocuments({
    ...base,
    project: "recharge-staging-y9y2y",
    state: "contained",
    pointer: { activeRevision: 4, pointerRevision: 7 },
  });
  assert.equal(next.revision.environmentId, "stage");
  assert.equal(next.revision.revision, 5);
  assert.equal(next.revision.enabled, true);
  assert.equal(next.pointer.pointerRevision, 8);
  assert.equal(next.revisionPath, `platformFeatureFlagRevisions/${next.key}:5`);
});

test("production, unknown projects and bad input are refused", () => {
  assert.throws(
    () => nextSwitchDocuments({ ...base, project: "recharge-prod" }),
    /refused/u,
  );
  assert.throws(
    () => nextSwitchDocuments({ ...base, project: "demo-recharge" }),
    /refused/u,
  );
  assert.throws(
    () => nextSwitchDocuments({ ...base, state: "maybe" }),
    /state/u,
  );
  assert.throws(
    () => nextSwitchDocuments({ ...base, switchId: "../x" }),
    /switch_id/u,
  );
  assert.throws(
    () => nextSwitchDocuments({ ...base, nowUtc: "yesterday" }),
    /time/u,
  );
});
