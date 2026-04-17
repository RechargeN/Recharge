# UI Baseline And Design System Governance

This document defines where UI code must live and how reusable UI is governed.

## 1) Placement Rules

### Reusable UI (must be in Design System)

Reusable UI means any component used by 2+ features or expected to be reused:

- buttons, inputs, chips, cards, badges;
- navigation primitives;
- loaders, empty/error states (generic variants);
- theme tokens and visual foundations.

Canonical location:

- `packages/design_system/*` (target architecture baseline).

### Feature-Specific UI (must stay in feature)

UI coupled to feature behavior/domain must stay inside the feature:

- complex product widgets with business logic;
- feature-specific composed sections and screens;
- context-dependent variants that are not broadly reusable.

Canonical location:

- `lib/features/<feature>/presentation/...`

## 2) Strict Boundaries

Forbidden:

- moving product/business logic into design system components;
- direct feature imports inside design system package;
- creating reusable primitives in feature folders if they are generic.

Allowed:

- design system components may expose styling/composition APIs;
- feature layer composes DS components with feature state/logic.

## 3) Component Tiers

Tier A: Foundation

- tokens: color, spacing, typography, radius, elevation, motion.

Tier B: Primitives

- basic building blocks with no product logic.

Tier C: Composites

- reusable compositions of primitives without feature-specific behavior.

Tier D: Feature UI

- feature-owned compositions with product logic (not DS).

## 4) Promotion Rules (Feature -> Design System)

A feature component can be promoted to DS only if:

1. Used in at least two features or planned for cross-feature reuse.
2. Business logic can be fully separated from rendering API.
3. API surface is stable enough for reuse.
4. Accessibility and theming requirements are met.

## 5) Quality Requirements For DS Components

- token-driven styling (no hardcoded random values);
- support for theme variants;
- widget tests and golden tests for visual contracts;
- accessibility baseline (labels/semantics/contrast focus).

## 6) Transitional Rule (Current Repository State)

Until `packages/design_system` is physically scaffolded in this repository:

- place new reusable widgets in `lib/shared/widgets` as temporary staging only;
- mark them with migration note to DS;
- no feature-specific logic allowed in these staged reusable widgets.

This transitional mode is temporary and should be removed once DS package is scaffolded.
