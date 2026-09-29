# Scenario / Quick Plan Boundary and Entry Migration

Version: **1.0 Approved implementation baseline**

Date: **2026-08-10**

Proposed slices: **SCN-BND-00 / SCN-BND-01 / SCN-ENTRY-01 / SCN-NOTIF-01 / SCN-LEGACY-01**

Runtime effect of this document: **SCN-BND-01, SCN-ENTRY-01,
SCN-SURFACE-01 and SCN-NOTIF-01 authorized and implemented locally;
SCN-LEGACY-01 destructive cleanup remains deferred to M10**

## 1. Status and authority

The product owner approved this bounded local/mock implementation on
2026-08-10. It does not authorize Firebase, backend, production subscriptions,
bulk stored-data rewrites or generated-file edits.

After acceptance, this specification is the normative delta for the bounded
topics below and supersedes conflicting entry-point, Favorites and notification
language in:

- `SCENARIO_BUILDER_SPEC.md` section 7;
- `SCENARIO_OBJECT_INTAKE_SLICE_SPEC.md` sections 11 and 21;
- historical `/scenario-builder` and `category == scenario` behavior described
  in `LAUNCH_STATUS.md` P10-P60 entries.

The canonical product boundary remains:

- Route, Scenario and Quick Plan are three different aggregates;
- canonical Scenario lives in the config-driven Create runtime;
- the current `features/scenarios` runtime is a legacy Quick Plan-shaped
  implementation and is not a second canonical Scenario model;
- no bulk rewrite or destructive migration is authorized.

## 2. Problem statement

The checkout currently exposes two differently shaped runtimes under Scenario
language:

1. canonical `ScenarioDraftData` inside Create Hub;
2. legacy `ScenarioDraftEntity` behind `/scenario-builder`.

Legacy consumers construct raw query links from Main, Search, Map, Favorites,
Notifications, Profile and Create continuation surfaces. Some newer
Details/Search/Map actions already target canonical Scenario by
`scenarioDraftId`, while older actions still open the legacy runtime. The
legacy controller also suppresses a second step by category, and the legacy
step model does not preserve a catalog source object ref independently from
the local step occurrence id.

The result is an ambiguous product boundary, lossy Quick Plan conversion and
navigation that cannot safely distinguish Quick Plan, Scenario and Route.

## 3. Canonical product definitions

### 3.1 Scenario

Scenario is an independently stored personal plan for at least one calendar
day. It may cover one or multiple days and does not have to occupy all 24 hours
of any day.

Invariants:

1. A Scenario has at least one calendar day.
2. A Scenario has its own permanent client-generated ULID.
3. Every occurrence inside a Scenario has its own `scenarioItemId`.
4. Scenario creation from an empty state is available only through Create Hub.
5. Existing Scenario is opened only by `scenarioDraftId`.
6. Personal Scenario containers are listed, opened and managed through
   Profile / My Scenarios.
7. Scenario containers do not appear in Main or Favorites.

### 3.2 Quick Plan

Quick Plan is a lightweight ordered plan made from several object occurrences.
It remains separate from Create Hub, Scenario storage and public catalog.

Invariants:

1. Quick Plan has its own `quickPlanId` and revision.
2. Every occurrence has its own `quickPlanItemId`.
3. A catalog-backed occurrence preserves `{objectType, objectId}` separately
   from `quickPlanItemId`.
4. The same catalog object may occur more than once.
5. Existing Quick Plan is opened only by `quickPlanId`.
6. `Expand to Scenario` creates a new independent Scenario and never mutates
   or renames the Quick Plan.

### 3.3 Route

Route remains a continuous track aggregate with geometry, anchors, segments,
GPX/elevation and POI placement. No Scenario or Quick Plan command may create
or mutate Route state.

## 4. Occurrence identity and repetitions

Category and source object identity do not define occurrence uniqueness.

The required identity layers are:

```text
catalog object:  place_123
Quick Plan item: quick_item_morning -> place_123
Quick Plan item: quick_item_evening -> place_123
Scenario item:   scenario_item_morning -> place_123
Scenario item:   scenario_item_evening -> place_123
```

Rules:

1. Any number of items from the same category is allowed.
2. The same catalog object may occur multiple times on the same or different
   days and at different times.
3. No automatic duplicate suppression uses category or `sourceObjectId`.
4. A deliberate second placement always receives a new occurrence id.
5. Technical double-submit protection uses a command idempotency key and does
   not remove a user-confirmed second occurrence.
6. A repeated object change creates one notification per affected
   `scenarioItemId`; notifications are not collapsed only because
   `sourceObjectId` is equal.

