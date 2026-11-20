import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

// Owner decision 2026-11-08: one confirmed delivery test covers a working week
// (was 24 hours), so repeated cloud runs do not each wait for a new e-mail.
export const receiptValidityMs = 7 * 24 * 60 * 60 * 1000;

/** N4a: dev and the reviewed staging project; the names carry their prefix. */
function environmentPrefix(projectId) {
  if (/^recharge-dev-[a-z0-9]{4,20}$/u.test(projectId ?? "")) return "dev";
  if (projectId === "recharge-staging-y9y2y") return "stage";
  return null;
}

export function inspectReceipt(query, receipt, now = new Date()) {
  const prefix = environmentPrefix(query.projectId);
  if (prefix === null) return false;
  if (
    !query.channelName?.startsWith(
      `projects/${query.projectId}/notificationChannels/`,
    )
  )
    return false;
  if (!/^billingAccounts\/[^/]+\/budgets\/[^/]+$/u.test(query.budgetName ?? ""))
    return false;
  const message = receipt?.budgetMessage;
  let payload;
  try {
    payload = JSON.parse(
      Buffer.from(message?.data ?? "", "base64").toString("utf8"),
    );
  } catch {
    return false;
  }
  const parts = query.budgetName.split("/");
  if (
    message?.attributes?.billingAccountId !== parts[1] ||
    message?.attributes?.budgetId !== parts[3] ||
    message?.attributes?.schemaVersion !== "1.0" ||
    message?.messageId !== receipt?.budgetMessageId ||
    message?.publishTime !== receipt?.budgetMessagePublishedAtUtc ||
    payload?.currencyCode !== "EUR" ||
    payload?.budgetAmount !== 5 ||
    payload?.budgetDisplayName !== `budget-guardrail-${prefix}`
  )
    return false;
  const time = Date.parse(receipt?.deliveredAtUtc);
  return (
    receipt?.schemaVersion === 2 &&
    receipt.projectId === query.projectId &&
    receipt.budgetName === query.budgetName &&
    receipt.channelName === query.channelName &&
    query.topicName ===
      `projects/${query.projectId}/topics/${prefix}-budget-events` &&
    query.subscriptionName ===
      `projects/${query.projectId}/subscriptions/${prefix}-budget-evidence` &&
    receipt.topicName === query.topicName &&
    receipt.subscriptionName === query.subscriptionName &&
    receipt.budgetPubsubMessageVerified === true &&
    typeof receipt.budgetMessageId === "string" &&
    receipt.budgetMessageId.trim().length > 0 &&
    typeof receipt.budgetMessageEvidenceRef === "string" &&
    receipt.budgetMessageEvidenceRef.trim().length > 0 &&
    Number.isFinite(Date.parse(receipt.budgetMessagePublishedAtUtc)) &&
    Date.parse(receipt.budgetMessagePublishedAtUtc) <= now.getTime() &&
    now.getTime() - Date.parse(receipt.budgetMessagePublishedAtUtc) <=
      receiptValidityMs &&
    receipt.budgetConfigurationVerified === true &&
    receipt.channelDeliveryVerified === true &&
    receipt.ownerAcknowledged === true &&
    typeof receipt.ownerAckEvidenceRef === "string" &&
    receipt.ownerAckEvidenceRef.trim().length > 0 &&
    receipt.testKind === "monitoring-channel-delivery" &&
    Number.isFinite(time) &&
    time <= now.getTime() &&
    now.getTime() - time <= receiptValidityMs
  );
}

// Pure local receipt reader. No SDK, HTTP, subprocess, email or cloud mutation.
// Plan mode never waits or writes. Apply mode may wait up to 24 hours for
// the operator to record the owner's real acknowledgement of the shown test.
if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try {
    let input = "";
    for await (const chunk of process.stdin) input += chunk;
    const query = JSON.parse(input);
    const applying = process.env.N2B_EXECUTION_PHASE === "apply";
    const deadline = Date.now() + (applying ? 86_400_000 : 0);
    let passed = false;
    do {
      try {
        passed = inspectReceipt(
          query,
          JSON.parse(readFileSync(query.receiptPath, "utf8")),
        );
      } catch {
        /* absent or incomplete receipt stays closed */
      }
      if (passed || Date.now() >= deadline) break;
      await new Promise((resolve) => setTimeout(resolve, 1000));
    } while (true);
    process.stdout.write(
      JSON.stringify({
        status: passed
          ? "delivered-and-owner-acknowledged"
          : "blocked-awaiting-real-delivery-and-owner-ack",
      }),
    );
  } catch {
    process.stdout.write(JSON.stringify({ status: "blocked-invalid-input" }));
  }
}
