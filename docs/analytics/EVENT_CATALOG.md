# Event Catalog

Status legend: `active` | `deprecated` | `removed`

## Required Columns

Every event entry must include:

- event_name
- version
- status
- feature
- trigger
- required_params
- business_owner
- technical_owner
- replacement_event (if deprecated)
- removal_date (if deprecated/removed)

## Current Events

| event_name | version | status | feature | trigger | required_params | business_owner | technical_owner | replacement_event | removal_date |
|---|---:|---|---|---|---|---|---|---|---|
| auth_screen_viewed | 1 | active | auth | auth screen rendered | `source_screen,source_action,locale` | TBD | TBD | - | - |
| auth_gate_viewed | 1 | active | auth | guest triggered protected action and auth gate opened | `source_screen,source_action` | TBD | TBD | - | - |
| auth_sign_in_started | 1 | active | auth | submit pressed and local validation passed | `source_screen,source_action,auth_method` | TBD | TBD | - | - |
| auth_sign_in_succeeded | 1 | active | auth | login succeeded and session persisted | `auth_method,user_role_before,user_role_after` | TBD | TBD | - | - |
| auth_sign_in_failed | 1 | active | auth | login failed | `auth_method,error_code,error_group` | TBD | TBD | - | - |
| auth_session_restore_started | 1 | active | auth | splash found refresh token and restore started | `had_refresh_token,source_screen` | TBD | TBD | - | - |
| auth_session_restore_succeeded | 1 | active | auth | restore pipeline completed successfully | `restore_result,user_role_after` | TBD | TBD | - | - |
| auth_session_restore_failed | 1 | active | auth | restore pipeline failed and user became guest | `restore_result,error_code,error_group` | TBD | TBD | - | - |
| auth_session_expired_shown | 1 | active | auth | session-expired message/sheet shown | `source_screen` | TBD | TBD | - | - |
| auth_sign_out_started | 1 | active | auth | sign-out action initiated | `source_screen` | TBD | TBD | - | - |
| auth_sign_out_succeeded | 1 | active | auth | local/session sign-out completed | `result` | TBD | TBD | - | - |
| auth_sign_out_failed | 1 | active | auth | sign-out endpoint failed but flow handled | `error_code,error_group` | TBD | TBD | - | - |
| discover_feed_loaded | 1 | active | discover | discover feed response received | `result,source,error_code?` | TBD | TBD | - | - |
| discover_filter_applied | 1 | active | discover | user applies filters | `filter_count,result` | TBD | TBD | - | - |
| discover_details_opened | 1 | active | discover | details page opened | `object_type,object_id,source` | TBD | TBD | - | - |
| map_radius_updated | 1 | active | discover | map radius changed | `radius_km,source` | TBD | TBD | - | - |
| create_draft_saved | 1 | active | create | draft save succeeded/failed | `draft_type,result,error_code?` | TBD | TBD | - | - |
| create_publish_submitted | 1 | active | create | publish request started | `entity_type,source` | TBD | TBD | - | - |
| create_publish_completed | 1 | active | create | publish response completed | `entity_type,result,error_code?` | TBD | TBD | - | - |
| explore_settings_updated | 1 | active | explore | settings update action | `setting_key,result,error_code?` | TBD | TBD | - | - |
| explore_role_switched | 1 | active | explore | role switch action | `from_role,to_role,result,error_code?` | TBD | TBD | - | - |

## Update Checklist For New Event

- [ ] Event name follows taxonomy naming convention.
- [ ] Required common parameters included.
- [ ] Business and technical owners assigned.
- [ ] Event version initialized or bumped.
- [ ] Dashboard/consumer impact reviewed.
