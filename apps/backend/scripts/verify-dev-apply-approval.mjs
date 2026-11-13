import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

// This is a fail-closed local checkpoint, not a Terraform executor or signature
// verifier. The operator must also verify actual owner approval/provenance and
// short-lived exact-project credentials before any apply. Never trust a label
// such as approved supplied by an untrusted file without that human evidence.
export function verifyDevApplyApproval({
  approval,
  planBytes,
  manifestBytes,
  commitSha,
  projectId,
  now = new Date(),
}) {
  const problems = [];
  if (!/^recharge-dev-[a-z0-9]{4,20}$/u.test(projectId ?? ""))
    problems.push("exact dev project required");
  if (!/^[a-f0-9]{40}$/u.test(commitSha ?? ""))
    problems.push("full commit SHA required");
  if (approval?.schemaVersion !== 1 || approval?.status !== "approved")
    problems.push("approved versioned record required");
  if (approval?.environment !== "dev" || approval?.projectId !== projectId)
    problems.push("environment/project mismatch");
  if (approval?.commitSha !== commitSha) problems.push("source mismatch");
  if (approval?.manifestSha256 !== sha256(manifestBytes))
    problems.push("manifest mismatch");
  if (approval?.savedPlanSha256 !== sha256(planBytes))
    problems.push("saved plan mismatch");
  if (
    !Array.isArray(approval?.operations) ||
    !approval.operations.includes("apply") ||
    approval.operations.some((op) => !["plan", "apply"].includes(op))
  )
    problems.push("apply operation required; unrelated operations forbidden");
  for (const field of ["owner", "ownerApprovalEvidenceRef", "recordRef"])
    if (typeof approval?.[field] !== "string" || !approval[field].trim())
      problems.push(`${field} required`);
  if (approval?.dataScope !== "synthetic")
    problems.push("synthetic scope required");
  for (const field of [
    "push",
    "merge",
    "marketActivation",
    "destroy",
    "serviceAccountKeyCreation",
  ])
    if (approval?.[field] !== false) problems.push(`${field} must be denied`);
  const issued = Date.parse(approval?.issuedAtUtc);
  const expires = Date.parse(approval?.expiresAtUtc);
  if (
    !Number.isFinite(now.getTime()) ||
    !Number.isFinite(issued) ||
    !Number.isFinite(expires) ||
    issued > now.getTime() ||
    expires <= now.getTime() ||
    expires <= issued
  )
    problems.push("record not currently valid");
  return problems;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  const [approvalFile, planFile, manifestFile, commitSha, projectId] =
    process.argv.slice(2);
  if (process.argv.length !== 7) {
    process.stderr.write(
      "Usage: node verify-dev-apply-approval.mjs <approval.json> <saved.tfplan> <manifest.json> <full-sha> <dev-project-id>\n",
    );
    process.exitCode = 1;
  } else {
    try {
      const problems = verifyDevApplyApproval({
        approval: JSON.parse(readFileSync(approvalFile, "utf8")),
        planBytes: readFileSync(planFile),
        manifestBytes: readFileSync(manifestFile),
        commitSha,
        projectId,
      });
      if (problems.length) {
        process.stderr.write(
          `Apply checkpoint denied: ${problems.join("; ")}\n`,
        );
        process.exitCode = 1;
      } else
        process.stdout.write(
          "Local apply-record bindings verified; no Terraform/cloud command executed. Verify actual owner approval, revocation and credentials separately.\n",
        );
    } catch {
      process.stderr.write(
        "Apply checkpoint denied: missing or unreadable input.\n",
      );
      process.exitCode = 1;
    }
  }
}
