import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");

const forbiddenEnvironmentNames = [
  "GOOGLE_APPLICATION_CREDENTIALS",
  "CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE",
  "FIREBASE_TOKEN",
  "GOOGLE_OAUTH_ACCESS_TOKEN",
  "GOOGLE_REFRESH_TOKEN",
  "ACTIONS_ID_TOKEN_REQUEST_URL",
  "ACTIONS_ID_TOKEN_REQUEST_TOKEN",
  "TF_TOKEN_app_terraform_io",
  "K_SERVICE",
  "FUNCTION_TARGET",
];

const projectEnvironmentNames = [
  "GOOGLE_CLOUD_PROJECT",
  "GCLOUD_PROJECT",
  "GCP_PROJECT",
  "CLOUDSDK_CORE_PROJECT",
];

const findings = [];
for (const name of forbiddenEnvironmentNames) {
  if (Object.hasOwn(process.env, name)) {
    findings.push(`forbidden environment name present: ${name}`);
  }
}

for (const name of projectEnvironmentNames) {
  if (!Object.hasOwn(process.env, name)) {
    continue;
  }
  const value = process.env[name] ?? "";
  if (!value.startsWith("demo-")) {
    findings.push(`non-demo project environment name present: ${name}`);
  }
}

for (const candidate of [
  path.join(repoRoot, ".firebaserc"),
  path.join(backendRoot, ".firebaserc"),
  path.join(repoRoot, "firebase.json"),
]) {
  if (existsSync(candidate)) {
    findings.push(
      `forbidden cloud-selection file present: ${path.relative(repoRoot, candidate)}`,
    );
  }
}

const firebaseConfig = JSON.parse(
  readFileSync(path.join(backendRoot, "firebase.json"), "utf8"),
);
if (firebaseConfig.functions?.runtime !== "nodejs22") {
  findings.push("backend firebase.json runtime is not nodejs22");
}

if (findings.length > 0) {
  for (const finding of findings) {
    process.stderr.write(`${finding}\n`);
  }
  process.exitCode = 1;
} else {
  process.stdout.write(
    "Cloud-context denial gate passed: no credential or real project context.\n",
  );
}
