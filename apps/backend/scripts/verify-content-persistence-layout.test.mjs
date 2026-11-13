import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const backend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

test("Content allowlist rejects outsiders and extra symbols", () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "content-layout-"));
  const copy = path.join(temporary, "apps", "backend");
  try {
    fs.mkdirSync(path.join(copy, "scripts"), { recursive: true });
    for (const directory of ["src", "test"]) {
      fs.cpSync(
        path.join(backend, "functions", directory),
        path.join(copy, "functions", directory),
        { recursive: true },
      );
    }
    for (const file of [
      "firestore.rules",
      "firestore.indexes.json",
      "scripts/verify-content-persistence-layout.mjs",
    ]) {
      fs.copyFileSync(path.join(backend, file), path.join(copy, file));
    }
    const run = () =>
      spawnSync(
        process.execPath,
        [path.join(copy, "scripts", "verify-content-persistence-layout.mjs")],
        { encoding: "utf8" },
      );
    const baseline = run();
    assert.equal(baseline.status, 0, baseline.stderr);
    const outsider = path.join(copy, "functions", "src", "unapproved.ts");
    fs.writeFileSync(
      outsider,
      "import { FirestoreContentRepository } from './modules/content/infrastructure/firestore_content_repository.js';\n",
    );
    const outside = run();
    assert.notEqual(outside.status, 0);
    assert.match(
      outside.stderr,
      /Content persistence used outside its module: unapproved.ts/u,
    );
    fs.unlinkSync(outsider);
    // A sibling whose name shares the prefix is still outside Content.
    const sibling = path.join(
      copy,
      "functions",
      "src",
      "modules",
      "content_foreign",
      "application",
      "foreign.ts",
    );
    fs.mkdirSync(path.dirname(sibling), { recursive: true });
    fs.writeFileSync(
      sibling,
      "import { FirestoreContentRepository } from '../../content/infrastructure/firestore_content_repository.js';\n",
    );
    const prefixed = run();
    assert.notEqual(prefixed.status, 0);
    assert.match(
      prefixed.stderr,
      /Content persistence used outside its module: modules\/content_foreign\/application\/foreign.ts/u,
    );
    fs.unlinkSync(sibling);
    const allowed = path.join(
      copy,
      "functions",
      "src",
      "modules",
      "catalog",
      "infrastructure",
      "firestore_catalog_repository.ts",
    );
    const source = fs.readFileSync(allowed, "utf8");
    assert.match(source, /import \{ assertContentEmulatorContext \}/u);
    fs.writeFileSync(
      allowed,
      source.replace(
        "import { assertContentEmulatorContext }",
        "import { assertContentEmulatorContext, FirestoreContentRepository }",
      ),
    );
    const extra = run();
    assert.notEqual(extra.status, 0);
    assert.match(
      extra.stderr,
      /imports FirestoreContentRepository from firestore_content_repository/u,
    );
    fs.writeFileSync(
      allowed,
      source +
        "\nconst bypass = import('../../content/infrastructure/firestore_content_repository.js');\n",
    );
    const dynamic = run();
    assert.notEqual(dynamic.status, 0);
    assert.match(
      dynamic.stderr,
      /references firestore_content_repository outside an import/u,
    );
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true });
  }
});
