import { createHash } from "node:crypto";
import { readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";

// N4a (owner-approved 2026-11-13): the reviewed non-production projects one
// release candidate is deployed to. Mirrors
// functions/src/shared/cloud_runtime_projects.ts (a unit test keeps them equal);
// production is never listed.
export const devProject = "recharge-dev-n2a01";
export const stagingProject = "recharge-staging-y9y2y";
export const reviewedProjects = Object.freeze([devProject, stagingProject]);
const knownNumbers = Object.freeze({ [devProject]: "420479958348" });

export function isReviewedProject(value) {
  return reviewedProjects.includes(value);
}

/** dev's number is fixed; staging's must be given (digits) and is written to its .env. */
export function resolveProjectNumber(projectId, configured) {
  if (!isReviewedProject(projectId))
    throw new Error(`unreviewed project ${projectId}`);
  const known = knownNumbers[projectId];
  if (configured === undefined || configured === null || configured === "") {
    if (known === undefined)
      throw new Error(`project number required for ${projectId}`);
    return known;
  }
  if (!/^[0-9]{6,20}$/u.test(configured) || (known && configured !== known))
    throw new Error(`invalid project number for ${projectId}`);
  return configured;
}

/** The deploy .env line staging needs (dev keeps its fixed number, no line). */
export function projectNumberEnvLines(projectId, projectNumber) {
  return knownNumbers[projectId] === undefined
    ? [`RECHARGE_PROJECT_NUMBER=${projectNumber}`]
    : [];
}

export function envFileFor(projectId) {
  if (!isReviewedProject(projectId))
    throw new Error(`unreviewed project ${projectId}`);
  return `.env.${projectId}`;
}

/**
 * The release-candidate digest of a staged codebase: every file except
 * node_modules, the stage manifest and the per-project .env, so dev and
 * staging stages of one RC have the same value.
 */
export function codeTreeDigest(stageDir) {
  const files = [];
  const walk = (dir) => {
    for (const name of readdirSync(dir).sort()) {
      const full = path.join(dir, name);
      const rel = path.relative(stageDir, full).split(path.sep).join("/");
      if (
        rel === "node_modules" ||
        rel === "stage-manifest.json" ||
        /^\.env\./u.test(rel)
      )
        continue;
      if (statSync(full).isDirectory()) walk(full);
      else
        files.push({
          name: rel,
          sha256: createHash("sha256").update(readFileSync(full)).digest("hex"),
        });
    }
  };
  walk(stageDir);
  files.sort((a, b) => a.name.localeCompare(b.name));
  return createHash("sha256").update(JSON.stringify(files)).digest("hex");
}

/** CLI: target project from STAGE_PROJECT_ID / STAGE_PROJECT_NUMBER (default dev). */
export function cliTarget(environment) {
  const projectId = environment.STAGE_PROJECT_ID || devProject;
  return {
    projectId,
    projectNumber: resolveProjectNumber(
      projectId,
      environment.STAGE_PROJECT_NUMBER,
    ),
  };
}
