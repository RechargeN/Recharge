import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");
const functionsRoot = path.join(backendRoot, "functions");
const lock = JSON.parse(
  readFileSync(path.join(backendRoot, "toolchain.lock.json"), "utf8"),
);
const packageManifest = JSON.parse(
  readFileSync(path.join(functionsRoot, "package.json"), "utf8"),
);
const firebaseConfig = JSON.parse(
  readFileSync(path.join(backendRoot, "firebase.json"), "utf8"),
);
const workflow = readFileSync(
  path.join(repoRoot, ".github", "workflows", "backend-r0.yml"),
  "utf8",
);

const failures = [];
const allowedLicenses = new Set([
  "(BSD-2-Clause OR MIT OR Apache-2.0)",
  "(MIT OR CC0-1.0)",
  "0BSD",
  "Apache-2.0",
  "BSD",
  "BSD-2-Clause",
  "BSD-3-Clause",
  "BlueOak-1.0.0",
  "CC0-1.0",
  "ISC",
  "MIT",
  "Python-2.0",
  "public domain",
]);
const allowedLifecycleHooks = new Set([
  "@firebase/util@1.15.3:postinstall",
  "protobufjs@7.6.5:postinstall",
  "re2@1.26.1:install",
]);

function collectPackageManifests(directory) {
  const manifests = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const child = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      manifests.push(...collectPackageManifests(child));
    } else if (entry.name === "package.json") {
      try {
        const manifest = JSON.parse(readFileSync(child, "utf8"));
        if (
          typeof manifest.name === "string" &&
          typeof manifest.version === "string"
        ) {
          manifests.push({ directory, manifest });
        }
      } catch {
        failures.push(`invalid installed package manifest: ${child}`);
      }
    }
  }
  return manifests;
}

function expectEqual(actual, expected, label) {
  if (actual !== expected) {
    failures.push(
      `${label} mismatch: expected ${expected}, received ${String(actual)}`,
    );
  }
}

function commandVersion(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", shell: false });
  if (result.error || result.status !== 0) {
    failures.push(`${command} version command failed`);
    return "";
  }
  return `${result.stdout ?? ""}\n${result.stderr ?? ""}`.trim();
}

expectEqual(lock.schemaVersion, 1, "toolchain lock schema");
expectEqual(process.version, `v${lock.node.version}`, "Node.js");

const npmExecutable = process.env.npm_execpath;
if (npmExecutable === undefined) {
  failures.push("npm_execpath is absent; run this gate through npm");
} else {
  expectEqual(
    commandVersion(process.execPath, [npmExecutable, "--version"]),
    lock.node.npm,
    "npm",
  );
}

const javaVersion = commandVersion("java", ["-version"]);
if (!javaVersion.includes("21.0.12") || !javaVersion.includes("+8")) {
  failures.push("Java mismatch: expected Temurin-compatible 21.0.12+8");
}

const terraformVersion = commandVersion("terraform", ["version", "-json"]);
try {
  expectEqual(
    JSON.parse(terraformVersion).terraform_version,
    lock.terraform.version,
    "Terraform",
  );
} catch {
  failures.push("Terraform did not return valid version JSON");
}

expectEqual(firebaseConfig.functions?.runtime, "nodejs22", "Firebase runtime");
expectEqual(packageManifest.engines?.node, "22", "package engines.node");
expectEqual(
  packageManifest.packageManager,
  `npm@${lock.node.npm}`,
  "package manager",
);

for (const [name, version] of Object.entries(lock.packages)) {
  const actual =
    packageManifest.dependencies?.[name] ??
    packageManifest.devDependencies?.[name];
  expectEqual(actual, version, `package ${name}`);
  const installedPackage = JSON.parse(
    readFileSync(
      path.join(functionsRoot, "node_modules", name, "package.json"),
      "utf8",
    ),
  );
  expectEqual(installedPackage.version, version, `installed package ${name}`);
}

const observedLifecycleHooks = new Set();
for (const { directory, manifest } of collectPackageManifests(
  path.join(functionsRoot, "node_modules"),
)) {
  if (typeof manifest.license === "string") {
    if (!allowedLicenses.has(manifest.license)) {
      failures.push(
        `unreviewed dependency license ${manifest.license}: ${manifest.name}@${manifest.version}`,
      );
    }
  } else {
    const hasLicenseFile = readdirSync(directory).some((name) =>
      /^(licen[cs]e)([-._].*)?$/iu.test(name),
    );
    if (!hasLicenseFile) {
      failures.push(
        `dependency has no license metadata or license file: ${manifest.name}@${manifest.version}`,
      );
    }
  }

  for (const hook of ["preinstall", "install", "postinstall"]) {
    if (typeof manifest.scripts?.[hook] === "string") {
      observedLifecycleHooks.add(
        `${manifest.name}@${manifest.version}:${hook}`,
      );
    }
  }
}

for (const hook of observedLifecycleHooks) {
  if (!allowedLifecycleHooks.has(hook)) {
    failures.push(`unreviewed dependency lifecycle hook: ${hook}`);
  }
}
for (const hook of allowedLifecycleHooks) {
  if (!observedLifecycleHooks.has(hook)) {
    failures.push(`expected reviewed lifecycle hook is absent: ${hook}`);
  }
}

for (const [repository, sha] of Object.entries(lock.githubActions)) {
  if (!workflow.includes(`${repository}@${sha}`)) {
    failures.push(`workflow does not pin ${repository} to the lock SHA`);
  }
}

for (const forbidden of [
  "hashicorp/setup-terraform@",
  "actions/upload-artifact@",
  "actions/cache@",
  "id-token: write",
  "ubuntu-latest",
  "windows-latest",
]) {
  if (workflow.includes(forbidden)) {
    failures.push(`workflow contains forbidden input: ${forbidden}`);
  }
}

for (const runner of lock.runners) {
  if (!workflow.includes(runner)) {
    failures.push(`workflow omits locked runner ${runner}`);
  }
}

if (failures.length > 0) {
  for (const failure of failures) {
    process.stderr.write(`${failure}\n`);
  }
  process.exitCode = 1;
} else {
  process.stdout.write("Exact R0 toolchain and workflow manifest verified.\n");
}
