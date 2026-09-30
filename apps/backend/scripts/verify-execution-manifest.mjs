import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { Ajv2020 } from "../functions/node_modules/ajv/dist/2020.js";
import addFormats from "../functions/node_modules/ajv-formats/dist/index.js";

const backendRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const repoRoot = path.resolve(backendRoot, "..", "..");
const configRoot = path.join(backendRoot, "config");

const readJson = (file) => JSON.parse(readFileSync(file, "utf8"));

function createValidator() {
  const ajv = new Ajv2020({ allErrors: true, strict: true });
  addFormats(ajv);
  ajv.addSchema(readJson(path.join(configRoot, "budget-policy.schema.json")));
  ajv.addSchema(readJson(path.join(configRoot, "flag-policy.schema.json")));
  return ajv.compile(
    readJson(path.join(configRoot, "execution-manifest.schema.json")),
  );
}

/** Facts the manifest must agree with; read from the repository, never assumed. */
function repositoryFacts() {
  const rules = readFileSync(path.join(backendRoot, "firestore.rules"), "utf8");
  const denied = new Set(
    [
      ...rules.matchAll(
        /match \/([A-Za-z0-9]+)\/\{document\} \{ allow read, write: if false; \}/gu,
      ),
    ].map((match) => match[1]),
  );
  const indexes = readJson(path.join(backendRoot, "firestore.indexes.json"));
  const ttl = new Map();
  for (const item of indexes.fieldOverrides ?? [])
    if (item.ttl === true)
      ttl.set(item.collectionGroup, [
        ...(ttl.get(item.collectionGroup) ?? []),
        item.fieldPath,
      ]);
  const composite = new Map();
  for (const item of indexes.indexes)
    composite.set(item.collectionGroup, [
      ...(composite.get(item.collectionGroup) ?? []),
      item.fields.map((field) => `${field.fieldPath}:${field.order}`),
    ]);
  const flagSource = readFileSync(
    path.join(backendRoot, "functions", "src", "shared", "feature_flags.ts"),
    "utf8",
  );
  const idsOf = (name) => {
    const block = new RegExp(
      `export const ${name} = Object\\.freeze\\(\\{([\\s\\S]*?)\\}\\);`,
      "u",
    ).exec(flagSource);
    return [...(block?.[1] ?? "").matchAll(/'([a-z][A-Za-z0-9.]*)'/gu)].map(
      (match) => match[1],
    );
  };
  return {
    denied,
    ttl,
    composite,
    features: [...idsOf("bookingFlagIds"), ...idsOf("identityFlagIds")],
    emergency: idsOf("abuseEmergencySwitchIds"),
    region: readJson(path.join(configRoot, "region-policy.schema.json"))
      .properties,
  };
}

const requiredNeverBlocked = [
  "booking.cancel",
  "privacy.dsr.export",
  "privacy.dsr.deletion",
  "privacy.dsr.restriction",
];
const requiredFirebaseCliOwned = [
  "firestore.rules",
  "firestore.indexes",
  "firestore.ttl",
  "functions.deployment",
];
/**
 * Emergency switches an operation depends on, directly or through reaching its
 * session: cancelling an existing Booking needs the cancel and query paths and a
 * usable session, so none of these may be part of cost containment.
 */
const blockingSwitches = {
  "booking.cancel": [
    "booking.cancel.incidentDisable",
    "booking.query.incidentDisable",
    "identity.session.issue.incidentDisable",
    "identity.session.rotate.incidentDisable",
  ],
};
const guardrails = { dev: 25, stage: 75, prod: 150 };
const secretLike =
  /-----BEGIN|AIza[0-9A-Za-z_-]{20,}|gh[pousr]_[0-9A-Za-z]{20,}|\.iam\.gserviceaccount\.com|@[a-z0-9-]+\.[a-z]{2,}/u;

