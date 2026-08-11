# RECHARGE — AI Scenario Generation Spec

Версия: v1.1 (2026-07-31).
Статус: **Approved; SCN-AI-01 local mock implemented; external providers gated**.
Slice family: `SCN-AI`.

AI Scenario Generation — один из вариантов создания Scenario. Пользователь
может по-прежнему создать Scenario вручную, из выбранных объектов, Quick Plan
conversion или публичного template. AI entry формирует проверяемый preview,
но не создаёт другой aggregate и не заменяет Scenario Builder.

Этот документ не выбирает AI-провайдера и не разрешает live integration во
время активной стабилизации.

Bounded local/mock contract `SCN-AI-01` разрешён как mature extension
существующего Scenario Create-типа по
[SCENARIO_AI_LOCAL_MOCK_SLICE_SPEC.md](SCENARIO_AI_LOCAL_MOCK_SLICE_SPEC.md).
Он не подключает внешнюю модель и не выдаётся за production AI.

Обязательный follow-up после текущей стабилизации — `SCN-AI-02`: выбрать
AI-провайдера через Accepted ADR и подключить его только через backend proxy
с typed Structured Output, privacy policy, quotas, cost ledger, kill switch,
evaluation fixtures и автоматическим fallback на `SCN-AI-01`. Без завершения
этого gate Local demo нельзя переименовывать или выдавать за production AI.

Связанные документы:

- [AI_PRODUCT_STRATEGY.md](AI_PRODUCT_STRATEGY.md);
- [SCENARIO_BUILDER_SPEC.md](SCENARIO_BUILDER_SPEC.md);
- [SCENARIO_AI_LOCAL_MOCK_SLICE_SPEC.md](SCENARIO_AI_LOCAL_MOCK_SLICE_SPEC.md);
- [SCENARIO_CONNECTED_PLANNING_SPEC.md](SCENARIO_CONNECTED_PLANNING_SPEC.md);
- [VISION.md](VISION.md);
- `docs/architecture/ARCHITECTURE_BASELINE.md`;
- `docs/architecture/LAUNCH_STATUS.md`;
- `docs/adr/0013-domain-policy-baseline.md`.

---

## 1. Product outcome

Пользователь описывает намерение естественным языком, например:

> Спокойный вечер в центре Риги в субботу с 17:00 до 22:00, вдвоём,
> до 80 EUR, без машины, с ужином и чем-то культурным.

Recharge возвращает не текстовую статью, а typed Scenario preview:

- 2–5 подходящих items;
- fixed/window/flexible timing;
- travel legs и buffers;
- бюджет с unknown/estimate разделением;
- availability/booking state;
- sources, freshness и confidence;
- blockers и alternatives;
- `Save`, `Edit`, `Replace`, `Check`, `Discard`.

Успех — пользователь получает выполнимую основу и может сохранить или
исправить её. Красивый текст без валидного typed plan не является успехом.

---

## 2. Entry modes

| Entry | Ввод | Результат |
|---|---|---|
| Scenario empty state | свободный prompt + компактные context controls | новый transient proposal |
| Smart Search | parsed intent + явное `Build Scenario with AI` | proposal из тех же typed conditions |
| Search/Map selection | выбранные object IDs + prompt | proposal с locked selected items |
| Existing Scenario | текущая revision + explicit `Suggest changes` | diff proposal, не silent rewrite |
| Public template copy | новая personal copy + контекст дат | proposal адаптации копии |

AI entry не заменяет `Add to Scenario`, ручной composer или deterministic
optimizer.

---

## 3. Scope

### 3.1 Входит

- parse user intent в typed constraints;
- поиск candidates в Recharge catalog;
- ограниченный web search для отсутствующих актуальных сведений;
- разрешение web candidate в known provider/catalog reference либо
  `unresolved`;
- получение schedule/opening/availability snapshots;
- расчёт travel time через provider port;
- формирование нескольких feasible proposals;
- deterministic validation;
- preview с evidence, confidence и issues;
- explicit materialization выбранного proposal в новый personal Scenario
  draft через существующий Scenario command/use case.

### 3.2 Не входит

- автоматическая покупка, hold, booking или payment;
- публикация Scenario;
- создание catalog entity из web result;
- прямое чтение Gmail/Calendar/личных сообщений;
- изменение existing Scenario без revision guard и confirmation;
- самостоятельное вычисление картографического travel time моделью;
- обещание точного времени пребывания для flexible activity;
- хранение API keys в мобильном приложении;
- Firebase/live-provider enablement во время стабилизации.

