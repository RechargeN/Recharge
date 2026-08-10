# Mobile Architecture M1 — Boundary Inventory and Enforcement Plan

**ID:** MOB-ARCH-M1-P
**Версия:** 1.1
**Дата:** 2026-08-10
**Статус:** Review — implementation complete, Linux CI evidence pending
**Parent:** [Recharge Mobile Architecture v3.1](RECHARGE_MOBILE_ARCHITECTURE_V3.md)
**Нормативные AC:** MOB-ARCH-AC-03–06, AC-56–57, AC-61–62, AC-75
**Runtime effect:** none
**Implementation authorization:** Approved 2026-08-10, Product owner (`хорошо, дальше`)

## 0. Решение

M1 создаёт проверяемую карту текущих архитектурных нарушений и заменяет
platform-dependent логику boundary-checker одним cross-platform Dart engine.
PowerShell сохраняется только как совместимый тонкий wrapper. M1 не исправляет
product code и не уменьшает 106 известных отклонений ценой скрытого рефакторинга.

Результат M1:

1. каждое legacy-исключение существует в структурированном registry;
2. у него есть stable ID, владелец, причина и target remediation slice;
3. новые нарушения блокируют CI;
4. устаревшие исключения блокируют CI, чтобы registry только сокращался;
5. Windows, Linux и macOS выполняют один Dart engine;
6. checker имеет fixtures и machine-readable output;
7. существующее поведение приложения не меняется.

## 1. Фактическая исходная точка

Аудит выполнен из корня активного checkout
`C:\Users\User\.codex\worktrees\5bb6\Recharge` 2026-08-10.

| Проверка | Факт |
|---|---|
| Current engine | `tools/scripts/check-boundaries.ps1` |
| Current registry | `tools/scripts/boundaries-allowlist.txt` |
| Gate result | pass |
| Фактически подавлено | 59 cross-feature imports |
| Строк исключений | 60 |
| Stale exception | 1 |
| Дополнительно найдено правилами v3.1 | 47 |
| Полный known-debt baseline M1 | 106 |
| CI runner | `ubuntu-latest` |
| CI shell | `pwsh` без закреплённой версии |
| Checker tests | отсутствуют |
| Machine-readable report | отсутствует |
| Missing-root behavior | exit 0 / silent skip |

Устаревшая запись:

```text
Cross-feature import: apps/mobile/lib/features/auth/presentation/pages/discover_hub_page.dart -> ../../../discover/presentation/widgets/discover_feed_section.dart
```

Она отсутствует в текущем import graph, поэтому current gate сообщает 59
suppressions при 60 строках allowlist.

### 1.1 Распределение 59 текущих нарушений

По source feature:

| Source | Count |
|---|---:|
| discover | 16 |
| explore | 13 |
| auth | 10 |
| scenarios | 10 |
| favorites | 6 |
| create | 2 |
| notifications | 2 |

По target feature:

| Target | Count |
|---|---:|
| discover | 24 |
| auth | 13 |
| favorites | 13 |
| create | 7 |
| scenarios | 2 |

Крупнейшие пары:

| Pair | Count |
|---|---:|
| auth → discover | 7 |
| scenarios → discover | 6 |
| favorites → discover | 6 |
| discover → favorites | 6 |
| discover → auth | 6 |
| explore → discover | 5 |
| auth → favorites | 3 |
| explore → auth | 3 |
| explore → create | 3 |
| остальные 9 пар | 14 |

Эти числа — baseline snapshot, а не разрешение оставить нарушения навсегда.

### 1.2 Отклонения, не видимые current checker

Расширенный read-only аудит правил v3.1 обнаружил ещё 47 imports. Ручной
pre-audit ожидал 46, а canonical directive scanner дополнительно нашёл один
relative domain → `core/geo` import; budget исправлен fail-closed до cutover:

| Rule family | Count | Target remediation |
|---|---:|---|
| feature → `app/di` или `app/presentation` | 12 | composition ports/providers; AC-61–62 |
| domain → `core/geo` | 26 | primitive reconciliation M2 |
| domain → `core/id` | 8 | domain port/shared primitive reconciliation M2 |
| domain → `core/identity` | 1 | identity primitive ownership M2 |
| domain → framework/infrastructure packages | 0 | remains blocking with no baseline exceptions |

Итого registry M1 содержит 106 exact exceptions: 59 current cross-feature + 47
новых классифицированных отклонений. Stale 60-я строка старого allowlist не
переносится. Это migration budget, а не новый разрешённый архитектурный уровень.

