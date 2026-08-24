import { createHash } from "node:crypto";
import {
  appendFileSync,
  chmodSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const version = "1.15.9";
const fingerprint = "C874011F0AB405110D02105534365D9472D7468F";
const platform = process.platform;
const architecture = process.arch;
const archives = {
  "linux:x64": {
    name: `terraform_${version}_linux_amd64.zip`,
    sha256: "76edd0b22d2f27d3d2e097cd793209646f719cf60f02ff3af626b07361137da1",
  },
  "win32:x64": {
    name: `terraform_${version}_windows_amd64.zip`,
    sha256: "b0fcd57e2abd19fc6d8e64b86a22f5f3fb734b0407385553cdcffc64677f18b6",
  },
};

const selected = archives[`${platform}:${architecture}`];
if (selected === undefined) {
  throw new Error(
    `unsupported R0 Terraform platform: ${platform}/${architecture}`,
  );
}

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const toolsRoot = path.resolve(backendRoot, ".r0-tools");
const allowedPrefix = `${backendRoot}${path.sep}`;
if (
  !toolsRoot.startsWith(allowedPrefix) ||
  path.basename(toolsRoot) !== ".r0-tools"
) {
  throw new Error("refusing to use an unresolved R0 tools directory");
}

const downloadRoot = path.join(toolsRoot, "downloads", version);
const binRoot = path.join(
  toolsRoot,
  "terraform",
  version,
  `${platform}-${architecture}`,
);
const gpgHome = path.join(toolsRoot, "gnupg");
mkdirSync(downloadRoot, { recursive: true });
rmSync(binRoot, { recursive: true, force: true });
mkdirSync(binRoot, { recursive: true });
rmSync(gpgHome, { recursive: true, force: true });
mkdirSync(gpgHome, { recursive: true });

async function download(url, destination) {
  const response = await fetch(url, { signal: AbortSignal.timeout(60_000) });
  if (!response.ok) {
    throw new Error(
      `download failed with HTTP ${response.status}: ${new URL(url).host}`,
    );
  }
  writeFileSync(destination, Buffer.from(await response.arrayBuffer()));
}

const releaseBase = `https://releases.hashicorp.com/terraform/${version}`;
const sumsName = `terraform_${version}_SHA256SUMS`;
const signatureName = `${sumsName}.72D7468F.sig`;
const archivePath = path.join(downloadRoot, selected.name);
const sumsPath = path.join(downloadRoot, sumsName);
const signaturePath = path.join(downloadRoot, signatureName);
const keyPath = path.join(downloadRoot, "hashicorp-pgp-keys.asc");

await Promise.all([
  download(`${releaseBase}/${selected.name}`, archivePath),
  download(`${releaseBase}/${sumsName}`, sumsPath),
  download(`${releaseBase}/${signatureName}`, signaturePath),
  download("https://keybase.io/hashicorp/pgp_keys.asc", keyPath),
]);

const inspectKey = spawnSync(
  "gpg",
  [
    "--batch",
    "--with-colons",
    "--import-options",
    "show-only",
    "--import",
    keyPath,
  ],
  { encoding: "utf8", shell: false },
);
if (
  inspectKey.status !== 0 ||
  !`${inspectKey.stdout}${inspectKey.stderr}`.includes(fingerprint)
) {
  throw new Error(
    "HashiCorp signing key fingerprint verification failed or gpg is unavailable",
  );
}

const importKey = spawnSync(
  "gpg",
  ["--batch", "--homedir", gpgHome, "--import", keyPath],
  {
    encoding: "utf8",
    shell: false,
  },
);
if (importKey.status !== 0) {
  const diagnostic = `${importKey.stderr || importKey.stdout}`
    .replaceAll(backendRoot, "<backend-root>")
    .replace(/[\r\n]+/gu, " ")
    .trim()
    .slice(0, 500);
  throw new Error(
    `HashiCorp signing key import failed (exit ${String(importKey.status)}): ${diagnostic || "no diagnostic output"}`,
  );
}

const verifySignature = spawnSync(
  "gpg",
  ["--batch", "--homedir", gpgHome, "--verify", signaturePath, sumsPath],
  { encoding: "utf8", shell: false },
);
if (verifySignature.status !== 0) {
  throw new Error("Terraform checksum-manifest signature verification failed");
}

const checksumLine = readFileSync(sumsPath, "utf8")
  .split(/\r?\n/u)
  .find((line) => line.endsWith(`  ${selected.name}`));
if (
  checksumLine === undefined ||
  !checksumLine.startsWith(`${selected.sha256}  `)
) {
  throw new Error(
    "official checksum manifest does not match the locked archive SHA",
  );
}

const actualSha = createHash("sha256")
  .update(readFileSync(archivePath))
  .digest("hex");
if (actualSha !== selected.sha256) {
  throw new Error("downloaded Terraform archive checksum mismatch");
}

const extraction =
  platform === "win32"
    ? spawnSync("tar.exe", ["-xf", archivePath, "-C", binRoot], {
        encoding: "utf8",
        shell: false,
      })
    : spawnSync("unzip", ["-q", archivePath, "-d", binRoot], {
        encoding: "utf8",
        shell: false,
      });
if (extraction.status !== 0) {
  throw new Error("Terraform archive extraction failed");
}

const executable = path.join(
  binRoot,
  platform === "win32" ? "terraform.exe" : "terraform",
);
if (!existsSync(executable)) {
  throw new Error("Terraform executable missing after verified extraction");
}
if (platform !== "win32") {
  chmodSync(executable, 0o755);
}

const versionCheck = spawnSync(executable, ["version", "-json"], {
  encoding: "utf8",
  shell: false,
});
if (
  versionCheck.status !== 0 ||
  JSON.parse(versionCheck.stdout).terraform_version !== version
) {
  throw new Error("extracted Terraform version mismatch");
}

if (process.env.GITHUB_PATH !== undefined) {
  appendFileSync(process.env.GITHUB_PATH, `${binRoot}${os.EOL}`);
}

process.stdout.write(`${binRoot}\n`);
