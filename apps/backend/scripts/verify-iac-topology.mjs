import { spawnSync } from "node:child_process";
import {
  cpSync,
  mkdirSync,
  writeFileSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
} from "node:fs";
import { createHash } from "node:crypto";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");
const terraformRoot = path.join(backendRoot, "infra", "terraform");
const moduleNames = [
  "project_baseline",
  "firestore",
  "storage",
  "runtime_identities",
  "ci_wif",
  "budget_alerts",
  "secret_containers",
  "app_check",
  "state_bucket",
];
const environments = ["dev", "stage", "prod"];
const problems = [];
const requireTerraform = process.argv.includes("--require-terraform");

function read(file) {
  return readFileSync(file, "utf8");
}

function filesUnder(directory, predicate) {
  return readdirSync(directory).flatMap((name) => {
    if (name === ".terraform") return [];
    const full = path.join(directory, name);
    if (statSync(full).isDirectory()) return filesUnder(full, predicate);
    return predicate(full) ? [full] : [];
  });
}

// ------------------------------------------------------------ required paths
for (const name of moduleNames)
  for (const file of ["main", "variables", "outputs", "versions"])
    if (!existsSync(path.join(terraformRoot, "modules", name, `${file}.tf`)))
      problems.push(`missing module file: ${name}/${file}.tf`);
for (const env of environments)
  for (const file of [
    "main.tf",
    "variables.tf",
    "outputs.tf",
    "providers.tf",
    "versions.tf",
    "backend.tf.example",
    "terraform.tfvars.example",
    ".terraform.lock.hcl",
  ])
    if (!existsSync(path.join(terraformRoot, "envs", env, file)))
      problems.push(`missing environment file: envs/${env}/${file}`);

const hclFiles = filesUnder(
  path.join(terraformRoot),
  (file) =>
    file.endsWith(".tf") && !file.endsWith(`${path.sep}.terraform.lock.hcl`),
).filter((file) => /[\\/](modules|envs)[\\/]/u.test(file));

