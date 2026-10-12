# D3 Activity — заходы 4–6, 2026-10-11

Рабочее дерево: `C:/Users/User/.claude/worktrees/recharge-d3-2`.
HEAD: `b1e678a23a4db584e496a9d44593fbcf86c45dc0`.
Проверяемые исходники: `b1e678a23a4db584e496a9d44593fbcf86c45dc0+wt:734abeb388d7`. SHA256 нормализованных LF bytes каждого
из 35 tracked/untracked изменённых файлов, сортированный список `path TAB sha LF`;
короткий fingerprint — первые 12 знаков SHA256 списка. Evidence-документы
исключены из собственной идентичности; полный manifest: `C:/Users/User/AppData/Local/Temp/recharge-d3-followup-20261011/before-final.json`.
Изменения runner из захода 3 сохранены. Новых commit/push/merge/deploy нет.

## 4. BCK-20 taxonomy — зависимость отсутствует

Подключение принятой revision **не выполнено**: нет необходимого BCK-20 runtime
контракта/артефакта. Это предусмотренный запросом альтернативный результат.
`emulator_activity_taxonomy.ts` и `emulator_activity_dependencies.ts` проверены.
Второй справочник, выдуманный revision ID и auto-rewrite старых drafts не добавлены.
Минимальная taxonomy пока остаётся в прежней Emulator-композиции и тестах;
утверждение «fixture теперь только в тестах» было бы неверным.

Конкретные зависимости:

1. Опубликованный immutable taxonomy dataset для принятой Category System,
   с точным revision ID/content hash и approval provenance. Принятый документ
   Category System не равен опубликованной BCK-20 dataset revision.
2. BCK-20 reader/repository этой revision. Сейчас
   `modules/reference_data/domain/repositories.ts` содержит только
   `MarketConfigRepositoryPort`, а `ReferenceDataService` публикует/активирует/
   откатывает только MarketConfig; `taxonomyRevisionRef` — ссылка, не reader.
3. Адаптер **существующего** Content `ReferenceDataPort.resolve`, связывающий
   MarketConfig.taxonomyRevisionRef с effective applicability (наследование и
   overrides) и required criteria IDs. Нельзя использовать мобильный справочник
   как самостоятельную серверную authority или переименовать fixture.
4. Явное разрешение unknown/unavailable/unapproved revision: существующий port
   уже допускает `policy_unavailable`; unanswered lookups уже дают
   `activity.taxonomy_unavailable`/`activity.criteria_registry_unavailable`.
   Проверяемый тест доступности есть; проверка отсутствующей принятой dataset
   через настоящий reader невозможна до п. 1–3.

Linked Place остаётся fail-closed на submit/publish/activate; dependency guard
не заменяется taxonomy lookup. Rollback после будущей интеграции: прежняя
Emulator reference-data композиция. Сейчас runtime composition не менялась.

## 5. Правила, mapper и Create

Принятая semantics: spec v1.4 §§9.2, 10, 13 step 7.
Четвёртая и последующие active informal Activity authenticated actor Creator
получают `flagged_for_review` и остаются видимыми. Счётчик общий для personal
и разных Pages; active включает published и hidden moderation records,
исключает draft/pending_review/archived/deleted. Порог не требует pre-review и
не блокирует сам по себе. Donation amount threshold не добавлен.

| Правило | Реализация | Покрытие |
|---|---|---|
| Required title/short description, категория, cover, coordinates, pin, access notes, duration | server Activity rules + existing mapper | existing mutation tests + shared compatibility cases |
| Title 5–80, short 20–180, access 10–300 | accepted bounds сохранены | новые shared upper/lower boundary controls, over-limit cases |
| Filled caution note max 200; note обязателен при informal | устранён пропуск проверки non-informal note в server и local validator; поле сохранённого note доступно в форме | shared 200/201 cases + local regression |
| Contribution kind/note/positive minor amount/market currency | mapper не выбрасывает неполный блок, server проверяет зависимости | existing cases + новые note 140/141 и amount-without-kind |
| Duration/group positive integers, min ≤ max; рекомендации не hard limits | удалён несогласованный server cap 100000; техническая граница safe JSON integer сохранена | zero cases, existing reversed ranges, новый valid >100000 control |
| Required criteria | whitespace теперь считается missing; false/0 не теряются | новый shared whitespace case + required-criteria unit regression |
| Mapper ↔ server | mapper сохраняет exact fields/values; изменения mapper не потребовались | fixture expanded 11 → 26, Dart exact-body parity + TS exact-issue/violation parity + wire |
| Informal fourth+ | existing local/mock CreateController ставит flaggedForReview, repository сохраняет его | существующие actor/cross-page и publish tests повторены; production count не доказан |
| Linked Place | прежний explicit unsupported mapper + server composition refusal | существующие отрицательные submit/publish/old-revision activate tests |

