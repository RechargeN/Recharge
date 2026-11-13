# H/K2 — accepted local product policy
Status: Approved for bounded local/Emulator implementation, owner decision 2026-10-15.
Source: owner's explicit six-part decision in this chat. This supplements, not silently
changes, the canonical BCK-12 and BCK-22 drafts. It is not production/legal approval.

H: authenticated personal users may review public Places. Event/Activity require a
noncancelled owner Booking and its server occurrence start in the past. Booking
confers permission, never attendance proof; Activity without a supported Booking owner
record fails closed. Exclude own/published/administered objects and owned/managed Pages.
One stable review per user/object; rating 1–5, optional text <=1000 Unicode code points;
edit/delete anytime, edited marker, immediate visibility. No badge or trusted attendance.
Deleted reviews retain a uniqueness tombstone; resubmission reuses the same review ID.
Moderator hide/restore applies to an exact review revision. Complaint alone has no effect.
Projection uses integer distribution/count/sum, fixed-point average only for >=3 visible
reviews; deterministic rebuild from current review state, not client ratings.

K2: directional mute hides eligible posts/reviews/new-publication notifications from
its owner; block prevents bilateral profile/post/people discovery and contact/invites/
mentions. Blocked author's events leave the viewer's feed but public event direct links
remain available. Existing bookings, cancellation/refunds, and service/safety notices
remain unaffected by either relation. Unsupported surfaces stay unavailable rather than
pretending to enforce a relation.

Sanctions: warning, hide, temporary restrictions of 7 or 30 days, permanent ban; ladder
is guidance, not a prerequisite. Human decisions only. Only a trusted owner grant can
issue permanent ban. Other staff reversible effects only. No automated containment.
Exact scope, reasons, notices, policy version, idempotency and revisions are mandatory.
One appeal per decision, available for at least six calendar months; seven days is a
response target, not legal compliance evidence. Independent reviewer where available;
self-review fails closed in this local slice. Reverse through owning services without
removing other holds. Abuse controls never auto-sanction.

16+ is a product threshold. DOB is self-declared, never trusted age evidence. Age-sensitive
access stays disabled without accepted server authority. Labels/organizer entry checks
do not grant access. Per-market age/legal qualification and DSA applicability remain
separate. No production registration or age-sensitive path is activated by this decision.

Rollback: disable independent runtime flags; preserve audit/receipts; reverse domain
effects through commands, never delete records to compensate. No push/deploy authorization.