## 2. Проблемы текущего checker

1. Логика реализована только в PowerShell.
2. CI зависит от состава `ubuntu-latest` и незакреплённого `pwsh`.
3. Отсутствие `lib`/`features` ошибочно считается успешным skip.
4. Stale allowlist entries не обнаруживаются.
5. Исключение не имеет stable ID, owner, reason, expiry и target slice.
6. Regex читает файл построчно и не покрывает multiline/conditional directives.
7. Нет fixtures для comments, raw strings, exports и path normalization.
8. Нет JSON-результата для CI artifacts и trend reporting.
9. Проверяется только часть правил Accepted Mobile Architecture v3.1.
10. Suppression count не защищён baseline budget: запись можно добавить молча,
    если review не заметил изменение файла.

## 3. Scope

### 3.1 Входит

- единый dependency scanner на Dart standard library;
- структурированная versioned policy;
- структурированный exception registry;
- миграция 106 известных исключений и удаление одной stale записи;
- deterministic text/JSON reports;
- self-test fixtures;
- thin PowerShell compatibility wrapper;
- CI cutover после доказанной parity;
- документация правил и baseline inventory;
- fail-closed execution при неверном cwd, отсутствующих roots или config error.

### 3.2 Не входит

- изменение любого файла в `apps/mobile/lib` или `apps/mobile/test`;
- устранение самих 106 известных отклонений;
- изменение product behavior, routes, state или DI;
- создание новых app facades/adapters;
- backend/Firebase/API contracts;
- новый package в `packages/` или изменение Melos graph;
- форматирование всего репозитория;
- автоматическая архитектурная классификация по именам классов;
- требование zero exceptions в рамках M1.

## 4. Выбранная реализация

### 4.1 Один cross-platform engine

Канонический engine — `tools/scripts/check_boundaries.dart`, использующий только
Dart standard library. Он запускается после Flutter setup без отдельного package
или dependency download:

```text
dart tools/scripts/check_boundaries.dart --repo-root . --format text
```

`check-boundaries.ps1` не содержит scanning/policy logic. Он только:

1. разрешает repo root;
2. проверяет наличие `dart`;
3. вызывает canonical Dart command;
4. возвращает неизменённый exit code.

Дублирование правил между Dart и PowerShell запрещено.

### 4.2 Exit contract

| Code | Meaning |
|---:|---|
| 0 | policy valid, no unsuppressed/stale/budget violations |
| 1 | architecture violation или stale/expired exception |
| 2 | tooling/config/root/parse error; gate inconclusive |

CI считает успешным только exit 0.

### 4.3 Directive scanner

Scanner обязан распознавать `import` и `export`, включая multiline, deferred и
conditional URIs, игнорируя comments и string literals вне directive. Каждый URI
нормализуется относительно source file и repo root. Path, уходящий за repo root,
даёт tooling error.

Подключение `package:analyzer` в M1 запрещено: для boundary gate не создаётся
новый tool package и не расширяется production dependency graph.

### 4.4 Versioned policy

`boundary-policy.json` содержит:

```text
schemaVersion
sourceRoots[]
knownLayers[]
blockingRules[]
excludedGeneratedRoots[]
exceptionBudget
```

Начальные blocking rules:

- `cross_feature_import`;
- `domain_to_non_domain_layer`;
- `application_to_data_or_presentation`;
- `data_to_application_or_presentation`;
- `presentation_to_data`;
- `domain_framework_dependency`;
- `domain_infrastructure_dependency`;
- `feature_to_app_di_or_app_presentation`.

App-placement semantics, которые нельзя доказать импортом, остаются manual
review checklist, а не эвристическим CI false positive.

### 4.5 Exception registry

`boundary-exceptions.json` заменяет plain-text allowlist после parity gate.

Каждая запись:

```text
id                    BND-LEGACY-0001...
rule                  stable rule ID
source                repo-relative normalized path
target                canonical import target
owner                 team/feature owner
reason                bounded explanation
introducedBefore      baseline date
targetSlice           remediation slice ID or backlog ID
expiresOn             ISO date or explicit null with approved rationale
fingerprint           normalized source + rule + target hash
```

Правила registry:

- duplicate ID/fingerprint — config error;
- missing required metadata — config error;
- exception без фактического нарушения — stale failure;
- expired exception — failure;
- новый exception повышает budget и требует отдельного approved RFC/ADR path;
- M1 budget устанавливается ровно в 106 и не может быть повышен этим slice;
- устранённое нарушение удаляется в том же PR;
- wildcard exceptions запрещены.

