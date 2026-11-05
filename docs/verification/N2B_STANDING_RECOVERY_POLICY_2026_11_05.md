# N2b standing recovery policy, owner revision 2026-11-05

Google-enabled API dependencies of approved services/Firebase registration and Google system service-agent roles are observed/evidenced/allowlisted and do not block N2b. No separate unreviewed billable resource creation or grants to user-controlled principals follow from this exception. Hard stops: paid resources beyond plan, basic roles except owner, roles on non-Google principals, billing drift, destroy/replace, state migration error. Refreshed plan may create only remaining approved addresses and update existing managed resources within the same package. Email acknowledgement plus real matching budget PubSub message still gates ordinary resources.

Live recovery readback: cloudbilling.googleapis.com activation completed after the previous interruption. Same new EUR billing linkage, Editor absent, only owner and two accepted Compute system-agent bindings. Compute VM/disk/address/network inventory empty. ServiceUsage audit proves telemetry activation in the same CrossLoggingResponse as Logging and Monitoring; recorded in observed allowlist. No API is disabled to force agreement with a static list.

Credential revision: ADC stays only in private-gcloud, not copied/printed/Git. One owner login lasts through N2b; revoke once at completion or 2026-11-08T23:59:00Z, whichever first. Google-required interactive login/MFA stays in Google UI. Credentials may be used only for this N2b dev project and read-only checks of the selected new billing account; old projects/account remain untouched. Prior per-window revocation instructions are superseded.

This changes execution policy/evidence only, not product runtime, billing thresholds, resources, WIF trust or Accepted ADRs. No push/merge.
