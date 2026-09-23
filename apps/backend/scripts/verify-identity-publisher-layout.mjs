import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");
const required = [
  "packages/api_contracts/schema/identity/v1/identity_common.schema.json",
  "packages/api_contracts/schema/identity/v1/account.schema.json",
  "packages/api_contracts/schema/identity/v1/auth_identity.schema.json",
  "packages/api_contracts/schema/identity/v1/session.schema.json",
  "packages/api_contracts/schema/identity/v1/access_snapshot.schema.json",
  "packages/api_contracts/schema/identity/v1/creator_verification.schema.json",
  "packages/api_contracts/schema/identity/v1/managed_page.schema.json",
  "packages/api_contracts/schema/identity/v1/page_membership.schema.json",
  "packages/api_contracts/schema/identity/v1/publisher_eligibility.schema.json",
  "apps/backend/functions/src/contracts/identity_v1.ts",
  "apps/backend/functions/src/contracts/identity_schema_registry.ts",
  "apps/backend/functions/src/contracts/validate_identity_contract.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/account.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/auth_identity.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/session.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/user.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/capability.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/authority_event.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/failures.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/creator_verification.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/managed_page.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/page_membership.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/access_snapshot.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/publisher_ref.ts",
  "apps/backend/functions/src/modules/identity_publisher/domain/repositories.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/identity_publisher_authority.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/account_linking_service.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/account_security_service.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/session_authority_service.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/creator_verification_service.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/managed_page_service.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/access_snapshot_service.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/publisher_eligibility_service.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/ports/provider_identity_verifier.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/ports/verification_decision_port.ts",
  "apps/backend/functions/src/modules/identity_publisher/application/ports/page_creation_policy_port.ts",
  "apps/backend/functions/src/modules/identity_publisher/infrastructure/in_memory_identity_authority_repository.ts",
  "apps/backend/functions/src/modules/identity_publisher/infrastructure/synthetic_provider_identity_verifier.ts",
  "apps/backend/functions/src/modules/identity_publisher/infrastructure/local_verification_decision_adapter.ts",
  "apps/backend/functions/src/modules/identity_publisher/infrastructure/local_page_creation_policy.ts",
  "apps/backend/functions/test/unit/identity_publisher/identity_domain.test.ts",
  "apps/backend/functions/test/contract/identity_fixture_parity.test.ts",
  "apps/backend/functions/test/integration/identity_publisher_authority.test.ts",
  "apps/backend/functions/test/rules/firestore_identity_rules.test.ts",
];

for (const relative of required) {
  if (!existsSync(path.join(repoRoot, relative)))
    throw new Error(`Identity/Publisher path absent: ${relative}`);
}
for (const relative of required.filter((item) => item.endsWith(".ts"))) {
  const source = readFileSync(path.join(repoRoot, relative), "utf8");
  if (/firebase-(?:admin|functions)|@google-cloud/u.test(source))
    throw new Error(`Identity/Publisher core imports cloud SDK: ${relative}`);
}
const rules = readFileSync(path.join(backendRoot, "firestore.rules"), "utf8");
const collections = [
  "identityAccounts",
  "identityProviderLinks",
  "identitySessions",
  "identityCreatorVerifications",
  "identityManagedPages",
  "identityPageMemberships",
];
for (const collection of collections) {
  if (
    !rules.includes(
      `match /${collection}/{document} { allow read, write: if false; }`,
    )
  )
    throw new Error(`Missing explicit Identity deny: ${collection}`);
}
const indexes = JSON.parse(
  readFileSync(path.join(backendRoot, "firestore.indexes.json"), "utf8"),
);
if (
  indexes.indexes.some((entry) => collections.includes(entry.collectionGroup))
)
  throw new Error(
    "Identity indexes are forbidden before a Firestore repository slice",
  );
process.stdout.write(
  `Identity/Publisher layout gate passed: ${required.length} required paths, six explicit denies, zero cloud dependency or premature indexes.\n`,
);
