import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { Ajv2020 } from "../functions/node_modules/ajv/dist/2020.js";
import addFormats from "../functions/node_modules/ajv-formats/dist/index.js";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const configRoot = path.join(backendRoot, "config");
const ajv = new Ajv2020({ allErrors: true, strict: true });
addFormats(ajv);

const schemaFiles = {
  environment: "environment.schema.json",
  regionPolicy: "region-policy.schema.json",
  marketCapability: "market-capability.schema.json",
  releaseManifest: "release-manifest.schema.json",
  secretReference: "secret-reference.schema.json",
};
const validators = Object.fromEntries(
  Object.entries(schemaFiles).map(([name, file]) => [
    name,
    ajv.compile(readJson(path.join(configRoot, file))),
  ]),
);
const valid = readJson(path.join(configRoot, "fixtures", "valid.json"));
const groups = {
  environment: valid.environments,
  regionPolicy: valid.regionPolicies,
  marketCapability: valid.marketCapabilities,
  releaseManifest: valid.releaseManifests,
  secretReference: valid.secretReferences,
};
for (const [target, values] of Object.entries(groups)) {
  for (const value of values) {
    if (!validators[target](value))
      throw new Error(
        `Valid ${target} fixture rejected: ${ajv.errorsText(validators[target].errors)}`,
      );
  }
}
for (const fixture of ["invalid.json", "forward.json"]) {
  for (const testCase of readJson(path.join(configRoot, "fixtures", fixture))
    .cases) {
    if (validators[testCase.target](testCase.value))
      throw new Error(
        `${fixture} case unexpectedly accepted: ${testCase.reason}`,
      );
  }
}
if (
  valid.marketCapabilities.some((entry) => entry.status !== "disabled") ||
  valid.releaseManifests.some((entry) => entry.status !== "disabled")
) {
  throw new Error("R1 valid fixtures must be disabled");
}
process.stdout.write(
  "R1 config gate passed: five schemas, valid/invalid/forward fixtures, disabled defaults.\n",
);

function readJson(file) {
  return JSON.parse(readFileSync(file, "utf8"));
}
