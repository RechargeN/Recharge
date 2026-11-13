# PVR-01 verification index

2026-10-10. Target: C:/Users/User/.codex/worktrees/7275/Recharge;
branch codex/recharge-integration; HEAD 8c69715bba03eb1cef7309d4496ebfddd6d11a1e.

| Stage | Result | Evidence |
|---|---|---|
| 00 | ready для архива 01; PVR-AC-01 подтверждён | [Baseline / передача](pvr-01/00-baseline.md) |
| 01 | ready; PVR-AC-02/03 подтверждены | [Archive / передача](pvr-01/01-archive.md) |
| 02 | ready; authoring_done=true; decision_accepted=true; ADR 0021 Accepted | [Decision / передача](pvr-01/02-decision.md) |
| 03–08 | Не выполнялись | Отчётов нет |

Baseline: 56 профильных + 22 Create/Scenario tests passed, exit 0.
Boundary exit 0, 0 violations, 71 existing suppressions.
Full analyze/test, device/cloud и итоговые A/U gates не выполнялись.
Commands/cwd/WIP/hashes/action/storage map и ограничения — в передаче.
[Master plan](../product/VIEWER_PROFILE_RETIREMENT_PLAN.md) остаётся Proposed;
runtime не изменён, ADR 0015/0017 Accepted не редактировались. Архива ещё нет.

## SHA-256 итоговых документов

Self-hash индекса не включается в сам индекс.
- 00-baseline.md: 4759C8671AD6BE8BA91FAE5D1915B931EC0770E36933810894ACCCA0078262BE
- VIEWER_PROFILE_RETIREMENT_PLAN.md: EBE73441EC483F795F6A1BF4F863BE4F4D0E51DAAC0A0E4E2BCDE5FC652742E0

## Заход 01 — 2026-10-10

[Архив](../archive/viewer-profile/2026-10-10/README.md),
[manifest](../archive/viewer-profile/2026-10-10/MANIFEST.md),
[передача 01](pvr-01/01-archive.md).
65 raw snapshots + 4 guides; source/copy bytes/SHA-256 checked 65/65,
manifest completeness and runtime/package isolation passed. Sources/WIP intact.
No Flutter run needed for this archive-only stage; final behavior gates open.
Previous no-archive note is the state at stage 00, preserved as earlier evidence.
- 01-archive.md SHA-256: 665385299924F5BDC273812FE2C8AA0375DF477A0793152C568D1B924F1984F0

## Заход 02 — 2026-10-10

[ADR 0021](../adr/0021-unified-personal-profile.md): Proposed;
authoring_done=true, decision_accepted=false, RESULT=needs_user_decision.
[Передача 02](pvr-01/02-decision.md). PVR-AC-04 content checked docs-only;
принятие конкретного текста ещё требуется. Existing roles/access and runtime
не изменены; архив 01 и прежние ADR сохранены. План v2.2 связывает bounded scope.
Hashes плана/00/01 в ранних разделах относятся к моменту тех заходов;
новый live-plan hash ниже, старый archived snapshot не меняется.
- ADR 0021 SHA-256: 9444AE1F0F7C110D30F491C1991792550D59EB9F734B134B72D473D2A144D2C9
- Current plan v2.2 SHA-256: E8AB099FD6341A9DFC961E133D263D502A982B8E746F442FBF5C1651BB1796E0
- 02-decision.md SHA-256: 1259F992863DF44F2E38F1BE44D47C5B1919EA59AE5C7718611E6C9C21102A95


## Принятие захода 02 — 2026-10-10

Пользователь явно принял текст ADR 0021 и bounded scope §6.1/§13.
ADR Accepted; передача 02 ready. Ранние Proposed/pending записи и hashes
сохраняют состояние до принятия; текущие hashes ниже. Следующий заход не начат.
- Accepted ADR 0021 SHA-256: 5CEEF9575528B71DE454952D5DB82D9073C9ADE3F81B549471FC0526E5B88184
- Current plan v2.3 SHA-256: AA31BE37FF411BF96CB5F95E30E8405B20B8B86B3FE99A45F902EE5363CF1232
- Accepted 02 handoff SHA-256: E2398DD24C2FC7964169078D460356C54ECB4DC4B09992AD7CA0B4BCAEA5BF57


## Заход 03 — 2026-10-10 (текущее дополнение)

RESULT=ready; authoring_done=true; decision_accepted=true (ADR 0021).
[Передача 03](pvr-01/03-spec-migration.md),
[retirement map](../product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md).
Общая личная часть перенесена в Creator v1.11; базовая контекстная публичная
проекция — в Public Creator v1.10. 16 VP-D / 43 VP-AC сохраняют IDs и зрелость;
Open/Draft вопросы не приняты, личный доступ не стал verified-only.
PVR-AC-05/06/22 подтверждены docs-only. Viewer originals/архив не изменены;
runtime cutover и A/U post-cutover сценарии остаются последующим заходам.

Проверки: analyze exit 0 / no issues; полный mobile suite exit 0 / 1303 passed,
20 skipped; boundary exit 0 / 567 files / 71 прежний suppression / 0 violations;
bounded diff check exit 0; 122 anchors / 166 новых links / 0 ошибок;
архив 65/65 и protected hashes 3302/3302 без изменений.
Ранние 03–08 «не выполнялись» записи относятся к состоянию до этого дополнения.
Заходы 04–08 здесь не выполнялись; коммита/push/merge/deploy не было.
- 03-spec-migration.md SHA-256: 9D2F0E47B0E5FA584953A46AF96223EA98E5D9B67761775D2E3DA826D1953E00
- Retirement map SHA-256: 515B2E649D94E50E9FCE4423F9600B779CFA931F929877933EA83B3C72E3AB4B