---

## 4. Truth model

### 4.1 Time

| Time basis | Представление |
|---|---|
| confirmed booking/session/event | exact fixed interval |
| provider schedule/opening hours | checked window + freshness |
| route provider | estimated range/ETA + calculatedAt |
| catalog/creator expected duration | estimated duration/range |
| AI suggestion without source | unresolved; не проходит final readiness |

AI не пишет `exact`, если значение не подтверждено source contract.
Travel time и flexible visit duration остаются оценками даже при наличии
конкретного числа.

### 4.2 Source confidence

```text
verifiedProvider > officialSource > catalogSnapshot > estimated > unresolved
```

При конфликте источников proposal создаёт typed issue и не выбирает удобное
значение молча.

### 4.3 Freshness

Каждый operational fact содержит:

- `sourceType`;
- `sourceRef` или безопасный URL;
- `checkedAt`;
- `validUntil`/TTL, если известно;
- `confidence`;
- `status: ready | stale | unresolved | unavailable`.

---

## 5. Input contract

Минимальный request:

```text
AiScenarioRequest
  requestId
  requesterId
  marketCityId
  locale
  currency
  timezone
  prompt
  date/time window
  group profile
  budget
  travel modes
  interests/mood
  accessibility constraints
  locked object IDs
  excluded object IDs
  source Scenario id/revision (optional)
```

`prompt` помогает интерпретации, но typed controls имеют приоритет при
конфликте. UI показывает распознанные ограничения до expensive generation.

Private notes, participant identity, booking codes и exact home location не
входят в request по умолчанию.

---

## 6. Tool contract

AI получает только bounded read-only tools:

```text
searchCatalog(query)
resolveCatalogObjects(refs)
searchWeb(query, market, date)
resolveWebCandidate(candidate)
getOperationalSchedule(refs, dateRange)
checkAvailability(refs, group, dateRange)
calculateTravelLegs(endpoints, departures, modes)
getCostSnapshots(refs, group, currency)
validateScenarioProposal(proposal)
```

Правила:

1. Tool schema строгая, versioned и документирует failure codes.
2. Все catalog relations возвращают permanent id/type.
3. Web result без resolution остаётся `unresolvedCandidate`.
4. AI не вызывает mutation tools.
5. Availability вызывается только для shortlist после дешёвой композиции.
6. Routing вызывается только для соседних legs выбранного shortlist.
7. Provider response нормализуется data adapter до передачи модели.
8. Raw provider payload не становится частью Scenario domain.

---

## 7. Orchestration

```text
1. Parse prompt + merge typed controls
2. Confirm interpreted constraints when material ambiguity exists
3. Search Recharge catalog
4. Use web search only for explicit gaps
5. Resolve candidates to stable refs
6. Build a bounded shortlist
7. Fetch operational snapshots
8. Compose 1–3 proposals around fixed anchors
9. Calculate only required adjacent legs
10. Run deterministic validation/materialization preview
11. Repair proposal within bounded attempts
12. Return preview, evidence, issues and alternatives
13. On explicit Save/Edit, create a new Scenario draft through normal command
```

Limits задаются config. Базовый target для city/day:

- до 20 catalog candidates до shortlist;
- до 8 shortlisted items;
- до 3 final proposals;
- до 2 repair attempts;
- до 2 provider calls одновременно;
- один generation request не выполняет booking/publish mutations.

---

## 8. Proposal и materialization boundary

AI output — `AiScenarioProposal`, не `Scenario`:

```text
AiScenarioProposal
  proposalId
  requestId
  interpretedContext
  proposedItems[]
  proposedLegs[]
  unresolvedCandidates[]
  evidence[]
  issues[]
  totalsPreview
  generationMetadata
```

Proposal:

- transient и имеет TTL;
- не публикуется;
- не получает Scenario lifecycle;
- не считается сохранённым планом;
- не создаёт permanent relation для unresolved web candidate.

После выбора:

1. backend/application повторно проверяет revision/freshness;
2. deterministic validator строит `ScenarioSeed`;
3. unresolved mandatory candidate требует замены/ручного custom location
   решения;
4. новый draft получает permanent Scenario/Day/Item/Location/Leg IDs по
   существующим правилам;