// ------------------------------------------------------------ forbidden content
const forbidden = [
  [/\bcredentials\s*=/u, "a provider credential"],
  [/\baccess_token\s*=/u, "an access token"],
  [/impersonate_service_account/u, "service account impersonation"],
  [
    /\bprovisioner\b|local-exec|remote-exec|null_resource/u,
    "an executing provisioner",
  ],
  [
    /^\s*backend\s+"/mu,
    "a real backend block (only backend.tf.example may show one)",
  ],
  [
    /recharge-(?:dev|stage|prod)-[a-z0-9]{4,}/u,
    "a literal provider project id",
  ],
  [/\bproject\s*=\s*"[^"$]/u, "a literal project"],
  [
    /BEGIN [A-Z ]*PRIVATE KEY|AIza[0-9A-Za-z_-]{20,}|gh[pousr]_[0-9A-Za-z]{20,}/u,
    "a secret",
  ],
  // Rules, indexes, TTL and Functions deployment belong to the Firebase CLI alone.
  [
    /resource\s+"(?:google_firestore_index|google_firestore_field|google_firebaserules_[a-z_]+|google_cloudfunctions2?_function|google_cloud_run_v2_service)"/u,
    "a resource owned by the Firebase CLI (double management)",
  ],
  [
    /resource\s+"google_billing_account_iam|resource\s+"google_project"|billing_info/u,
    "project creation or a billing change",
  ],
  [/google_secret_manager_secret_version/u, "a secret version (a value)"],
];
for (const file of hclFiles) {
  const text = read(file)
    .split(/\r?\n/u)
    .filter((line) => !/^\s*#/u.test(line))
    .join("\n");
  const relative = path.relative(repoRoot, file);
  for (const [pattern, label] of forbidden)
    if (pattern.test(text)) problems.push(`${relative}: contains ${label}`);
}

// ------------------------------------------------------------ gate on every resource
for (const name of moduleNames) {
  const dir = path.join(terraformRoot, "modules", name);
  const main = read(path.join(dir, "main.tf"));
  const variables = read(path.join(dir, "variables.tf"));
  if (!/variable "enabled"[\s\S]*?default\s*=\s*false/u.test(variables))
    problems.push(`modules/${name}: enabled must exist and default to false`);
  const blocks = main.split(/\nresource "/u).slice(1);
  for (const block of blocks) {
    const head = block.slice(0, block.indexOf("{"));
    if (!/var\.enabled/u.test(block.slice(0, 600)))
      problems.push(
        `modules/${name}: resource ${head.trim()} is not guarded by var.enabled`,
      );
  }
  if (
    ["firestore", "storage", "state_bucket", "secret_containers"].includes(
      name,
    ) &&
    !/prevent_destroy\s*=\s*true/u.test(main)
  )
    problems.push(`modules/${name}: data resources need prevent_destroy`);
}

// ------------------------------------------------------------ environment roots
const stateKeys = new Set();
const projects = new Set();
for (const env of environments) {
  const dir = path.join(terraformRoot, "envs", env);
  const main = read(path.join(dir, "main.tf"));
  const variables = read(path.join(dir, "variables.tf"));
  const backend = read(path.join(dir, "backend.tf.example"));
  for (const name of moduleNames) {
    const match = new RegExp(
      `module "${name}" \\{([\\s\\S]*?)\\n\\}`,
      "u",
    ).exec(main);
    if (match === null)
      problems.push(`envs/${env}: module ${name} is not used`);
    else if (
      !/enabled\s*=\s*true/u.test(match[1]) ||
      !match[1].includes("depends_on = [terraform_data.execution_guard]")
    )
      problems.push(
        `envs/${env}: module ${name} must have stable presence and depend on execution_guard`,
      );
  }
  for (const required of [
    'resource "terraform_data" "execution_guard"',
    "precondition {",
    "condition     = local.authorization_valid",
    "condition     = local.manifest_authorized",
    'local.authorization.status == "approved"',
    "local.authorization.environment == var.environment_id",
    "local.authorization.projectId == var.project_id",
    "local.authorization.commitSha == var.release_commit_sha",
    "local.authorization.manifestSha256 == filesha256(local.manifest_path)",
    "var.authorization_record_sha256 == filesha256(var.authorization_record_path)",
    "timecmp(local.authorization.expiresAtUtc, plantimestamp()) > 0",
  ])
    if (!main.includes(required))
      problems.push(
        `envs/${env}: missing blocking authorization check: ${required}`,
      );
  if (/enabled\s*=[^\n]*provisioning_authorized/u.test(main))
    problems.push(
      `envs/${env}: execution permission must not change resource cardinality`,
    );
  for (const label of ["application", "environment", "managed_by", "stage"])
    if (!new RegExp(`${label}\\s*=`, "u").test(main))
      problems.push(`envs/${env}: label ${label} missing`);
  if (!new RegExp(`environment = "${env}"`, "u").test(main))
    problems.push(`envs/${env}: wrong environment label`);
  if (!new RegExp(`default\\s*=\\s*"${env}"`, "u").test(variables))
    problems.push(`envs/${env}: wrong environment_id`);
  if (!/project_id[\s\S]*?default\s*=\s*null/u.test(variables))
    problems.push(`envs/${env}: project_id must default to null`);
  if (!/authorization_ref[\s\S]*?default\s*=\s*null/u.test(variables))
    problems.push(`envs/${env}: authorization_ref must default to null`);
  const key = /prefix\s*=\s*"([^"]+)"/u.exec(backend)?.[1];
  if (key === undefined || !key.endsWith(`/${env}`))
    problems.push(`envs/${env}: state prefix does not name the environment`);
  else if (stateKeys.has(key))
    problems.push(`envs/${env}: state prefix is shared`);
  else stateKeys.add(key);
  const projectPattern = new RegExp(`recharge-${env}-`, "u");
  if (!projectPattern.test(variables))
    problems.push(`envs/${env}: project id rule does not name the environment`);
  projects.add(env);
  // The manifest this root hashes must be the single shared one.
  if (!/config\/manifests\/execution-manifest\.json/u.test(main))
    problems.push(`envs/${env}: does not read the execution manifest`);
}
if (projects.size !== 3) problems.push("three environment roots are required");