## 5. Entry policy

### 5.1 Create Scenario

An empty new Scenario is created only through:

```text
Create Hub -> Scenario
```

The following old entry actions are removed rather than redirected to another
implicit creation flow:

- Main -> Build Scenario;
- Search/Smart Search -> Build Scenario;
- Map -> Create Scenario from selection;
- Favorites -> Build Scenario;
- Notifications -> Build/Open legacy Scenario route.

Two explicit materialization operations remain allowed outside empty Create
Hub creation because they have a source aggregate and show the copy boundary:

- Quick Plan -> Expand to Scenario;
- public Scenario/template -> Create my copy.

### 5.2 Add to Scenario

`Add to Scenario` is allowed from Details, Search results and Map only.

It never offers a blank `Create new Scenario` target. The target chooser has:

1. **My active editable Scenarios**;
2. **My inactive/completed editable Scenarios** in a separate section;
3. **Public Scenarios and templates** as copy sources, not mutable targets.

For an owned editable target, Apply adds occurrences to that exact
`scenarioDraftId`. For a public Scenario or template, the UI must say
`Create my copy and add`; the command first materializes an independent private
copy and then adds the requested occurrences atomically.

If no eligible owned target or copy source exists, `Add to Scenario` is not
shown. There is no shortcut to blank Scenario creation.

### 5.3 Placement

The existing day/position/role review remains, with these amendments:

- a target has at least one calendar day;
- repeated exact object refs are allowed without warning or blocking;
- each selected placement receives a new `scenarioItemId`;
- batch intent order is preserved;
- no logistics or availability is fabricated.

## 6. Copy and conversion semantics

### 6.1 Public Scenario/template -> own Scenario

`ForkScenario` and `CreateFromScenarioTemplate` are distinct from
`ExpandQuickPlanToScenario`.

The created copy:

- gets a new Scenario ULID;
- gets new day, location, leg and item ids;
- is owned by the requester;
- starts as private;
- starts with object-update tracking enabled;
- stores `{sourceType, sourceId, sourceRevision}` provenance;
- has no automatic live synchronization with the source;
- does not copy another user's private notes, execution state, participants,
  tokens or secrets.

When invoked by `Add to Scenario`, copying the source and adding the requested
occurrences is one logical conditional-save command. A half-created empty copy
is forbidden.

### 6.2 Quick Plan -> Scenario

For a new catalog-backed Quick Plan item, conversion preserves the catalog ref:

```text
quickPlanItemId + {objectType, objectId} + snapshot
    -> new scenarioItemId + same {objectType, objectId} + refreshed/safe snapshot
```

The converter also records the Quick Plan and item provenance. A legacy item
without an independently persisted source ref becomes a custom Scenario item
with typed issue `legacySourceIdentityMissing`; object identity is never
guessed from title, category or coordinates.

Every Expand creates a new private Scenario with at least Day 1. The original
Quick Plan remains unchanged and there is no live link.

## 7. Typed navigation

New code must not use a raw URL as product identity. The app-level navigation
contract distinguishes:

```text
OpenScenarioDraft(scenarioDraftId)
OpenQuickPlan(quickPlanId)
OpenRoute(routeId)
CreateScenarioInCreateHub()
AddObjectsToScenario(intentId)
ExpandQuickPlan(quickPlanId, expectedRevision)
ForkScenario(sourceScenarioId, sourceRevision)
CreateFromScenarioTemplate(templateId, sourceRevision)
```

Rules:

1. Existing Scenario never restores from mood/category/query seeds.
2. Existing Quick Plan never restores from category-only query seeds.
3. Query seed may start transient creation only and must be materialized to a
   permanent id before editing/saving.
4. Old `/scenario-builder?...` links go through a compatibility classifier.
5. Ambiguous legacy links fail closed with an explanatory recovery state.
6. The old route remains until the observation period and zero-consumer proof.

The target route for the renamed product is `/quick-plan/:quickPlanId`. The old
`/scenario-builder` path becomes compatibility-only and must not be emitted by
new code.

## 8. Surface ownership

| Surface | Scenario behavior |
|---|---|
| Main | No Scenario or ambiguous legacy Quick Plan blocks/actions |
| Create Hub | The only blank Scenario creation entry |
| Details/Search/Map | Add objects to an eligible existing/copy-materialized Scenario |
| Profile | List, open, manage and track owned Scenario containers |
| Favorites | No Scenario containers and no automatic Scenario-object insertion |
| Notifications | Object occurrence updates in tracked Scenario context only |
| Quick Plan | Explicit Expand to a new independent Scenario |

