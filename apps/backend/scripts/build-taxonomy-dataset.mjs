import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";

const root = fileURLToPath(new URL("../../../", import.meta.url));
const source = readFileSync(
  resolve(root, "docs/product/CATEGORY_SYSTEM.md"),
  "utf8",
).replaceAll("\r\n", "\n");
const sha = (value) => createHash("sha256").update(value).digest("hex");
const sourceHash =
  "5dfe5347363eeb7d72933812424f22667e730a6edfb16aeb7c79fbeb8ef259f9";
if (sha(source) !== sourceHash)
  throw new Error("taxonomy_source_hash_mismatch");
const aliases = {
  E: "event",
  A: "activity",
  R: "route",
  P: "place",
  S: "session",
  C: "class_workshop",
};
const all = [
  "event",
  "activity",
  "route",
  "place",
  "session",
  "scenario",
  "find_people",
  "class_workshop",
  "rental",
  "collection",
];
const types = (value) => {
  if (value.trim() === "все") return all.toSorted();
  const found = value.match(/\[([^\]]+)\]/u);
  if (!found) throw new Error(`taxonomy_types_invalid:${value}`);
  return found[1]
    .split(",")
    .map((v) => {
      const id = aliases[v.trim()];
      if (!id) throw new Error("taxonomy_type_unknown");
      return id;
    })
    .toSorted();
};
const profiles = [];
for (const match of source
  .slice(source.indexOf("## §6."), source.indexOf("## §7."))
  .matchAll(/^\| \d+ \| `([^`]+)` \| ([^|]+) \|/gmu)) {
  const fields = match[2].trim().startsWith("—")
    ? []
    : match[2].split(",").map((v) => v.trim());
  profiles.push({
    id: match[1],
    fieldIds: fields.map((v) => v.replace("*", "")).toSorted(),
    requiredFieldIds: fields
      .filter((v) => v.endsWith("*"))
      .map((v) => v.slice(0, -1))
      .toSorted(),
  });
}
if (profiles.length !== 22) throw new Error("taxonomy_profile_count");
const categories = [];
const section = source.slice(
  source.indexOf("### 7.1 "),
  source.indexOf("## §8."),
);
for (const block of section
  .split(/(?=^### 7\.)/mu)
  .filter((v) => v.startsWith("###"))) {
  const heading = block.match(/^### 7\.\d+[^`]*`([^`]+)`[^\n]*\((\d+)\)/u);
  const defaults = block.match(/^default: `([^`]+)` · types: ([^\n]+)/mu);
  if (!heading || !defaults) throw new Error("taxonomy_heading_invalid");
  const categoryId = heading[1];
  const paragraph = block
    .slice(block.indexOf(defaults[0]) + defaults[0].length)
    .trimStart()
    .split("\n\n")[0];
  // The one fallback paragraph also contains explanatory prose after its ID.
  const ids =
    categoryId === "other"
      ? ["other_event"]
      : paragraph
          .replaceAll("\n", " ")
          .split(",")
          .map((v) => v.trim());
  if (
    ids.length !== Number(heading[2]) ||
    ids.some((v) => !/^[a-z][a-z0-9_]*$/u.test(v))
  )
    throw new Error(`taxonomy_category_count:${categoryId}`);
  const entries = new Map(
    ids.map((id) => [
      id,
      { id, profileId: defaults[1], applicableTypes: types(defaults[2]) },
    ]),
  );
  let columns = [];
  for (const line of block.split("\n")) {
    if (!line.startsWith("|")) continue;
    const cells = line
      .split("|")
      .slice(1, -1)
      .map((v) => v.trim());
    if (cells[0] === "исключение") {
      columns = cells;
      continue;
    }
    if (cells[0].startsWith("---")) continue;
    if (columns.length === 0 || cells.length !== columns.length)
      throw new Error("taxonomy_override_shape");
    for (const id of cells[0].split(",").map((v) => v.trim())) {
      const entry = entries.get(id);
      if (!entry)
        throw new Error(`taxonomy_override_unknown:${categoryId}:${id}`);
      for (let i = 1; i < columns.length; i++) {
        if (!cells[i]) continue;
        if (columns[i] === "types") entry.applicableTypes = types(cells[i]);
        else if (columns[i] === "profile") {
          const profile = cells[i].match(/^([a-z_]+)(?: · (\[[^\]]+\]))?$/u);
          if (!profile) throw new Error("taxonomy_profile_override_invalid");
          entry.profileId = profile[1];
          if (profile[2]) entry.applicableTypes = types(profile[2]);
        } else throw new Error("taxonomy_override_column_unknown");
      }
    }
  }
  categories.push({
    id: categoryId,
    subcategories: [...entries.values()].toSorted((a, b) =>
      a.id < b.id ? -1 : 1,
    ),
  });
}
if (
  categories.length !== 28 ||
  categories.reduce((n, c) => n + c.subcategories.length, 0) !== 530
)
  throw new Error("taxonomy_total_count");
