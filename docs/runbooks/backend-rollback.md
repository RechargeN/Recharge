# Backend rollback (Draft, not executed)

Status: **Draft — never rehearsed.** No rollback is claimed proven until it is
rehearsed on stage (BCK-05 §25). It grants no authority.

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
