import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";

import {
  closurePackages,
  importClosure,
  renderLock,
  treeDigest,
} from "./package-media-tools-runtime.mjs";

function tree(files) {
  const root = mkdtempSync(path.join(tmpdir(), "n3b-closure-"));
  for (const [rel, text] of Object.entries(files)) {
    mkdirSync(path.dirname(path.join(root, rel)), { recursive: true });
    writeFileSync(path.join(root, rel), text);
  }
  return root;
}

test("closure: follows relative imports; only node: and sharp may be bare", () => {
  const root = tree({
    "media-tools-runtime/src/a.js":
      "import x from 'node:http';\nimport { y } from './b.js';\n",
    "media-tools-runtime/src/b.js":
      "import sharp from 'sharp';\nexport * from '../../functions/src/m.js';\n",
    "functions/src/m.js": "export const m = 1;\n",
  });
  try {
    assert.deepEqual(importClosure(root, ["media-tools-runtime/src/a.js"]), [
      "functions/src/m.js",
      "media-tools-runtime/src/a.js",
      "media-tools-runtime/src/b.js",
    ]);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("closure: Firebase, Firestore, fakes or stand code never enter the image", () => {
  for (const [file, text] of [
    ["media-tools-runtime/src/a.js", "import 'firebase-admin';\n"],
    ["media-tools-runtime/src/a.js", "import './fake_scanner.js';\n"],
    [
      "media-tools-runtime/src/a.js",
      "import '../../functions/test/stand/x.js';\n",
    ],
    ["media-tools-runtime/src/a.js", "import 'node-fetch';\n"],
  ]) {
    const root = tree({
      [file]: text,
      "media-tools-runtime/src/fake_scanner.js": "",
      "functions/test/stand/x.js": "",
    });
    try {
      assert.throws(() => importClosure(root, [file]), undefined, text);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  }
});

const integrity = (c) => `sha512-${c.repeat(86)}==`;
const toolsLock = {
  artifacts: { talosKey: { url: "https://example.invalid/talos.gpg" } },
  verified: {
    node: { nodeVersion: "v22.23.2" },
    talosKeySha256: "b".repeat(64),
    gpg: { signingKeyFingerprint: "5BADCA2665EF59DCF8A23D8B707F0DB480836771" },
  },
  npm: [
    {
      name: "sharp",
      version: "0.35.5",
      resolved: "https://registry.npmjs.org/sharp/-/sharp-0.35.5.tgz",
      integrity: integrity("A"),
    },
  ],
  linux: {
    node: { tarball: "node-v22.23.2-linux-x64.tar.xz", sha256: "c".repeat(64) },
    clamav: {
      url: "https://example.invalid/clamav.deb",
      sha256: "d".repeat(64),
    },
    clamavSignature: {
      url: "https://example.invalid/clamav.deb.sig",
      sha256: "e".repeat(64),
    },
    npm: [],
  },
};
function functionsLock(overrides = {}) {
  const packages = {};
  for (const name of closurePackages)
    packages[`node_modules/${name}`] = {
      version: name === "sharp" ? "0.35.5" : "1.0.0",
      resolved: `https://registry.npmjs.org/${name}/-/x.tgz`,
      integrity: name === "sharp" ? integrity("A") : integrity("B"),
    };
  return { packages: { ...packages, ...overrides } };
}

test("lock: every artifact pinned; disagreeing or foreign pins stop the stage", () => {
  const rendered = renderLock(toolsLock, functionsLock());
  assert.match(
    rendered.env,
    /^NODE_URL=https:\/\/nodejs\.org\/dist\/v22\.23\.2\/node-v22\.23\.2-linux-x64\.tar\.xz$/mu,
  );
  assert.match(rendered.env, /^TALOS_FINGERPRINT=5BADCA26/mu);
  assert.equal(rendered.npm.trim().split("\n").length, closurePackages.length);
  assert.throws(() =>
    renderLock(
      toolsLock,
      functionsLock({
        "node_modules/sharp": {
          version: "0.35.5",
          resolved: "https://registry.npmjs.org/sharp/-/sharp-0.35.5.tgz",
          integrity: integrity("C"),
        },
      }),
    ),
  );
  assert.throws(() =>
    renderLock(
      toolsLock,
      functionsLock({
        "node_modules/semver": {
          version: "7.8.5",
          resolved: "https://evil.invalid/semver.tgz",
          integrity: integrity("B"),
        },
      }),
    ),
  );
  assert.throws(() =>
    renderLock(
      {
        ...toolsLock,
        linux: {
          ...toolsLock.linux,
          clamav: { url: "https://x.invalid/a b", sha256: "d" },
        },
      },
      functionsLock(),
    ),
  );
});

test("tree digest: content and paths decide, stage.json does not", () => {
  const one = tree({ "a.txt": "1", "stage.json": "x" });
  const two = tree({ "a.txt": "1", "stage.json": "y" });
  const three = tree({ "a.txt": "2" });
  try {
    assert.equal(treeDigest(one), treeDigest(two));
    assert.notEqual(treeDigest(one), treeDigest(three));
  } finally {
    for (const dir of [one, two, three])
      rmSync(dir, { recursive: true, force: true });
  }
});