for (const c of categories)
  for (const s of c.subcategories)
    if (!profiles.some((p) => p.id === s.profileId))
      throw new Error("taxonomy_profile_missing");
const canonical = (value) =>
  Array.isArray(value)
    ? `[${value.map(canonical).join(",")}]`
    : value && typeof value === "object"
      ? `{${Object.keys(value)
          .toSorted()
          .map((k) => `${JSON.stringify(k)}:${canonical(value[k])}`)
          .join(",")}}`
      : JSON.stringify(value);
const payload = canonical({
  schemaVersion: 1,
  taxonomyId: "category-system",
  semanticVersion: "1.4.3",
  sourceRecordId: "SRCREC-CATEGORY-143-001",
  sourceDocumentSha256: sourceHash,
  categories: categories.toSorted((a, b) => (a.id < b.id ? -1 : 1)),
  profiles: profiles.toSorted((a, b) => (a.id < b.id ? -1 : 1)),
});
const hash = sha(payload);
const dir = resolve(
  root,
  "packages/api_contracts/schema/reference_data/v1/artifacts",
);
mkdirSync(dir, { recursive: true });
const artifact = resolve(dir, "category-system-1.4.3.json");
if (process.argv.includes("--check")) {
  if (readFileSync(artifact, "utf8") !== payload)
    throw new Error("taxonomy_artifact_drift");
  const generated = readFileSync(
    resolve(
      root,
      "apps/backend/functions/src/modules/reference_data/infrastructure/taxonomy_dataset.generated.ts",
    ),
    "utf8",
  );
  const payloadMatch =
    /export const taxonomyPayload =\s*('[^']*'|"(?:[^"\\]|\\.)*");/.exec(
      generated,
    );
  const mirrored = payloadMatch
    ? payloadMatch[1].startsWith("'")
      ? payloadMatch[1].slice(1, -1)
      : JSON.parse(payloadMatch[1])
    : null;
  if (mirrored !== payload || !generated.includes(hash))
    throw new Error("taxonomy_runtime_mirror_drift");
  const manifest = JSON.parse(
    readFileSync(resolve(dir, "taxonomy_manifest.json"), "utf8"),
  );
  if (
    manifest.artifactSha256 !== hash ||
    manifest.sourceDocumentSha256 !== sourceHash ||
    manifest.taxonomyRevisionId !== `taxonomy-1.4.3-sha256:${hash}`
  )
    throw new Error("taxonomy_manifest_drift");
} else {
  writeFileSync(artifact, payload);
  writeFileSync(
    resolve(
      root,
      "apps/backend/functions/src/modules/reference_data/infrastructure/taxonomy_dataset.generated.ts",
    ),
    `// Generated by build-taxonomy-dataset.mjs from the accepted semantic source.\nexport const taxonomyPayload = ${JSON.stringify(payload)};\nexport const taxonomyArtifactHash = '${hash}';\nexport const taxonomyRevisionId = 'taxonomy-1.4.3-sha256:${hash}';\n`,
  );
}
console.log(
  JSON.stringify({
    revisionId: `taxonomy-1.4.3-sha256:${hash}`,
    artifactSha256: hash,
    categories: categories.length,
    subcategories: 530,
    profiles: profiles.length,
  }),
);
