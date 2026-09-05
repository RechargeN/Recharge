# Recharge backend — R0 toolchain scaffold

Status: **local R0 scaffold operational; Amendments Required before R0 Pass;
no product/cloud backend**.

This directory exists only to prove the approved BCK-R0-TCH-01 v0.2 local
toolchain and Firebase Emulator Suite boundary. It contains no Booking, Event,
identity, profile, notification, payment or other Recharge domain behavior.

## Safety boundary

- project identity is always `demo-recharge`;
- no `.firebaserc`, cloud credential, OIDC, service-account key or secret;
- no Firebase/Google project creation, API enablement, billing or deployment;
- no Terraform backend, stateful resource, plan or apply;
- Firestore and Storage client access deny all;
- the sole Function refuses non-emulator execution;
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
```

From `apps/backend/infra/terraform`, after the verified R0 Terraform installer:

```text
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate -no-color
```

A missing exact tool, network outage or command that did not execute is
`Inconclusive`, never Pass. Current hosted parity and Moderate transitive
advisory disposition remain open. See
`docs/evidence/backend/r0/BCK-R0-TCH-01_RESULT.md`.
