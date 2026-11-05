# N2b — bounded dev bootstrap review, 2026-11-05

Local preparation only. No cloud write, deployment, acceptance-status change, push or merge. Source baseline 6e7121a; previous local preparations fe3e842/7921bf5. This document replaces the earlier five blockers for this **infrastructure-only** scope; it does not close platform/runtime gates.

## Delivery criteria (owner revision)

Before ordinary resources: (a) exact Monitoring email channel enabled/configuration read back, a real test notification received and explicitly acknowledged by RechargeN; (b) budget connected to dedicated Pub/Sub topic, a real Cloud Billing budget update pulled from its subscription. A zero-cost budget update is valid; no threshold event required. (c) first real 50% threshold email is confirmed when actual usage reaches EUR2.50; remains Pending until then, never simulated by spending or lowering the budget.

The graph contains an email channel, a narrowly filtered log-based alert policy, budget, EU-persisted topic, 24-hour-retention subscription, and a topic-scoped publisher binding for billing-budget-alerts@system.gserviceaccount.com. No public or project-wide publisher binding. Monitoring test uses exactly one synthetic Logging entry after separate future package approval. It does not claim proof of budget-threshold email delivery.

Receipt v2 binds project/budget/channel/topic/subscription. It requires actual owner acknowledgement reference, configuration readback, raw Pub/Sub message, correct billingAccountId/budgetId/schemaVersion1.0 attributes, budgetAmount5/EUR/display name, message ID and timestamp. Polling gate reads local evidence only and cannot send mail or fabricate acknowledgement. Budget updates may take hours; up to 24h wait, then fail closed. Ordinary resources depend on the gate. Receipt provenance remains a human/operator trust boundary, not a cryptographic attestation; private artifacts stay outside Git. No self-published test messages qualify.

## Exact proposed actions and authority boundaries

1. Create only selected recharge-dev candidate project, no default VPC, deletion protection. Link only it to the separately verified new active EUR account. Old account/projects excluded.
2. Enable cost-control API allowlist: billingbudgets, monitoring, serviceusage, cloudresourcemanager, pubsub, logging (.googleapis.com). Create channel/budget/topic/subscription/publisher binding/test alert policy. Read back budget EUR5 and 50/75/90/100% thresholds and exact project filter.
3. Send one Logging entry: logName projects/<exact-project>/logs/dev-budget-channel-test; resource global; jsonPayload.kind=n2b-email-delivery-probe plus nonsecret synthetic run ID. Pull up to 10 Pub/Sub messages without automatic acknowledgement, retain raw evidence privately; validate the matching budget update. Acknowledge only the matching message after storing evidence. No manual publish, data seed, read of unrelated logs or projects. Receive owner acknowledgement of actual email. Write private receipt only after both criteria pass.
4. After gate: state bucket EU, ordinary API allowlist firestore/storage/iam/firebase, Firebase registration with google-beta7.43.0, Firestore Native(default) eur3/PITR/deletion protected, private media STANDARD europe-west1, recovery disabled, three SAs without keys or IAM grants, disabled WIF scaffold. No Functions/build/deployment/Auth/provider activation or data writes. Firebase registration is not removable from a project; destruction is not a rollback option. Service-managed identities/internal notification rules may be created by enabled services; reconcile, never grant them unreviewed privileges. Unexpected resources/APIs/roles beyond documented service-managed effects => stop.
5. Read-only reconcile actual resources, Firebase registration, API list, IAM policies including service-managed grants, budget config, bucket privacy/locations/versioning, Firestore PITR/location, WIF disabled. Record project number and actual resource names; do not infer them from plan unknowns.
6. Approved state migration: retain encrypted/access-restricted local state and hash/lineage/serial/resource-address inventory first; copy tracked backend.tf.example to ignored backend.tf; init -migrate-state with exact dev state bucket and prefix terraform/bootstrap/dev. No force-copy or state push. Verify GCS state lineage/serial/addresses match preserved local state. On failure stop, preserve both copies; never apply another root or re-create resources. Migration is an explicit extra command in the approved package, not covered by saved resource-plan bytes alone.
7. Read-only smoke only. Stop after evidence, revoke temporary ADC immediately after the approved execution window. Future IAM/runtime/release work is separate.

