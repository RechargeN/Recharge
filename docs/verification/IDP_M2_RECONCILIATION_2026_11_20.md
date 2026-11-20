# IDP-03A/04A/05A and architecture M2 — final reconciliation, 2026-11-20

Status: CP0–CP5 local implementation/gates verified; exact-HEAD Linux CI pending. Owner alone sets Done. This is architecture M2,
not R1 M2 acceptance. Main remains `78d6a386` (live GitHub recheck: unchanged).
Branch: `codex/idp-m2-on-main-20261120`; no push or main merge performed.

## Checkpoints and command evidence

| Checkpoint | Commit | Complete local evidence |
|---|---|---|
| CP0 | safety WIP86218542 + three pre-rebase safety tags | Input journal, original PR10/11 preserved |
| CP1 | aa20ed60 | analyze0; full2684 pass/83skip; diff0; semantic conflict journal |
| spec amendment | 00af72fa | main spec retained plus explicit ADR0023 reconciliation |
| CP2 | 8ccc9097 | analyze0; full2691 pass/83skip; diff0; ten types/access matrix |
| CP3 | 45eda2d6 | analyze0; full2713 pass/83skip; boundary0; diff0 |
| CP4 | c78101f5 | analyze0; full2713 pass/83skip; boundary0; diff0; zero proof and archive |
| CP5 | final manifest | analyze0; full2713 pass/83skip; boundary self-test/scan/drift0; diff0; exact-HEAD CI pending |

All full commands ran from `apps/mobile` with Flutter3.44.9/Dart3.12.2 via the
installed flutter_tools snapshot, FLUTTER_ROOT=C:/src/flutter. Exit0 is measured,
not inferred from the last line. Existing 83 stand/platform skips were retained;
no timeout, skip or golden-baseline widening. The six checkpoint plans, logs and
explicit .exit files are in `outputs/IDP-M2-ONMAIN-2026-11-20/`.

Evidence command legend (G1–G6 is expanded here rather than an unexplained test label):

- **G0:** `git log --oneline --reverse 78d6a386..HEAD`; CP0 journal/CP1 commit map
  and conflict journal; Approved plan §13; exact current HEAD is FINAL-HEAD.json.
- **G1:** `flutter analyze --no-pub` and **complete**
  `flutter test --no-pub --reporter expanded`; exact invocation used
  `C:/src/flutter/bin/cache/dart-sdk/bin/dart.exe C:/src/flutter/bin/cache/flutter_tools.snapshot ...`.
  Per-checkpoint *.log and *.exit outputs above. Named test files below identify
  cases included in the complete run; isolated green tests are not substitutes.
- **G2:** `dart tools/scripts/check_boundaries.dart --repo-root . --self-test`;
  one `--format markdown --output docs/architecture/MOBILE_BOUNDARY_INVENTORY.md`
  regeneration; read-only `--check-output` and `--format text`. Generator report:
  710 files, 69/71 active exceptions, violations/stale/expired0; exit0.
- **G3:** `python tools/scripts/audit_m2_static_evidence.py` → CP5-static-evidence.json: exact Git comparison to merged main, import
  inspection of shared/domain code and historical M2-A registry objects.
  `git diff --quiet 78d6a386 -- apps/backend infra packages/api_contracts AGENTS.md`
  exits0; registry also unchanged. Static facts are assertions with captured output.
- **G4:** `python tools/scripts/audit_m2_references.py --self-test`, then
  `--label cp4-zero-before-removal` **before** removal and `--label cp4-final-tree`
  after; resolved Market command `dart tools/scripts/audit_m2_market_references.dart
  outputs/IDP-M2-ONMAIN-2026-11-20/CP4-market-final-zero-before-removal.json`.
  Pre-reference1372 files/zero consumers, retained declarations present; Market
  resolved1365 units/canary2/refs0/unresolved0. Final token inventory1366 files,
  no declarations/aliases/forwarding reliance. Archive receipt22 verified hashes.
- **G5:** `python tools/scripts/audit_m2_temporal_boundaries.py --output
  outputs/IDP-M2-ONMAIN-2026-11-20/CP4-temporal-inventory.json`: 257 classified
  reader/fallback entries, permissive UTC readers0; file:line/context/decision
  retained for each entry. Required feature legacy inheritance is explicit;
  active configuration cannot be passed to restore codecs after CP4.
