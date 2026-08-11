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
| event_classification_archetype_selected | 1 | active | event_create | creator explicitly selects or confirms an archetype | `archetype,source,suggestion_reason?,suggestion_confidence?` | TBD | TBD | - | - |
| event_classification_primary_participation_selected | 1 | active | event_create | creator selects the primary attendee role | `mode` | TBD | TBD | - | - |
| event_classification_additional_participation_changed | 1 | active | event_create | creator adds or removes an additional attendee role | `mode,selected,count` | TBD | TBD | - | - |
| event_classification_cleared | 1 | active | event_create | creator explicitly clears classification | `status` | TBD | TBD | - | - |
| scenario_transit_action | 1 | active | scenario | official transit Apply/Replace is accepted or rejected, or Recheck completes | `action,result,freshness?` | TBD | TBD | - | - |
| scenario_object_intake_action | 1 | active | scenario | external Add to Scenario flow opens, previews, applies, cancels, retries or opens its target | `source_surface,action,result,batch_size_bucket,target_kind?,placement?,source_status?` | TBD | TBD | - | - |
| explore_settings_updated | 1 | active | explore | settings update action | `setting_key,result,error_code?` | TBD | TBD | - | - |
| explore_role_switched | 1 | active | explore | role switch action | `from_role,to_role,result,error_code?` | TBD | TBD | - | - |

`scenario_transit_action` is deliberately enum-only. Its payload allowlist is
`action`, `result`, and optional `freshness`; stop queries/names, trip/item/user
ids, dates, times, notes, URLs, digests and other Scenario content are forbidden.

`scenario_object_intake_action` is also deliberately enum/bucket-only. Its
payload allowlist is `source_surface`, `action`, `result`,
`batch_size_bucket`, optional `target_kind`, optional `placement`, and optional
aggregate `source_status`. Object/Scenario/intent/user ids, titles, notes,
queries, prompts, dates/times, coordinates, addresses, categories, URLs,
publisher names and revision numbers are forbidden.

All `event_classification_*` events are enum/status-only. Archetype and
participation values use the canonical closed enums; suggestion reason and
confidence use the application allowlist. Titles, descriptions, free-text
`otherReason`, category labels, organizer/publisher ids and draft ids are
forbidden.

## Update Checklist For New Event

- [ ] Event name follows taxonomy naming convention.
- [ ] Required common parameters included.
- [ ] Business and technical owners assigned.
- [ ] Event version initialized or bumped.
- [ ] Dashboard/consumer impact reviewed.
