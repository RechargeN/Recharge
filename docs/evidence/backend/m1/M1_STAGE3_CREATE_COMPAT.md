# M1 пересмотр, заход 3 — совместимость Create и сервера (Place, Activity, Rental, Collection)

Дата 2026-10-14. Ветка `claude/m1-stage3-create-compat` от `d5394c4`.
Реестр: [M1_REOPEN_REGISTER.md](../../../verification/M1_REOPEN_REGISTER.md)
(K-06…K-09), дефект DEF-03 в
[M1_DEFECT_REGISTER.md](../../../verification/M1_DEFECT_REGISTER.md).

Решения владельца 2026-10-14: Р-09 (серверные правила не ослабляются; неполный
черновик сохраняется, готовность к submit/publish проверяется заранее), **3-А**
(публичные детали D6 расширены на Place, Rental, Collection), **3-Б** (серверные
требования показываются в форме Create только при включённом серверном пути;
локальные правила формы не меняются).

## 1. Фактическая матрица до захода

Получена прогоном настоящих клиентских проверок (`ValidateXDraftUseCase` плюс
проверки таксономии `CreateController`) на тех же черновиках, из которых
строятся фикстуры `*_create_compat.json`. Таблицы §5.7 в поправках D3.x к этому
моменту частично устарели: коммит D5 (`0f61871`) уже выровнял правила Activity.

| Тип | Случаев | Совпадают | Клиент пропускал, сервер отклонял |
|---|---|---|---|
| Activity | 26 | 25 | `subcategory_not_applicable` (пара есть в таксономии, но не применима к Activity) |
| Place | 11 | 4 | обложка; краткое описание < 20; режим часов; тип входа; валюта; телефон; `sourceType` |
| Rental | 10 | 3 | обложка; подкатегория; устаревшее подтверждение доступности; версия политики; точность места передачи; радиус доставки; `#` в ссылке |
| Collection | 10 | 5 | краткое описание; обложка; неизвестная подкатегория; ссылка на несохранённый объект; устаревший предпросмотр состава |

Сервер проверяет правила типа только на `submitForPublication` и
`publishApprovedRevision`; `createDraft`/`updateDraft` принимают неполный
черновик — разделение «сохранение / готовность» на сервере уже было.

## 2. Что сделано

**Сервер (3-А).** `validation_details.ts`: точный allowlist «код → путь в теле»
для Place, Rental, Collection по фактическим полям тел; коды
`<prefix>.unknown_field:<key>` и любые неизвестные остаются общим отказом;
критерии Place — `place.criteria.required_missing` с путём
`/body/criteria/<id>` (ключи из серверного реестра); `rental.private_field_forbidden`
— без ключа. Публичный код приведён к схеме `content_result.schema.json`
(`snake_case`, без суффикса): `place.pricing.entryType` → `place.pricing.entry_type`,
`place.hours.mode_unsupported:seasonal` → `place.hours.mode_unsupported`. Тест
проверяет по схеме каждый код allowlist. Фикстуры Place, Rental, Collection
получили `expectedViolations`; тесты совместимости, integration и Emulator
сверяют их с ответом сервера.

**Клиент.**

- `content_server_readiness.dart` (domain): порты статических серверных правил,
  которые локальные проверки пропускали; работают на теле, которое отправляет
  маппер, и возвращают те же публичные код и путь. На всех случаях трёх фикстур:
  ни одного отказа сверх серверного, для 18 случаев-разрывов — точное совпадение.
  TEST-ONLY политика Rental сверяется тестом с `rental_reference_policy.json`.
- Activity: `canonicalSubcategoryApplies` — применимость пары именно к Activity
  по канонической таксономии; исправлено локальное правило `_activityIssues`.
- Контроллеры публикации Place, Rental, Collection: нарушения в состоянии;
  отказ сервера сохраняет свои поля; перед `submit` проверка готовности —
  заведомо отклоняемое тело не отправляется. Валюта Place — из
  `CreateRuntimeDefaults` через композицию (без хардкода, AGENTS п. 5).
- Форма Create (3-Б): `DraftServerRequirements` над блоками Place, Rental,
  Collection показывает «поле: что исправить» только при включённом серверном
  пути (`contentServerPathProvider`, значение из guard'ов тестового входа в
  `main.dart`, фичи не импортируют `app/di`); ответ сервера по тому же полю
  имеет приоритет; отказ без известного поля — общее сообщение. Панели
  публикации передают отказ в store формы.
- `unknown_fields`: сохранение полей более новой схемы и отказ маппера уже
  покрыты тестами всех четырёх типов (`*_draft_mapper_test.dart`,
  `*_content_body_mapper_test.dart`); `linked_place` Activity (D3.9) не менялся.