Оставшаяся серверная зависимость §13 step 7: `ModerationDispositionPort.profileFor`
не получает actor/body и не возвращает post-publication review signal;
BCK-07 submission moderation metadata не моделирует `flagged_for_review`.
Нужен authoritative actor-based active count и согласованный BCK-22 signal
contract с учётом hidden/archived, cross-page и concurrency/idempotency.
Продуктовая semantics уже принята; решение о runtime authority и контракте
остаётся открытым. Включать pre-review вместо soft signal нельзя.
Текущая Emulator staff-review policy не объявляется полной реализацией §§10/13.

## 6. BCK-07 validation details — реализовано

Addendum `BCK07-VALIDATION-DETAILS-01` в `CONTENT_PUBLICATION_BACKEND_SPEC.md`
документирует авторизованное пользователем additive изменение v1:

```json
{"schemaVersion":1,"kind":"rejected","code":"validation_failed","violations":[{"code":"activity.title_length","fieldPath":"/body/title"}]}
```

Legacy general response остаётся валидным. Details необязательны и допустимы
только для `validation_failed`: 1–50 entries, стабильный code и JSON Pointer.
Сервер использует public allowlist, не возвращает body values, unknown keys,
контактные данные, координаты, stacks или policy diagnostics. Dynamic criterion
suffix превращается в стабильный code и разрешённый публичный field path.

Existing shared gateway декодирует details, exception и Activity controller
сохраняют их. Application feedback сопоставляет только известную code/path
пару с локальным текстом. Existing Create form показывает errorText возле
нужного поля; общий текст остаётся для unknown/malformed/неотображаемых ошибок.
Transient store изолирован account/publisher/local draft и updatedAt; он не
пишет details в draft/journal и не показывает старые ошибки после изменения.
Возврат из test publication panel в Create использует тот же scoped store.
Нет нового Create flow или mobile Activate. Lifecycle и authority не менялись.

Rollback 5–6: вернуть изменённые rules/local validator, gateway/controller/UI
и optional schema projection к прежнему состоянию; убрать новые feedback
файлы и addendum. Старые drafts не мигрируются. Изменения runner захода 3
откатываются отдельно, не общим reset/clean.

## Gates

Evidence root: `C:/Users/User/AppData/Local/Temp/recharge-d3-followup-20261011`. Только финальные завершённые прогоны составляют
acceptance evidence; диагностические первые failures не включены.

| Gate | Результат | Evidence |
|---|---|---|
| Backend build + full unit/integration/contract, repeated after projector hardening | 965/965, 0 skipped, exit 0 | backend-final-after-hardening.log |
| Backend lint, full + final changed files | exit 0 | lint.log; lint-hardening.log |
| Changed backend formatting | pass | format.log |
| Flutter analyze --no-pub, full app | 0 issues, exit 0 | flutter-analyze-final.log |
| Flutter test --no-pub, full suite | 1421 passed, 30 pre-existing skipped, exit 0 | flutter-full.log |
| Boundary | 0 violations; 71/71 прежних suppressions | boundary.log |
| Full sequential Emulator before final projector hardening | 210/210, 0 skipped/timeout, exit 0 | emulator-full.log; emulator-full-summary.json |
| Final affected Emulator Place/Activity group | 29/29, 0 skipped/timeout, exit 0; 168.080 s / 300 s timeout | emulator-place-activity-final.log; emulator-place-activity-final-summary.json |
| Tracked + all untracked diff checks | pass; no staged diff | diff-check.log |
| Final source fingerprint before/after | identical, 35 files | before-final.json/after-final.json |

Полный Emulator нужен, потому что изменён общий Content failure mechanism;
он включает Place/Event/Activity и guards, Media, Booking, rules/reference-data.
Mobile full gates обязательны из-за общего gateway/exception и existing Create
form. Device/Linux/cloud/production не выполнялись и не заявлены. Catalog и
новая taxonomy integration не добавлены.


