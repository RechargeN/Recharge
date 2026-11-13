import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

import {
  buildReleaseCandidate,
  gitTreeDigest,
  verifyReleaseCandidate,
} from "./build-release-candidate.mjs";

// N4a: the release candidate is rebuilt from Git objects at its commit; any
// drift in a recorded digest refuses it. Codebase staging is injected here (it
// needs the built lib and is covered by runtime-projects.test.mjs).

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..", "..", "..");
const head = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], {
  encoding: "utf8",
}).stdout.trim();
const codebases = {
  "n2c-identity": {
    entry: "lib/src/dev_identity_entry.js",
    codeTreeSha256: "1".repeat(64),
    files: 20,
  },
  "n3a2-content-media": {
    entry: "lib/src/dev_content_media_entry.js",
    codeTreeSha256: "2".repeat(64),
    files: 90,
  },
  "n3c-notifications": {
    entry: "lib/src/dev_notifications_entry.js",
    codeTreeSha256: "3".repeat(64),
    files: 30,
  },
};
const digest = `sha256:${"a".repeat(64)}`;
const now = new Date("2026-11-13T12:00:00.000Z");

function validator() {
  const require = createRequire(
    path.join(root, "apps", "backend", "functions", "package.json"),
  );
  const Ajv2020 = require("ajv/dist/2020.js").default;
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  return ajv.compile(
    JSON.parse(
      readFileSync(
        path.join(
          root,
          "apps",
          "backend",
          "config",
          "release-candidate.schema.json",
        ),
        "utf8",
      ),
    ),
  );
}

test("a release candidate from HEAD matches its schema and verifies", () => {
  const rc = buildReleaseCandidate({
    sourceSha: head,
    mediaToolsDigest: digest,
    now,
    codebases,
  });
  const validate = validator();
  assert.equal(validate(rc), true, JSON.stringify(validate.errors));
  assert.equal(rc.releaseCandidateId, `RC-20261113-${head.slice(0, 7)}`);
  assert.equal(rc.production, false);
  assert.deepEqual(rc.targets, [
    "recharge-dev-n2a01",
    "recharge-staging-y9y2y",
  ]);
  assert.equal(rc.config.ttlFieldOverrides, "not-deployed");
  assert.match(rc.toolchain.node, /^22\./u);
  assert.deepEqual(verifyReleaseCandidate(rc, { root, codebases }), []);
  // The digest of a committed tree does not depend on the checkout's line endings.
  assert.equal(
    gitTreeDigest(root, head, "packages/api_contracts/schema").treeSha256,
    rc.contracts.treeSha256,
  );
});

test("drift, production or a foreign target is refused", () => {
  const rc = buildReleaseCandidate({
    sourceSha: head,
    mediaToolsDigest: digest,
    now,
    codebases,
  });
  const tampered = structuredClone(rc);
  tampered.config.firestoreRulesSha256 = "0".repeat(64);
  assert.deepEqual(verifyReleaseCandidate(tampered, { root, codebases }), [
    "config differs from the source commit",
  ]);
  const code = structuredClone(rc);
  code.artifacts["n3c-notifications"].codeTreeSha256 = "f".repeat(64);
  assert.notDeepEqual(verifyReleaseCandidate(code, { root, codebases }), []);
  assert.throws(() =>
    buildReleaseCandidate({
      sourceSha: head,
      mediaToolsDigest: digest,
      targets: ["recharge-prod"],
      codebases,
    }),
  );
  assert.throws(() =>
    buildReleaseCandidate({
      sourceSha: head,
      mediaToolsDigest: "latest",
      codebases,
    }),
  );
  const validate = validator();
  assert.equal(validate({ ...rc, production: true }), false);
  assert.equal(validate({ ...rc, targets: ["recharge-prod"] }), false);
});
