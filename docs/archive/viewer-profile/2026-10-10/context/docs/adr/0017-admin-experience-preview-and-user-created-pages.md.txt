# ADR 0017: Admin Experience Preview And User-Created Professional Pages

- Status: Accepted
- Date: 2026-07-31
- Deciders: Recharge team
- Supersedes: ADR 0016 only where this ADR explicitly changes local/mock
  fixtures, Admin preview and Professional Page creation
- Related: ADR 0013, ADR 0015, ADR 0016,
  `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md`

## Context

ADR 0016 allowed a bounded local/mock identity and workspace foundation during
stabilization. The first IDP-03A implementation incorrectly represented
multi-page behavior with three pre-created Professional Page fixtures. That
does not match the product rule: a page belongs in a user's workspace only
after that user creates it or receives an explicit membership.

The product also requires an Admin account to inspect the Viewer, Creator and
Professional Page experiences. This is a QA/moderation preview requirement,
not a new persisted role and not a way for an ordinary user to change identity
or grants.

Professional Page self-service creation needs a bounded quota and moderator
visibility. A user may create up to three owned pages. Additional pages require
an explicit request and moderator approval.

## Decision

### No invented user pages

- The default local/mock account starts with zero Professional Pages.
- Mock fixtures may describe capabilities and identity state, but must not
  invent user-owned pages.
- A page appears in the workspace switcher only after a local user creation
  record or an explicit membership record exists.
- Demo/test pages may exist only inside an individual test that clearly creates
  or injects them for that test.

### Admin experience preview

An authenticated Admin with `admin.experience.preview` may select a
session-scoped preview:

```text
viewer | creator | professionalPage
```

The preview:

- changes presentation only;
- does not change persisted `User`, `Creator` or `Admin` role;
- does not grant verification, membership, publisher or mutation authority;
- is not a `WorkspaceRef`;
- is not a `PublisherRef`;
- is unavailable to ordinary users;
- keeps Viewer and Creator on the same personal bottom navigation.

Professional Page preview with no page opens the empty/onboarding experience
and a `Create Professional Page` action. It never creates a hidden placeholder
page.

### Local/mock Professional Page creation

During the bounded stabilization exception, an authenticated verified Creator
with `page.create` may create a local/mock Professional Page:

- a permanent client-generated ULID/UUID is assigned;
- the creator becomes the explicit owner;
- an active owner membership is created for the exact page id;
- page verification starts as `pending`;
- the page is labelled local/mock and is not externally published;
- market, country, locale, IANA timezone and ISO currency are explicit fields.

This local flow is product validation only. It does not write production roles,
verification decisions, memberships or grants.

### Self-service quota

- The self-service ownership quota is three Professional Pages per user.
- Invited or delegated non-owner memberships do not consume the ownership
  quota.
- Creating pages one through three is allowed.
- A fourth or later owned page is not created automatically.
- The user submits an idempotent `PageLimitIncreaseRequest` to moderators.
- Only an approved moderator decision may raise that user's effective quota.
- Local/mock IDP work may persist and display a pending request, but it may not
  simulate a production approval or authoritative grant.

### Notifications

Local/mock creation produces durable notification events:

- the user receives page-created and `pending review` confirmation;
- the moderator inbox receives a new-page review notification;
- a quota-increase request notifies both the user and moderator inbox;
- an eventual moderator decision notifies the user.

In this ADR, “new account notification” means a newly created Professional
Page. Notification for registration of a new personal Recharge user is a
separate product event and is not added by this decision.

Notification delivery is idempotent by stable event id. Payloads contain
opaque user/page/request ids and do not include identity evidence.

## Stabilization Scope

ADR 0017 adds only the following local/mock work to IDP-03A/04A/05A:

- remove pre-created page fixtures;
- persist local user-created pages and owner memberships;
- enforce the default ownership quota of three;
- persist a pending quota-increase request;
- write local user and moderator-inbox notifications;
- expose Admin experience preview without changing authority;
- cover zero, one, three and over-limit behavior.

Firebase, production moderation, authoritative approval, external page
publication and real notification delivery remain prohibited.

## Security And Invariants

- Admin preview never authorizes a protected operation.
- Active workspace remains UX state, not authority.
- A page id is selectable only when the current access snapshot contains that
  exact page and active membership.
- Page ownership is explicit and is never inferred from display name, email or
  profile text.
- The fourth page is fail-closed until an approved quota exists.
- Repeated creation or request submissions are idempotent.
- Logs and analytics use opaque ids and stable reason codes.

## Rollout

```text
remove invented fixtures
  -> local page create with quota 3
  -> local user/moderator notifications
  -> Admin experience preview
  -> workspace-aware shell
```

## Rollback

Rollback disables local page creation and Admin preview, returns the app to the
personal experience and leaves persisted local records readable but
non-authoritative. It never replaces a removed fixture with another invented
page and never grants a quota increase.

## Consequences

- Multi-page behavior is exercised with user actions rather than fictional
  ownership.
- Admin can inspect all three product experiences without corrupting role or
  permission state.
- The common case remains bounded to three owned pages.
- Moderator workflow becomes visible before production integration.
- Production authority remains deferred behind its original gates.
