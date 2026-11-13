# Operational recovery (L2, local/Emulator only)

Status: **Draft, local/Emulator only.** Contract and registry:
[OPS-L2](../product/OPERATIONS_L2_RECOVERY_AMENDMENT.md). No cloud worker,
callable, UI or production operator identity exists (OB-01); every step below
runs through `createEmulatorOperationsConsole` in a test or stand script.

## Who may act

Only an operator with a current Session and an entry in the test-only server
registry `operationsOperatorAuthority` for the exact family and action:
`ops.inspect`, `ops.replay`, `ops.reconcile`, `ops.disable`, `ops.enable`,
`ops.restore`. Each call is audited in `operationsOperatorAudit` in the same
transaction as the authorization; if the audit or the registry cannot be read
or written, nothing happens (`audit_or_authority_unavailable`). Source-data
repair is never done here: it is a K3 proposal, approval and owner execution.

## 1. Something is stuck or failing

1. `inspect(operator, family, taskId)` — state (`pending`, `in_flight`,
   `unknown`, `retry_scheduled`, `done`, `dead_letter`), attempts and budget,
   failure class and code, the first failure and the bounded history. No
   payload or personal data is shown.
2. `unknown` means an attempt started and its lease expired without a result.
   Do not treat it as failed or done: run reconciliation (step 3) or let the
   next attempt run; both read the owner receipt first.
3. `reconcile(operator, 'TF-01')` — bounded pages from its own checkpoint;
   `repaired` lists what the owner path fixed, `findings` what is still open.
   Run it again until `cycleCompleted`; a repeated run creates no new effect.
   TF-03 reconciliation is the F1 reconciler (`reconcile(operator, 'TF-03')`).

## 2. A dead letter

- `permanent` (`permanent_rejection` on replay): the payload or record cannot
  succeed. Repair the source through K3; the producer then emits a new fact
  under a new key. Never edit the task.
- `transient` or `unknown`: `replay(operator, family, taskId, decision)` with
  a short reason code. The replay keeps the original failure, attempts and
  history and grants five more attempts (TF-01/02) or one more budget (TF-03,
  at most three replays). The same `decisionId` returns its stored result.
- `payload_changed`: the source no longer matches the task digest. Stop and
  investigate; the old key is not reused for a new payload.
- `family_contained`: the family is disabled; re-enable first (section 3).

Replay never bypasses the owner: current revisions, recipient restriction,
DSR tombstones and holds are checked by the owner when the task runs, so an
erased subject yields `suppressed`/`superseded`, not a new effect.

## 3. Emergency disable and re-enable

- `setContainment(operator, family, true, decision)` (`ops.disable`) writes a
  new immutable revision of the family switch (`*.incidentDisable`) and moves
  its pointer, audited in the same transaction.
- Dispatch and the effect transaction both read the switch; queued work stays
  and no attempt is spent. Confirmed effects are not undone.
- In-flight limits: TF-01 finishes the lifecycle page already running
  (≤ 200 bookings); TF-03 may finish a Tx2 started before the switch (OB-08);
  TF-04…07 finish their current bounded run. Reconcile afterwards.
- An unreadable or malformed switch counts as disabled.
- Re-enable needs `ops.enable` and a current Session; it reopens dispatch only.
  Privacy deletion (TF-08, TF-10, TF-11) has no switch by contract.

## 4. Restore (admission only)

There is no backup or PITR runtime (OB-04) and no cutover (OB-06). For a copy
already placed in an **isolated named database**:

1. `admitRestore(operator, { restored, liveDatabaseId, restoreStartedAtUtc,
   authority, redeletion })` (`ops.restore`).
2. `closed: deletion_authority_unavailable` — the deletion authority failed or
   answered for a moment before the restore began. Keep the copy closed.
3. `closed: redeletion_failed` — a decision could not be re-applied. Closed.
4. `incomplete` — every decision re-applied, but L1 keeps blocked or held
   records (PB codes). Not admitted.
5. `admitted` — every erasure and restriction re-applied through the L1
   runner bound to the copy. Cutover is still a separate, absent step.

A check on a synthetic snapshot is not a restore of a production backup.
