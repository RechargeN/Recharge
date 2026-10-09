import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

/**
 * F1 Notifications layout gate (NOTIFICATIONS_F1_INBOX_AMENDMENT §10, §16).
 *
 * - the Notifications module has exactly the approved files;
 * - its domain and application layers import no cloud SDK and no other module;
 * - Booking, Identity, Privacy orchestration and the other modules never import
 *   the Notifications module (the privacy runner composition is the only
 *   approved user), so an inbox outage cannot block cancellation, access
 *   recovery or other privacy tasks; Booking reaches only the outbox contract;
 * - Booking transactions never name a Notifications collection;
 * - no push, email or SMS SDK exists anywhere in the Functions source or
 *   dependencies;
 * - Rules deny every Notifications collection explicitly.
 */
const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const src = path.join(backendRoot, "functions", "src");
const moduleRoot = path.join(src, "modules", "notifications");

const approved = [
  "domain/notification_effect.ts",
  "domain/inbox_item.ts",
  "domain/notification_templates.ts",
  "domain/notification_policy.ts",
  "domain/delivery_attempt.ts",
  "domain/repositories.ts",
  "application/consume_notification_effect.ts",
  "application/notification_reconciler.ts",
  "application/notifications_query_handler.ts",
  "application/notifications_command_handler.ts",
  "application/notifications_privacy_task_handler.ts",
  "infrastructure/firestore_notifications_repository.ts",
  "infrastructure/firestore_notification_sources.ts",
  "infrastructure/in_memory_notifications_repository.ts",
].sort();

function walk(directory) {
  return readdirSync(directory).flatMap((name) => {
    const full = path.join(directory, name);
    return statSync(full).isDirectory() ? walk(full) : [full];
  });
}

const relative = (file) => path.relative(src, file).replaceAll("\\", "/");
const problems = [];

if (!existsSync(moduleRoot)) problems.push("modules/notifications is absent");
else {
  const actual = walk(moduleRoot)
    .map((file) => path.relative(moduleRoot, file).replaceAll("\\", "/"))
    .sort();
  if (JSON.stringify(actual) !== JSON.stringify(approved))
    problems.push(
      `unexpected Notifications module files: ${actual.join(", ")}`,
    );
}
for (const required of [
  "notifications_entry.ts",
  "notifications/outbox.ts",
  "booking/notification_effects.ts",
])
  if (!existsSync(path.join(src, required)))
    problems.push(`missing ${required}`);

const importsOf = (source) =>
  [...source.matchAll(/(?:from|import)\s*\(?\s*['"]([^'"]+)['"]/gu)].map(
    (match) => match[1],
  );
const cloud = /^(?:firebase-admin|firebase-functions|@google-cloud)/u;
// The only cross-module read: Identity account status for recipient eligibility.
const identityAccounts =
  "../../identity_publisher/infrastructure/firestore_identity_authority_repository.js";

for (const file of existsSync(moduleRoot) ? walk(moduleRoot) : []) {
  const layer = path.relative(moduleRoot, file).split(path.sep)[0];
  const source = readFileSync(file, "utf8");
  for (const specifier of importsOf(source)) {
    if (layer !== "infrastructure" && cloud.test(specifier))
      problems.push(`${relative(file)} imports cloud SDK ${specifier}`);
    if (
      layer === "domain" &&
      specifier.startsWith(".") &&
      !specifier.startsWith("./")
    )
      problems.push(
        `${relative(file)} (domain) imports outside its layer: ${specifier}`,
      );
    if (layer === "application" && /\/infrastructure\//u.test(specifier))
      problems.push(
        `${relative(file)} (application) imports infrastructure: ${specifier}`,
      );
    const ownLayers = [
      "./",
      "../domain/",
      "../application/",
      "../infrastructure/",
      "../../../shared/",
    ];
    if (
      specifier.startsWith(".") &&
      !ownLayers.some((prefix) => specifier.startsWith(prefix)) &&
      !(layer === "infrastructure" && specifier === identityAccounts)
    )
      problems.push(`${relative(file)} imports another module: ${specifier}`);
  }
}

// Approved users of the Notifications module outside it.
const allowedUsers = new Map([
  ["notifications_entry.ts", null],
  ["index.ts", ["./notifications_entry.js"]],
  [
    "modules/privacy_orchestration/application/privacy_domain_task_runner.ts",
    [
      "../../notifications/application/notifications_privacy_task_handler.js",
      "../../notifications/domain/repositories.js",
      "../../notifications/infrastructure/firestore_notifications_repository.js",
    ],
  ],
]);
for (const file of walk(src)) {
  const name = relative(file);
  if (name.startsWith("modules/notifications/") || !name.endsWith(".ts"))
    continue;
  const source = readFileSync(file, "utf8");
  const specifiers = importsOf(source).filter(
    (specifier) =>
      /modules\/notifications\/|notifications_entry/u.test(specifier) ||
      (/^\.\.?\/(?:\.\.\/)*notifications\//u.test(specifier) &&
        !specifier.endsWith("notifications/outbox.js")),
  );
  if (specifiers.length === 0) continue;
  const allowed = allowedUsers.get(name);
  if (allowed === undefined) {
    problems.push(
      `${name} must not import the Notifications module: ${specifiers.join(", ")}`,
    );
    continue;
  }
  if (allowed !== null)
    for (const specifier of specifiers)
      if (!allowed.includes(specifier))
        problems.push(
          `${name} imports an unapproved Notifications path: ${specifier}`,
        );
}

// Booking reaches only the outbox contract and never names inbox state.
const notificationCollections = [
  "notificationInboxItems",
  "notificationEffectReceipts",
  "notificationDeliveryAttempts",
  "notificationPreferences",
  "notificationCommandReceipts",
  "notificationReconcileCheckpoints",
];
for (const directory of [
  "booking",
  "modules/identity_publisher",
  "audit",
  "inventory",
  "policy",
]) {
  const root = path.join(src, directory);
  if (!existsSync(root)) continue;
  for (const file of walk(root)) {
    const source = readFileSync(file, "utf8");
    for (const collection of notificationCollections)
      if (source.includes(collection))
        problems.push(
          `${relative(file)} names Notifications state ${collection}`,
        );
  }
}

// No push, email or SMS provider anywhere.
const providers =
  /firebase-admin\/messaging|getMessaging\s*\(|nodemailer|@sendgrid|twilio|mailgun|postmark|@aws-sdk\/client-s(?:es|ns)|node-apn|apn2|web-push/u;
for (const file of walk(src))
  if (providers.test(readFileSync(file, "utf8")))
    problems.push(`${relative(file)} references a push, email or SMS provider`);
const pkg = JSON.parse(
  readFileSync(path.join(backendRoot, "functions", "package.json"), "utf8"),
);
for (const dependency of Object.keys({
  ...pkg.dependencies,
  ...pkg.devDependencies,
}))
  if (providers.test(dependency))
    problems.push(`package.json depends on ${dependency}`);

const rules = readFileSync(path.join(backendRoot, "firestore.rules"), "utf8");
for (const collection of notificationCollections)
  if (
    !rules.includes(
      `match /${collection}/{document} { allow read, write: if false; }`,
    )
  )
    problems.push(`Rules lack the explicit deny for ${collection}`);

if (problems.length > 0) {
  throw new Error(
    `Notifications layout gate failed:\n- ${problems.join("\n- ")}`,
  );
}
process.stdout.write(
  `Notifications layout gate passed: ${approved.length} module files, no cloud SDK in domain/application, no Booking/Identity/Privacy dependency on the inbox, no push/email/SMS provider, ${notificationCollections.length} explicit Rules denies.\n`,
);
