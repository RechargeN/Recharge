# H — Reviews and rating projection: eligibility blocker

Current status: Superseded for the bounded local slice by the owner decision of 2026-10-15.
See [REVIEWS_H_LOCAL_SLICE_SPEC.md](REVIEWS_H_LOCAL_SLICE_SPEC.md) and [accepted local policy](REVIEWS_TRUST_SAFETY_LOCAL_OWNER_POLICY.md).
The text below is the historical pre-decision blocker snapshot, not current runtime status.


Status: Blocked (policy), 2026-10-15. Owner requested H after K1.
This records the required policy-first branch of task 23, not a delivered Reviews runtime.

## Evidence

USER_LIBRARY_REVIEWS_BACKEND_SPEC.md §10 explicitly calls the eligibility rules
candidate rules pending owner acceptance. §31 lists BCK12-OD-01/02/03/04/07
as blocking decisions. No Accepted review eligibility owner decision was found
in the current repository's ADR/owner-decision/amendment documents.

Booking creation does not prove participation. A self-reported Visit is not
trusted attendance evidence. Neither grants a verified badge.
Existing G persistence does not upgrade either fact into eligibility evidence.

## Disabled behavior

No review submission command/callable, review edit/delete lifecycle, rating writer
or rating rebuild worker has been added or enabled. Source inspection found no
backend review submission surface in src/index.ts and no end-user review-submit
repository/controller in mobile. Existing display/demo rating fields are not a
server-authoritative projection. K1 reports do not silently create a Reviews owner.

## Unblock requirements

Record accepted policy revision, reviewable targets and ownership exclusions;
rating scale and text limits; eligible evidence issuers and verification;
edit/delete/visibility lifecycle and moderation; fixed-point aggregation,
freshness and reproducible rebuild rules. Specify K1 report linkage to exact
review revisions. Trusted evidence must be verified by its owner, not a client claim.

Only then implement the conditional H lifecycle/projection scope and its tests.
No arbitrary evidence kind, edit window, numerical rating policy or badge was invented.
Rollback: documentation-only; runtime behavior unchanged.