5. сохранение выполняется обычным Scenario repository flow.

Модель не генерирует permanent IDs.

---

## 9. Deterministic validation

До показа `Ready` обычный код проверяет:

- market/timezone/date;
- opening windows и fixed anchors;
- overlaps и required buffers;
- travel feasibility;
- source status/freshness;
- group/capacity/accessibility;
- budget basis и unknown components;
- duplicate objects;
- day/item limits;
- locked/excluded objects;
- Route/Scenario/Quick Plan aggregate boundaries;
- booking-required without available handoff;
- permanent IDs и relation types.

AI может предложить repair, но итоговый readiness вычисляет существующий
domain/application validator.

---

## 10. UX

### 10.1 Primary flow

```text
Describe -> Review understood context -> Generating -> Preview
  -> Save | Edit | Replace item | Check availability | Discard
```

### 10.2 Item badges

- `Confirmed`;
- `Checked now`;
- `Official source`;
- `Estimated`;
- `Needs checking`;
- `Unavailable`;
- `Booking required`.

### 10.3 Honest timing

UI различает:

- fixed start/end;
- operational window;
- expected duration range;
- calculated travel range;
- buffer;
- unresolved gap.

Нельзя показывать оценочное время как подтверждённую бронь или гарантированный
arrival.

### 10.4 Explainability

Пользователь видит короткую причину выбора и может открыть source details.
Internal chain-of-thought не хранится и не показывается.

---

## 11. Cost policy

- Catalog-first: internal search предшествует web.
- Web search используется только при нехватке/актуализации данных.
- Availability проверяется только для финальных bookable items.
- Route matrix не строится для всех пар candidates.
- Reorder пересчитывает затронутые legs.
- Provider/tool budgets задаются server config.
- Cost ledger считает provider/model/tool usage на request и accepted
  proposal.
- Daily/monthly threshold включает warning, degrade и hard kill switch.
- При превышении quota возвращается catalog-only/manual fallback.

UI не обещает live check, если cost policy его не выполнила.

---

## 12. Privacy, safety и injection resistance

1. Raw prompt не входит в public Scenario, analytics или ordinary logs.
2. Telemetry использует bucketed constraints и result counters.
3. Web content считается untrusted data, а не instruction.
4. Tool permissions неизменны для content найденных страниц.
5. Модель не получает provider secrets.
6. Exact private location редактируется локально/через отдельный consent flow.
7. Booking references и participant contacts не передаются generation model.
8. Public custom location проходит существующие privacy/moderation gates.
9. Generated creator/public text не публикуется автоматически.

---

## 13. Failure и fallback

| Failure | Поведение |
|---|---|
| AI unavailable | открыть manual Scenario composer с уже введённым context |
| Web unavailable | catalog-only proposal или явный incomplete state |
| Routing unavailable | manual/unknown legs; Start/ready блокируется по policy |
| Availability unavailable | `Needs checking`; booking claim запрещён |
| Invalid structured output | bounded retry, затем typed failure |
| Proposal infeasible | показать blockers и ручной composer, не выдумывать repair |
| Quota exceeded | deterministic/catalog-only fallback |
| Source conflict | issue + alternatives; без silent choice |
| Stale source during Save | refresh/diff/confirm; stale proposal не применяется |

Пользовательский ввод сохраняется локально при любом failure.

---

## 14. Feature flags

```text
aiScenarioEntryEnabled
aiScenarioCatalogToolsEnabled
aiScenarioWebSearchEnabled
aiScenarioLiveAvailabilityEnabled
aiScenarioLiveRoutingEnabled
aiScenarioRepairEnabled
```

Флаги независимы. Выключение web/live provider не отключает catalog-only AI
или manual Scenario Builder.

---

## 15. Rollout

| Slice | Содержание | Gate |
|---|---|---|
| SCN-AI-00 | product/architecture contract, eval fixtures, no runtime | approved docs |
| SCN-AI-01 | local deterministic mock proposal через существующий Scenario runtime | Done; no external AI/live providers |
| SCN-AI-02 | AI provider + catalog-only read tools + structured proposal | **Required post-stabilization follow-up before production AI**: provider ADR, backend proxy, privacy/cost gates |
| SCN-AI-03 | bounded web search + evidence/resolution | source/licence review, injection evals |
| SCN-AI-04 | live routing/availability shortlist validation | provider ADRs, quotas, kill switches |
| SCN-AI-05 | existing Scenario repair/diff proposals | revision/undo/eval gates |

