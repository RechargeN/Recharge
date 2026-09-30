import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");
const functionsSrc = path.join(backendRoot, "functions", "src");
const required = [
  "apps/backend/functions/src/modules/content/domain/storage_limits.ts",
  "apps/backend/functions/src/modules/content/infrastructure/firestore_content_repository.ts",
  "apps/backend/functions/src/modules/content/infrastructure/emulator_content_composition.ts",
  "apps/backend/functions/src/modules/content/application/content_integrity_recovery.ts",
  "apps/backend/functions/test/support/content_repository_scenarios.ts",
  "apps/backend/functions/test/integration/content_repository_parity.test.ts",
  "apps/backend/functions/test/emulator/content_firestore_repository.test.ts",
  "apps/backend/functions/test/emulator/content_concurrency.test.ts",
  "apps/backend/functions/test/emulator/content_recovery.test.ts",
  "apps/backend/functions/test/emulator/content_rules_default_deny.test.ts",
  "apps/backend/functions/test/emulator/content_emulator_guard.test.ts",
];
for (const relative of required) {
  if (!existsSync(path.join(repoRoot, relative)))
    throw new Error(`Content persistence path absent: ${relative}`);
}

function sourceFiles(directory) {
  return readdirSync(directory).flatMap((name) => {
    const full = path.join(directory, name);
    if (statSync(full).isDirectory()) return sourceFiles(full);
    return full.endsWith(".ts") ? [full] : [];
  });
}
const cloudImport = /firebase-(?:admin|functions)|@google-cloud/u;
const allowedCloud = new Set([
  path.join(
    "modules",
    "content",
    "infrastructure",
    "firestore_content_repository.ts",
  ),
  path.join(
    "modules",
    "content",
    "infrastructure",
    "emulator_content_composition.ts",
  ),
]);
for (const file of sourceFiles(path.join(functionsSrc, "modules", "content"))) {
  const relative = path.relative(functionsSrc, file);
  if (
    !allowedCloud.has(relative) &&
    cloudImport.test(readFileSync(file, "utf8"))
  )
    throw new Error(`Content core imports a cloud SDK: ${relative}`);
}
for (const file of sourceFiles(path.join(functionsSrc, "contracts"))) {
  if (
    /content_/u.test(path.basename(file)) &&
    cloudImport.test(readFileSync(file, "utf8"))
  )
    throw new Error(`Content contract imports a cloud SDK: ${file}`);
}

// Single writer, no endpoint: nothing outside the Content module reaches the
// Firestore adapter or its composition, and the Functions entry knows nothing of it.
const contentDir = path.join(functionsSrc, "modules", "content");
for (const file of sourceFiles(functionsSrc)) {
  if (file.startsWith(contentDir)) continue;
  const source = readFileSync(file, "utf8").replaceAll("\\", "/");
  if (/firestore_content_repository|emulator_content_composition/u.test(source))
    throw new Error(
      `Content persistence used outside its module: ${path.relative(functionsSrc, file)}`,
    );
}
const entry = readFileSync(path.join(functionsSrc, "index.ts"), "utf8");
if (/content/iu.test(entry))
  throw new Error("The Functions entry must not expose Content persistence");

const rules = readFileSync(path.join(backendRoot, "firestore.rules"), "utf8");
const collections = [
  "contentDrafts",
  "contentExternalBindings",
  "contentSubmissions",
  "contentPublishedRevisions",
  "contentPublicationPointers",
  "contentIdempotency",
  "contentAudit",
  "contentEffects",
];
for (const collection of collections) {
  if (
    !rules.includes(
      `match /${collection}/{document} { allow read, write: if false; }`,
    )
  )
    throw new Error(`Missing explicit Content deny: ${collection}`);
}
const indexes = JSON.parse(
  readFileSync(path.join(backendRoot, "firestore.indexes.json"), "utf8"),
);
const contentIndexes = indexes.indexes.filter((entry) =>
  collections.includes(entry.collectionGroup),
);
const expected = [
  ["contentEffects", ["contentId:ASCENDING", "pointerRevision:ASCENDING"]],
  [
    "contentPublishedRevisions",
    ["contentId:ASCENDING", "revisionNumber:ASCENDING"],
  ],
];
const actual = contentIndexes
  .map((entry) => [
    entry.collectionGroup,
    entry.fields.map((field) => `${field.fieldPath}:${field.order}`),
  ])
  .sort((left, right) => left[0].localeCompare(right[0]));
if (JSON.stringify(actual) !== JSON.stringify(expected))
  throw new Error(
    `Content composite indexes must be exactly the two approved ones, found ${JSON.stringify(actual)}`,
  );

process.stdout.write(
  `Content persistence layout gate passed: ${required.length} required paths, eight explicit denies, exactly two composite indexes, cloud SDK confined to two Emulator-only files, no endpoint or outside user.\n`,
);
