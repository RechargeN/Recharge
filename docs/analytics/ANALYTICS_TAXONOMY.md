# Analytics Taxonomy

This document defines event naming, required parameters, ownership, and event lifecycle policy.

## 1) Naming Convention

Event name format:

`<feature>_<object>_<action>`

Rules:

- lowercase snake_case only;
- no generic names like `click`, `open`, `submit`;
- use domain-specific object names (`session`, `feed`, `filter`, `draft`, `publish`);
- one event = one business meaning.

Examples:

- `auth_session_restored`
- `auth_sign_in_succeeded`
- `discover_feed_loaded`
- `discover_filter_applied`
- `create_draft_saved`
- `create_publish_completed`

## 2) Required Common Parameters

Every event must include:

- `event_name`
- `event_version` (integer, starts at 1)
- `event_timestamp_utc` (ISO-8601)
- `app_version`
- `platform` (`android`/`ios`/`web`)
- `environment` (`dev`/`stage`/`prod`)
- `session_id`
- `user_id` (nullable when anonymous)

Recommended contextual parameters:

- `feature`
- `screen`
- `source`
- `result` (`success`/`failure`)
- `error_code` (if failure)

## 3) Ownership Model

Each event must have:

- business owner (product/feature owner),
- technical owner (engineering owner),
- status (`active`/`deprecated`/`removed`),
- deprecation plan if status is not `active`.

Ownership is registered in `EVENT_CATALOG.md`.

## 4) Privacy And Data Rules

- Do not send direct PII (email, phone, full name, exact address, message content).
- Use stable internal IDs instead of personal fields.
- If aggregation can replace raw detail, prefer aggregation.

## 5) Event Lifecycle Policy

### Active
- Event is valid and consumed by dashboards/alerts.

### Deprecated
- Event is still emitted temporarily for compatibility.
- Must include replacement event and removal date.

### Removed
- Event is no longer emitted.
- Catalog entry kept for history with removal date.

## 6) Change Rules

For any analytics event change:

1. Update `EVENT_CATALOG.md`.
2. Bump `event_version` when payload semantics change.
3. Update dashboards/consumers if impacted.
4. Mention analytics impact in PR.

## 7) Quality Checks

- New events without catalog entry are not allowed.
- Deprecated events without replacement/removal date are not allowed.
- Required common parameters must be present for all production events.
