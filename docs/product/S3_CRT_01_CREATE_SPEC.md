# S3-CRT-01 Create Draft + Publish Spec

Status: Done  
Date: 2026-04-20

## Scope

- Create flow supports both `event` and `place`.
- Local draft persistence.
- Publish happy path with status `pending_review`.

## Approved Decisions

1. Entity types in slice:
   - `event`
   - `place`
2. Media model for MVP:
   - `coverImage` (required for publish)
   - `gallery` (additional images)
3. Event model baseline:
   - include required MVP core from approved list:
     identity/time/location/audience/pricing/booking/organizer/media/system statuses.
4. Place support:
   - implemented in same create flow and same draft lifecycle.
5. Publish behavior:
   - local publish mock success
   - `publishStatus = pending_review`
6. Post-publish UX:
   - success screen with return to discover.

## Out Of Scope

- Real backend publish API integration
- Real media upload pipeline
- Advanced moderation controls/UI
- Advanced phase-2/phase-3 fields

## Definition Of Done (Target)

- User can create/edit draft for event and place.
- User can save and restore draft locally.
- Publish validates required fields (including required `coverImage`).
- Successful publish returns `pending_review` state and success UI.
- Unit/widget tests added for controller and primary create-page validation path.

## Verification Evidence (2026-04-20)

- `dart analyze lib test integration_test` -> no issues.
- `flutter test .\test\unit\create_controller_test.dart` -> pass (`+3`).
- `flutter test .\test\widget\create_page_test.dart` -> pass (`+1`).
- `flutter test` -> pass (`+22`).
