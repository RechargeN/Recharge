# PVR-01 / 06 — regression and handoff

STAGE: 06; RESULT: **not_ready**; DATE: 2026-10-10 (Europe/Moscow).
TARGET_ROOT: C:/Users/User/.codex/worktrees/7275/Recharge.
HEAD input/output: 8c69715bba03eb1cef7309d4496ebfddd6d11a1e.
BRANCH input/output: codex/recharge-integration.

Локальные gates зелёные, но это не закрывает всю A/U матрицу. Главный найденный
блокер A12/PVR-AC-19: существующий Favorites contract не изолирует аккаунты.
Ни переход к 07, ни verdict Done для PVR-01 этой передачей не разрешаются.
Commit/push/merge/deploy/cloud, другие агенты и сообщения в чужие чаты отсутствуют.

## База, authority и WIP

Реальные передачи [00](00-baseline.md), [01](01-archive.md),
[02](02-decision.md), [03](03-spec-migration.md),
[04](04-presentation-access.md), [05](05-unified-ui.md) проверены по наличию,
содержанию, SHA и ссылкам. Master plan v2.3 §§10/15 прочитаны.
Target AGENTS.md v2026-10-10 и пользовательские инструкции применены;
реальные conditional consumers/storage/Create guards прочитаны без массовых edits.
[ADR 0021](../../adr/0021-unified-personal-profile.md) **Accepted**:
прямое принятие пользователем «Принимаю конкретный текст ADR 0021 и связанный
bounded scope плана §6.1/§13», а не только authoring_done.
ADR SHA: 5CEEF9575528B71DE454952D5DB82D9073C9ADE3F81B549471FC0526E5B88184.
Plan SHA: AA31BE37FF411BF96CB5F95E30E8405B20B8B86B3FE99A45F902EE5363CF1232.

Собственная дельта сравнивается с **входом 06**, не с HEAD: F01–F07 уже имели
uncommitted cutover 05; backend Media/tooling/schema/docs WIP чужой.
Входные копии, полный status input/output, hashes и own-delta.patch:
`C:/Users/User/AppData/Local/Temp/pvr06-sbx8y1gc`. Проверены 2057 tracked protected paths; кроме собственного
F07 (добавлен в разрешённую дельту после воспроизведения overflow) внешних
изменений от входа 06 не обнаружено. Untracked ADR/plan/архив/00–05 отдельно
hash-checked; общий индекс сохранён byte-prefix и только дополнен.
22 SHA-строки 05 проверены: runtime/tests/ADR/plan/guards совпали с входом;
два backend paths в таблице исторической дельты 05 содержат *до-05* hashes,
поэтому их regex comparison не является PVR mismatch. Backend не редактировался.

SHA предыдущих передач (не переписаны):
- `docs\verification\pvr-01\00-baseline.md`: `4759C8671AD6BE8BA91FAE5D1915B931EC0770E36933810894ACCCA0078262BE`
- `docs\verification\pvr-01\01-archive.md`: `665385299924F5BDC273812FE2C8AA0375DF477A0793152C568D1B924F1984F0`
- `docs\verification\pvr-01\02-decision.md`: `E2398DD24C2FC7964169078D460356C54ECB4DC4B09992AD7CA0B4BCAEA5BF57`
- `docs\verification\pvr-01\03-spec-migration.md`: `9D2F0E47B0E5FA584953A46AF96223EA98E5D9B67761775D2E3DA826D1953E00`
- `docs\verification\pvr-01\04-presentation-access.md`: `2FE5F84A9B77A8D837B4A28499DC176C020FD7896D4E8281BFEFFDA6DE63447D`
- `docs\verification\pvr-01\05-unified-ui.md`: `143D6F04F91D156207683D7024E3EB4A88D51420D46FFADA1A697EFBC0A05789`

## Исправленные конкретные ошибки

1. IdentityWorkspaceController.ensureLoaded: при A → B загрузке старый
accessSnapshot/page workspace/Admin preview оставались в loading и после
ошибки B. Новый delayed/error тест **сначала упал** (expected null, actual
IdentityAccessSnapshot; exit 1), затем прошёл. При смене userId загрузка
начинается с IdentityWorkspaceState.initial(); reload того же userId сохраняет
прежнее поведение. Guards, grants, storage и operation revision не изменены.
2. WorkspaceSection Create Professional Page dialog на 360 dp/150% дал
RenderFlex overflow: dropdown справа 287 px, Column снизу 182 px. Диалог теперь
scrollable; dropdown isExpanded, label с ellipsis. Тест с длинным page name
реально создаёт страницу, затем scroll/tap переключает обратно personal,
проверяет exact workspace ID, preview reset и отсутствие layout exceptions.

