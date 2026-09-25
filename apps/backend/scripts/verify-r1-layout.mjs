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
const section = document.slice(
  document.indexOf("## 26. Stage 7 exact R1 executable implementation map"),
);
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
  "apps/backend/functions/test/unit/security/authentication_guard.test.ts",
  "apps/backend/functions/test/unit/security/privacy_foundation.test.ts",
  "apps/backend/functions/test/rules/firestore_security_privacy_rules.test.ts",
  "apps/backend/functions/test/integration/privacy_orchestration.test.ts",
  "apps/backend/functions/test/rules/firestore_identity_rules.test.ts",
  "apps/backend/functions/test/integration/identity_publisher_authority.test.ts",
  "apps/backend/functions/src/platform/config/firestore_feature_flag_gate.ts",
  "apps/backend/functions/src/platform/bootstrap/booking_composition_root.ts",
];

if (manifestPaths.length !== 122) {
  throw new Error(
    `R1 manifest must contain 122 unique paths; found ${manifestPaths.length}`,
  );
}
for (const relativePath of manifestPaths) {
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
      !approvedSecurityPrivacyExtensionPaths.includes(relative)
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
  `R1 layout gate passed: ${manifestPaths.length} exact actions, ${approvedSecurityPrivacyExtensionPaths.length} approved local foundation extensions and ${compatibilityPaths.length} retained RAW-C paths; no forbidden dependency or directory.\n`,
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