/** Returns every problem found; empty means the manifest is consistent. */
export function verifyExecutionManifest(manifest, facts = repositoryFacts()) {
  const problems = [];
  const validate = createValidator();
  if (!validate(manifest))
    problems.push(
      `schema: ${JSON.stringify(validate.errors?.slice(0, 5) ?? [])}`,
    );
  if (manifest?.environments === undefined || manifest.firestore === undefined)
    return problems;

  // ---- collections, indexes and TTL equal the repository
  const listed = manifest.firestore.collections.map((item) => item.name);
  if (new Set(listed).size !== listed.length)
    problems.push("collections: duplicate name");
  for (const name of listed)
    if (!facts.denied.has(name))
      problems.push(`collections: ${name} has no explicit Rules deny`);
  for (const name of facts.denied)
    if (!listed.includes(name))
      problems.push(`collections: ${name} is denied in Rules but not listed`);
  for (const name of [...facts.ttl.keys(), ...facts.composite.keys()])
    if (!listed.includes(name))
      problems.push(
        `collections: ${name} has an index or TTL but is not listed`,
      );
  for (const item of manifest.firestore.collections) {
    const ttl = [...(facts.ttl.get(item.name) ?? [])].sort();
    if (JSON.stringify([...item.ttlFields].sort()) !== JSON.stringify(ttl))
      problems.push(`collections: ${item.name} TTL fields differ from indexes`);
    const composite = (facts.composite.get(item.name) ?? [])
      .map((fields) => fields.join(","))
      .sort();
    const declared = item.compositeIndexes
      .map((fields) => fields.join(","))
      .sort();
    if (JSON.stringify(declared) !== JSON.stringify(composite))
      problems.push(
        `collections: ${item.name} indexes differ from firestore.indexes.json`,
      );
  }

  // ---- flags equal the code registry and default off
  const flagIds = manifest.flags.flags.map((item) => item.id);
  const registry = [...facts.features, ...facts.emergency];
  if (
    JSON.stringify([...flagIds].sort()) !== JSON.stringify([...registry].sort())
  ) {
    // A reduced fixture may list a subset, never an unknown flag.
    for (const id of flagIds)
      if (!registry.includes(id))
        problems.push(`flags: ${id} is not in the code registry`);
  }
  for (const item of manifest.flags.flags) {
    if (item.defaultState !== "off")
      problems.push(`flags: ${item.id} does not default off`);
    const emergency = facts.emergency.includes(item.id);
    if ((item.kind === "emergencySwitch") !== emergency)
      problems.push(`flags: ${item.id} has the wrong kind`);
  }

  // ---- locations equal the accepted region policy
  const policy = manifest.locationPolicy;
  if (
    policy.firestore.location !== facts.region.firestoreLocation.const ||
    policy.functions.region !== facts.region.functionsRegion.const ||
    policy.mediaStorage.location !== facts.region.storageRegion.const ||
    policy.recoveryStorage.location !== facts.region.exportLocation.const
  )
    problems.push("locations: differ from the accepted region policy");

  // ---- identities, per environment
  const allowedShared = new Set(["backup-operator", "restore-operator"]);
  for (const [env, item] of Object.entries(manifest.environments)) {
    if (item.logicalId !== env) problems.push(`${env}: logicalId mismatch`);
    const names = item.serviceAccounts.map((account) => account.name);
    if (new Set(names).size !== names.length)
      problems.push(`${env}: duplicate service account`);
    for (const account of item.serviceAccounts) {
      const ok =
        account.name === `deploy-${env}` ||
        (account.kind === "runtime" &&
          /^runtime-[a-z][a-z0-9-]*$/u.test(account.name)) ||
        allowedShared.has(account.name);
      if (!ok)
        problems.push(
          `${env}: ${account.name} is not in the identity catalogue`,
        );
      if (account.kind === "deploy" && account.name !== `deploy-${env}`)
        problems.push(`${env}: a deploy identity of another environment`);
    }
    if (!names.includes(`deploy-${env}`))
      problems.push(`${env}: no deploy identity`);
    for (const other of Object.keys(guardrails))
      if (other !== env && names.includes(`deploy-${other}`))
        problems.push(`${env}: holds deploy-${other}`);
    if (item.projectId !== null || item.projectIdSuffix !== null)
      problems.push(`${env}: a provider project id is invented`);

    // ---- budget and containment
    const budget = item.budget;
    if (
      budget.guardrailMonthlyEur !== guardrails[env] ||
      budget.status !== "proposed"
    )
      problems.push(
        `${env}: budget differs from the proposed BCK05-OD-04 baseline`,
      );
    if (
      JSON.stringify(budget.thresholdsPercent) !==
      JSON.stringify([50, 75, 90, 100])
    )
      problems.push(`${env}: budget thresholds`);
    for (const need of requiredNeverBlocked)
      if (!budget.containment.neverBlocked.includes(need))
        problems.push(`${env}: neverBlocked lacks ${need}`);
    for (const id of budget.containment.killSwitchIds) {
      if (!facts.emergency.includes(id))
        problems.push(`${env}: unknown kill switch ${id}`);
      for (const protectedOperation of budget.containment.neverBlocked)
        if (
          id.startsWith(`${protectedOperation}.`) ||
          id === protectedOperation ||
          (blockingSwitches[protectedOperation] ?? []).includes(id)
        )
          problems.push(
            `${env}: kill switch ${id} can block ${protectedOperation}`,
          );
    }
  }

  // ---- ownership: exactly one owner per resource, Firebase CLI owns the fixed set
  const seen = new Map();
  for (const item of manifest.resourceOwners) {
    if (seen.has(item.resource))
      problems.push(`owners: ${item.resource} has two entries`);
    seen.set(item.resource, item.owner);
  }
  for (const resource of requiredFirebaseCliOwned)
    if (seen.get(resource) !== "firebase_cli")
      problems.push(`owners: ${resource} must be owned by the Firebase CLI`);

  // ---- no secret, address or invented project id anywhere in the text
  const text = JSON.stringify(manifest);
  if (secretLike.test(text))
    problems.push("content: a secret-like or address-like value is present");
  for (const match of text.matchAll(
    /(recharge-(?:dev|stage|prod)-[a-z0-9]{3,})/gu,
  ))
    problems.push(
      `content: ${match[1]} looks like an invented provider project id`,
    );

  // ---- runbooks exist
  for (const runbook of manifest.procedures.runbooks)
    if (!existsSync(path.join(repoRoot, runbook)))
      problems.push(`runbooks: ${runbook} is absent`);
  return problems;
}

function main() {
  const validate = createValidator();
  const manifest = readJson(
    path.join(configRoot, "manifests", "execution-manifest.json"),
  );
  const problems = verifyExecutionManifest(manifest);
  const valid = readJson(
    path.join(configRoot, "manifests", "fixtures", "valid.json"),
  );
  for (const [index, fixture] of valid.manifests.entries())
    if (!validate(fixture))
      problems.push(`valid fixture ${String(index)} rejected`);
  for (const file of ["invalid.json", "forward.json"])
    for (const item of readJson(
      path.join(configRoot, "manifests", "fixtures", file),
    ).cases)
      if (validate(item.value))
        problems.push(`${file}: "${item.reason}" was accepted`);
  if (problems.length > 0) {
    process.stderr.write(
      `Execution manifest gate failed:\n- ${problems.join("\n- ")}\n`,
    );
    process.exitCode = 1;
    return;
  }
  process.stdout.write(
    `Execution manifest gate passed: ${String(manifest.firestore.collections.length)} collections, ${String(manifest.flags.flags.length)} flags, three environments, no project id, secret or authority.\n`,
  );
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) main();
