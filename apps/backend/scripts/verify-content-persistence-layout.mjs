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
// Emulator-only adapters: the repository, its composition, the read-only
// publication feed the local Catalog reads (E1) and the Event → Booking
// handoff store (E2.0).
const allowedCloud = new Set(
  [
    "firestore_content_repository.ts",
    "emulator_content_composition.ts",
    "content_publication_feed.ts",
    "firestore_event_booking_handoff_repository.ts",
  ].map((name) => path.join("modules", "content", "infrastructure", name)),
);
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

// Single writer: outside the Content module only the approved Emulator-only
// files reach the Firestore adapter or its composition, and each imports only
// the listed symbols (C1 Media, C2 Moderation, C3 entry adapter, E1 Catalog).
// The Emulator context guard is the only thing the other repositories borrow.
const persistenceModules = [
  "firestore_content_repository",
  "emulator_content_composition",
];
const guardOnly = {
  firestore_content_repository: ["assertContentEmulatorContext"],
};
const approvedOutsideUsers = {
  "content_entry.ts": {
    firestore_content_repository: ["FirestoreContentRepository"],
    emulator_content_composition: ["createEmulatorContentService"],
  },
  // D2: composition root of Content's reaction to late Media restriction.
  "media_effects_entry.ts": {
    firestore_content_repository: ["FirestoreContentRepository"],
  },
  "modules/media/infrastructure/emulator_media_composition.ts": {
    firestore_content_repository: ["FirestoreContentRepository"],
  },
  "modules/media/infrastructure/firestore_media_repository.ts": guardOnly,
  "modules/moderation/infrastructure/content_moderation_adapter.ts": {
    firestore_content_repository: [
      "contentCollections",
      "FirestoreContentRepository",
    ],
  },
  "modules/moderation/infrastructure/emulator_moderation_composition.ts": {
    firestore_content_repository: ["FirestoreContentRepository"],
  },
  "modules/moderation/infrastructure/emulator_staff_authority.ts": guardOnly,
  "modules/moderation/infrastructure/firestore_moderation_repository.ts":
    guardOnly,
  "modules/catalog/infrastructure/emulator_catalog_composition.ts": {
    firestore_content_repository: ["FirestoreContentRepository"],
  },
  "modules/catalog/infrastructure/firestore_catalog_repository.ts": guardOnly,
};
const importStatement =
  /import\s+(?:type\s+)?\{([^}]*)\}\s+from\s+'[^']*\/(firestore_content_repository|emulator_content_composition)\.js';/gu;
const contentDir = path.join(functionsSrc, "modules", "content");
for (const file of sourceFiles(functionsSrc)) {
  if (file.startsWith(contentDir + path.sep)) continue;
  const relative = path.relative(functionsSrc, file).replaceAll("\\", "/");
  const source = readFileSync(file, "utf8");
  const mentions = persistenceModules.filter((name) => source.includes(name));
  if (mentions.length === 0) continue;
  const approved = approvedOutsideUsers[relative];
  if (approved === undefined)
    throw new Error(`Content persistence used outside its module: ${relative}`);
  const imported = {};
  for (const match of source.matchAll(importStatement)) {
    const names = match[1]
      .split(",")
      .map((part) => part.replace(/\btype\b/u, "").trim())
      .filter((part) => part.length > 0);
    imported[match[2]] = [...(imported[match[2]] ?? []), ...names];
  }
  const withoutApprovedImports = source.replace(importStatement, "");
  for (const name of persistenceModules)
    if (withoutApprovedImports.includes(name))
      throw new Error(`${relative} references ${name} outside an import`);
  for (const name of mentions) {
    if (imported[name] === undefined)
      throw new Error(`${relative} references ${name} outside an import`);
    for (const symbol of imported[name])
      if (!(approved[name] ?? []).includes(symbol))
        throw new Error(`${relative} imports ${symbol} from ${name}`);
  }
}
// The Functions entry never imports Content internals; its Content surface is
// exactly the approved Emulator-only callables (C3) and effect trigger (E2).
const entry = readFileSync(path.join(functionsSrc, "index.ts"), "utf8");
if (/from '\.\/modules\/content\//u.test(entry))
  throw new Error("The Functions entry must not import Content internals");
const approvedContentExports = [
  "consumeContentEffectV1",
  "contentCommandV1",
  "contentQueryV1",
];
const contentExports = [...entry.matchAll(/export const (\w+)\s*=/gu)]
  .map((match) => match[1])
  .filter((name) => /content/iu.test(name))
  .sort();
for (const name of contentExports)
  if (!approvedContentExports.includes(name))
    throw new Error(
      `The Functions entry exposes an unapproved Content export: ${name}`,
    );

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
  `Content persistence layout gate passed: ${required.length} required paths, eight explicit denies, exactly two composite indexes, cloud SDK confined to ${allowedCloud.size} Emulator-only files, ${Object.keys(approvedOutsideUsers).length} approved outside users with exact symbols, Content exports ${contentExports.join(", ")}.\n`,
);