Также добавлены/усилены тесты limited active manager (страница A без owner
rights и без B), persisted workspace v3 двух аккаунтов с повторным созданием
repository/read-only storage comparison, Settings edit/save/preferences/logout
на 360 dp/150% с длинным именем. Не выдавались фиктивные grants ради прохождения.

**Собственные файлы:** 2 runtime + 4 tests, этот новый отчёт и append индекса.
F01–F06, app router/route_names/Settings runtime, access entities, Publisher,
Scenario/Visited/Favorites storage contracts не менялись.

| Path | SHA-256 после 06 |
|---|---|
| `apps/mobile/lib/features/identity/application/controllers/identity_workspace_controller.dart` | `57544A52ED54CD6D600BBBF9977DD68FB7A8512A76BD5C2C6ABF7973037FD3C0` |
| `apps/mobile/lib/features/identity/presentation/widgets/workspace_section.dart` | `09660B1EFFFE345C163FEBFDA95F550901ED14A52947AEA69E3B49E968C71C2A` |
| `apps/mobile/test/unit/identity_workspace_usecase_test.dart` | `E427B0CEB18A1878B74FA34D19D4A2289648170F21B28CAB1056DDC241AAFD97` |
| `apps/mobile/test/unit/identity_workspace_repository_test.dart` | `22AAD77834BA2B972ADB980F02505661022124639D3C0F2EEDBCCC098B8724BC` |
| `apps/mobile/test/widget/settings_page_test.dart` | `B3DFDE7E1CD7F628C1CCA8A7A902297E8E1B7DFE91278CF56D6B2E4233F85BF6` |
| `apps/mobile/test/widget/workspace_section_test.dart` | `92963CDBD505BDA50566B5E99B36925EE84B1A8349E268E077049B51A1D30841` |

## Команды и результаты

Working directory Flutter: `C:/Users/User/.codex/worktrees/7275/Recharge/apps/mobile`.
Исполняемые файлы: `C:/src/flutter/bin/flutter.bat`, `C:/src/flutter/bin/dart.bat`.
`--no-pub` использует существующий resolved lock; dependency changes отсутствуют.
Evidence logs в указанной входной копии 06; они не означают device/cloud evidence.

- Focused: `flutter test --no-pub test/unit/profile_role_summary_test.dart test/unit/identity_workspace_usecase_test.dart test/unit/identity_workspace_repository_test.dart test/widget/profile_page_test.dart test/widget/workspace_section_test.dart test/widget/professional_app_shell_test.dart test/widget/app_shell_test.dart test/widget/settings_page_test.dart test/widget/visited_places_page_test.dart test/unit/identity_notification_sink_test.dart test/unit/visit_history_repository_test.dart test/unit/visited_places_controller_test.dart test/unit/auth_controller_test.dart test/unit/auth_repository_impl_test.dart test/unit/create_controller_test.dart test/unit/scenario_create_integration_test.dart test/unit/create_exact_scenario_open_test.dart test/widget/favorites_page_test.dart`: **exit 0, 111 passed**, 21 s; `focused.log`.
- `flutter analyze --no-pub`: **exit 0, No issues found**, 172.1 s; `analyze.log`.
- `flutter test --no-pub`: **exit 0, 1322 passed / 20 existing skipped / 0 failed**, 4:08; `full-test.log`.
- Root `C:/Users/User/.codex/worktrees/7275/Recharge`: `dart tools/scripts/check_boundaries.dart --repo-root . --format text`: **exit 0**, 567 files / 71 existing suppressed / 0 violations / 0 stale / 0 expired; `boundary.log`.
- Root `git diff --check`: **exit 0**; только LF/CRLF warnings существующего WIP; `diff.log`. Новый untracked report отдельно проверен на trailing whitespace/links.
- Root `git status --short`: input/output сохранены; HEAD/branch прежние.
- Symbol scan `rg -n '_ViewerProfileBody|_ViewerUpgradeRow|_RoleTrack|PROFILE MODE|admin-preview-viewer|AccountExperience.viewer|AdminExperiencePreview.viewer' apps/mobile/lib`: **0 matches** (rg exit 1 означает отсутствие совпадений).

## A-матрица: фактическое покрытие и границы

