# N2a — Firebase dev preflight, 2026-11-04

**NO-GO for N2b.** Read-only cloud discovery found no active billing account;
the sole visible account is Closed and its free trial has ended. No cloud
resource, billing linkage, API, IAM binding, notification channel or credential
was created or changed. No existing project was selected as the dev target.
The owner controls login/MFA/payment entry and must explicitly approve the
exact N2b package before any cloud mutation. Private account IDs, contact
address and observations are retained outside Git in the chat deliverables.

## Source and local corrections

Isolated branch `codex/n2a-dev-preflight`, based on
`6e7121a17871c7c8ef2a5962981c0a417db2ebd4`. The original detached checkout is
preserved. No push, merge, main-protection change or WIF policy weakening.

- Manifest covers all 47 current code flags: 19 listed default-off and 28
  explicitly excluded from this minimal dev. Checker rejects gaps, unknown
  flags, duplicate/overlapping dispositions and wrong flag kinds. The canonical
  `class_workshop` ID now parses correctly. Exclusions do not implement or
  enable cloud Place/Route/publication adapters.
- Dev-only `execution_operation=plan` accepts a bound, current plan-only owner
  record with read-only access. Default apply mode remains closed; plan output
  does not claim provisioning authority. Other environment roots are unchanged.
- Local apply checkpoint checks exact saved-plan, manifest, full source SHA,
  project, scope, current expiry and forbidden operations. It executes no
  Terraform and cannot prove consent/signature/revocation by itself. Applying
  a saved plan does not re-evaluate the HCL operation variable: actual human
  approval and credential separation remain mandatory.
- `backend-deploy.yml` exists only as a skipped, preparation-only workflow with
  no OIDC/deploy step. This resolves the missing file path, not the executable
  protected-main/WIF gate. Validation CI tests the apply checkpoint with local
  synthetic fixtures and receives no OIDC.
- Dev remains EUR5 with 50/75/90/100 percent notification thresholds. Recovery
  remains disabled; Accepted placement remains eur3/europe-west1/EU. Contact
  addresses are execution inputs outside Git, not metric labels or manifests.

## Read-only cloud boundary

The owner confirmed browser login. Resource Manager listed two pre-existing
projects, neither assigned to this dev. The candidate ID chosen by the operator
passes the UI syntax check, but read-only form validation does not prove global
availability or reserve the ID. The Create button was never submitted.

There is no observed dev project number/resource inventory. Project-scoped
IAM, API enablement, quotas, resource placement, budgets and notification
delivery therefore remain unverified, not passed. The EUR display on the closed
billing account is not an actual-account SKU/tax cost estimate. No supported
monthly cost estimate at or below EUR5 or exact real IaC plan is claimed yet.

Known ADC/Cloud SDK credential-store presence and relevant environment names
were checked without dumping credentials. An existing Firebase CLI config store
was found but not read or used; no service-account key was created. A bounded
pattern scan is not a full credential audit. Browser login is not ADC or
Terraform provider authentication.

## Remaining gates

1. Suitable active billing, with any restoration/payment action kept inside the
   owner-approved N2b package and payment entry performed by the owner.
2. Actual dev project availability/number and inventory, exact permissions/API
   allowlist, scoped operator access and protected state custody.
3. Executable deployment source/protected-main/WIF evidence, without changing
   main protections or pushing/merging under this authorization.
4. Budget channel creation and delivery acknowledged by the owner, backup
   escalation policy, monitoring/containment and recovery evidence.
5. Exact IaC package including bootstrap/project/billing actions; current ordinary
   environment root does not create a project or link billing. Show all unknowns,
   cost estimate, changes and saved-plan digest before asking for one apply.
6. Cloud-capable domain adapters/exports for any future functional object tests;
   local Emulator paths are not silently promoted to cloud runtime.

Local verification outcomes, red attempts and final source hashes are recorded
in the accompanying chat outputs. This document does not change M2/Android
acceptance or close iOS, cloud, stage, production, legal or market gates.