Legacy Scenario favorites remain readable for migration classification but are
not rendered as Favorites and are never deleted automatically. Quick Plan must
use its own storage contract; saving it as a Favorite is removed.

## 9. Scenario lifecycle and update tracking

Two independent user-visible states are required.

### 9.1 Date-derived lifecycle

```text
upcoming | active | completed
```

It is derived from Scenario calendar days and the configured timezone. It is
not a manual authority flag.

### 9.2 User tracking preference

```text
updatesOn | updatesOff
```

It is user-scoped and controlled from Profile / My Scenarios.

- `updatesOn`: new object-occurrence update/reminder notifications may be
  produced;
- `updatesOff`: no new notifications are produced;
- existing notification history remains;
- turning updates back on does not replay an unbounded backlog.

New copies from a public Scenario/template start with `updatesOn`.

## 10. Scenario-context notifications

Notifications do not contain Scenario cards. The `Scenarios` filter shows
updates to objects occurring in tracked Scenarios.

Typed notification data contains:

```text
subjectRef:       {objectType, objectId}
scenarioContext: {scenarioId, scenarioItemId}
changeType
sourceRevision/fingerprint
occurredAt
```

Examples include Event time/cancellation, Place hours/closure/address changes,
Route version/availability changes and other typed catalog-object updates.

If `place_123` occurs in the morning and evening, the same source change
creates two notifications, one per `scenarioItemId`. The idempotency key is
scoped by user, Scenario, Scenario item, source change revision and change
type. A notification opens the affected object or a review of that occurrence;
Scenario container management remains under Profile.

New notification records use typed refs. `targetRoute` remains read-only legacy
compatibility data. Old raw `/scenario-builder?...` targets pass through the
legacy classifier and never become new records.

The stabilization implementation is local/mock and must be labelled honestly.
Real remote object-change production requires later remote adapters,
authoritative data, identity and observability gates.

## 11. Legacy classification and migration journal

The classifier returns one of:

```text
quickPlan | scenario | route | ambiguous | unsupported
```

Classification uses versioned payload shape, stored ids and known route
contracts. It never infers identity from display title, category or coordinates.

For every materialized migration/copy, the local journal stores only:

- source kind/id/revision;
- target kind/id/revision;
- result and typed reason;
- timestamp and migration contract version.

It does not store private notes, prompts, tokens, participant identity or raw
object payload. Ambiguous records remain readable through compatibility and
are not rewritten. Source deletion is a separate M10 task after an observation
period.

## 12. Staged implementation

### 12.1 SCN-BND-00 — this document

Documentation only. No runtime effect.

### 12.2 SCN-BND-01 — M2 identity correction

Scope:

- preserve catalog source ref separately from Quick Plan occurrence id;
- remove category/source-object duplicate suppression;
- preserve repeated occurrences through conversion;
- add legacy missing-source typed issue.

Exact files:

- `apps/mobile/lib/features/scenarios/domain/entities/scenario_draft_entity.dart`
- `apps/mobile/lib/features/scenarios/application/controllers/scenario_builder_controller.dart`
- `apps/mobile/lib/app/adapters/legacy_quick_plan_conversion_adapter.dart`
- `apps/mobile/lib/features/create/domain/entities/quick_plan_conversion.dart`
- `apps/mobile/lib/features/create/domain/usecases/expand_quick_plan_to_scenario_usecase.dart`
- `apps/mobile/test/unit/scenario_builder_controller_test.dart`
- `apps/mobile/test/unit/quick_plan_conversion_test.dart`
- `apps/mobile/test/widget/scenario_builder_page_test.dart`

No router, Favorites, Notifications, Profile, backend or Firebase changes.

### 12.3 SCN-ENTRY-01 — M3 typed navigation and chooser correction

New files:

- `apps/mobile/lib/app/application/planning_navigation_intent.dart`
- `apps/mobile/lib/app/application/planning_navigation_resolver.dart`
- `apps/mobile/lib/app/adapters/legacy_planning_link_classifier.dart`
- `apps/mobile/lib/features/create/domain/entities/scenario_copy_request.dart`
- `apps/mobile/lib/features/create/domain/usecases/fork_scenario_usecase.dart`
- `apps/mobile/test/unit/planning_navigation_resolver_test.dart`
- `apps/mobile/test/unit/legacy_planning_link_classifier_test.dart`
- `apps/mobile/test/unit/fork_scenario_test.dart`

Modified files:

- `apps/mobile/lib/app/router/route_names.dart`
- `apps/mobile/lib/app/router/app_router.dart`
- `apps/mobile/lib/app/application/controllers/scenario_object_intake_controller.dart`
- `apps/mobile/lib/app/application/state/scenario_object_intake_state.dart`
- `apps/mobile/lib/app/application/scenario_object_intake_facade.dart`
- `apps/mobile/lib/app/presentation/scenario_object_intake_sheet.dart`
- `apps/mobile/lib/features/create/domain/entities/scenario_object_intake.dart`
- `apps/mobile/lib/features/create/domain/usecases/apply_scenario_object_intake_usecase.dart`
- `apps/mobile/lib/features/create/presentation/pages/create_page.dart`
- `apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart`
- `apps/mobile/lib/features/discover/presentation/pages/discover_results_page.dart`
- `apps/mobile/lib/features/discover/presentation/pages/discover_map_page.dart`
- related existing SCN-INTAKE unit/widget tests

The `Create new Scenario` intake branch and its empty-target recovery are
removed. The existing owned target, inactive/completed section and explicit
public/template copy paths are covered independently.

### 12.4 SCN-SURFACE-01 — M3 surface ownership and Quick Plan naming

This slice performs one atomic feature move/rename. It must not leave a second
Quick Plan runtime next to `features/scenarios`.

Destination/new files:

- `apps/mobile/lib/features/quick_plan/domain/entities/quick_plan_entity.dart`
- `apps/mobile/lib/features/quick_plan/domain/repositories/quick_plan_repository.dart`
- `apps/mobile/lib/features/quick_plan/data/models/quick_plan_model.dart`
- `apps/mobile/lib/features/quick_plan/data/datasources/quick_plan_local_datasource.dart`
- `apps/mobile/lib/features/quick_plan/data/repositories/quick_plan_repository_impl.dart`
- `apps/mobile/lib/features/quick_plan/application/controllers/quick_plan_controller.dart`
- `apps/mobile/lib/features/quick_plan/application/state/quick_plan_state.dart`
- `apps/mobile/lib/features/quick_plan/application/quick_plan_providers.dart`
- `apps/mobile/lib/features/quick_plan/presentation/pages/quick_plan_page.dart`
- Quick Plan mapper/repository/controller/widget tests matching these paths

Removed only after all imports are switched in the same slice:

- `apps/mobile/lib/features/scenarios/domain/entities/scenario_draft_entity.dart`
- `apps/mobile/lib/features/scenarios/application/controllers/scenario_builder_controller.dart`
- `apps/mobile/lib/features/scenarios/application/state/scenario_builder_state.dart`
- `apps/mobile/lib/features/scenarios/application/scenario_builder_providers.dart`
- `apps/mobile/lib/features/scenarios/presentation/pages/scenario_builder_page.dart`
- `apps/mobile/test/unit/scenario_builder_controller_test.dart`
- `apps/mobile/test/widget/scenario_builder_page_test.dart`

Modified files:

- `apps/mobile/lib/features/auth/presentation/pages/discover_hub_page.dart`
- `apps/mobile/lib/features/favorites/presentation/pages/favorites_page.dart`
- `apps/mobile/lib/features/favorites/domain/entities/favorite_item_entity.dart`
- `apps/mobile/lib/features/favorites/data/models/favorite_item_model.dart`
- `apps/mobile/lib/features/explore/presentation/pages/profile_page.dart`
- `apps/mobile/lib/app/di/service_locator.dart`
- existing Home/Favorites/Profile/Quick Plan tests

This slice removes Scenario from Main and Favorites, stops saving Quick Plan as
a Favorite, exposes owned Scenario containers only from Profile and presents
the migrated product as Quick Plan. Old stored favorites and
`/scenario-builder` links remain compatibility inputs, but no runtime class or
new import remains under `features/scenarios` after this atomic move.

### 12.5 SCN-NOTIF-01 — M3 local/mock Scenario object updates

New files:

- `apps/mobile/lib/features/create/domain/entities/scenario_tracking_preference.dart`
- `apps/mobile/lib/features/create/domain/repositories/scenario_tracking_repository.dart`
- `apps/mobile/lib/features/create/data/repositories/scenario_tracking_repository_impl.dart`
- `apps/mobile/lib/features/notifications/domain/entities/scenario_notification_context.dart`
- `apps/mobile/lib/features/notifications/domain/usecases/project_scenario_object_updates_usecase.dart`
- corresponding unit tests

Modified files:

- `apps/mobile/lib/features/notifications/domain/entities/notification_item_entity.dart`
- `apps/mobile/lib/features/notifications/data/models/notification_item_model.dart`
- `apps/mobile/lib/features/notifications/data/datasources/notifications_local_datasource.dart`
- `apps/mobile/lib/features/notifications/data/repositories/notifications_repository_impl.dart`
- `apps/mobile/lib/features/notifications/application/controllers/notifications_controller.dart`
- `apps/mobile/lib/features/notifications/presentation/pages/notifications_page.dart`
- `apps/mobile/lib/features/explore/presentation/pages/profile_page.dart`
- `apps/mobile/test/unit/notifications_controller_test.dart`
- `apps/mobile/test/widget/notifications_page_test.dart`
- `apps/mobile/test/widget/profile_page_test.dart`

This slice adds the `Scenarios` notification filter, per-occurrence typed
context and Profile updates toggle. It does not add remote polling, Firebase or
provider integrations.

### 12.6 SCN-LEGACY-01 — M10 physical cleanup

Only after zero new emitters, compatibility metrics/fixtures and an observation
period:

- remove `/scenario-builder` compatibility route;
- remove legacy raw query builders;
- remove legacy link/favorite classifiers after stored-data exit evidence;
- remove `targetRoute` fallback after stored compatibility exit evidence;
- remove obsolete allowlist suppressions and migration flags.

## 13. Acceptance criteria

1. Scenario requires at least one calendar day.
2. Blank Scenario creation is reachable only through Create Hub.
3. `Add to Scenario` never offers blank new Scenario creation.
4. Owned active targets and inactive/completed targets are separate sections.
5. Selecting public/template source creates a new private owned copy and adds
   the requested occurrences atomically.
6. The same category may appear any number of times.
7. The same source object may appear any number of times.
8. Every placement receives a new occurrence id.
9. Technical retry does not duplicate one confirmed command.
10. Existing Scenario opens only by `scenarioDraftId`.
11. Existing Quick Plan opens only by `quickPlanId`.
12. New code emits no `/scenario-builder?...` link.
13. Main renders no Scenario/legacy Quick Plan blocks or actions.
14. Favorites renders no Scenario containers and receives no automatic
    Scenario-object insertion.
15. Quick Plan is not persisted as a Favorite.
16. Profile is the Scenario container list/management surface.
17. Date lifecycle and update tracking preference are independent.
18. `updatesOff` stops new notifications without deleting history.
19. Notifications `Scenarios` filter contains object-occurrence updates, not
    Scenario cards.
20. Two occurrences of one changed object create two notifications.
21. Notification idempotency prevents duplicates for the same occurrence and
    source change revision.
22. New notifications store typed subject/scenario context.
23. Old raw targets remain readable through compatibility only.
24. Quick Plan conversion preserves a known catalog source ref.
25. Missing legacy source identity becomes a custom item with typed issue and
    is never guessed.
26. Copy/conversion creates new permanent ids and no live source dependency.
27. Ambiguous legacy payload is not rewritten.
28. No new cross-feature boundary suppression is introduced.
29. Targeted and contract/navigation matrix tests pass.
30. `flutter analyze`, full `flutter test`, boundary gate and `git diff --check`
    pass for every runtime slice before Done.

## 14. Contract/navigation matrix tests

The final matrix covers:

- Create Hub blank Scenario creation;
- no Main/Favorites/Notifications creation path;
- Details/Search/Map existing-target chooser;
- no-target hidden action;
- active and inactive/completed target sections;
- owned apply versus public/template copy-and-add;
- exact Scenario/Quick Plan/Route typed navigation;
- same-category and same-object repeated placements;
- per-occurrence notification projection;
- updates on/off behavior;
- old raw link classification and ambiguous fail-closed recovery;
- restart/revision/idempotency behavior;
- 360 dp and 150% text scaling for chooser and notification filters.

## 15. Rollback

Each runtime slice keeps an independent local feature flag or resolver switch:

- typed planning navigation;
- existing/copy-only Scenario intake;
- Quick Plan named route;
- Scenario-context notifications.

Rollback disables only the affected new surface. Readers continue to preserve
new known fields and compatibility records. Rollback never rewrites Scenario
into Quick Plan/Route, never deletes a source aggregate and never restores
category-based duplicate suppression.

## 16. Explicit exclusions

This plan does not authorize:

- Firebase or `apps/backend` creation;
- production object-change subscriptions;
- live availability, routing, booking or payments;
- automatic public Scenario synchronization;
- Scenario containers in Main, Favorites or Notifications;
- a new Create type;
- generated file edits;
- destructive migration or bulk rename.