| ID | Статус | Evidence / остаток |
|---|---|---|
| A01 | Не закрыт | Actual app_router redirect и SignIn origin-return прочитаны; auth-controller tests зелёные, но новый end-to-end no-session → origin route case не выполнен. Code review не выдан за route assertion. |
| A02 | Подтверждён local/mock | T01 ordinary User personal content/handoffs трёх scopes: Saved/Visited/Settings/Scenario exact ID; T02 User notStarted page create refusal, snapshot unchanged; T04 operation guard. |
| A03 | Частично | T04 реальные CreateProfessionalPageUseCase отказы для notStarted/pending/rejected/expired/revoked и успех verified; personal projection общая. Не заявляется полная UI/action матрица каждого publishing guard; blanket restriction не добавлен. |
| A04 | Подтверждён для page.create | T04 verified identity without page grant denied; missing capability не заменена title/preview. Другие операции только в существующих Create tests. |
| A05 | Подтверждён bounded actions | T01 Creator/generator listing/search/map/draft handoffs + Create controller guards; T05 verified page.create/quota. |
| A06 | Частично | Новый реальный controller delayed/error B case очищает authority/workspace/preview и запрещает preview; T04 unknown access fail closed. Не выполнены все Profile/Created/Settings UI error/loading transitions. |
| A07 | Частично | T05 controller preview сохраняет same snapshot; T01 scopes сохраняют existing draft publisher. Совместная реальная preview/switch + live Create controller связка не проверена (U14). |
| A08 | Подтверждён | T03 Admin page preview с 0 pages/memberships: page navigation и пустое Account; T02 explicit create только пользовательской страницы. |
| A09 | Подтверждён workspace/ownership | T05 selects/restores created page exact ID; T02 создаёт owner membership и возвращается personal; общий owner tools contract не изменён. |
| A10 | Подтверждён limited active manager | Новый T05 select page-0, no page.manage/ownedPages, page-1 throws, savedWorkspace остаётся page-0. Pending invited status не считается active; новые права не добавлены. |
| A11 | Подтверждён recovery/refusal | T05 revoked saved page falls back/repairs personal и unknown exact page throws. |
| A12 | **Не проходит полный контракт** | Identity A→B loading/error/retry исправлен и доказан, keys workspace двух аккаунтов изолированы. Favorites API/storage глобальны; настоящий logout/login A→B всех личных libraries не закрыт. |

## U-матрица

| ID | Статус | Evidence / остаток |
|---|---|---|
| U01 | Частично | T01 реальный Profile и один Creator layout доказаны; отдельный новый actual personal nav → Profile integration case не добавлен. T03/app_shell nav зелёные в своих fixtures. |
| U02 | Подтверждён | T01 direct ProfileWorkspace route и отсутствие PROFILE MODE/User/Pro selector; route continuation handoff. |
| U03 | Подтверждён сохранённый contract, A12 открыт | T01 Saved route; favorites_page 8 tests: existing item/filter/remove/empty/search handoffs. Межаккаунтная изоляция отсутствует в контракте. |
| U04 | Подтверждён | visited_places_page: User и Creator history, конкретный place details route, empty. |
| U05 | Подтверждён | visit_history_repository: selfReported/idempotency same day/two dates/future rejection/remove/corrupt+foreign filtering; прежний v2 storage. |
| U06 | Подтверждён | T01 unverified User открывает exact-owned-scenario, ownerId requests только creator_1; create_exact_scenario_open rejects foreign ID. |
| U07 | Подтверждён bounded handoff | T01 Create Scenario route с type=scenario и exact draft route; Create guards/personal Scenario integration зелёные; legacy builder не подставлен в этот handoff. |
| U08 | Подтверждён | T01 listing status/readiness, save/draft/published, Search/Map query params и smart-route intent. |
| U09 | Подтверждён | T01 incomplete draft continuation и historical legacy route-context handoff tests сохранены; старое naming не выбирает personal composition. |
| U10 | Частично | Усиленный Settings widget: edit longName → tap Save → persisted profile; toggle notifications → persisted setting → actual logout home route; repository повторно read. Новый reopen UI и actual Explore secure-storage keys case не выполнены. |
| U11 | Подтверждён bounded workspace/nav | T02 реальное создание page → personal через tap exact IDs/preview reset; T03 page nav Content/Account → Settings и personal preview/home. |
| U12 | Подтверждён | Новый repository case читает pre-PVR workspace schemaVersion 3 personal/page из отдельных keys, новый instance, storage bytes read-only unchanged. Existing managed-page v1/v2 migration tests также зелёные. |
| U13 | Подтверждён | T05 0/1/3 projection, create 1–3/deny4, pending request idempotence; T02 controller notifications2; identity_notification_sink durable/idempotent/moderator inbox. |
| U14 | **Не закрыт** | T01 существующий draft page publisher одинаков после presentation scope и handoffs. Это не реальный workspace switch связанный с active_create_publisher_provider; stronger fixture пока отсутствует. |
| U15 | Подтверждён | T02 ordinary User WorkspaceSection не имеет ChoiceChip/Admin preview и page.create; Settings inline composition прежняя. |
| U16 | Частично | T01 personal/workspace360/150%; Settings longName360/150% save/logout tap; T02 long page-name360/150% create/switch scroll/tap без exceptions. Не заявляются визуальные/device screenshots или все page shell variants. |

