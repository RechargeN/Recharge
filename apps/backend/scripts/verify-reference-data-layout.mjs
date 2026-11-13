import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");
const required = [
  "packages/api_contracts/schema/reference_data/v1/localized_text.schema.json",
  "packages/api_contracts/schema/reference_data/v1/market_config_revision.schema.json",
  "packages/api_contracts/schema/reference_data/v1/mandatory_copy_reference.schema.json",
  "packages/api_contracts/schema/reference_data/v1/source_record.schema.json",
  "packages/api_contracts/schema/reference_data/v1/activation_pointer.schema.json",
  "apps/backend/functions/src/contracts/reference_data_v1.ts",
  "apps/backend/functions/src/contracts/reference_data_schema_registry.ts",
  "apps/backend/functions/src/contracts/validate_reference_data_contract.ts",
  "apps/backend/functions/src/modules/reference_data/domain/identifiers.ts",
  "apps/backend/functions/src/modules/reference_data/domain/localized_text.ts",
  "apps/backend/functions/src/modules/reference_data/domain/source_provenance.ts",
  "apps/backend/functions/src/modules/reference_data/domain/mandatory_copy.ts",
  "apps/backend/functions/src/modules/reference_data/domain/market_config.ts",
  "apps/backend/functions/src/modules/reference_data/domain/capability_matrix.ts",
  "apps/backend/functions/src/modules/reference_data/domain/failures.ts",
  "apps/backend/functions/src/modules/reference_data/domain/repositories.ts",
  "apps/backend/functions/src/modules/reference_data/application/resolve_localized_text.ts",
  "apps/backend/functions/src/modules/reference_data/application/evaluate_market_capability.ts",
  "apps/backend/functions/src/modules/reference_data/application/reference_data_service.ts",
  "apps/backend/functions/src/modules/reference_data/application/rollback_market_config.ts",
];
for (const relative of required) {
  if (!existsSync(path.join(repoRoot, relative)))
    throw new Error(`Reference-data path absent: ${relative}`);
}
for (const relative of required.filter((item) => item.endsWith(".ts"))) {
  const source = readFileSync(path.join(repoRoot, relative), "utf8");
  if (/firebase-(?:admin|functions)|@google-cloud/u.test(source))
    throw new Error(`Reference-data core imports cloud SDK: ${relative}`);
}
for (const relative of required.filter((item) =>
  item.includes("/src/contracts/"),
)) {
  const source = readFileSync(path.join(repoRoot, relative), "utf8");
  if (/from ['"]\.\.\/modules\//u.test(source))
    throw new Error(
      `Reference-data wire contract depends on domain module: ${relative}`,
    );
}
process.stdout.write(
  `Reference-data layout gate passed: ${required.length} required paths; no cloud dependency.\n`,
);
