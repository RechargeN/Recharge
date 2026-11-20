# IDP/M2 integration — CP2, 2026-11-20

Status: local/mock implementation verified; owner acceptance pending. Dependency: CP1 `aa20ed60`; ADR 0023 reconciliation amendment `00af72fa` preserves main spec history.

## Publisher coverage

Canonical `draft_publisher.dart` supplies the effective publisher and capture/restore rules. New controller drafts capture the active Personal/Page publisher once; workspace switches update only the default for the next draft. Existing draft identity is not recomputed. Event supplies the identity lifecycle pattern; Event schedule/admission policies are not generalized to other types.

| Type | Persisted publisher | Personal/Page fresh, switch, save, restore | Template copy | Duplicate |
|---|---|---|---|---|
| Event | typed Event + envelope | yes | Event templates | not exposed |
| Place | typed Place + envelope | yes | not exposed | not exposed |
| Activity | typed Activity + envelope | yes | not exposed | not exposed |
| Find People | typed FindPeople + envelope | yes | not exposed | not exposed |
| Rental | typed Rental + envelope | yes | Rental templates | Rental duplicate |
| Collection | typed Collection + envelope | yes | not exposed | not exposed |
| Session | envelope | yes | not exposed | not exposed |
| Scenario | envelope | yes | not exposed | not exposed |
| Route | typed Route + envelope | yes | not exposed | not exposed |
| Class/Workshop | envelope | yes | not exposed | not exposed |

Evidence: `create_publisher_defaults_test.dart` loops over all ten types and both publishers, persists and restores across workspace changes. `create_draft_model_test.dart` tests missing legacy identity for all ten, stored Route identity and conflicting typed/envelope identities. Missing/ambiguous identity requires selection and never derives ownership from organizer/name. `create_template_test.dart` covers supported copies, distinct new ids even at the same instant, source immutability, owner scope, and rejection of unsupported copy APIs. This does not add eight new template products.

## Access matrix

| Actor / operation | Allowed | Denied / revalidated | Evidence |
|---|---|---|---|
| User, Personal free Create | Fresh matching access capability; no identity verification role gate | Missing/stale/foreign access, claimed caller capabilities | identity_access_guards; identity_router_guards |
| User, risky paid/booking/rental/money | Relevant capability plus verification fact | Free boolean cannot bypass typed paid Event mode, even zero price; internal booking requires verification | create_publish_guards |
| Exact Page publisher | Current exact-page active membership, capabilities and verification | Foreign Page, revoked/inactive membership; stored publisher remains unchanged | identity_access_guards; create_publish_guards |
| Existing personal-only publication products | Existing product policy retained | Page capture does not grant Session/Scenario/Route/Class publication | product publication tests and Route policy |
| Admin tools | Admin actor and dedicated capability | Personal/Page workspace and Admin preview cannot grant authority; Page is not Admin publisher | admin_tools_page; identity_router_guards; identity_access_guards |
| Admin preview | Presentation only, current loaded Admin access | Loading/error/account switch/revocation clears authority and preview; transient same-user auth recovery preserves workspace/route | identity_workspace_usecase; identity_router_guards |
| Page creation / quota | Zero initial pages; local owner membership; first three; pending idempotent request and durable notifications | Fourth create denied; exact owner storage, concurrent writes/foreign actor fenced; unavailable Page falls back safely | identity_workspace_usecase; workspace_section |

Application actions reload access rather than trusting the screen snapshot. Router redirect revalidates protected entries; destination Consumers watch capability providers. CP1 AUTH-ROT-02 and redirect-loop tests are retained. Production/backend grants and verification decisions are outside this checkpoint. The default local fixture is explicitly Admin, not a production access source.

## Fresh gates

- Focused CP2: 130 passed, exit 0 (`CP2-focused1.log/.exit`); one additional unsupported-template test then included in the full run.
- `flutter analyze --no-pub`: no issues, exit 0 (`CP2-analyze.log/.exit`).
- `flutter test --no-pub --reporter expanded`: 2691 passed, 83 existing skips, zero failures, exit 0 (`CP2-flutter-full.log/.exit`).
- `git diff --check`: exit 0.

Logs are in `outputs/IDP-M2-ONMAIN-2026-11-20`. Boundary inventory remains untouched until the single CP5 regeneration. Full-spec production/backend criteria are not closed by these local tests; final review requires CP3–CP5 and exact-HEAD Linux CI. No push/device/cloud action.

## Rollback

Revert the CP2 implementation commit independently; spec amendment is separately revertible as `00af72fa`. Existing data is read without workspace-based publisher migration. Compatibility declarations remain pending combined-tree zero-reference proof.
