# Backend backup, restore and disaster recovery (Draft, not executed)

Status: **Draft.** RPO/RTO and retention are BCK05-OD-05 (Proposed; recommendation in
`docs/product/PRODUCTION_PREP_OWNER_DECISIONS_2026_11_24.md`, D-04).

**Staging fact (RUN-05, 2026-11-24):** PITR, delete protection and a daily backup kept
7 days are on in `recharge-staging-y9y2y` (dev: PITR, no schedule). Drill N4d
(2026-11-16/21, synthetic): PITR clone into an isolated database — data loss 12 s,
13.5 min to a verified state; restore from a scheduled backup — 12 min; after a
restore the Privacy module re-applies erasures to the copy (`admitRestoredCopy`).
Not proven: Auth restore, full RTO, a deletion journal outside the database
(PB-15). Temporary databases are deleted by name after the drill.

## Procedure (when a provisioning slice and OD-05 are accepted)

1. `confirm-protection-enabled` — point-in-time recovery or scheduled backup is on
   for the environment, and its destination is in the declared location.
2. `run-isolated-restore-drill` — restore into an **isolated** target, never over
   live data; a restore-operator identity without cutover rights runs it.
3. `reconcile-restored-data` — compare counts, invariants (for example Booking
   oversell, ledger drift) and privacy state against the source.
4. `record-rpo-rto-evidence` — measured values, dates, owner and limitations.

## Privacy

- A restore must not resurrect deleted or restricted data: after a restore, the
  deletion and restriction records are replayed before any access is reopened.
- Backup and export copies are retained and expired under the accepted retention
  policy; delayed erasure stays visible until proven.

## Gaps stated

The measured RPO/RTO, drill cadence and the specialist privacy/legal verdict are
not available. This runbook is complete only when a drill has passed.
