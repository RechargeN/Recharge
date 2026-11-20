import { pathToFileURL } from "node:url";

// Round 2.1 (owner approval 2026-11-18): an Operations emergency switch in dev
// or staging. Pure: it only builds the next revision and pointer documents
// (same shape as the Operations console writes) for an operator runner that
// commits them with a precondition on the current pointer. Production and
// unknown projects are refused; nothing here talks to a cloud.

export const projects = Object.freeze({
  "recharge-dev-n2a01": "dev",
  "recharge-staging-y9y2y": "stage",
});
export const revisionCollection = "platformFeatureFlagRevisions";
export const pointerCollection = "platformActiveFeatureFlagPointers";
const switchIdShape = /^[a-zA-Z][a-zA-Z0-9.-]{2,120}$/u;

/**
 * @param {{project: string, switchId: string, state: "open" | "contained",
 *   pointer?: {activeRevision?: number, pointerRevision?: number} | null,
 *   nowUtc: string, decisionId: string}} input
 */
export function nextSwitchDocuments(input) {
  const environmentId = projects[input.project];
  if (!environmentId) throw new Error("switch_project_refused");
  if (!switchIdShape.test(input.switchId)) throw new Error("switch_id_invalid");
  if (input.state !== "open" && input.state !== "contained")
    throw new Error("switch_state_invalid");
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/u.test(input.nowUtc))
    throw new Error("switch_time_invalid");
  if (!/^[A-Za-z0-9_-]{8,80}$/u.test(input.decisionId))
    throw new Error("switch_decision_invalid");
  const key = `${environmentId}:LV:${input.switchId}`;
  const current = input.pointer?.activeRevision;
  const revision =
    Number.isSafeInteger(current) && current > 0 ? current + 1 : 1;
  const pointerRevision = Number.isSafeInteger(input.pointer?.pointerRevision)
    ? input.pointer.pointerRevision + 1
    : 1;
  return {
    key,
    revisionPath: `${revisionCollection}/${key}:${revision}`,
    pointerPath: `${pointerCollection}/${key}`,
    revision: {
      schemaVersion: 1,
      revision,
      environmentId,
      marketId: "LV",
      capabilityId: input.switchId,
      // An emergency switch is "enabled" when it contains.
      enabled: input.state === "contained",
      createdAtUtc: input.nowUtc,
      decisionId: input.decisionId,
    },
    pointer: { key, activeRevision: revision, pointerRevision },
  };
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try {
    const input = JSON.parse(process.argv[2] ?? "");
    process.stdout.write(JSON.stringify(nextSwitchDocuments(input)) + "\n");
  } catch (error) {
    process.stderr.write(
      `${error instanceof Error ? error.message : "switch_input_invalid"}\n`,
    );
    process.exitCode = 1;
  }
}