Empty states Profile Created/User, Favorites, Visit History, page preview покрыты.
Полные UI loading/error/retry/back для четырёх поверхностей **не закрыты**;
ни enum-only, ни прочитанный switch не переименованы в behavioral evidence.

## Данные и найденный блокер

Actual FavoritesLocalDataSource использует `favorites_items_v1` без user suffix;
FavoritesRepository.getFavorites()/add/remove не принимают userId;
FavoritesController.ensureLoaded() имеет общий _requestedOnce. Следовательно,
смена auth user сама по себе не создаёт изолированный Saved набор. Это старый
local/mock контракт, не доказанная новая регрессия cutover. Исправление требует
отдельного bounded scope для Favorites domain/repository/datasource/controller,
DI/auth lifecycle и migration/rollback ownership policy legacy key; эти файлы
не входят в разрешённые implementation файлы 06. Общую библиотеку нельзя
удалить, произвольно приписать B/A или «починить» фиктивными capabilities.

Тестовый двухаккаунтный workspace storage и limited memberships проверены,
Visited собственные IDs и Scenario owner scopes проверены раздельно.
Probe keys `unrelated-profile-account-a`/`unrelated-saved-account-a` в workspace
тесте — **только sentinels отсутствия побочного write**, не реальные Saved/Profile
repositories. Единой storage fixture с двумя аккаунтами, двумя memberships,
Saved/visit/private Scenario/existing publisher draft и настоящими auth+workspace
switches ещё нет; §10.3 не объявляется выполненным.

Future AccountStatus active/securityLocked/suspended/deletionPending/tombstoned:
**docs-only** transfer в Creator `#vp-15-1` / retirement map, Draft maturity
сохранена; существующий runtime не содержит полного соответствующего engine.
Это конкретное основание docs-only, не N/A для текущих auth/workspace проверок.

## PVR-AC verdict

| Критерий | Вердикт 06 |
|---|---|
| 07 | Подтверждён User/direct profile local/mock; personal-nav full integration остаток U01 |
| 08 | Подтверждены actual operation guards/unchanged snapshots; полная UI status матрица остаток A03/A06 |
| 09 | Подтверждён bounded existing Creator/listing handoff scope |
| 10 | Сохранение Saved/Visited contract подтверждено; A12 Saved isolation не закрыта |
| 11 | Подтверждён personal Scenario exact-owned library без verification gate |
| 12 | Частично: edit/save/logout да; reopen UI/real storage keys остаток U10 |
| 13 | Подтверждён runtime scan + T01 direct entries |
| 14 | Подтверждён T02/T03 no Viewer preview |
| 15 | Подтверждён bounded personal/page nav/Account/Settings |
| 16 | Подтверждён exact page/owner/limited manager/revoked recovery |
| 17 | Подтверждён read old workspace v3 без reset и page migrations |
| 18 | Не закрыт stronger actual workspace switch + existing draft case |
| 19 | Не закрыт: global Favorites contract и полный A12 fixture отсутствует |
| 20 | Частично: unknown/loading/error access guard; actual auth redirect round-trip case остаток A01 |
| 21 | Подтверждены описанные local widget360/150 states; полный набор вариантов не заявляется |

## Откат и следующий исполнитель

Восстановить **только собственные 6 paths** из входных копий `C:/Users/User/AppData/Local/Temp/pvr06-sbx8y1gc`
либо обратить own-delta.patch после проверки поздних edits. Удалить только
этот 06 report и appended06 index block; pre06 index сохранён в backup.
Не применять reset/clean и не откатывать storage пользователя. При полном отказе
от cutover использовать согласованный coordinated rollback05, а не архив вместо
поздних source. Архив raw не менялся.

Archive: `docs/archive/viewer-profile/2026-10-10/`, MANIFEST.md SHA
CE309F4E5BD8952A7AF4F0C4CADD4865396BCA6DDC12376AE2EC5C32C0DFF214.
PowerShell parser manifest (9 pipe cells, numeric bytes column) + exact
Join-Path archive base + Get-FileHash -Algorithm SHA256 / Get-Item.Length:
**65 rows, 0 missing/hash/size mismatch, 69 total files**.
Исторические original source hashes не сравнивались с уже изменённым cutover
как будто source обязан оставаться старым.

07 не начат. Для готовности 06 нужны реальная A01/auth-return проверка,
U14 actual active publisher integration, полный §10.3 fixture и перечисленные
UI reopen/error/back остатки; A12 требует явно согласованного расширения
Favorites/auth lifecycle scope с ownership migration policy. До этого 07/08
не должны считать A/U матрицу либо PVR-AC-18/19/20 закрытыми.