// Exact accepted WIF surface, tested without exchanging any real token.
const wif = read(path.join(terraformRoot, "modules", "ci_wif", "main.tf"));
for (const clause of [
  "assertion.iss",
  "assertion.aud",
  "assertion.sub",
  "assertion.repository_id",
  "assertion.repository_owner_id",
  "assertion.repository_visibility",
  "assertion.workflow_ref",
  "assertion.ref",
  "assertion.environment",
  "assertion.event_name",
  "allowed_audiences",
  "backend-deploy.yml@refs/heads/main",
  "disabled                           = !local.configured",
])
  if (!wif.includes(clause)) problems.push(`WIF: missing constraint ${clause}`);
if (wif.includes("backend-iac-validate.yml"))
  problems.push("Validation workflow must never be trusted");

// ------------------------------------------------------------ workflow
const workflowPath = path.join(
  repoRoot,
  ".github",
  "workflows",
  "backend-iac-validate.yml",
);
if (!existsSync(workflowPath))
  problems.push("workflow backend-iac-validate.yml is absent");
else {
  // Comments may mention what is forbidden; only real workflow lines count.
  const workflow = read(workflowPath)
    .split(/\r?\n/u)
    .filter((line) => !/^\s*#/u.test(line))
    .join("\n");
  if (!/^permissions:\s*\n\s+contents:\s*read\s*$/mu.test(workflow))
    problems.push("workflow: permissions must be exactly contents: read");
  if (/id-token/u.test(workflow))
    problems.push("workflow: id-token is forbidden");
  if (/\$\{\{\s*secrets\./u.test(workflow))
    problems.push("workflow: secrets are forbidden");
  if (
    /terraform[^\n]*\bapply\b|\bdestroy\b|gcloud|firebase\s+deploy|firebase-tools[^\n]*deploy/u.test(
      workflow,
    )
  )
    problems.push("workflow: a cloud or apply step is present");
  for (const match of workflow.matchAll(/uses:\s*([^\s@]+)@([^\s]+)/gu))
    if (!/^[0-9a-f]{40}$/u.test(match[2]))
      problems.push(`workflow: ${match[1]} is not pinned to a commit`);
  if (/pull_request_target/u.test(workflow))
    problems.push("workflow: pull_request_target is forbidden");
}

// ------------------------------------------------------------ Terraform (pinned, local or CI copy)
function findTerraform() {
  const candidates = [];
  if (process.env.TERRAFORM_BIN) candidates.push(process.env.TERRAFORM_BIN);
  const platformKey = `${process.platform}-${process.arch}`.replace(
    "win32",
    "win32",
  );
  const exe = process.platform === "win32" ? "terraform.exe" : "terraform";
  candidates.push(
    path.join(
      backendRoot,
      ".r0-tools",
      "terraform",
      "1.15.9",
      platformKey,
      exe,
    ),
  );
  candidates.push("terraform");
  for (const candidate of candidates) {
    const result = spawnSync(candidate, ["version"], {
      encoding: "utf8",
      env: { ...process.env, CHECKPOINT_DISABLE: "1" },
    });
    if (result.status === 0 && /Terraform v1\.15\.9\b/u.test(result.stdout))
      return candidate;
  }
  return undefined;
}

function run(binary, args, cwd, extraEnv = {}) {
  const cleaned = { ...process.env };
  for (const name of Object.keys(cleaned))
    if (
      /^(GOOGLE_|GCLOUD_|CLOUDSDK_|FIREBASE_TOKEN|GOOGLE_APPLICATION)/u.test(
        name,
      )
    )
      delete cleaned[name];
  return spawnSync(binary, args, {
    cwd,
    encoding: "utf8",
    env: {
      ...cleaned,
      CHECKPOINT_DISABLE: "1",
      TF_IN_AUTOMATION: "1",
      TF_INPUT: "0",
      ...extraEnv,
    },
  });
}

const terraform = findTerraform();
if (terraform === undefined) {
  if (requireTerraform)
    problems.push("the pinned Terraform 1.15.9 is required and was not found");
  else
    process.stdout.write(
      "Terraform 1.15.9 not found: static IaC checks only.\n",
    );
} else {
  const fmt = run(
    terraform,
    ["fmt", "-check", "-recursive", "-no-color"],
    terraformRoot,
  );
  if (fmt.status !== 0)
    problems.push(
      `terraform fmt -check failed: ${fmt.stdout.trim().split("\n").slice(0, 5).join(", ")}`,
    );
  const providerMirror = path.join(terraformRoot, ".terraform", "providers");

  // No real provider plan, no ADC lookup, no dummy access token. Test copies
  // contain only mocked providers and synthetic records; no persistent state.
  if (!existsSync(providerMirror) && !process.env.CI) {
    problems.push(
      "Local verified provider mirror missing; downloads require separate permission.",
    );
  } else
    for (const env of environments) {
      const scratch = mkdtempSync(
        path.join(os.tmpdir(), "recharge-iac-review-"),
      );
      try {
        const root = path.join(scratch, "infra", "terraform");
        const dir = path.join(root, "envs", env);
        mkdirSync(path.dirname(dir), { recursive: true });
        cpSync(
          path.join(terraformRoot, "modules"),
          path.join(root, "modules"),
          { recursive: true },
        );
        mkdirSync(dir);
        for (const name of readdirSync(path.join(terraformRoot, "envs", env)))
          if (/\.tf$|\.lock\.hcl$/u.test(name))
            writeFileSync(
              path.join(dir, name),
              read(path.join(terraformRoot, "envs", env, name)),
            );
        const manifestDir = path.join(scratch, "config", "manifests");
        mkdirSync(manifestDir, { recursive: true });
        const raw = read(
          path.join(
            backendRoot,
            "config",
            "manifests",
            "execution-manifest.json",
          ),
        );
        writeFileSync(path.join(manifestDir, "execution-manifest.json"), raw);
        const digest = createHash("sha256").update(raw).digest("hex");
        const record = {
          schemaVersion: 1,
          status: "approved",
          recordRef: "synthetic-not-authority",
          owner: "test-only",
          ownerApprovalEvidenceRef: "test-only",
          environment: env,
          projectId: `recharge-${env}-selftest0`,
          manifestSha256: digest,
          commitSha: "a".repeat(40),
          dataScope: "synthetic",
          operations: ["plan", "apply"],
          push: false,
          merge: false,
          marketActivation: false,
          issuedAtUtc: "2000-01-01T00:00:00Z",
          expiresAtUtc: "2100-01-01T00:00:00Z",
        };
        const variants = [
          ["complete_but_draft", record],
          ["expired", { ...record, expiresAtUtc: "2001-01-01T00:00:00Z" }],
          [
            "wrong_environment",
            { ...record, environment: env === "dev" ? "prod" : "dev" },
          ],
          ["wrong_project", { ...record, projectId: "recharge-dev-foreign0" }],
          ["wrong_manifest", { ...record, manifestSha256: "0".repeat(64) }],
          ["unsigned", { ...record, status: "draft" }],
        ];
        let tests = 'mock_provider "google" {}\n';
        tests += `run "missing_record" {
        command = plan
        variables { project_id = "recharge-${env}-selftest0" }
        expect_failures = [terraform_data.execution_guard]
      }\n`;
        for (const [name, value] of variants) {
          const recordRaw = JSON.stringify(value);
          writeFileSync(path.join(dir, `${name}.json`), recordRaw);
          tests += `run "${name}" {
          command = plan
          variables {
            project_id = "recharge-${env}-selftest0"
            authorization_ref = "synthetic-not-authority"
            manifest_sha256 = "${digest}"
            authorization_record_path = "./${name}.json"
            authorization_record_sha256 = "${createHash("sha256").update(recordRaw).digest("hex")}"
            release_commit_sha = "${"a".repeat(40)}"
          }
          expect_failures = [terraform_data.execution_guard]
        }\n`;
        }
        writeFileSync(path.join(dir, "authorization.tftest.hcl"), tests);
        const init = run(
          terraform,
          [
            "init",
            "-backend=false",
            "-input=false",
            "-lockfile=readonly",
            "-no-color",
            ...(existsSync(providerMirror)
              ? [`-plugin-dir=${providerMirror}`]
              : []),
          ],
          dir,
        );
        if (init.status !== 0) {
          problems.push(
            `envs/${env}: init failed: ${init.stderr.slice(0, 600)}`,
          );
          continue;
        }
        for (const args of [
          ["validate", "-no-color"],
          ["test", "-no-color"],
        ]) {
          const result = run(terraform, args, dir);
          if (result.status !== 0)
            problems.push(
              `envs/${env}: ${args[0]} failed: ${result.stdout.slice(-1200)} ${result.stderr.slice(-1200)}`,
            );
          else if (args[0] === "test")
            process.stdout.write(
              `${env}: mocked authorization tests passed (no cloud).\n`,
            );
        }
        // Isolate the record checks: otherwise the Draft-manifest refusal would
        // conceal a broken expiry/hash/environment check. Override ONLY in this
        // disposable mocked copy, never in the workspace or with a real provider.
        writeFileSync(
          path.join(dir, "review_override.tf"),
          "locals { manifest_authorized = true }\n",
        );
        let isolated = tests.replace(
          /(run "complete_but_draft"[\s\S]*?)expect_failures = \[terraform_data.execution_guard\]/u,
          '$1assert {\n condition = output.provisioning_authorized == true\n error_message = "Synthetic valid record rejected"\n }',
        );
        const audience = `https://iam.googleapis.com/projects/123456789012/locations/global/workloadIdentityPools/github-${env}/providers/github-actions`;
        const expectedTrust = [
          "assertion.iss == 'https://token.actions.githubusercontent.com'",
          `assertion.aud == '${audience}'`,
          `assertion.sub == 'repo:RechargeN@277012929/Recharge@1213588766:environment:backend-${env}'`,
          "assertion.repository_id == '1213588766'",
          "assertion.repository_owner_id == '277012929'",
          "assertion.repository_visibility == 'public'",
          "assertion.workflow_ref == 'RechargeN/Recharge/.github/workflows/backend-deploy.yml@refs/heads/main'",
          "assertion.ref == 'refs/heads/main'",
          `assertion.environment == 'backend-${env}'`,
          env === "dev"
            ? "assertion.event_name in ['push', 'workflow_dispatch']"
            : "assertion.event_name == 'workflow_dispatch'",
        ].join(" && ");
        for (const [name, repositoryId, expected] of [
          ["exact_wif", "1213588766", expectedTrust],
          ["foreign_repo", "9999999999", "false"],
        ]) {
          isolated += `run "${name}" {
          command = plan
          variables {
            project_id = "recharge-${env}-selftest0"
            authorization_ref = "synthetic-not-authority"
            manifest_sha256 = "${digest}"
            authorization_record_path = "./complete_but_draft.json"
            authorization_record_sha256 = "${createHash("sha256").update(JSON.stringify(record)).digest("hex")}"
            release_commit_sha = "${"a".repeat(40)}"
            project_number = "123456789012"
            github_repository_id = "${repositoryId}"
            github_repository_owner_id = "277012929"
          }
          assert {
            condition = output.trust_condition == ${JSON.stringify(expected)}
            error_message = "WIF differs from exact accepted claim restrictions"
          }
        }\n`;
        }
        writeFileSync(path.join(dir, "authorization.tftest.hcl"), isolated);
        const isolatedResult = run(terraform, ["test", "-no-color"], dir);
        if (isolatedResult.status !== 0)
          problems.push(
            `envs/${env}: isolated record tests failed: ${isolatedResult.stdout.slice(-1500)} ${isolatedResult.stderr.slice(-1500)}`,
          );
        else
          process.stdout.write(
            `${env}: isolated record checks passed under mock-only override.\n`,
          );
      } finally {
        if (
          path.dirname(scratch) !== path.resolve(os.tmpdir()) ||
          !path.basename(scratch).startsWith("recharge-iac-review-")
        )
          throw new Error("Unexpected cleanup target");
        rmSync(scratch, { recursive: true, force: true });
      }
    }
}

if (problems.length > 0) {
  process.stderr.write(
    `IaC topology gate failed:\n- ${problems.join("\n- ")}\n`,
  );
  process.exitCode = 1;
} else {
  process.stdout.write(
    `IaC topology gate passed: ${String(moduleNames.length)} modules, three isolated environment roots, blocking authorization, stable resource presence, no credential, backend, project literal or double-managed resource${terraform === undefined ? "" : "; Terraform fmt, validate and mock-provider negative tests passed"}.\n`,
  );
}
