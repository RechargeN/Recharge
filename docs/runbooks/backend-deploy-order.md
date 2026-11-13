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
