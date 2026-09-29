# S1-AUTH-01 Spec

Status: Done (checkpoint fixed)  
Date: 2026-04-17

## Scope

This slice includes:

- guest mode entry and protected-action auth gate;
- sign-in (`email + password`);
- session restore on app start;
- expired-session handling;
- sign-out.

Out of scope:

- sign-up, social login, forgot password, MFA, creator upgrade flow.

## Confirmed Decisions

1. Lifecycle naming
   - Use `pending_review` (not `pending`) in lifecycle vocabulary.

2. Password validation (MVP)
   - Minimum length: **8**.
   - Must pass local validation before login request.

3. Logout behavior when offline
   - Local logout is treated as success.
   - Tokens and session metadata are cleared immediately.
   - UI transitions to guest mode without waiting for network.

4. Post-login protected-action behavior
   - `favorite`: auto-apply action after successful login.
   - `create` / `profile`: open requested target screen after login.
   - Origin route/context must be preserved.

5. Moderation auto-hide threshold
   - `>=5` unique reports per object within `24h`.

6. Analytics naming
   - Snake style with explicit `sign_in`: `auth_sign_in_*`.

## Auth Routing Contracts

- App start:
  - valid session -> authenticated discover hub,
  - no valid session -> guest discover hub.
- Protected action in guest:
  - open auth gate and preserve origin target.
- Login success:
  - return to origin target if present, otherwise default target contract.
- Logout:
  - transition to guest discover hub.
- Expired session:
  - show session-expired UI and transition to guest.

## API Contract Surface (MVP)

- `POST /v1/auth/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `GET /v1/auth/me`

Error handling must map stable auth codes (invalid credentials, revoked/expired refresh, rate limiting, etc.) to UI states.

## Test Requirements

Required:

- unit tests for auth use cases/controller/session rules;
- widget tests for sign-in states;
- integration tests for login success, restore session, and sign-out.

## Checkpoint Verification (2026-04-17)

- `flutter test .\test\widget\sign_in_page_test.dart` -> passed (`+1`)
- `flutter test .\test\unit\auth_controller_test.dart` -> passed (`+3`)
- `dart analyze test\widget\sign_in_page_test.dart` -> no issues