- **G6:** `git diff --check`; source-only Dart formatting; CP5 final gate manifest
  and external GitHub Actions exact-SHA result (not yet available).

## All ten Create types × five lifecycle paths

`draft_publisher.dart` is the sole effective-publisher/capture reader; Event is
the identity lifecycle reference, not a schedule/paid-policy template for other
types. The common versioned envelope covers types without a typed publisher.

| Type | Fresh Personal/Page | Template copy | Duplicate | Restore/workspace switch | Legacy |
|---|---|---|---|---|---|
| Event | PASS capture once | PASS new capture; source unchanged | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit typed+envelope; unknown/conflict requires selection/refuses publish |
| Place | PASS capture once | N/A existing surface; API refuses unsupported type | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit typed+envelope; unknown/conflict requires selection/refuses publish |
| Activity | PASS capture once | N/A existing surface; API refuses unsupported type | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit typed+envelope; unknown/conflict requires selection/refuses publish |
| Find People | PASS capture once | N/A existing surface; API refuses unsupported type | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit typed fields+envelope; unknown/conflict requires selection/refuses publish |
| Rental | PASS capture once | PASS new capture; source unchanged | PASS Rental duplicate; new capture/id | PASS stored publisher unchanged | PASS preserve explicit typed+envelope; unknown/conflict requires selection/refuses publish |
| Collection | PASS capture once | N/A existing surface; API refuses unsupported type | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit typed+envelope; unknown/conflict requires selection/refuses publish |
| Session | PASS capture once | N/A existing surface; API refuses unsupported type | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit envelope; unknown/conflict requires selection/refuses publish |
| Scenario | PASS capture once | N/A existing surface; API refuses unsupported type | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit envelope; unknown/conflict requires selection/refuses publish |
| Route | PASS capture once | N/A existing surface; API refuses unsupported type | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit typed+envelope; unknown/conflict requires selection/refuses publish |
| Class/Workshop | PASS capture once | N/A existing surface; API refuses unsupported type | N/A existing surface | PASS stored publisher unchanged | PASS preserve explicit envelope; unknown/conflict requires selection/refuses publish |

Evidence: `create_publisher_defaults_test.dart` loops ten types × Personal/Page;
`create_draft_model_test.dart` covers all ten missing legacy identities and
stored Route/conflicting envelopes. `create_template_test.dart` covers actual
Event/Rental templates, Rental duplicate, foreign owners, source immutability,
unsupported copy APIs and same-instant distinct ids. No eight new copy products
or generic Publish-as picker were added. Unknown legacy identity is deliberately
blocked rather than guessed; this does not claim the full production IDP-AC10
publisher-choice UX is shipped. Existing personal-only publication policies for
Session/Scenario/Route/Class are retained even when their envelope captures Page.

## Personal / Page / Admin and IDP review criteria

| Criterion/action | Evidence and result | Local status |
|---|---|---|
| Zero initial pages; user creation; owner membership | identity_workspace_usecase: default fixture has0; verified User creates first3; active owner membership; permanent ids | PASS |
| Limit3 and extension request | fourth create refused; pending request idempotent; concurrent retry/actor fencing | PASS |
| Notifications and owner storage | durable idempotent local events, recipient/owner scope, account switch isolation | PASS |
| Exact Page and fallback | PageA membership does not grant PageB; revoked/suspended membership and stale actor denied; Personal safe fallback | PASS |
| Personal free User | activeCreateCapabilitiesProvider and real router regressions: zero-page ordinary User retains Personal Create; risky Event modes still require facts | PASS |
| Page submit/direct action | latest repository access, exact publisher/membership/capability; unavailable/revoked/foreign Page refused without changing draft publisher | PASS |
| Admin tools | separate Admin+capability surface; nonAdmin with capability and Admin without capability denied; Page cannot act as Admin publisher | PASS |
| Admin preview | presentation only; no authority/WorkspaceRef/PublisherRef change; revocation/account switch clears protected surface | PASS |
| Open-screen revocation, deep links, stale snapshots | identity_access_guards / identity_router_guards / admin_tools_page; redirect settles without loops; direct actions revalidate | PASS |
| AUTH-ROT-02 recoverable guest | same-user temporary guest preserves Page workspace/route while active authority is null; different actor/logout clears authority | PASS |
| Protected Event contract | cp1_event_contract_regression: exact paid/free main payload bytes, legacy EventMoneyDraft amount/currency, date validity incl0000 refusal and unchanged length bounds | PASS |
| Protected UTC transport/debug route | cp3_protected_utc_regression + real router .000Z route; establish/readCurrent/refresh, intentional invalid UTC refusal, expiry not bypassed | PASS |
| Full gates | fresh CP1–CP5 complete runs above; exact-HEAD Linux CI pending | LOCAL PASS / CI BLOCKED |
| A34 signin before main merge | explicitly assigned to Claude by owner; Codex did not touch phone | OWNER GATE |

