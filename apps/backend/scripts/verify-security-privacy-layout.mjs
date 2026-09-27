import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");
const required = [
  "packages/api_contracts/schema/privacy/v1/privacy_request.schema.json",
  "packages/api_contracts/schema/privacy/v1/privacy_request_status.schema.json",
  "packages/api_contracts/schema/privacy/v1/privacy_domain_task.schema.json",
  "apps/backend/functions/src/security/authentication_guard.ts",
  "apps/backend/functions/src/security/data_class_registry.ts",
  "apps/backend/functions/src/security/collection_access_matrix.ts",
  "apps/backend/functions/src/security/retention_registry.ts",
  "apps/backend/functions/src/security/age_policy_port.ts",
  "apps/backend/functions/src/security/security_flags.ts",
  "apps/backend/functions/src/security/security_redaction_policy.ts",
  "apps/backend/functions/src/security/abuse_policy.ts",
  "apps/backend/functions/src/security/app_check_policy.ts",
  "apps/backend/functions/src/modules/privacy_orchestration/domain/privacy_request.ts",
  "apps/backend/functions/src/modules/privacy_orchestration/domain/privacy_domain_task.ts",
  "apps/backend/functions/src/modules/privacy_orchestration/domain/privacy_evidence.ts",
  "apps/backend/functions/src/modules/privacy_orchestration/application/privacy_orchestration_service.ts",
  "apps/backend/functions/src/modules/privacy_orchestration/infrastructure/in_memory_privacy_request_repository.ts",
  "apps/backend/functions/src/modules/privacy_orchestration/infrastructure/in_memory_privacy_task_repository.ts",
];
for (const relative of required) {
  if (!existsSync(path.join(repoRoot, relative)))
    throw new Error(`Security/privacy path absent: ${relative}`);
}
for (const relative of required.filter((item) => item.endsWith(".ts"))) {
  const source = readFileSync(path.join(repoRoot, relative), "utf8");
  if (/firebase-(?:admin|functions)|@google-cloud/u.test(source))
    throw new Error(`Security/privacy core imports cloud SDK: ${relative}`);
}
const rules = readFileSync(path.join(backendRoot, "firestore.rules"), "utf8");
for (const collection of [
  "privacyRequests",
  "privacyDomainTasks",
  "securityAuditEvents",
  "securityRateLimitCounters",
  "securityRateLimitAttempts",
  "securityAudit",
]) {
  if (
    !rules.includes(
      `match /${collection}/{document} { allow read, write: if false; }`,
    )
  )
    throw new Error(`Missing explicit privacy deny: ${collection}`);
}
if (
  /allow\s+(?:read|write|create|update|delete)[^;]*:\s*if\s+true/u.test(rules)
)
  throw new Error("Security/privacy slice must not add a direct-client allow");
const indexes = JSON.parse(
  readFileSync(path.join(backendRoot, "firestore.indexes.json"), "utf8"),
);
if (
  indexes.indexes.some((entry) =>
    [
      "privacyRequests",
      "privacyDomainTasks",
      "securityAuditEvents",
      "securityRateLimitCounters",
      "securityRateLimitAttempts",
      "securityAudit",
    ].includes(entry.collectionGroup),
  )
)
  throw new Error(
    "Privacy Firestore indexes are forbidden before a repository/query slice",
  );
process.stdout.write(
  `Security/privacy layout gate passed: ${required.length} paths, explicit deny Rules, zero premature indexes.\n`,
);
