import { spawnSync } from "node:child_process";
import {
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
    /\bprovisioner\b|local-exec|remote-exec|null_resource|terraform_data/u,
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
  const text = read(file);
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
    else if (!/enabled\s*=\s*local\.provisioning_authorized/u.test(match[1]))
      problems.push(
        `envs/${env}: module ${name} is not gated by provisioning_authorized`,
      );
  }
  if (
    !/provisioning_authorized\s*=\s*\(\s*var\.project_id != null\s*&&\s*var\.authorization_ref != null\s*&&\s*var\.manifest_sha256 == filesha256/u.test(
      main,
    )
  )
    problems.push(`envs/${env}: the authorization gate is weakened`);
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
    const result = spawnSync(candidate, ["version"], { encoding: "utf8" });
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
    env: { ...cleaned, TF_IN_AUTOMATION: "1", TF_INPUT: "0", ...extraEnv },
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
  const planOf = (env, variables) => {
    const dir = path.join(terraformRoot, "envs", env);
    const scratch = mkdtempSync(path.join(os.tmpdir(), `recharge-iac-${env}-`));
    try {
      const args = [
        "plan",
        "-input=false",
        "-lock=false",
        "-refresh=false",
        "-no-color",
        `-out=${path.join(scratch, "plan")}`,
      ];
      for (const [key, value] of Object.entries(variables))
        args.push(`-var=${key}=${value}`);
      // A synthetic placeholder lets the provider configure without looking for
      // credentials; with zero resources no API is ever called, and with
      // refresh disabled nothing is read.
      const plan = run(terraform, args, dir, {
        GOOGLE_OAUTH_ACCESS_TOKEN: "offline-plan-placeholder",
      });
      if (plan.status !== 0)
        return {
          error:
            plan.stderr.trim().slice(0, 300) || plan.stdout.trim().slice(-300),
        };
      const shown = run(
        terraform,
        ["show", "-json", path.join(scratch, "plan")],
        dir,
      );
      const json = JSON.parse(shown.stdout);
      return {
        changes: (json.resource_changes ?? []).length,
        outputs: json.planned_values?.outputs ?? {},
      };
    } finally {
      rmSync(scratch, { recursive: true, force: true });
    }
  };
  for (const env of environments) {
    const dir = path.join(terraformRoot, "envs", env);
    const init = run(
      terraform,
      [
        "init",
        "-backend=false",
        "-input=false",
        "-no-color",
        ...(existsSync(providerMirror)
          ? [`-plugin-dir=${providerMirror}`]
          : []),
      ],
      dir,
    );
    if (init.status !== 0) {
      problems.push(
        `envs/${env}: terraform init failed: ${init.stderr.trim().slice(0, 200)}`,
      );
      continue;
    }
    const validate = run(terraform, ["validate", "-no-color"], dir);
    if (validate.status !== 0) {
      problems.push(
        `envs/${env}: terraform validate failed: ${validate.stdout.trim().slice(0, 300)}`,
      );
      continue;
    }
    // The gate closed: zero resources. Partially open: still zero. Only the exact
    // combination opens it, and that is only ever planned, never applied.
    const closed = planOf(env, {});
    if (closed.error !== undefined)
      problems.push(`envs/${env}: empty plan failed: ${closed.error}`);
    else if (
      closed.changes !== 0 ||
      closed.outputs.provisioning_authorized?.value !== false
    )
      problems.push(
        `envs/${env}: the closed gate planned ${String(closed.changes)} resources`,
      );
    const manifestHash = createHash("sha256")
      .update(
        readFileSync(
          path.join(
            backendRoot,
            "config",
            "manifests",
            "execution-manifest.json",
          ),
        ),
      )
      .digest("hex");
    const syntheticProject = `recharge-${env}-selftest0`;
    const partial = planOf(env, {
      project_id: syntheticProject,
      authorization_ref: "selftest-record",
      manifest_sha256: "0".repeat(64),
    });
    if (partial.error !== undefined)
      problems.push(
        `envs/${env}: partial-authorization plan failed: ${partial.error}`,
      );
    else if (partial.changes !== 0)
      problems.push(
        `envs/${env}: a wrong manifest hash still planned ${String(partial.changes)} resources`,
      );
    const noReference = planOf(env, {
      project_id: syntheticProject,
      manifest_sha256: manifestHash,
    });
    if (noReference.error !== undefined)
      problems.push(
        `envs/${env}: no-reference plan failed: ${noReference.error}`,
      );
    else if (noReference.changes !== 0)
      problems.push(
        `envs/${env}: a missing authorization reference still planned ${String(noReference.changes)} resources`,
      );
    const open = planOf(env, {
      project_id: syntheticProject,
      authorization_ref: "selftest-record",
      manifest_sha256: manifestHash,
    });
    if (open.error !== undefined)
      problems.push(`envs/${env}: open-gate plan failed: ${open.error}`);
    else if (open.changes === 0)
      problems.push(`envs/${env}: the gate never opens even with every input`);
  }
}

if (problems.length > 0) {
  process.stderr.write(
    `IaC topology gate failed:\n- ${problems.join("\n- ")}\n`,
  );
  process.exitCode = 1;
} else {
  process.stdout.write(
    `IaC topology gate passed: ${String(moduleNames.length)} modules, three isolated environment roots, every resource gated, no credential, backend, project literal or double-managed resource${terraform === undefined ? "" : "; Terraform fmt, validate and gate-behaviour plans passed"}.\n`,
  );
}
