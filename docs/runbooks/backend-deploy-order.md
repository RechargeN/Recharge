# Backend deploy order (Draft, not executed)

Status: **Draft — written from the accepted OD-07 topology, never executed.** It
grants no authority: no project, resource or deployment exists and nothing here
may be run until a provisioning slice is separately approved (BCK-05 §36).

## Preconditions (all must hold, for one final SHA)

1. One final commit SHA: every check below refers to it; any later edit means a
   new SHA and a full re-run.
2. A verified release artifact and its provenance exist for that SHA; nothing is
   rebuilt for another environment.
3. A verified owner authorization record for the target environment names the
   exact execution-manifest hash (`config/manifests/execution-manifest.json`).
   Check its source, expiry/revocation, approved operations and saved-plan digest
   again immediately before apply; a reference/hash alone is not approval.
4. Environment-specific credentials come only from that environment workload
   identity; no long-lived key is used.

## N4a (2026-11-13): staging is no longer only a draft

The owner approved N4a: one immutable release candidate (`apps/backend/scripts/build-release-candidate.mjs`,
schema `apps/backend/config/release-candidate.schema.json`) is deployed first to dev, then to
`recharge-staging-y9y2y`. The staging ownership root is `infra/terraform/bootstrap/stage` (a reviewed copy of
the dev bootstrap); `check-n4a-plan.mjs` refuses any plan with update/delete, a foreign project, a delete
permission, automatic deletion, a basic role, a public member, a budget other than €5 or Cloud Run beyond 0..1.
Functions entries bind to the reviewed project list in `functions/src/shared/cloud_runtime_projects.ts`
(dev and staging; production is never listed). Production stays closed; Emulator data is never copied.

## Order

1. `verify-single-final-sha` — the SHA under deployment equals the verified one.
2. `verify-release-artifact-and-provenance` — digest and manifest match.
3. `check-authorization-record` — record present, hash equal, environment equal.
4. `terraform-plan-reviewed` — a human reviews the plan of **that environment
   root only** (`apps/backend/infra/terraform/envs/<env>`); any surprise stops.
5. `terraform-apply-by-authorized-slice` — only inside the approved slice, by the
   environment deploy identity, with its own state bucket.
6. `firebase-deploy-rules-indexes-ttl` — Firebase CLI from the artifact. Indexes
   are built before Functions that need them go live.
7. `firebase-deploy-functions` — all risky flags stay **off**.
8. `smoke` — see the list in the manifest: functions discoverable, Rules default
   deny, Booking flags off, no public Storage access, budget route present.
9. `observe` — watch the agreed signals before any flag is turned on.

Read-only inspection and active smoke are distinct scopes, defined in
`backend-provisioning-and-destroy.md`. Reading a budget channel is not a successful
delivery test. The checked-in Draft manifest blocks execution; this ordering is
not an executable approval or a claim that the deployment runner exists.

## Rules

- dev, stage and prod never share state, rights or parameters.
- Promotion goes dev, then stage, then prod with the same artifact.
- A failed, skipped or manually asserted step is inconclusive and stops the order.
- Flags are turned on only by the rollout process, never as part of a deploy.

## Final R1-staging pass (2026-11-19/20): what the deploy order must include

Learned on dev and staging; every item cost a failed end-to-end run once.

1. **Switches before code.** In the cloud a missing Operations switch is contained (round 2.1). A new
   worker is deployed contained and opened afterwards with `n4x_switch.py open <env> <switchId>`; the
   privacy runtime has a deploy switch instead (`N5D_PRIVACY_ENABLED`, part of the owner deploy record,
   remembered by the runner and changed only with `N5D_PRIVACY=on|off`), because a new Operations switch
   would change the pinned execution manifest.
2. **Indexes before the workers that query them.** The Booking composite indexes (`bookings`,
   `bookingProjectionDeliveries`, `bookingReconfirmationDeadlineJobs`) were never deployed and the
   5-minute delivery worker failed with `FAILED_PRECONDITION`. Deploy indexes from the repository file
   restricted to the needed groups plus every group already deployed; Firebase never deletes an index
   without `--force`. The cloud refuses a one-field composite (`bookings occurrenceId`); the deploy filters
   it, the file is pinned by the execution manifest and is not edited.
3. **Firestore triggers need `roles/run.invoker` for their own runtime account on exactly their Cloud
   Run services** (check-n4c-plan round 3). Without it Eventarc retries with 403 and nothing is delivered;
   a 200 from a trigger proves nothing until the effect is read back.
4. **Product feature flags are Emulator-only** (`FirestoreFeatureFlagGate` is false outside the Emulator).
   A cloud worker must take its gate from its Operations switch, or it answers 200 and does nothing.
5. **Benign CLI exits:** `deploy_end exit 1` with "could not set up cleanup policy" after every
   function reports success; "Failed to list functions" before anything is deployed is transient — retry.
   Any "Failed to create function" stops the runner.
6. **After the deploy, prove the effect**: one synthetic or owner action end to end, read back from
   Firestore and the request log (probes 401 and a clean IAM check are necessary, not sufficient).