## Заход 04 — 2026-10-10 (текущее дополнение)

RESULT=ready; compile-safe presentation/access preparation.
[Передача 04](pvr-01/04-presentation-access.md). Preview сохраняет actual
canCreate/canGenerate; общий Creator title/layout helper подготовлен отдельно
от operation authority. Full UI cutover и удаление enum не выполнены.
Focused: 48 + 13 + 10 passed; targeted/full analyze exit 0, no issues;
full mobile suite exit 0, 1313 passed / 20 прежних skipped / 0 failed.
Boundary exit 0: 567 files, 71 прежний suppression, 0 violations;
standard full/bounded diff checks exit 0; archive 65/65; protected 1018/1018.
PVR-AC-08/20 подтверждены только в описанном helper/guard scope;
post-cutover A/U matrix остаётся последующим заходам.
Ранние «04 не выполнялся» записи относятся к состоянию до этого дополнения.
Заход 05 не начат; commit/push/merge/deploy/cloud не выполнялись.
- 04-presentation-access.md SHA-256: 2FE5F84A9B77A8D837B4A28499DC176C020FD7896D4E8281BFEFFDA6DE63447D


## Заход 05 — 2026-10-10 (текущее дополнение)

RESULT=ready; coherent local UI cutover.
[Передача 05](pvr-01/05-unified-ui.md). Один личный Creator layout,
AccountExperience personal/professionalPage, Admin preview creator/professionalPage;
Viewer body/upgrade/fallback selector удалены. Saved/Visited/Scenario/Created,
Creator/generator tools и personal/page nav сохранены без новых grants/storage.
Focused: 18 widgets, 51 access/Create guards, 10 extra regression passed;
targeted/full analyze exit 0, no issues; полный suite exit 0,
1319 passed / 20 прежних skipped / 0 failed. Boundary 567 files / 71 прежний
suppression / 0 violations; standard diff check exit 0; архив 65/65.
2162/2164 protected files unchanged; два concurrent backend-script changes
вне собственной дельты отдельно зафиксированы в передаче.
PVR-AC-07/09/13/14/15 подтверждены в описанном local UI scope; полная A/U
регрессия и следующие gates остаются 06–08. Ранние «05 не выполнялся» записи
относятся к состоянию до этого дополнения. Заход 06 не начат;
commit/push/merge/deploy/cloud не выполнялись.
- 05-unified-ui.md SHA-256: 143D6F04F91D156207683D7024E3EB4A88D51420D46FFADA1A697EFBC0A05789


## Заход 06 — regression: not_ready (2026-10-10)

[Передача 06](pvr-01/06-regression.md). Исправлены перенос identity snapshot/workspace/preview A→B при loading/error и overflow page-create dialog360/150%. Focused111 passed; full analyze0; full suite1322 passed/20 skipped/0 failed; boundary567/71 existing suppressed/0 violations; diff0; archive65/65 hashes+bytes. Это не полный verdict Done: A12 обнаружил глобальный Favorites key/API; реальные auth-return, workspace+draft publisher и единая двухаккаунтная storage fixture остаются открыты. Previous evidence не переписано; own scope6 runtime/test files + report/index. 07 не начат; commit/push/merge/deploy/cloud отсутствуют.
- 06-regression.md SHA-256: AE4672735212625DDEE23EA11EFF2B12763F3CD5C3A838EFE7E6CBA43C496E52


## Заход 07 — retirement/restore: ready (bounded docs only, 2026-10-10)

[Передача 07](pvr-01/07-retirement-restore.md). Viewer/Public Viewer paths заменены retirement pointers; map1.1/index2.0 и metadata pins обновлены, история сохранена. 198 links/anchors, 16 VP-D/43 VP-AC; archive65/65 hashes+sizes; выборочный restore profile_page.dart вне runtime exact bytes/SHA, 27 imports. Runtime/packaging scans0; Dart не менялся; diff0. 06 остаётся not_ready и его A/U gaps не закрыты. 08 не начат; commits/cloud отсутствуют.
- 07-retirement-restore.md SHA-256: 085C72C61DBE51A316C3D50D0F9A79CF5A85893DD79379C7056DA282A7697C99


## Заход08 — final gates: not_ready / PVR In progress (2026-10-10)

[Передача08](pvr-01/08-final-gates.md). Полные local gates зелёные: analyze0; test1322 passed/20 existing skipped/0 failed; boundary567 files/71 baseline suppressed/0 violations; diff0; archive65/65 exact. LAUNCH_STATUS/AGENTS/master plan отражают реализованный единый Creator и архив, но не Done: AC18/19 и частичные behavioral07/08/12/20/21 остаются открыты. Изменены только factual status docs и report/index; runtime/storage не менялись. Все прошлые evidence сохранены; commit/push/merge/deploy/cloud отсутствуют.
- 08-final-gates.md SHA-256: 9FE454484665FC34638B88E6A7729F88A99964FB6C0E8E6D088864F82190C8D7
