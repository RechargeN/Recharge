# S3-NOTIF-01 Notifications List + Mark Read Spec

Status: Done  
Date: 2026-04-20

## Scope

- Protected `/notifications` screen for authenticated users.
- Local/mock notifications list for MVP.
- `mark read` action per single item.
- Open `targetRoute` on notification tap when route is present.

## Approved Decisions

1. Auth policy:
   - screen is protected by router/auth gate.
2. Data source:
   - local/mock storage, no backend push in this slice.
3. MVP actions:
   - list notifications,
   - mark one notification as read.
4. Notification types:
   - `system`,
   - `reminder`,
   - `activity`.
5. Open behavior:
   - if notification has `targetRoute`, open it after mark-read;
   - if route is absent, stay on notifications screen.

## Out Of Scope

- Push token lifecycle and real push integration.
- Mark-all-read action.
- Notification preferences deep settings.
- Backend delivery, pagination, and realtime updates.

## Definition Of Done (Target)

- `notifications` feature implemented in domain/data/application/presentation layers.
- `/notifications` route is wired and protected.
- Notification tap marks item as read and optionally opens target route.
- Unit tests for controller behavior are green.
- Widget test for page mark-read behavior is green.

## Verification Evidence (2026-04-20)

- `dart analyze lib\features\notifications` -> no issues.
- `dart analyze lib\app\router\app_router.dart` -> no issues.
- `dart analyze lib\app\di\service_locator.dart` -> no issues.
- `dart analyze lib\features\auth\presentation\pages\discover_hub_page.dart` -> no issues.
- `dart analyze lib\features\auth\presentation\pages\sign_in_page.dart` -> no issues.
- `flutter test .\test\unit\notifications_controller_test.dart` -> pass (`+2`).
- `flutter test .\test\widget\notifications_page_test.dart` -> pass (`+1`).
- `dart analyze lib test integration_test` -> no issues.
- `flutter test` -> pass (`+25`).