Canonical references: Accepted ADR0015/0016/0017 as superseded by Accepted
ADR0023; main IDENTITY_PUBLISHER_SLICE_SPEC plus separate §18 amendment. Local
mock Admin fixture describes bounded test access; no production grants, real
verification decisions, quota approvals or Page publication authority added.
Full-product production/backend acceptance criteria are not closed by this work.

## M2 AC01–40 → command/output → commit → status

| AC | Criterion | Evidence (commands G0–G6 above and output) | Commit/tree | Status |
|---|---|---|---|---|
| AC-01 | M2 выполняется slices A–E, а не одним bulk rewrite. | G0: separate CP0–CP5 plans and commits; source stack transferred one by one | aa20ed60; 00af72fa; 8ccc9097; 45eda2d6; c78101f5 | PASS_LOCAL |
| AC-02 | Ни один runtime slice не начинается без принятия этого плана. | G0: Approved plan acceptance record §13 retained before runtime slices | 6f00b2f8; aa20ed60 | PASS_SCOPE |
| AC-03 | Shared primitive не импортирует framework/infrastructure. | G3: sharedFrameworkInfrastructureImports=[] | c78101f5 tree | PASS_LOCAL |
| AC-04 | Feature policy не переносится в shared primitive. | G3 + G1: no feature/app imports in shared; DST/GTFS/free/publisher policy remains feature-owned | 45eda2d6; c78101f5 | PASS_LOCAL |
| AC-05 | M2 не создаёт backend/Firebase runtime. | G3: forbiddenScopeChanges=[]; backend/infra/contracts/AGENTS diff empty | c78101f5 tree | PASS_SCOPE |
| AC-06 | Exception budget никогда не увеличивается. | G3/G2: unchanged registry; budget71, active69; no increase | 6f00b2f8; c78101f5 | PASS_LOCAL |
| AC-07 | M2-A удаляет ровно BND-LEGACY-0060–0094. | G3: m2aExactlyExpected35=true, exact IDs0060–0094 | 6f00b2f8 | PASS_HISTORICAL_RECHECKED |
| AC-08 | После M2-A budget равен 71 при отсутствии иных изменений. | G3: M2-A budget106→71; current69 under71, two removals already in main | 6f00b2f8; 78d6a386 | PASS_RECONCILED |
| AC-09 | Geo semantics WGS 84/elevation остаются совместимыми. | G1 shared_geo_primitives_test / geo_foundation_test: WGS84/elevation/serialization fixtures pass | 6f00b2f8; c78101f5 tree | PASS_LOCAL |
| AC-10 | Geo algorithms deterministic на прежних fixtures. | G1 Geo deterministic distance/encoding/hash/bounds fixtures pass | 6f00b2f8; c78101f5 tree | PASS_LOCAL |
| AC-11 | Domain импортирует Geo только из shared primitives. | G3: domainLegacyGeoImports=[]; G4 forwardingReliance0 production/tests/exports | c78101f5 | PASS_LOCAL |
| AC-12 | Generator interface не зависит от `uuid` package. | G3: IdGenerator interface imports=[]; G1 shared_id_generator_contract_test passes | 6f00b2f8; c78101f5 | PASS_LOCAL |
| AC-13 | UUID implementation остаётся composition dependency. | G3: UUID/ULID retained in core implementation; explicit show imports, dependency-free shared interface | c78101f5 | PASS_LOCAL |
| AC-14 | `loc_*` не проходит permanent-ID validation. | G1 scenario_draft_validation_test rejects temporary ids; validate_route_draft_usecase_test; collection/route materialization tests pass | c78101f5 tree | PASS_LOCAL |
| AC-15 | Identity domain не импортирует Flutter-facing experience. | G3: identityDomainPresentationImports=[]; G1 identity workspace state/preview tests pass | 6f00b2f8; 8ccc9097 | PASS_LOCAL |
| AC-16 | Money хранит integer minor units + currency metadata. | G1 money_primitive_test / money_test / money_consumers_test: integer range and exact metadata; strict subtotal reads | aa20ed60; 45eda2d6 | PASS_LOCAL |
| AC-17 | CurrencyCode нормализуется и валидируется структурно. | G1 currency code cases in money_primitive_test; structurally invalid/unknown metadata typed refusal | aa20ed60; 45eda2d6 | PASS_LOCAL |
| AC-18 | Money arithmetic запрещает неявное смешение валют. | G1 money_primitive_test arithmetic and minorUnitsIn currency mismatch refuse | aa20ed60 | PASS_LOCAL |
| AC-19 | Decimal input не проходит через binary floating-point. | G1 money_parser_test / money_consumers_test: decimal text parsed exactly, no binary-float input path | aa20ed60 | PASS_LOCAL |
| AC-20 | Excess scale даёт typed validation, не silent rounding. | G1 money_parser_test / money_legacy_adapter_test: excess scale typed error, explicit rounding only | aa20ed60 | PASS_LOCAL |
| AC-21 | Legacy `double` читается только migration adapter. | G1 money_legacy_adapter_test / create_temporal_persistence_test; legacy number/object reader retained only in data adapter | aa20ed60; 45eda2d6; c78101f5 | PASS_LOCAL |
| AC-22 | Current writers не создают normalized `double` amounts. | G1 create/Discover/Library/QuickPlan Money mapper tests: current writers keep integer minor-unit keys; paid/free Event bytes match main | aa20ed60; c78101f5 | PASS_LOCAL |
| AC-23 | Free semantics не выводится универсально из нулевой суммы. | G1 create_publish_guards_test paid-zero Event cannot fake free; Activity/Scenario free knowledge remains explicit feature state | 8ccc9097; c78101f5 | PASS_LOCAL |
| AC-24 | Multi-currency total не вычисляется без rate snapshot. | G1 scenario_draft_validation / scenario_create_integration / collection budget tests: currency subtotals and explicit FX snapshot policy | aa20ed60; 45eda2d6 | PASS_LOCAL |
| AC-25 | EUR exponent 2 покрыт boundary/property tests. | G1 money primitive/parser/formatter/legacy boundary-property EUR exponent2 tests pass | aa20ed60 | PASS_LOCAL |
| AC-26 | Money M2 завершён до M8 remote writes. | G1 Money migration verified on combined tree; G3 no new backend/M8 enablement. Existing separately approved main adapters preserved; no claim of M8 completion | aa20ed60; c78101f5 | PASS_DEPENDENCY_BOUNDARY |
| AC-27 | LocalDate не маскируется под UTC instant. | G1 local_date_primitive_test; Class/Place/Visit calendar readers use LocalDate; UTC calculator is internal only | 45eda2d6 | PASS_LOCAL |
| AC-28 | UtcInstant fail closed для non-UTC input. | G1 utc_instant_test / cp3_protected_utc_regression_test: .000Z accepted, +00:00/zoneless/impossible timestamps deliberately refused | 45eda2d6 | PASS_LOCAL |
| AC-29 | Persisted schedule хранит UTC + IANA zone. | G1 cp3_temporal_boundary_regression_test AC29/35 + create_temporal_persistence + Event/Session/Scenario mapper tests; G5 no permissive UTC readers | 45eda2d6; c78101f5 | PASS_LOCAL |
| AC-30 | DST gap/overlap outcomes детерминированы тестами. | G1 Event timezone/materialization, Session preview and Class DST/fold tests pass; GTFS >24h service date kept feature-owned | 45eda2d6; c78101f5 tree | PASS_LOCAL |
| AC-31 | Visit date использует timezone Place. | G1 visit_history_repository_test + visit facade/widget tests: Place-zone today, no Riga fallback, owner/place/day idempotency and v2 reads | aa20ed60; 45eda2d6 | PASS_LOCAL |
| AC-32 | LocaleTag не означает готовность l10n. | G1 locale_tag_test + l10n boundary tests; locale tags do not claim UI/legal localization readiness | 45eda2d6; c78101f5 | PASS_SCOPE |
| AC-33 | MarketRef использует stable ID, не display name. | G1 market_ref_test / market_config_test; stable IDs, explicit Catalog namespace bridge; unknown market refused | 45eda2d6; c78101f5 | PASS_LOCAL |
| AC-34 | Mapper не угадывает market/currency/timezone. | G1 cp3_temporal_boundary_regression_test AC34; G5 each fallback classified; active-config arguments removed from restore APIs after zero refs | 45eda2d6; c78101f5 | PASS_LOCAL |
| AC-35 | Unknown/invalid primitive даёт typed failure. | G1 cp3_temporal_boundary_regression_test AC35 / protected UTC / primitive/mapper regressions: typed refusal, no normalizing calendar or truncating money | 45eda2d6; c78101f5 | PASS_LOCAL |
| AC-36 | Compatibility read не выполняет скрытый destructive rewrite. | G1 create_temporal_persistence / templates / Visit v2 / Scenario snapshots tests: corrupt originals retained, original payload bytes retained with no destructive rewrite; legacy identities never rewritten from workspace | 45eda2d6; c78101f5 | PASS_LOCAL |
| AC-37 | Legacy declaration удаляется только при zero references. | G4 pre-removal1372-file zero + resolved Market1365 units/canary2; archive22 hashes; post-tree1366-file zero and full analyze clean | c78101f5 | PASS_LOCAL |
| AC-38 | Полный analyzer/test/boundary/diff CI зелёный для каждого slice. | G1/G2/G6 local complete gates green through CP4; CP5 fresh analyze0/full2713 pass83skip and boundary/diff0. Exact final HEAD Linux Actions requires authorized publication | c78101f5 code tree; final HEAD manifest | BLOCKED_EXACT_HEAD_CI |
| AC-39 | LAUNCH_STATUS обновляется только после evidence. | G0/G6: only authorized IDP/M2 rows updated from measured gates; no new Done promotion; final CI/owner gates explicit | CP5 documentation commit; exact HEAD in FINAL-HEAD.json | PASS_RECONCILED_PENDING_CI |
| AC-40 | M2 Done не утверждает backend или production readiness. | G3 forbidden scope empty; explicit no backend/production/R1 readiness promotion | c78101f5 tree | PASS_SCOPE |