### 4.6 Reports

Text output оптимизирован для человека. Deterministic Markdown output обновляет
`MOBILE_BOUNDARY_INVENTORY.md`; режим `--check-output` сравнивает его с registry
без записи и блокирует drift. JSON output содержит:

```text
schemaVersion
toolVersion
policyVersion
scannedFileCount
violationCount
suppressedCount
staleExceptionCount
violations[]
exceptions[]
durationMs
```

Paths всегда repo-relative с `/`; timestamps/duration не участвуют в golden
comparison. Generated inventory имеет явный header и не редактируется вручную.

## 5. Exact file plan будущей реализации

### 5.1 Новые файлы

| File | Ownership | Назначение |
|---|---|---|
| `tools/scripts/check_boundaries.dart` | tooling | canonical scanner, policy evaluator, CLI, text/JSON/Markdown output |
| `tools/scripts/boundary-policy.json` | architecture | versioned blocking rules and roots |
| `tools/scripts/boundary-exceptions.json` | architecture debt | 106 exact structured exceptions |
| `tools/scripts/boundary_fixtures/manifest.json` | tooling tests | expected exit codes/findings |
| `tools/scripts/boundary_fixtures/valid/domain_to_domain.dart` | tooling tests | allowed direction |
| `tools/scripts/boundary_fixtures/valid/presentation_to_application.dart` | tooling tests | allowed direction |
| `tools/scripts/boundary_fixtures/valid/comments_and_strings.dart` | tooling tests | false-positive shield |
| `tools/scripts/boundary_fixtures/valid/app_shell_composition.dart` | tooling tests | allowed app composition |
| `tools/scripts/boundary_fixtures/invalid/cross_feature.dart` | tooling tests | cross-feature finding |
| `tools/scripts/boundary_fixtures/invalid/domain_to_data.dart` | tooling tests | layer finding |
| `tools/scripts/boundary_fixtures/invalid/domain_framework.dart` | tooling tests | Flutter/Riverpod finding |
| `tools/scripts/boundary_fixtures/invalid/application_to_data.dart` | tooling tests | layer finding |
| `tools/scripts/boundary_fixtures/invalid/data_to_application.dart` | tooling tests | layer finding |
| `tools/scripts/boundary_fixtures/invalid/presentation_to_data.dart` | tooling tests | layer finding |
| `tools/scripts/boundary_fixtures/invalid/feature_to_app_di.dart` | tooling tests | composition leak finding |
| `tools/scripts/boundary_fixtures/invalid/conditional_import.dart` | tooling tests | every conditional URI scanned |
| `tools/scripts/boundary_fixtures/invalid/multiline_deferred.dart` | tooling tests | multiline deferred import scanned |
| `docs/architecture/MOBILE_BOUNDARY_INVENTORY.md` | architecture | generator-owned registry snapshot and remediation grouping |

### 5.2 Изменяемые файлы

| File | Exact change |
|---|---|
| `tools/scripts/check-boundaries.ps1` | заменить engine тонким wrapper к Dart CLI |
| `.github/workflows/mobile-ci.yml` | установить Flutter/Dart в boundary job; self-test; canonical check; upload JSON artifact on failure |
| `docs/architecture/IMPORT_BOUNDARIES.md` | v3.1 rules, Dart command, exception lifecycle, exit contract |
| `docs/architecture/CI_GATES_POLICY.md` | canonical command, fail-closed/inconclusive semantics, no budget growth |
| `docs/architecture/LAUNCH_STATUS.md` | только после зелёных gates отметить M1 tooling status; никаких feature claims |
| `docs/architecture/ARCHITECTURE_BASELINE.md` | связать frozen baseline с фактическим M1 status без runtime claim |
| `docs/architecture/RECHARGE_MOBILE_ARCHITECTURE_V3.md` | обновить M1 roadmap status после approved implementation |
| `docs/architecture/RECHARGE_ARCHITECTURE.md` | заменить текущую legacy-allowlist policy на structured registry governance |
| `docs/architecture/PLATFORM_FOUNDATION_SPEC.md` | заменить текущую remediation-ссылку на structured registry budget |
| `docs/product/S3_REL_01_RELEASE_READINESS_SPEC.md` | сохранить historical evidence и явно отметить M1 supersession |
| `AGENTS.md` | обновить дату и canonical local/CI boundary command |

### 5.3 Удаляемый файл после parity