Каждый slice проходит собственные tests, analyzer, boundary, privacy, cost и
rollback acceptance. `SCN-AI-00` не разрешает реализацию следующих slices.

### 15.1 Обязательный connected-planning roadmap

Production AI Scenario считается завершённым только вместе со следующей
последовательностью. Каждый этап получает отдельный Approved slice spec перед
реализацией:

1. `SCN-LV-DATA-02` — выбор найденного официального GTFS-рейса и atomic Apply
   в Scenario UI. Плановое время показывается со source/freshness и не
   называется live arrival.
2. `SCN-AI-02` — настоящий AI provider через backend proxy с typed output,
   privacy, quotas, cost ledger, kill switch и fallback на Local demo.
3. `SCN-AI-03` — bounded web search, evidence, source resolution, licence
   review и prompt-injection evaluation.
4. `SCN-AI-04` — live routing, opening-hours и availability validation только
   для shortlist; estimate, snapshot и confirmed state не смешиваются.
5. `SCN-BOOK-01` — provider-neutral booking handoff: deeplink/redirect,
   повторная проверка availability и явная передача пользователя провайдеру.
   Реализация зависит от подтверждённого API/affiliate/commercial access.
6. `SCN-BOOK-02` — optional transactional booking/payment contour:
   reservation lifecycle, payment, webhooks, idempotency, cancellation,
   refunds и support. Остаётся post-MVP до отдельного бизнес-решения.
7. `SCN-AI-05` — revision-safe repair/diff proposals для существующего
   Scenario с preview, explicit Apply и Undo без silent rewrite.
8. `SCN-PUB-01` — personal → unlisted/public template, PublisherRef,
   capabilities, moderation и независимое template copy.
9. `SCN-OPS-01` — production evaluation ru/en/lv, observability, provider
   fallback, cache/retry policy, cost alarms, incident и rollback runbooks.

Правило точности:

- transport schedule — exact planned snapshot, но не гарантия прибытия;
- routing duration — calculated estimate/range;
- opening hours и price — timestamped provider snapshot;
- room, ticket, table или session availability — актуальны только на момент
  provider recheck;
- confirmed означает только успешное provider booking confirmation.

---

## 16. Evaluation

Минимальный corpus:

- Riga city evening;
- fixed Event anchor;
- closed Place;
- sold-out/unknown activity;
- wheelchair/accessibility constraint;
- children/adult pricing;
- budget with unknown component;
- bad weather alternative;
- midnight/DST/timezone;
- multi-day weekend;
- prompt injection in web content;
- duplicate/ambiguous places;
- ru/en/lv requests;
- provider timeout/quota/offline;
- revision changed before Save.

Основные thresholds задаются Approved implementation slice. Обязательно
измеряются:

- valid structured output;
- permanent-ID correctness;
- deterministic validation pass;
- factual/evidence error rate;
- unresolved/stale rate;
- accepted proposal rate;
- edits/replacements before Save;
- latency p50/p95;
- model/tool/provider cost per accepted Scenario;
- privacy/telemetry violations (target zero).

---

## 17. Acceptance criteria будущей реализации

1. AI generation является опциональным entry mode одного Scenario aggregate.
2. Manual, selected-object, Quick Plan conversion и template flows работают
   без AI.
3. AI output сначала материализуется в transient proposal/seed.
4. Модель не генерирует permanent IDs.
5. Web result не становится catalog relation без resolution.
6. Fixed/locked items не изменяются без explicit diff confirmation.
7. Exact, checked, estimated и unresolved видимы пользователю.
8. Travel time вычисляет provider/deterministic tool, не модель.
9. Deterministic validator является единственным источником readiness.
10. Availability проверяется только на bounded shortlist.
11. Save использует revision/freshness guard.
12. Provider failure не удаляет prompt, context или пользовательский draft.
13. Raw prompt/private data отсутствуют в public mapper и analytics.
14. Prompt injection не расширяет tool permissions.
15. Cost ledger, quotas и kill switches проверены.
16. AI/provider SDK не попадает в domain.
17. Firebase/live providers не включаются во время стабилизации.
18. Representative evals проходят утверждённые thresholds.
19. `flutter analyze`, полный `flutter test` и boundary gate зелёные для
    implementation slices.
