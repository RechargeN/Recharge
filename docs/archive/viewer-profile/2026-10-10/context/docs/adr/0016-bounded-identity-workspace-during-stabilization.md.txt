# ADR 0016: Bounded Identity And Workspace Implementation During Stabilization

- Status: Accepted
- Date: 2026-07-31
- Deciders: Recharge team
- Supersedes: ADR 0015 section 7 only for the bounded local/mock slices defined
  here
- Related: ADR 0013, ADR 0015,
  `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md`

## Context

ADR 0015 accepted the target identity and publisher model but deferred all
implementation until stabilization exit. The product now needs the local
account/workspace foundation to evaluate the approved personal Creator and
multi-page Professional Page experience before production backend integration.

The required behavior crosses auth, profile/settings, app-shell navigation and
Create publisher defaults. An unrestricted exception would undermine the
active stabilization gate, while continuing to represent Creator and
`Pro generator` as manually switched UI tiers contradicts the accepted target
model.

## Decision

The following bounded Identity/Workspace implementation slices may run during
stabilization:

1. **IDP-03A — local access and workspace foundation**
   - explicit mock Admin role and admin capabilities;
   - explicit verified-Creator demo state and personal Creator grants;
   - local/mock `ManagedPage` and `ManagedPageMembership` contracts;
   - exact page-scoped capabilities;
   - `WorkspaceRef {type: personal | page, id}`;
   - owner-namespaced active-workspace preference;
   - Settings `Switch workspace` between `Personal profile` and authorized
     Professional Pages;
   - safe fallback to personal workspace when a page is missing, suspended or
     revoked.
2. **IDP-04A — workspace-aware presentation and local publisher defaults**
   - personal Viewer and Creator share
     `Home / Favorites / Smart Search / Notifications / Profile`;
   - Professional Page uses
     `Page / Content / Create / Notifications / Account`;
   - Creator tools appear from verified eligibility and grants without a
     manual Viewer/Creator switch;
   - active workspace supplies the default `PublisherRef` only for a new
     local draft;
   - switching workspace never silently rewrites an existing draft publisher;
   - page content surfaces remain scoped to the exact active page.
3. **IDP-05A — bounded local guards and Admin entry**
   - UI, router and application guards use explicit capabilities;
   - Admin tools are a separate protected surface, never a workspace or
     publisher;
   - existing local moderation tools may be linked when their exact capability
     is present;
   - negative tests cover forged/stale workspace, cross-page leakage, revoked
     membership and Admin-without-capability cases.

These slices implement local/mock product behavior only. Mock state is test
data, not verification or production authority. Role alone never authorizes
personal publishing, page publishing or Admin operations.

### Stabilization gates remain mandatory

Every bounded slice must:

- use the accepted architecture layers and cross-feature contracts;
- preserve unrelated working-tree changes;
- include unit and widget coverage proportional to its scope;
- keep all ten Create types compatible where a shared publisher contract is
  touched;
- pass `flutter analyze` and `flutter test`;
- pass repository boundary and diff checks;
- update `LAUNCH_STATUS.md` with exact evidence and remaining gates;
- remain independently reviewable and reversible.

Failure of a bounded slice does not relax stabilization acceptance. It returns
to Doing or is rolled back without disabling the existing personal consumer
flow.

## Explicitly Not Authorized

This ADR does not authorize:

- Firebase configuration, adapters, Rules, Functions or production cutover;
- production Google/Apple migration or removal of the current mock session;
- collection, upload or review of real identity documents;
- real Creator or Professional Page verification decisions;
- client-written role, verification, membership or privileged grants;
- production ManagedPage publication or externally reachable page content;
- production moderation/access administration;
- payments, KYC, tax, payout or contracts;
- a new global `Pro` role;
- a manual Viewer/Creator profile switch;
- any new Create type or unrelated cross-feature flow.

Those operations remain behind the original ADR 0015 stabilization boundary,
the separately approved Firebase gate and their own implementation slices.

## Data And Security Constraints

- User, page, membership, workspace and publisher relations use permanent
  ULID/UUID identifiers.
- Page A grants never authorize Page B.
- Active workspace is UX preference, not authority.
- Admin tools do not satisfy Creator verification, publisher or page membership
  checks.
- Persisted roles remain `User`, `Creator` and `Admin`.
- Persisted workspace types remain `personal` and `page`.
- Logs and analytics use opaque IDs and stable reason codes.
- International contracts use stable market/country, locale, IANA timezone and
  ISO currency codes.

## Rollout

Implementation order is:

```text
IDP-03A local contracts and switcher
  -> IDP-04A workspace shell and local PublisherRef defaults
  -> IDP-05A guards, Admin entry and negative coverage
```

Each slice starts disabled behind a local/mock capability or configuration
boundary where partial activation could expose inconsistent behavior.

## Rollback

Rollback disables page workspace activation and returns the app to the personal
consumer shell. Local page fixtures and workspace preferences may remain
readable but cannot authorize mutations. Existing drafts retain their stored
publisher and are never mass-rewritten during rollback.

## Consequences

- The approved workspace model can be validated before Firebase integration.
- The misleading legacy role switch can be removed without inventing a new
  role.
- Stabilization receives additional scoped work and test surface.
- Production identity, verification and page authority remain intentionally
  unavailable.
- ADR 0015 remains authoritative except for the exact timing exception defined
  here.

