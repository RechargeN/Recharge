# N2b recovery read-only evidence, 2026-11-05

STOP: project IAM contains an unapproved roles/editor binding on the default Compute service account. No IAM change, default-network deletion, import, refresh plan or apply was performed in this recovery window. Temporary ADC revoked, exit0/file absent. This is not completed recovery.

ServiceUsage audit proves google provider7.43.0 enabled compute.googleapis.com as part of the previous google_project operation (Terraform1.15.9 user agent). The same activation operation CrossLoggingResponse lists compute, backupdr, oslogin and servicenetworking. The owner's conditional API exception is therefore satisfied; these four APIs are recorded in bootstrap/dev/provider-side-effects.allowlist.json as observed side effects, not new google_project_service resources. None was disabled/re-enabled. This exception does not grant Editor or other IAM roles.

Successful full Compute list responses: zero networks, subnetworks, firewalls, routes, VMs, disks and reserved addresses. Five DONE/error-free operations from the previous attempt show deletion of default-allow-icmp/default-allow-internal/default-allow-rdp/default-allow-ssh and networks/default. No further deletion required or attempted. These operations completed before the prior ADC revocation; this closes the earlier uncertainty without retroactively treating resource-plan0destroy as proof of no internal provider deletions.

IAM readback includes roles/owner on owner principal, roles/compute.instanceGroupManagerServiceAgent on the Google APIs service agent, roles/compute.serviceAgent on Compute system service agent, and roles/editor on default Compute SA. No bindings were altered. Additional service-managed roles are recorded as observations, not approved grants.

New billing account remains open/EUR, only exact dev project linked, billingEnabled=true. Budget list could not be verified: Billing Budgets API returned403 requiring a quota project for user ADC. No quota project was set or API enabled to bypass this. No assertion of zero budgets follows from the403.

State remains unchanged: only existing terraform_data.review_guard, project absent; stale lock preserved. Original plan remains void. The proposed automatic-apply criterion would also need explicit review if a later real plan shows27creates because review_guard already exists; never remove that state object merely to force28creates.

Raw evidence is private outside Git; redacted user-facing evidence and report reside in task outputs. No account/principal personal email is committed. Original tracked Terraform/manifest resource configuration unchanged; no push/merge. Recovery is blocked pending a separately reviewed disposition of unapproved IAM roles and quota-project needs. No new approval question is issued here.