## Permissions requested for future package, not granted now

Owner principal only, no permanent role grants to Codex or runtime SAs. Existing owner needs project create/get, project billing assign/update plus billing.accounts.get and billing.resourceAssociations.create on selected new account; billing.budgets create/get/list/update; serviceusage.services enable/get/list; monitoring notificationChannels create/get/list and alertPolicies create/get/list; logging.notificationRules.create (internal log-alert integration), logging.logEntries.create for the one synthetic entry; pubsub topics/subscriptions create/get/list, topic getIamPolicy/setIamPolicy, subscriptions.consume/acknowledge for matching evidence; firebase.projects.update/get and resourcemanager.projects.update for Firebase registration; datastore.databases.create/get/list/update; storage.buckets.create/get/list/update and objects get/create/list for **state only**; iam.serviceAccounts create/get/list and workloadIdentityPools/providers create/get/list. No service-account-key creation, organization-policy change, project-wide IAM binding, production permission or billing detach. Terraform may need additional API-specific read permissions: any failure is reviewed, never solved by silently granting Owner or broadening scope.

## Checkpoints and rollback

Plan record permits only plan. Saved Terraform binary is technically applicable by anyone with sufficient cloud credentials: output apply_authorized=false is informational. Before future apply, verify actual human consent, current full source SHA/manifest digest, saved-plan SHA256 and unexpired **separate apply record** using verify-dev-apply-approval.mjs; inspect serialized plan independently with check-dev-bootstrap-plan.mjs and exact reviewed inventory digest. Fail closed on any mismatch, foreign project, mutation/replacement/delete, key resource, unexpected address or enabled/weakened WIF. Never apply a .void plan. No unattended auto-apply or credentials in Git.

If email/message/ack is absent, wait ends with gate error; cost controls may exist, ordinary resources must not. Terraform can finish independent cost-control branches despite an error; reconcile actual partial state, preserve it, do not retry apply outside approved reviewed behavior. If a later operation fails, stop workload and retain state/resources/budget; no destroy/data deletion/billing detach. Reconcile and review a new plan before repair. PITR is protection, not proof of restore; clone/recovery/restore and drills remain separate approvals.

## Scope disposition of previous blocker 5

Protected-main executable deployment/WIF remains a **runtime/release follow-up**, outside this bootstrap. Trust condition false/provider disabled, no principal bindings, workflow inert. No main-gate weakening or claim that deployment is ready. All 47 code flags have dev disposition and no runtime is deployed. iOS/other platform gates remain open for their scopes; Android evidence is not transferred to iOS. RechargeN is sole Finance/Incident/IAM owner; no independent backup contact is invented. Bootstrap operations stop while owner is unavailable; unattended traffic/operations are prohibited until a real backup escalation owner is appointed. This is a bounded single-owner bootstrap limitation, not evidence of redundant incident coverage.

SLO/error-budget/burn targets in N1 remain design requirements for future eligible runtime traffic. No service telemetry or SLO attainment is claimed from empty infra. Kill-switch for this scope: stop synthetic operator operations; keep budget/email/PubSub/audit/state intact, no automatic billing detach. Runtime flag propagation/recovery must be tested in a separate runtime slice before traffic.

## Cost model

User-facing N2B-COST-500-SYNTHETIC.md/json computes EUR3.52025/month under explicitly assumed rates/workload/tax contingency, not an EUR SKU quote or guarantee. Includes eur3 data/indexes+PITR, europe-west1 media and retained copies, EU versioned state, operations/egress/logging/PubSub and reserves. 500 business objects total +4500 auxiliary docs, no runtime/Maps/SMS/AI. Actual EUR SKU and volume reconciliation required before workload; exceeding envelope stops optional operations, never deletes data.

## Primary references

- https://firebase.google.com/docs/projects/terraform/get-started
- https://registry.terraform.io/providers/hashicorp/google-beta/7.43.0/docs/resources/firebase_project
- https://docs.cloud.google.com/billing/docs/how-to/budgets-programmatic-notifications
- https://docs.cloud.google.com/logging/docs/alerting/log-based-alerts
- https://cloud.google.com/firestore/pricing
- https://cloud.google.com/storage/pricing