### Exact evidence reuse after the last correction

The full Emulator and Flutter suites ran on
`b1e678a23a4db584e496a9d44593fbcf86c45dc0+wt:3bfe8ff24895`; before/after-full
manifests are identical. Subsequently only `validation_details.ts` and its
unit test changed: dictionary lookup now requires `Object.hasOwn`, excluding
`constructor`, `toString`, `__proto__` from public details. Known public
code/path pairs, schema, fixtures, lifecycle, ports, mapper and all Dart files
are unchanged. The additional unit adversarial inputs now resolve to the
same general fallback as other unknown codes.

Full backend suites were repeated on the final revision. The affected public
Activity wire projection and shared Place regressions are repeated in the
named `place-activity` group. Other completed Emulator groups are reused:
the last change adds only a guard for inherited JavaScript dictionary keys,
which their accepted validators never emit; no owning module, lifecycle,
reference lookup, scheduler, Media, Booking, Identity or pointer behavior
changed. Flutter/boundary evidence is reused because no Dart source changed.
Do not label the original full Emulator run as having executed the final
fingerprint; the final revision is assessed by this explicit diff + repeats.

### Full Emulator measured groups on this pass

| Group | Passed | Duration | Configured timeout |
|---|---:|---:|---:|
| platform | 10 | 15.527 s | 120 s |
| booking | 62 | 150.386 s | 240 s |
| content-media | 63 | 163.438 s | 330 s |
| handoff-notifications | 34 | 229.292 s | 450 s |
| place-activity | 29 | 161.635 s | 300 s |
| rules-reference | 12 | 6.608 s | 120 s |

Sum of groups: 726.886 s; startup/build/shutdown are additional.
No timeouts or parallel groups. Runner coverage and timeout policy from
заход 3 remain unchanged.

### Files changed in заходы 4–6

- `apps/backend/functions/src/contracts/content_v1.ts`
- `apps/backend/functions/src/modules/content/application/content_publication_service.ts`
- `apps/backend/functions/src/modules/content/domain/failures.ts`
- `apps/backend/functions/src/modules/content/domain/type_rules/activity_rules.ts`
- `apps/backend/functions/src/modules/content/domain/validation_details.ts`
- `apps/backend/functions/test/contract/content_fixture_parity.test.ts`
- `apps/backend/functions/test/emulator/content_activity_callable.test.ts`
- `apps/backend/functions/test/unit/content/type_rules_activity.test.ts`
- `apps/backend/functions/test/unit/content/type_rules_activity_create_compat.test.ts`
- `apps/backend/functions/test/unit/content/validation_details.test.ts`
- `apps/mobile/lib/app/presentation/activity_publication_panel.dart`
- `apps/mobile/lib/features/create/application/activity_publication_controller.dart`
- `apps/mobile/lib/features/create/application/activity_validation_feedback.dart`
- `apps/mobile/lib/features/create/application/activity_validation_feedback_provider.dart`
- `apps/mobile/lib/features/create/data/functions_event_publication_gateway.dart`
- `apps/mobile/lib/features/create/domain/entities/content_validation_violation.dart`
- `apps/mobile/lib/features/create/domain/entities/event_publication.dart`
- `apps/mobile/lib/features/create/domain/usecases/validate_activity_draft_usecase.dart`
- `apps/mobile/lib/features/create/presentation/pages/create_page.dart`
- `apps/mobile/lib/features/create/presentation/widgets/activity_create_block.dart`
- `apps/mobile/lib/features/create/presentation/widgets/activity_publication_section.dart`
- `apps/mobile/test/fixtures/create/user_activity_draft.dart`
- `apps/mobile/test/unit/activity_draft_validation_test.dart`
- `apps/mobile/test/unit/activity_publication_controller_test.dart`
- `apps/mobile/test/unit/activity_validation_feedback_test.dart`
- `apps/mobile/test/unit/content_publication_gateway_type_test.dart`
- `apps/mobile/test/widget/activity_create_block_test.dart`
- `docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md`
- `packages/api_contracts/schema/content/v1/content_result.schema.json`
- `packages/api_contracts/schema/content/v1/fixtures/activity_create_compat.json`

The five runner files above were pre-existing WIP from заход 3 and were preserved.
