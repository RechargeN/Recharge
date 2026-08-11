# ADR 0015: Authenticated Viewer, Verified Creator And Professional Page

- Status: Accepted
- Date: 2026-07-26
- Deciders: Recharge team
- Supersedes: ADR 0013 policy 6 only where it permits unauthenticated guest mode
- Related: ADR 0013, `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md`

## Context

Recharge needs one unambiguous identity and publishing model for consumer
access, creator eligibility and professional publishing.

The previous baseline allowed unauthenticated read-only guest mode. Product
policy now requires every Viewer to authenticate. Google or Apple
authentication proves control of an external account, but does not by itself
grant Creator status or prove a professional identity.

The current UI also exposes `Pro generator` as if it were a third user role.
The accepted domain baseline has only `User`, `Creator` and `Admin`. A
professional publisher must therefore be modelled through a page, scoped
membership and capabilities rather than another global role.

## Decision

### 1. Authentication is mandatory

Every product user, including the read-only Viewer, must have an authenticated
Recharge session. The production providers are Google and Apple.

There is no unauthenticated guest browsing mode. A cold start, logout, expired
session or public deep link without a valid session opens the authentication
flow and preserves the intended destination where safe.

### 2. Viewer maps to the User role

`Viewer` is product/UI terminology for an authenticated account with the
system role `User`.

A Viewer can use consumer capabilities such as discovery, favorites,
participation and profile management. Authentication alone never grants
Creator or professional publishing authority.

A Viewer may prepare and locally save a pre-verification draft so work is not
lost during an upgrade flow. Submit, moderation entry and publication remain
blocked until Creator eligibility and the required content capabilities are
present.

### 3. Creator requires additional identity verification

`Creator` remains a system role. It is granted only after the account completes
the accepted additional identity-verification process.

Google/Apple authentication, verified email and phone confirmation are trust
signals, but none is silently treated as full Creator identity verification.
The authoritative verification result is server-owned, audited and cannot be
written by the client.

Creator access is determined by all applicable inputs:

```text
authenticated session
  + active account
  + verified creator identity
  + role/capability grant
  + resource ownership and lifecycle
```

A verified Creator may create and publish from the personal publisher when the
required type-specific capabilities are present.

### 4. Pro is not a role

`Pro` or `Pro generator` is a product/UI tier, not a system role. It means:

```text
verified Creator
  + active membership in a ManagedPage
  + page-scoped capabilities
```

The canonical UI surface is a `Professional Page`; it is the product name of
the domain `ManagedPage`, not a second aggregate. It may represent a company,
organization, representative office, venue operator or private professional
whose services fit Recharge.

A Professional Page may reference one or more Place entities, but the page and
a physical Place are different aggregates. A company rename must not change
content ownership, and a Place address must not become a publisher identifier.

One Creator may manage multiple Professional Pages and explicitly choose the
active publisher.

### 5. Publisher is explicit and ID-based

Every publishable content aggregate stores:

```text
PublisherRef {
  type: user | page,
  id: ULID/UUID
}
```

If only the personal publisher is eligible, it may be selected automatically.
If personal and page publishers are both eligible, or more than one page is
eligible, Create Hub must show an explicit `Publish as` choice.

Display name, avatar, professional type and verified badge are presentation
snapshots. Authorization always resolves the publisher by ID.

Personal identity verification and Professional Page verification are separate
facts. A verified Creator does not automatically make a page verified, and a
verified page does not grant membership or publishing authority.

### 6. Authorization is capability- and scope-based

The global roles remain:

```text
User | Creator | Admin
```

Privileged actions require explicit capabilities. Publishing as a page also
requires an active membership and the capability for that exact page.
Possession of `manage_page` for one page grants no access to another.

Client-side routing and UI guards improve UX but are not authoritative.
Application use cases enforce the decision, and production backend rules or
trusted operations repeat it.

### 7. Stabilization boundary

This ADR records the target policy. It does not authorize implementation during
the active stabilization slice.

Identity verification, Professional Page, cross-aggregate PublisherRef and
Firebase enforcement are a new cross-feature flow. Implementation starts only
through an approved post-stabilization slice. Existing mock behavior remains
non-production until that slice passes its acceptance criteria.

## Consequences

- The completed `S1-AUTH-01` guest behavior remains historical evidence, not
  the target product policy.
- App entry and logout behavior must eventually migrate from guest Discover to
  the authentication gate.
- Creator upgrade needs a dedicated verification lifecycle and audit trail.
- Create Hub needs one publisher selector shared by all ten accepted types.
- The current derived `ProfileRoleTier.proGenerator` may remain a UI
  projection only if its name and documentation cannot be confused with a
  persisted role.
- Professional Page verification, ownership and membership must be modelled
  separately from Place ownership or a self-declared business relationship.
- Firebase integration remains a later approved slice; clients cannot grant
  roles, verification or page membership.

## Rejected Alternatives

### Treat any Google/Apple account as a Creator

Rejected because provider authentication proves account access, not the
additional identity and trust level required for publishing.

### Add `Pro` as a fourth global role

Rejected because professional authority is publisher- and page-scoped. A
global role would over-grant access and conflict with ADR 0013.

### Use a Place or company name as the publisher

Rejected because names and addresses are mutable display data and cannot
provide stable ownership or authorization.

### Keep unauthenticated Viewer access

Rejected by the mandatory-auth product decision.

## Migration

The implementation slice must provide:

1. safe session/deep-link migration from guest entry to mandatory auth;
2. versioned verification and Professional Page contracts;
3. migration from aggregate-specific publisher fields to canonical
   `PublisherRef`;
4. compatibility reads for existing local drafts;
5. fail-closed submit/publish behavior when verification, membership or
   publisher eligibility is unknown;
6. unit, widget, integration and backend authorization coverage before
   production activation.