## Boundary debt reconciliation

The supplied old list had71 exceptions. Main already removed BND-LEGACY-0023
(Discover map→Create taxonomy) and BND-LEGACY-0051 (Scenario builder→Create
taxonomy). Current69 entries are all active with exact fingerprints; budget71
was not raised. Registry was not edited. Inventory was generated once after
cleanup, not manually merged. `CP5-boundary-debt-matrix.csv` lists each active
ID/source/target/rule/owner/targetSlice/fingerprint/status; generator exit0 and
zero stale/expired findings validate that status. Twelve composition exceptions
remain assigned to MOB-ARCH-M3-COMPOSITION; the other57 remain in their existing
BND-REM target slices. They are live architecture debt, not falsely marked Done.

## Blockers / explicit limits

1. Exact final HEAD Linux Actions is not available until the owner authorizes
   push of this new branch and a draft PR. The attached plan §4.3 explicitly
   reserves that publication permission. No old PR was force-pushed or closed.
2. Before any main merge, Claude must perform the owner's A34 signin check for
   the protected UTC transport change. No install/clear/signout/logcat action
   was performed by Codex.
3. Owner acceptance/Done and the fate of old PR4/10/11 remain owner decisions.
   Current local proof does not accept cloud, staging, production or R1 M2.
4. Unknown/unproven legacy publisher remains selection-required and cannot
   publish. This bounded capture/non-rewrite scope does not implement the full
   future Publish-as UX or new template products. Required legacy data readers
   remain intentional contracts, not zero-reference dead wrappers.

## Rollback

CP4 removal commit is `c78101f558d92bf2227d783333f096bbb41d6034`.
`git revert c78101f558d92bf2227d783333f096bbb41d6034` restores the coherent
compatibility tree; CP3 source is `45eda2d6`. Each of30 removed items is listed
with archive path/proof/removal commit/rollback in
[removal matrix](IDP_M2_REMOVAL_ROLLBACK_2026_11_20.md).
CP3 can then be reverted independently for UTC/config changes; CP2 access changes
and spec amendment are separate commits. Safety tags preserve original PR10/11
and input WIP. No read-triggered storage rewrite or cloud migration needs undoing.
Re-run full gates after rollback. Main and foreign worktrees were not changed.
