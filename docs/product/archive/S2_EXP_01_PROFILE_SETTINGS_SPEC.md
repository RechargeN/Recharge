# S2-EXP-01 Profile + Settings Spec

Status: Done (checkpoint fixed)  
Date: 2026-04-18

## Scope

- Profile basic view/edit.
- Settings basic controls.
- Auth-gated access for profile/settings routes.

## Approved Decisions

1. `Profile` editable fields:
   - `displayName`
   - `about`
   - `city`
   - `avatar`
2. `Profile` read-only fields:
   - `email`
   - `userId`
   - `currentRole`
3. `Settings` MVP:
   - `language`
   - `currency`
   - `notifications` on/off
   - `logout`
   - `support/help`
   - `privacy policy` link
   - `terms of service` link
4. Guest to `/profile` or settings uses auth gate with return to origin after sign-in.
5. Persistence:
   - sensitive values: secure storage
   - profile/settings UI values: local persistent storage
6. Role system:
   - show current role
   - role-based UI branching only
   - no upgrade flow in this slice
7. Git execution branch for this slice: `feature/s2-exp-01`.

## Out Of Scope

- Role upgrade flow
- Account deletion
- Password/email change
- Payment settings
- Connected accounts
- Advanced privacy controls

## Definition Of Done (Target)

- Profile page supports read + edit for approved fields.
- Settings page supports approved controls and persistence.
- Guest cannot access protected profile/settings actions without auth gate.
- Route return after sign-in preserves origin.
- Unit and widget tests added for profile/settings controllers and key page states.
- Analyze/tests for touched scope pass.

## Checkpoint Verification (2026-04-18)

- `dart analyze lib\features\explore\application\controllers\explore_controller.dart` -> no issues
- `dart analyze lib\features\explore\presentation\pages\profile_page.dart` -> no issues
- `dart analyze lib\features\explore\presentation\pages\settings_page.dart` -> no issues
- `dart analyze lib\app\router\app_router.dart` -> no issues
- `dart analyze lib\app\di\service_locator.dart` -> no issues
- `flutter test .\test\unit\explore_controller_test.dart` -> passed (`+3`)
- `flutter test .\test\widget\settings_page_test.dart` -> passed (`+1`)