## 3. Проверки

Итоги и пределы evidence приведены в §4. Заход 3 закрыт после разбора failed D3.1 и полного успешного повтора.

## 4. Итоги прогона

Runtime реализации: `4e82352`; исправления тестовой композиции: `5b3060f` и `b91e8198552a40a75352ce44dfec9ddb2811a64a` (только тесты, production runtime не менялся).

| Гейт | Результат | Evidence |
|---|---|---|
| Backend format/lint/typecheck/layout | pass | исходные журналы Claude `b_format`, `b_lint`, `b_typecheck`, `b_persistence_layout` |
| Backend unit/contract/integration | 731/55/254 passed, 0 failed | `b_unit.log`, `b_contract.log`, `b_integration.log` |
| Emulator | place-activity, rental, collection, content-media pass | четыре исходных `emu_*.log` |
| Flutter analyze, свежий повтор | 0 issues, exit 0 | `stage3-analyze.log`, `stage3-analyze-final.log` |
| Flutter test, свежий полный повтор | 1635 passed / 67 skipped / 0 failed, exit 0 | `stage3-flutter-test.log` |
| Boundary/inventory, свежий повтор | 0 нарушений, 71/71; check-output exit 0 | `stage3-boundary.log`, `stage3-inventory.log` |
| D3.1, первая попытка | failed: UI не нашёл заголовок Place; summary rc=0 неверен | `gate_d3-1.log`, failed evidence сохранено |
| D3.1, первый повтор | failed: Place UI 1/1, Page access 7/8; второй UI boot тоже не регистрировал defaults | `d31-repeat-failed-page-ui.log` |
| D3.1, финальный полный повтор | pass, exit 0: delivery 4, controller 6, UI 1, Page access 8, two installs 1 | `stage3-d31-final.log` |
| D3.2/D3.3/D3.4 | pass: controller 6/6/7, UI по 1 | исходные `gate_d3-2.log`, `gate_d3-3.log`, `gate_d3-4.log`; проверены финальные markers и Flutter summaries |
| Diff | commit-range и рабочее дерево без нарушений | `git diff --check d5394c4 HEAD`, `git diff --check` |

Исходные журналы сохранены из scratchpad Claude `500f136c-97a1-4367-a429-c939635ffb0b/logs3`. Они получены до `4e82352` на рабочем runtime, позднее сохранённом этим коммитом; исходная summary сама указывает `HEAD d5394c4 dirty=56`. Это не прогоны на чистом закреплённом SHA. Свежий полный suite проверил `5b3060f`; финальный D3.1 и analyzer проверили `b91e819`. Отличие обоих от `4e82352` — только регистрация `CreateRuntimeDefaults` в двух UI-тестах. Второе исправление затрагивает тест, пропускаемый общим suite и исполняемый полным D3.1. Финальные обязательные прогоны на закреплённом runtime SHA остаются задачей заходов 4–5.

Пакет журналов и SHA-256: `C:/Users/User/Documents/Codex/2026-10-14/4-b1-e2-c3-runtime-2/outputs/stage3-logs/`, manifest `SHA256SUMS.txt`. Пустой лог lint/typecheck означает отсутствие вывода, их exit 0 записан в исходной summary; summary D3.1 не используется как успех.

Причина D3.1: `createPlacePublicationController` после изменения композиции читает валюту из `CreateRuntimeDefaults`; boot двух UI-тестов их не регистрировал. Добавлены тестовые регистрации в `place_publication_ui_stand_test.dart` и `page_access_revocation_stand_test.dart`, настоящий controller и сервер сохранены. Сам репозиторный gate корректно завершал failed Flutter ненулевым кодом. Неверный rc=0 был во внешней сводке запуска; оба повтора сохраняют `$LASTEXITCODE` процесса непосредственно, без pipeline.

Состав `4e82352` проверен: в backend `test/unit/content` изменены только четыре относящихся к совместимости/validation-details файла; массовых CRLF-only изменений остальных тестов в коммите нет. Штатное восстановление D1 tools проверило lockfile SHA-256 и GPG; его собственное изменение install metadata lockfile отменено и в заход 3 не входит.

K-06…K-09 и DEF-03 закрыты в scope совместимости четырёх типов: проверки readiness совпадают с фикстурами сервера, поле отказа отображается в Create, корректные черновики проходят реальные стенд-гейты. Это не закрытие полного Create UI для Event (K-05), B1 adapter/platform evidence или Map (заход 4), не приёмка M1 и не device/cloud/production evidence. Старое `250/250` остаётся историей `e3710f6`.

Rollback: откат коммитов захода 3 в обратном порядке; не откатывать чужой WIP. Failed evidence и история проверок сохраняются.
