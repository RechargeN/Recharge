import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { stageRuntime as stageIdentity } from "./package-n2c-identity-runtime.mjs";
import { stageRuntime as stageContentMedia } from "./package-n3a2-content-media-runtime.mjs";
import { stageRuntime as stageNotifications } from "./package-n3c-notifications-runtime.mjs";
import { reviewedProjects } from "./runtime-projects.mjs";

// N4a (owner-approved 2026-11-13): the immutable release candidate. Source
// digests come from Git objects at the source commit (identical on Windows
// and Linux checkouts); codebase digests from the staged files that are
// deployed. Local only: no network, Firebase CLI or cloud call; nothing secret.
const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "..",
);

/** Index groups deployed to cloud projects (no TTL field overrides, D-07). */
export const deployedIndexGroups = Object.freeze([
  "contentEffects",
  "contentPublishedRevisions",
  "contentSubmissions",
  "notificationInboxItems",
]);
export const lockfilePaths = Object.freeze([
  "apps/backend/functions/package-lock.json",
  "apps/backend/n2c-identity-runtime/package-lock.json",
  "apps/backend/n3a2-content-media-runtime/package-lock.json",
  "apps/backend/n3c-notifications-runtime/package-lock.json",
  "apps/backend/infra/terraform/bootstrap/dev/.terraform.lock.hcl",
  "pubspec.lock",
]);

function git(root, args) {
  const result = spawnSync("git", ["-C", root, ...args], {
    encoding: "buffer",
    maxBuffer: 256 * 1024 * 1024,
  });
  if (result.status !== 0)
    throw new Error(
      `git ${args[0]} failed: ${result.stderr.toString().trim()}`,
    );
  return result.stdout;
}

const sha256 = (data) => createHash("sha256").update(data).digest("hex");

/** Digest of a committed path: every blob id under it at the commit. */
export function gitTreeDigest(root, sha, relPath) {
  const listing = git(root, [
    "ls-tree",
    "-r",
    "--full-tree",
    sha,
    "--",
    relPath,
  ])
    .toString("utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [meta, name] = line.split("\t");
      return `${meta.split(" ")[2]} ${name}`;
    })
    .sort();
  if (listing.length === 0)
    throw new Error(`nothing committed under ${relPath}`);
  return {
    root: relPath,
    treeSha256: sha256(listing.join("\n")),
    files: listing.length,
  };
}

export function gitBlobSha256(root, sha, relPath) {
  return sha256(git(root, ["cat-file", "blob", `${sha}:${relPath}`]));
}

function gitText(root, sha, relPath) {
  return git(root, ["cat-file", "blob", `${sha}:${relPath}`]).toString("utf8");
}

function match(text, pattern, what) {
  const found = text.match(pattern);
  if (!found) throw new Error(`toolchain pin not found: ${what}`);
  return found[1];
}

