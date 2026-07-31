# RECHARGE — SCN-AI-01 Local Scenario Proposal Slice

Версия: v1.0 (2026-07-31).
Статус: **Approved**.
Implementation: **Done**.
Slice: `SCN-AI-01`.

## 1. Цель

Добавить внутри существующего Scenario Create flow честный local/mock-first
vertical AI Scenario Generation:

- пользователь вводит естественный запрос;
- система формирует transient catalog-first proposal;
- proposal показывает понятый контекст, stops, evidence, confidence, totals и
  ограничения;
- текущий Scenario draft не меняется до явного `Apply to Scenario`;
- Apply добавляет выбранные catalog objects одной undoable операцией и
  пропускает результат через существующий Scenario readiness validator.

Slice проверяет product/architecture contract до подключения внешней модели.
Он не выдаёт детерминированную генерацию за production AI: UI использует
маркировку `Local demo` и явно сообщает, что live data не проверяются.

## 2. Разрешение во время стабилизации

`SCN-AI-01` является mature local/mock extension уже принятого Scenario
Create-типа и разрешён текущей stabilization policy:

- новый Create-тип и aggregate не создаются;
- существующие form/config engine, ScenarioDraftData и validators
  переиспользуются;
- внешние AI/web/booking/routing/Firebase providers отсутствуют;
- реализация reversible и выключается удалением одного optional coordinator;
- базовые manual/selected-object/Quick Plan/template flows не зависят от неё.

## 3. В scope

- transient `ScenarioGenerationProposal`;
- provider-neutral generator port;
- deterministic local mock adapter поверх `CatalogObjectPickerPort`;
- bounded keyword interpretation ru/en/lv;
- исключение catalog objects, уже присутствующих в draft;
- максимум три предложенных catalog stops;
- application preview/materialization coordinator;
- source revision guard;
- explicit Generate/Apply/Edit/Discard;
- atomic Apply через один Scenario history entry;
- catalog snapshot/estimated/unknown disclosure;
- focused unit/widget tests.

## 4. Не в scope

- OpenAI или другой AI SDK;
- web search;
- live opening hours, availability, booking, traffic или routing;
- новые persistent proposal tables/schema;
- автоматическая публикация/бронь/оплата;
- создание permanent IDs моделью/mock generator;
- замена, удаление или перестановка существующих stops;
- изменения Route, Quick Plan, Firebase, GTFS или legacy scenarios feature;
- analytics raw prompt.

## 5. UX

Панель располагается над тремя Scenario Create steps.

До generation:

- заголовок `Build with AI`;
- badge `Local demo`;
- prompt field;
- example prompt;
- `Generate preview`.

После generation:

- чипы interpreted context;
- proposed stops с причиной выбора и `Catalog snapshot`;
- activity total;
- disclosures `Travel not calculated`, `Live availability not checked`,
  `Costs unknown`;
- deterministic readiness summary;
- `Apply to Scenario`, `Edit prompt`, `Discard`.

При существующих items proposal только добавляет новые unique catalog objects.
Их замена или удаление запрещены.

## 6. Domain/application contract

```text
ScenarioGenerationRequest
  prompt
  marketCityId
  timezoneId
  currencyCode
  sourceRevision
  format/party/pace/travelMode
  existingCatalogObjectIds

ScenarioGenerationProposal
  id (transient, generator-owned)
  sourceRevision
  interpretedContext
  items[] (existing catalog candidate refs)
  evidence[]
  issues[]
  activityMinutes
  confidence
  mode = localDemo
```

Proposal не является Scenario, не сериализуется mapper-ом и не попадает в
Create draft storage.

`ScenarioGenerationCoordinator`:

1. вызывает generator use case;
2. временно materializes proposal через `ScenarioCreateCoordinator`;
3. вычисляет readiness;
4. возвращает application preview;
5. при Apply повторно проверяет source revision и materializes proposal в
   актуальный draft.

## 7. Failure и rollback

| Сбой | Поведение |
|---|---|
| пустой prompt | inline validation, generator не вызывается |
| нет новых candidates | понятный empty result, draft не меняется |
| generator exception | typed error + сохранённый prompt |
| draft revision изменился | Apply отклонён, требуется Regenerate |
| invalid proposal | preview не применяется |
| feature/coordinator отсутствует | панель скрыта, manual flow работает |

Rollback: удалить DI registration/panel/coordinator. Persisted schema и
существующие drafts не требуют миграции.

## 8. Acceptance criteria

1. UI явно маркирует генератор как `Local demo`.
2. Generate не меняет revision, items, autosave или undo stack draft.
3. Proposal содержит только IDs, полученные из catalog port.
4. Existing catalog object не предлагается повторно.
5. Максимум три stops.
6. Prompt интерпретируется детерминированно и без сети.
7. Travel, availability и cost не выдаются за проверенные.
8. Preview проходит существующий deterministic readiness validator.
9. Apply требует совпадения source revision.
10. Apply добавляет proposal одной undoable операцией.
11. Discard не меняет draft.
12. Manual Scenario flow работает без generator coordinator.
13. Raw prompt не попадает в persisted Scenario и analytics.
14. Domain/data/application/presentation boundaries соблюдены.
15. Focused unit/widget tests покрывают success, empty, duplicate, stale,
    apply, discard и failure.
16. `flutter analyze`, полный `flutter test`, boundary и diff checks зелёные.
