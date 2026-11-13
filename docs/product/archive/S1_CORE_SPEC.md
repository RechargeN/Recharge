# S1-CORE-01 Spec

Status: Done (checkpoint fixed)  
Date: 2026-04-17

## Scope

This slice includes:

- app lifecycle observer wiring;
- app route observer wiring;
- baseline telemetry events for discover feed/details critical states.

Out of scope:

- external dashboards and alert automation;
- deep performance profiling;
- non-critical instrumentation.

## Implementation Baseline

1. Lifecycle
   - `AppLifecycleObserver` attached in app root.
   - Emits lifecycle state changes.

2. Routing telemetry
   - `AppRouteObserver` attached to router observers.
   - Emits push/replace/return route events with route names.

3. Discover telemetry
   - Feed: load started / loaded / failed events.
   - Details: load started / viewed / failed events.

## Checkpoint Verification (2026-04-17)

- `dart analyze lib test integration_test` -> no issues
- `flutter test .\test\unit\discover_feed_controller_test.dart` -> passed (`+3`)
- `flutter test .\test\widget\discover_feed_section_test.dart` -> passed (`+1`)
- `flutter test` -> passed (`+8`)