| File | Условие удаления | Recovery |
|---|---|---|
| `tools/scripts/boundaries-allowlist.txt` | JSON registry содержит 106 активных записей; stale запись исключена; parity текущих 59 правил зелёная | восстановить из git и вернуть legacy wrapper |

Ни один файл приложения, contracts package, backend или Accepted ADR не входит
в implementation diff.

## 6. Реализация по commit-safe этапам

### M1-A — Snapshot and fixtures

- зафиксировать 59 current findings, 47 расширенных findings и одну stale строку;
- добавить fixtures/manifest;
- реализовать Dart scanner в shadow mode;
- старый PowerShell gate остаётся blocking.

Gate: Dart self-test green; Dart/PowerShell находят одинаковые 59 активных
cross-feature violations, а расширенные Dart rules детерминированно находят ещё
47 отклонений на текущем tree.

### M1-B — Policy and registry migration

- добавить versioned policy;
- материализовать 106 exact JSON exceptions;
- назначить owner/target slice/expiry rationale;
- JSON report подтверждает 106 suppressed, 0 stale, 0 unsuppressed;
- exception budget = 106.

Gate: registry schema, duplicate, stale, expired и budget-negative fixtures
зелёные.

### M1-C — Cross-platform cutover

- сделать Dart engine blocking в CI;
- добавить Flutter setup в boundary job для гарантированного Dart runtime;
- PowerShell превратить в wrapper;
- проверить Windows wrapper и Linux canonical invocation;
- удалить plain-text allowlist после parity evidence.

Gate: одинаковые findings/exit semantics на Windows и CI Linux.

### M1-D — Documentation and status

- обновить IMPORT_BOUNDARIES, CI policy и AGENTS;
- создать inventory/remediation grouping;
- обновить LAUNCH_STATUS только фактическим tooling result;
- выполнить полный repo verification.

## 7. Verification commands

Из корня репозитория:

```text
dart tools/scripts/check_boundaries.dart --self-test
dart tools/scripts/check_boundaries.dart --repo-root . --format text
dart tools/scripts/check_boundaries.dart --repo-root . --format json
dart tools/scripts/check_boundaries.dart --repo-root . --format markdown --output docs/architecture/MOBILE_BOUNDARY_INVENTORY.md --check-output
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\scripts\check-boundaries.ps1
git diff --check
```

Из `apps/mobile`:

```text
flutter analyze
flutter test
```

CI evidence обязательно включает boundary job на Linux. Windows evidence может
быть локальным или отдельным CI job. Timeout, отсутствующий Dart runtime,
невалидный config и parser crash — не pass.

## 8. Rollout и rollback

### Rollout

1. Shadow Dart engine, legacy PowerShell остаётся blocking.
2. Parity на fixtures и active tree.
3. JSON registry active, оба engine проверяются.
4. Dart становится blocking, PowerShell — wrapper.
5. Plain-text allowlist удаляется.

### Rollback triggers

- false positive на valid Dart directive;
- Windows/Linux дают разные fingerprints;
- checker не запускается в clean CI;
- registry теряет finding или допускает budget growth;
- runtime превышает согласованный CI budget.

### Rollback action

- вернуть blocking вызов legacy PowerShell commit;
- восстановить plain-text allowlist из git;
- оставить Dart engine shadow-only для диагностики;
- не отключать boundary gate полностью;
- не добавлять wildcard exception;
- открыть remediation issue с fixture, воспроизводящим дефект.

Rollback не меняет application code и не легализует новые нарушения.

## 9. Риски и shields

| Риск | Shield |
|---|---|
| Parser расходится с Dart syntax | directive fixtures + conditional/multiline cases |
| JSON registry превращается в новый вечный allowlist | budget 106, stale/expiry failure, owner/target slice |
| CI работает, local нет | один Dart engine + PS wrapper + Windows evidence |
| Missing cwd даёт false pass | exit 2 fail-closed |
| Новый rule ломает весь tree | shadow inventory, отдельный policy revision, approved exceptions only |
| M1 превращается в feature refactor | запрещены изменения `apps/mobile/**` |
| Generated/fixtures дают шум | explicit excluded roots и negative tests |
| Отчёт расходится с registry | inventory генерируется/проверяется canonical engine |

## 10. Acceptance criteria

