# RECHARGE — Public Professional Page Local Slice Specification

Status: **Approved**

Version: **1.0**

Date: **2026-08-16**

Slice: **PPP-01A — bounded local/mock public resolver and owner preview**

## 0. Authority and intent

This is the Approved current-slice specification for the first application
integration of `PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v1.3 and
`PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` v2.34. Accepted ADRs and
`IDENTITY_PUBLISHER_SLICE_SPEC.md` remain higher authority.

The slice proves provider-neutral contracts, fail-closed resolution and an
honest UI. It does not authorize Firebase, production verification,
production moderation, remote contact reveal, remote Follow/Block/Mute,
publication grants or a pre-created demo page.

## 1. Scope

PPP-01A implements:

- typed `PublicManagedPageProjection`, content summary and viewer context;
- the closed `ManagedPageFieldModerationOverlay` value/key model needed by
  the public projection;
- exact `verified + active` public resolution by permanent page id or slug;
- response-indistinguishable `notFound` for missing and hidden pages;
- a read-only, publisher-indexed content projection repository whose local
  implementation starts empty;
- a protected owner/team preview for an existing local page, clearly labelled
  as preview and never treated as public resolution;
- a public page screen with identity header, verification badge, content
  empty state, Share, and capability-derived Manage/Edit affordances;
- schema migration for any `ManagedPage` fields added by this slice.

## 2. Explicitly out of scope

- inventing or seeding a Professional Page for the demo account;
- changing `pending` local pages to `verified` or making them public;
- production moderation decisions or a moderator UI;
- raw contact data, contact reveal, Follow, Report, Block or Mute runtime;
- content inference from names, categories, relations or active workspace;
- new analytics events for this surface; a later slice must define an explicit
  allowlist and MUST NOT log a slug, locale, display text or raw reference;
- all-ten Create `PublisherRef` migration;
- Firebase, network, backend, deployment or production data processing.

Out-of-scope actions are hidden rather than rendered as working buttons. Their
target contracts remain in the full functional specification.

## 3. Runtime rules

1. `resolveById` and `resolveBySlug` use one repository and one resolver.
2. Only `verificationStatus == verified` and `lifecycle == active` returns
   `publicPage`; all other and unknown states return the same `notFound`.
3. Active workspace and team membership never authorize public visibility.
4. Owner preview loads only through exact-page membership. It displays a
   persistent `Preview — not publicly visible` banner unless the canonical
   resolver independently returns `publicPage`.
5. Preview may project only locally available safe fields. It never exposes
   membership, capability, verification evidence or internal notes.
6. Public content is queried only by `{type: page, id}`. The local repository
   returns an empty typed result until an Approved per-type adapter exists.
7. `publicRevision` is opaque; cache identity includes requested locale.
8. Unknown schema, field key, overlay value type, page reference or cursor
   fails closed.

## 4. File boundary

Runtime changes stay inside `features/identity` plus app composition:

- `features/identity/domain/entities/` — public projection, overlay and state;
- `features/identity/domain/repositories/` — public page/read-model ports;
- `features/identity/domain/usecases/` — resolver and preview projection;
- `features/identity/data/` — local/mock adapters;
- `features/identity/application/` — controller/state/providers;
- `features/identity/presentation/` — public/preview page;
- `app/router/`, `app/di/` — route and dependency wiring only.

No new cross-feature import is permitted.

## 5. Persistence and migration

- Existing identity local storage remains owner-namespaced.
- New optional page fields use a versioned migration; a v1 record must load
  without loss and receive deterministic safe defaults.
- Public read projections use a separate read-only namespace and contain no
  raw contacts or membership/capability data.
- Rollback removes the route/registration and ignores the newer optional
  fields; existing page/membership records remain readable and are not
  deleted or rewritten destructively.

## 6. Acceptance criteria

- **PPP-01A-AC01:** Every non-`verified+active` combination and a missing page
  return the same `notFound` type and public UI.
- **PPP-01A-AC02:** ID and slug for a verified active record resolve the same
  projection; unknown or retired references fail closed.
- **PPP-01A-AC03:** The default mock account still starts with zero pages.
- **PPP-01A-AC04:** A user-created pending page is not publicly resolvable,
  but its authorized member can open the clearly labelled preview.
- **PPP-01A-AC05:** Preview never changes verification, lifecycle,
  membership, capability, workspace or publisher state.
- **PPP-01A-AC06:** Public/preview payloads contain no raw contact,
  verification evidence, team list, capability set or internal note.
- **PPP-01A-AC07:** Content attribution uses exact page `PublisherRef`; the
  empty local read model does not infer content from any other signal.
- **PPP-01A-AC08:** Follow, Contact, Report, Block and Mute are absent until
  their Approved runtime slices exist; Share and safe Manage/Edit behave as
  specified.
- **PPP-01A-AC09:** 360 dp and 150% text scale render without overflow and
  status is never communicated by color alone.
- **PPP-01A-AC10:** v1 identity page records migrate without data loss;
  unknown/newer schemas fail closed.
- **PPP-01A-AC11:** analyzer, focused/full tests, boundary and diff checks are
  recorded in `LAUNCH_STATUS.md`; the status remains Review if full evidence
  is incomplete.

## 7. Required tests

- resolver matrix for every verification/lifecycle combination;
- missing-vs-hidden indistinguishability;
- id/slug parity and malformed reference;
- overlay key/value and effective-value rules;
- v1 persistence migration and unknown-schema behavior;
- zero-page default and pending-page public denial;
- exact-membership preview authorization and cross-page denial;
- public/member projection parity at the same locale;
- empty publisher-indexed content projection;
- hidden gated actions and working Share/Manage affordances;
- 360 dp/150% widget coverage;
- existing identity/workspace regression suites.

## 8. Rollback and completion

Rollback disables/removes the public route, preview entry and public-page
registrations. It does not delete local pages, memberships or drafts.

PPP-01A may reach **Review** when all ACs are implemented and scoped gates are
green. It cannot make Public Professional Page production Done; that still
requires production Identity, verification/moderation authority, remote read
models, action contracts and the full functional specification's DoD.
