# Backend backup, restore and disaster recovery (Draft, not executed)

Status: **Draft.** RPO/RTO and retention are BCK05-OD-05 (Proposed); no
protection or restore runtime exists. Nothing here is evidence.

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
