# ADR 0018: Provider-Neutral AI Assistance Capability

- Status: Accepted
- Date: 2026-08-03
- Deciders: Recharge team
- Related: ADR 0011, ADR 0013, `docs/product/AI_PRODUCT_STRATEGY.md`,
  `docs/product/AI_PLATFORM_LOCAL_SLICE_SPEC.md`

## Context

Recharge already has bounded local/mock assistance inside Place and Scenario,
while the accepted product direction defines AI as a horizontal capability
layer rather than a role, workspace, catalog entity or Create type. The frozen
architecture baseline has no dedicated AI capability module. Putting generic
prompt, privacy, quota and provider-envelope concerns into an individual
product feature would duplicate policy and make a later provider migration
feature-specific.

The application is still in stabilization. Live AI, backend integration,
provider credentials and metered calls remain prohibited. A local capability
foundation is useful only if it is reversible, provider-neutral and cannot
mutate product aggregates.

## Decision

Add `apps/mobile/lib/features/ai_assist/` as a provider-neutral capability
feature with the standard `domain / data / application` layers and no required
presentation surface.

The module owns only cross-use-case AI-assistance concerns:

- versioned prompt definitions and registry contracts;
- transient request/result envelopes;
- evidence, confidence, issue, usage and typed failure metadata;
- deterministic input sanitization;
- bounded structured-output validation;
- local/mock gateway behavior;
- local feature switches and in-memory quota simulation;
- coordination with the existing provider cost policy and ledger.

It does not own product aggregates or feature-specific business validation.
Every consumer keeps its own typed proposal, validator and explicit domain
command.

### Cross-feature boundary

Product features must not import `features/ai_assist` directly. Future
integration uses an app-level adapter/facade that implements the consumer's
existing domain port and receives AI capability services from dependency
injection. This preserves the frozen no-cross-feature-import boundary.

### Provider boundary

- Mobile contains no production provider SDK, credential or secret.
- Production calls require a later Accepted provider ADR and backend proxy.
- Provider output is untrusted until generic envelope validation and the
  consumer's deterministic feature validation both pass.
- AI never performs booking, payment, publication or destructive mutation.
- Manual and deterministic flows remain available when the capability is
  disabled.

## Stabilization Scope

ADR 0018 permits only `AI-PLAT-LOCAL-01` during stabilization:

- contracts, local registry, sanitizer and validators;
- deterministic local/mock gateway and failure simulation;
- in-memory quota and zero-cost ledger wiring;
- unit tests and DI registration;
- no consumer migration, UI, persistence, network or production provider.

Each product integration remains a separate Approved slice.

## Privacy And Security Invariants

- Raw input is transient and is absent from results, cost ledger and ordinary
  telemetry.
- Email and phone-like values are redacted before the gateway boundary.
- Tool identifiers are allowlisted by a versioned prompt definition.
- Structured payloads have bounded depth, entries and string sizes.
- Disabled capabilities and exhausted quotas fail closed.
- Local/mock output never receives authoritative confidence.

## Rollback

Remove the DI registrations and the isolated `features/ai_assist` module.
There is no persisted schema, migration, remote state or consumer dependency to
clean up. Existing Place, Scenario and Smart Search behavior is unchanged.

## Consequences

- A shared AI-assistance contract exists without selecting a provider.
- Product features retain their own source-of-truth models and validators.
- Future provider integration has an explicit backend and app-adapter seam.
- The frozen baseline gains one capability feature through this ADR without
  broadening the active stabilization exception.
