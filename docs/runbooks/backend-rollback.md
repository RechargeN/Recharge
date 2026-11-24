# Backend rollback (Draft, not executed)

Status: **Draft — partially rehearsed.** No rollback is claimed proven until it is
rehearsed on stage (BCK-05 §25). It grants no authority.

**Staging fact (RUN-02, 2026-11-24):** 2026-11-17 a rollback of Booking code and of
the media image was checked. 2026-11-20 a repeat was cancelled: rolling back to a
version without Privacy would delete functions. Release candidates older than
`d09afb8d` have a sign-in defect, so the earliest safe rollback target is a
candidate at or after `d09afb8d`. A full rehearsal is planned with the owner
(runbooks README, rehearsal 3.5).

## Order (fastest safe action first)

1. `disable-flags` — turn the affected flags off. This stops new risky behaviour
   without changing data. Cancelling an existing Booking and mandatory privacy
   operations must keep working.
2. `reselect-previous-release-pointer` — point back to the previous compatible
   release revision (pointers are revision-fenced; a stale pointer fails closed).
3. `redeploy-previous-artifact` — the previous **verified** artifact through the
   normal deploy order; never a rebuild.
4. `verify-smoke` — the smoke list of the manifest.
5. `record-decision` — who, when, why, which SHA.

## Data

- A schema or data migration is not undone by redeploying code. Data repair is a
  separate, reviewed procedure with its own evidence; never an ad hoc script.
- Rejected, quarantined or restricted content is never made public merely because
  code or configuration rolled back.

## Not allowed

- Disabling billing to stop an incident (it can destroy data).
- Editing generated files or release manifests by hand.
