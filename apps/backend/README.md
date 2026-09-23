# Recharge backend — local platform and bounded domain foundations

Status: **local R1 platform, Reference Data, Security/Privacy and an in-memory
Identity/Publisher authority; all cloud and market activation disabled**.

R1 adds a provider-neutral local platform skeleton on top of the retained R0
and disabled RAW-C compatibility evidence. It contains typed logical
environments, immutable release/config revisions, optimistic activation
pointers, default-deny security ports, bounded telemetry and in-memory
adapters. It does not add or activate a product domain.

The BCK-20 foundation adds immutable, schema-validated LV/EE/LT market
configuration, explicit locale fallback outcomes, currency and IANA-timezone
contracts, mandatory-copy and source-eligibility gates, and compatible
activation-pointer rollback. Its data is synthetic, each market is isolated,
and every capability remains disabled. No external dataset is imported.

The BCK-04 local foundation adds server-resolved actor/session/market/workspace
checks, default-deny authentication and capability decisions, App Check and
rate-limit ports, privacy-safe audit/redaction controls, data-class/access/
retention registries, unavailable-by-default age policy, emergency-disable
flags and an in-memory DSR task lifecycle. It stores no secret values, chooses
no numeric age, performs no physical deletion and exposes no client or cloud
handler.

The BCK-06 local slice adds provider-neutral Google/Apple assertion ports,
hashed provider-subject linking, Account and Session authority with revocation
fences, Creator and ManagedPage verification lifecycles, exact-page membership,
fresh AccessSnapshot evaluation and ID-based PublisherRef eligibility. It is
in-memory and test-only: no OAuth credential, Firebase Auth adapter, Firestore
repository, callable export or production grant exists.

## Safety boundary

- project identity is always `demo-recharge`;
- no `.firebaserc`, cloud credential, OIDC, service-account key or secret;
- no Firebase/Google project creation, API enablement, billing or deployment;
- no Terraform backend, stateful resource, plan or apply;
- Firestore and Storage client access deny all;
- R1 has no Function export; the existing R0 plus five disabled RAW-C exports
  remain unchanged and refuse non-emulator use;
- all `local/dev/stage/prod` identities are logical and `unbound`;
- every market, capability, feature flag and release is `disabled`;
- Terraform has no resources, backend, real project or credential input;
- `apps/mobile` does not depend on this package.

Any command requesting login, a real project, credentials, billing or deploy
is a boundary failure and must stop.

## Exact toolchain

The authoritative pins live in `toolchain.lock.json`. Required hosts:

- Node.js 22.23.2 / npm 10.9.8;
- Eclipse Temurin 21.0.12+8;
- Terraform 1.15.9;
- Windows x64 or Linux x64.

Do not substitute a global Firebase CLI or floating tool version.

## Local verification

From `apps/backend/functions`:

```text
npm ci --ignore-scripts
npm run verify:cloud-context
npm run verify:toolchain
npm run format:check
npm run lint
npm run typecheck
npm run test:unit
npm run test:contract
npm run test:emulator
npm run verify:generated
npm run verify:reproducibility
npm run verify:r1:layout
npm run verify:r1:config
npm run verify:r1:exports
npm run test:r1
npm run test:r1:emulator
npm run test:reference-data
npm run test:security-privacy
npm run test:identity-publisher
```

From `apps/backend/infra/terraform`, after the verified R0 Terraform installer:

```text
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate -no-color
```

The exact R1 collection families are `platformReleaseManifests`,
`platformActiveReleasePointers`, `platformFeatureFlagRevisions`,
`referenceMarketConfigRevisions` and `referenceActivationPointers`. Direct
client access is denied. Only the local Emulator/Admin test context may write
synthetic records, and every test removes them.

Future Identity collections are also enumerated in `firestore.rules` as
explicit client deny-all. They have no Firestore repository or index; the
current Identity authority exists only inside the local composition root.

A missing exact tool, network outage or command that did not execute is
`Inconclusive`, never Pass. Current hosted parity and Moderate transitive
advisory disposition remain open. See
`docs/evidence/backend/r0/BCK-R0-TCH-01_RESULT.md`.
