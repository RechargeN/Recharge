import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");
const deliveryMapPath = path.join(
  repoRoot,
  "docs",
  "product",
  "RECHARGE_BACKEND_DELIVERY_MAP.md",
);
const document = readFileSync(deliveryMapPath, "utf8");
const sectionStart = document.indexOf(
  "## 26. Stage 7 exact R1 executable implementation map",
);
const sectionEnd = document.indexOf("\n## 27.", sectionStart);
if (sectionStart < 0 || sectionEnd < 0) {
  throw new Error("Exact R1 manifest section boundaries are absent");
}
const section = document.slice(sectionStart, sectionEnd);
const tablePaths = [
  ...section.matchAll(/^\|\s*([CMR])\s*\|\s*`([^`]+)`/gmu),
].map((match) => match[2]);
const compatibilityBlock =
  section.match(/### 26\.6[\s\S]*?```text\r?\n([\s\S]*?)```/u)?.[1] ?? "";
const compatibilityPaths = compatibilityBlock
  .split(/\r?\n/u)
  .map((line) => line.trim())
  .filter(Boolean);
const manifestPaths = [...new Set(tablePaths)];
const approvedSecurityPrivacyExtensionPaths = [
  "apps/backend/functions/src/security/age_policy_port.ts",
  "apps/backend/functions/src/security/authentication_guard.ts",
  "apps/backend/functions/src/security/collection_access_matrix.ts",
  "apps/backend/functions/src/security/data_class_registry.ts",
  "apps/backend/functions/src/security/retention_registry.ts",
  "apps/backend/functions/src/security/security_flags.ts",
  "apps/backend/functions/src/security/security_redaction_policy.ts",
  "apps/backend/functions/src/security/abuse_policy.ts",
  "apps/backend/functions/src/security/app_check_policy.ts",
  "apps/backend/functions/src/platform/security/firestore_abuse_rate_limiter.ts",
  "apps/backend/functions/test/unit/security/authentication_guard.test.ts",
  "apps/backend/functions/test/unit/security/privacy_foundation.test.ts",
  "apps/backend/functions/test/unit/abuse_policy.test.ts",
  "apps/backend/functions/test/unit/app_check_policy.test.ts",
  "apps/backend/functions/test/rules/firestore_security_privacy_rules.test.ts",
  "apps/backend/functions/test/integration/privacy_orchestration.test.ts",
  "apps/backend/functions/test/rules/firestore_identity_rules.test.ts",
  "apps/backend/functions/test/integration/identity_publisher_authority.test.ts",
  "apps/backend/functions/src/platform/config/firestore_feature_flag_gate.ts",
  "apps/backend/functions/src/platform/bootstrap/booking_composition_root.ts",
];

// Later approved slices share directories owned by the historical R1 gate.
// BCK-05 §36.6, BCK-07 §34/38 and BCK-14 local file maps; no wildcard grants.
const approvedSubsequentSlicePaths = [
  "apps/backend/config/budget-policy.schema.json",
  "apps/backend/config/execution-manifest.schema.json",
  "apps/backend/config/flag-policy.schema.json",
  "apps/backend/config/manifests/execution-manifest.json",
  "apps/backend/config/manifests/fixtures/forward.json",
  "apps/backend/config/manifests/fixtures/invalid.json",
  "apps/backend/config/manifests/fixtures/valid.json",
  "apps/backend/functions/test/integration/content_publication_security.test.ts",
  "apps/backend/functions/test/integration/content_publication_service.test.ts",
  "apps/backend/functions/test/integration/content_repository_parity.test.ts",
  "apps/backend/functions/test/integration/media_content_readiness.test.ts",
  "apps/backend/functions/test/integration/media_deletion_reconcile.test.ts",
  "apps/backend/functions/test/integration/media_privacy_boundary.test.ts",
  "apps/backend/functions/test/integration/media_security.test.ts",
  "apps/backend/functions/test/integration/media_upload_service.test.ts",
  // D2 (MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md §12): late Media restriction.
  "apps/backend/functions/test/integration/content_media_availability.test.ts",
  "apps/backend/functions/test/integration/media_delivery_gate.test.ts",
  "apps/backend/functions/test/integration/media_orphan_sweep.test.ts",
  "apps/backend/functions/test/integration/moderation_media_restriction.test.ts",
  // D3.1 (PLACE_D3_1_PUBLICATION_AMENDMENT.md §8): Place enablement matrix.
  "apps/backend/functions/test/integration/content_place_enablement.test.ts",
  // D3.2 (ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md §8): Activity enablement matrix.
  "apps/backend/functions/test/integration/content_activity_enablement.test.ts",
  // D3.3 (RENTAL_D3_3_PUBLICATION_AMENDMENT.md §11): Rental enablement matrix.
  "apps/backend/functions/test/integration/content_rental_enablement.test.ts",
  // D3.4 (COLLECTION_D3_4_PUBLICATION_AMENDMENT.md §8): Collection enablement and membership.
  "apps/backend/functions/test/integration/content_collection_enablement.test.ts",
  // D4 (LOCAL_IMPORT_D4_AMENDMENT.md §8): one draft per local import source.
  "apps/backend/functions/test/integration/content_local_import.test.ts",
  // D4.1 (LOCAL_IMPORT_D4_1_ROLLBACK_AMENDMENT.md §5): import rollback and cleanup fencing.
  "apps/backend/functions/test/integration/content_local_import_rollback.test.ts",
];

if (
  manifestPaths.length !== 134 ||
  tablePaths.length !== manifestPaths.length
) {
  throw new Error(
    `R1 manifest must contain 134 unique paths without duplicates; found ${manifestPaths.length} unique / ${tablePaths.length} rows`,
  );
}
for (const relativePath of [
  ...manifestPaths,
  ...approvedSubsequentSlicePaths,
]) {
  if (!existsSync(path.join(repoRoot, relativePath)))
    throw new Error(`R1 manifest path is absent: ${relativePath}`);
}
for (const relativePath of compatibilityPaths) {
  if (!existsSync(path.join(repoRoot, relativePath))) {
    throw new Error(`RAW-C compatibility path is absent: ${relativePath}`);
  }
}

const ownedRoots = [
  "apps/backend/config",
  "apps/backend/functions/src/security",
  "apps/backend/functions/src/platform",
  "apps/backend/functions/test/unit/config",
  "apps/backend/functions/test/unit/security",
  "apps/backend/functions/test/unit/platform",
  "apps/backend/functions/test/rules",
  "apps/backend/functions/test/integration",
  "apps/backend/infra/env",
];
for (const root of ownedRoots) {
  for (const file of walk(path.join(repoRoot, root))) {
    const relative = path.relative(repoRoot, file).replaceAll("\\", "/");
    if (
      !manifestPaths.includes(relative) &&
      !approvedSecurityPrivacyExtensionPaths.includes(relative) &&
      !approvedSubsequentSlicePaths.includes(relative)
    )
      throw new Error(`Unexpected file in exact R1 layout: ${relative}`);
  }
}

const sourceRoot = path.join(backendRoot, "functions", "src");
for (const relative of manifestPaths.filter(
  (item) =>
    item.startsWith("apps/backend/functions/src/") && item.endsWith(".ts"),
)) {
  const source = readFileSync(path.join(repoRoot, relative), "utf8");
  const layer = relative.split("/")[4];
  if (
    layer === "shared" &&
    /from ['"]\.\.\/(?:config|security|platform|booking|inventory|notifications|audit|policy)/u.test(
      source,
    )
  ) {
    throw new Error(`shared dependency direction violated: ${relative}`);
  }
  if (
    layer === "contracts" &&
    /from ['"]\.\.\/(?:config|security|platform|booking|inventory|notifications|audit|policy)/u.test(
      source,
    )
  ) {
    throw new Error(`contracts dependency direction violated: ${relative}`);
  }
  if (
    (layer === "config" || layer === "security") &&
    /firebase-(?:admin|functions)|\/booking\/|\/inventory\/|\/notifications\/|\/audit\//u.test(
      source,
    )
  ) {
    throw new Error(`${layer} dependency direction violated: ${relative}`);
  }
}
for (const forbidden of ["workers", "schedules"]) {
  if (existsSync(path.join(sourceRoot, "platform", forbidden)))
    throw new Error(`Forbidden R1 directory: platform/${forbidden}`);
}

process.stdout.write(
  `R1 layout gate passed: ${manifestPaths.length} exact actions, ${approvedSecurityPrivacyExtensionPaths.length} approved local foundation extensions, ${approvedSubsequentSlicePaths.length} approved subsequent-slice paths and ${compatibilityPaths.length} retained RAW-C paths; no forbidden dependency or directory.\n`,
);

function walk(root) {
  if (!existsSync(root)) return [];
  const files = [];
  for (const entry of readdirSync(root)) {
    const absolute = path.join(root, entry);
    if (statSync(absolute).isDirectory()) files.push(...walk(absolute));
    else files.push(absolute);
  }
  return files;
}