export function toolchainAt(root, sha) {
  return {
    node: match(
      gitText(root, sha, ".github/workflows/backend-r0.yml"),
      /node-version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)/u,
      "node",
    ),
    terraform: match(
      gitText(root, sha, "apps/backend/scripts/install-terraform.mjs"),
      /const version = "([0-9]+\.[0-9]+\.[0-9]+)"/u,
      "terraform",
    ),
    googleProvider: match(
      gitText(
        root,
        sha,
        "apps/backend/infra/terraform/bootstrap/dev/.terraform.lock.hcl",
      ),
      /provider "registry\.terraform\.io\/hashicorp\/google" \{\s*version\s*=\s*"([0-9.]+)"/u,
      "google provider",
    ),
    firebaseTools: match(
      gitText(root, sha, "apps/backend/functions/package-lock.json"),
      /"node_modules\/firebase-tools": \{\s*"version": "([0-9.]+)"/u,
      "firebase-tools",
    ),
    flutter: match(
      gitText(root, sha, ".github/workflows/backend-r1.yml"),
      /flutter-version:\s*"?([0-9]+\.[0-9]+\.[0-9]+)/u,
      "flutter",
    ),
  };
}

/** Stages the three Functions codebases with inert placeholders; .env is not in the digest. */
export function codebaseDigests(functionsRoot) {
  const dir = mkdtempSync(path.join(tmpdir(), "recharge-rc-"));
  const uid = "rcplaceholderuid0000000000";
  try {
    const out = {};
    for (const [name, stage, extra] of [
      ["n2c-identity", stageIdentity, { appId: "1:420479958348:android:0" }],
      ["n3a2-content-media", stageContentMedia, { allowedUids: [uid] }],
      ["n3c-notifications", stageNotifications, { allowedUids: [uid] }],
    ]) {
      const manifest = stage({
        outDir: path.join(dir, name),
        runtimeEnabled: false,
        ...extra,
        ...(functionsRoot ? { functionsRoot } : {}),
      });
      out[name] = {
        entry: manifest.entry,
        codeTreeSha256: manifest.codeTreeSha256,
        files: manifest.files.length - 1, // without the per-project .env
      };
    }
    return out;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

export function buildReleaseCandidate({
  root = repoRoot,
  sourceSha,
  mediaToolsDigest,
  now = new Date(),
  targets = [...reviewedProjects],
  codebases,
}) {
  if (!/^[0-9a-f]{40}$/u.test(sourceSha ?? ""))
    throw new Error("sourceSha required");
  if (!/^sha256:[0-9a-f]{64}$/u.test(mediaToolsDigest ?? ""))
    throw new Error("media-tools image digest required");
  if (targets.some((target) => !reviewedProjects.includes(target)))
    throw new Error("only reviewed non-production projects are targets");
  const stamp = now.toISOString().replace(/\.[0-9]{3}Z$/u, "Z");
  return {
    schemaVersion: 1,
    releaseCandidateId: `RC-${stamp.slice(0, 10).replaceAll("-", "")}-${sourceSha.slice(0, 7)}`,
    sourceSha,
    createdAtUtc: stamp,
    targets,
    production: false,
    contracts: gitTreeDigest(root, sourceSha, "packages/api_contracts/schema"),
    config: {
      executionManifestSha256: gitBlobSha256(
        root,
        sourceSha,
        "apps/backend/config/manifests/execution-manifest.json",
      ),
      firestoreRulesSha256: gitBlobSha256(
        root,
        sourceSha,
        "apps/backend/firestore.rules",
      ),
      firestoreIndexesSha256: gitBlobSha256(
        root,
        sourceSha,
        "apps/backend/firestore.indexes.json",
      ),
      deployedIndexGroups: [...deployedIndexGroups],
      ttlFieldOverrides: "not-deployed",
    },
    reference: gitTreeDigest(
      root,
      sourceSha,
      "packages/api_contracts/schema/reference_data/v1/artifacts",
    ),
    toolchain: toolchainAt(root, sourceSha),
    lockfiles: lockfilePaths.map((relPath) => ({
      path: relPath,
      sha256: gitBlobSha256(root, sourceSha, relPath),
    })),
    artifacts: {
      ...(codebases ?? codebaseDigests()),
      "media-tools": { imageDigest: mediaToolsDigest },
    },
    notices: { noticeSha256: gitBlobSha256(root, sourceSha, "NOTICE.md") },
  };
}

/** Recompute everything except the creation time; returns the differences. */
export function verifyReleaseCandidate(
  rc,
  { root = repoRoot, codebases } = {},
) {
  let fresh;
  try {
    fresh = buildReleaseCandidate({
      root,
      sourceSha: rc.sourceSha,
      mediaToolsDigest: rc.artifacts?.["media-tools"]?.imageDigest,
      now: new Date(rc.createdAtUtc),
      targets: rc.targets,
      codebases,
    });
  } catch (error) {
    return [`release candidate cannot be rebuilt: ${error.message}`];
  }
  const errors = [];
  for (const key of Object.keys(fresh))
    if (JSON.stringify(fresh[key]) !== JSON.stringify(rc[key]))
      errors.push(`${key} differs from the source commit`);
  for (const key of Object.keys(rc))
    if (!(key in fresh)) errors.push(`unexpected field ${key}`);
  return errors;
}

function cleanHead(root) {
  const head = git(root, ["rev-parse", "HEAD"]).toString("utf8").trim();
  const dirty = git(root, ["status", "--porcelain"]).toString("utf8").trim();
  if (dirty !== "") throw new Error("worktree is not clean");
  return head;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const args = process.argv.slice(2);
  try {
    if (args[0] === "--verify") {
      const rc = JSON.parse(readFileSync(args[1], "utf8"));
      const head = cleanHead(repoRoot);
      const errors = verifyReleaseCandidate(rc);
      if (head !== rc.sourceSha)
        errors.unshift("HEAD is not the release candidate commit");
      if (errors.length > 0) {
        process.stderr.write(
          `release candidate refused:\n- ${errors.join("\n- ")}\n`,
        );
        process.exitCode = 1;
      } else
        process.stdout.write(
          `${rc.releaseCandidateId} verified at ${rc.sourceSha}\n`,
        );
    } else {
      const digest = args[args.indexOf("--media-tools-digest") + 1];
      const out = args[args.indexOf("--out") + 1];
      if (!args.includes("--media-tools-digest") || !args.includes("--out"))
        throw new Error(
          "usage: --media-tools-digest sha256:<hex> --out <file> | --verify <file>",
        );
      const rc = buildReleaseCandidate({
        sourceSha: cleanHead(repoRoot),
        mediaToolsDigest: digest,
      });
      writeFileSync(out, JSON.stringify(rc, null, 2) + "\n");
      process.stdout.write(`${rc.releaseCandidateId} -> ${out}\n`);
    }
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