- **MOB-M1-AC-01:** Implementation diff не меняет `apps/mobile/**`, `packages/**`, backend или ADR.
- **MOB-M1-AC-02:** Baseline документирует 59 current findings, 47 expanded v3.1 findings и 1 stale legacy entry.
- **MOB-M1-AC-03:** Canonical engine реализован на Dart standard library.
- **MOB-M1-AC-04:** PowerShell содержит только wrapper logic.
- **MOB-M1-AC-05:** Windows и Linux используют один policy engine.
- **MOB-M1-AC-06:** Missing repo/source root возвращает exit 2, не pass.
- **MOB-M1-AC-07:** Text, JSON и Markdown formats имеют одинаковые findings.
- **MOB-M1-AC-08:** Import/export, multiline, deferred и conditional URIs покрыты fixtures.
- **MOB-M1-AC-09:** Comments/strings не создают false positives.
- **MOB-M1-AC-10:** Relative/package paths нормализованы repo-relative с `/`.
- **MOB-M1-AC-11:** Path escape за repo root fail-closed.
- **MOB-M1-AC-12:** Policy и exception registry имеют schemaVersion.
- **MOB-M1-AC-13:** Каждое исключение имеет stable ID, owner, reason и target slice.
- **MOB-M1-AC-14:** Wildcard exceptions запрещены.
- **MOB-M1-AC-15:** Duplicate ID/fingerprint возвращает exit 2.
- **MOB-M1-AC-16:** Stale или expired exception возвращает exit 1.
- **MOB-M1-AC-17:** Exception budget равен 106 и не увеличивается M1.
- **MOB-M1-AC-18:** Новое unsuppressed нарушение возвращает exit 1.
- **MOB-M1-AC-19:** Dart/legacy parity подтверждает 59 current findings и отдельный expanded audit подтверждает ещё 47.
- **MOB-M1-AC-20:** Устаревшая 60-я строка не переносится в JSON registry.
- **MOB-M1-AC-21:** Generated inventory группирует debt по rule/source/target/pair и проходит `--check-output`.
- **MOB-M1-AC-22:** App-level semantic placement остаётся explicit manual review gate.
- **MOB-M1-AC-23:** CI устанавливает доступный Dart runtime до boundary command.
- **MOB-M1-AC-24:** Boundary CI публикует JSON artifact при failure.
- **MOB-M1-AC-25:** PowerShell wrapper возвращает исходный Dart exit code.
- **MOB-M1-AC-26:** Rollback восстанавливает legacy gate, но не отключает проверку.
- **MOB-M1-AC-27:** `flutter analyze` проходит без ошибок.
- **MOB-M1-AC-28:** Полный `flutter test` проходит.
- **MOB-M1-AC-29:** Canonical boundary self-test и repo check проходят.
- **MOB-M1-AC-30:** `git diff --check` проходит.
- **MOB-M1-AC-31:** LAUNCH_STATUS не получает product/runtime claims.
- **MOB-M1-AC-32:** M1 не исправляет и не маскирует feature violations.

## 11. Definition of Ready

До старта реализации владелец продукта должен был отдельно утвердить:

1. exact file plan §5;
2. Dart-as-canonical-engine решение;
3. structured JSON registry вместо plain-text allowlist;
4. baseline budget 106 (59 current + 47 expanded v3.1 findings);
5. AC-01–AC-32 и exclusions §3.2.

Approval получен 2026-08-10. Все пять пунктов приняты одной командой продолжить
по этому exact plan. Runtime приложения и product behavior не входили в
разрешение и не изменялись M1.

## 12. Definition of Done

M1 Done только после выполнения AC-01–AC-32, зелёного local/CI evidence и
фактического обновления status docs. Существование этого плана, Dart-файла или
JSON registry по отдельности не является Done.

## 13. Implementation evidence

Локальная реализация завершена 2026-08-10:

- canonical Dart checker self-test — pass;
- fixtures cover import/export, multiline, deferred, conditional directives,
  comments/strings, every enforced rule and report-format parity;
- Dart analyzer для checker — 0 issues;
- repository scan — 380 Dart files, 106 findings, 106 exact suppressions,
  0 unsuppressed, 0 stale, 0 expired, budget 106/106;
- generated Markdown inventory drift check — pass;
- Windows PowerShell wrapper parity — pass с теми же 106 findings;
- missing repo root подтверждён как tooling error с exit code 2;
- `flutter analyze --no-pub` — 0 issues;
- полный `flutter test --no-pub` — 659 passed;
- `git diff --check` — pass;
- application, packages, backend и ADR не изменялись этим slice.

Оставшийся gate: первый фактический запуск обновлённого `boundaries` job на
GitHub Actions Linux. До его `success` MOB-ARCH-M1 остаётся `Review`, а не
`Done`; timeout/cancelled/missing runtime не считаются pass.
