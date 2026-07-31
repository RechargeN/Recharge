# RECHARGE — AI Product Strategy

Версия: v1.0 (2026-07-30).
Статус: **Approved product direction; implementation gated**.

Этот документ фиксирует AI как общий capability layer Recharge. Он не
утверждает конкретного AI-провайдера, не разрешает production integration и
не создаёт отдельную роль, сущность каталога или одиннадцатый Create-тип.
Каждый AI use case реализуется отдельным reviewable slice после выполнения
своих delivery gates.

Связанные документы:

- [VISION.md](VISION.md);
- [SCENARIO_BUILDER_SPEC.md](SCENARIO_BUILDER_SPEC.md);
- [SCENARIO_AI_GENERATION_SPEC.md](SCENARIO_AI_GENERATION_SPEC.md);
- [SCENARIO_CONNECTED_PLANNING_SPEC.md](SCENARIO_CONNECTED_PLANNING_SPEC.md);
- `docs/architecture/ARCHITECTURE_BASELINE.md`;
- `docs/architecture/LAUNCH_STATUS.md`;
- `docs/adr/`.

---

## 1. Решение

AI в Recharge — не самостоятельный раздел ради чата и не источник истины.
Это заменяемый orchestration/assistance layer поверх существующих domain
models, repositories, validators и provider ports.

Первый подробно специфицированный продуктовый вариант использования AI —
**AI Scenario Generation**: создание проверяемого Scenario preview по
естественному запросу пользователя.

AI Scenario Generation является одним из вариантов использования AI, а не
полным определением AI-направления Recharge.

---

## 2. Портфель AI use cases

| ID | Use case | Пользовательская ценность | Статус направления |
|---|---|---|---|
| AI-01 | AI Scenario Generation | получить выполнимую основу city/day/weekend/trip плана по контексту | подробно специфицировано; implementation gated |
| AI-02 | LLM Smart Search | разобрать естественный запрос в typed Discover conditions | post-stabilization; rule-based parser остаётся fallback |
| AI-03 | Personal recommendations | ранжировать допустимые объекты и alternatives по контексту и обратной связи | future; требуется отдельный ranking ADR/evaluation |
| AI-04 | Creator assist | предложить черновик описания, структуру и criteria без автоматической публикации | Place local/mock vertical реализован в `PLC-ADP-01`; production provider остаётся gated |
| AI-05 | Scenario recovery | предложить перестройку оставшегося плана при задержке, закрытии или недоступности | future; только proposal + explicit apply |
| AI-06 | Review/quality assistance | суммировать известные сигналы качества и выявлять конфликтующие сведения | future; не заменяет Review и moderation decisions |

Портфель может расширяться только через обновление продукта и отдельную
спецификацию. AI не должен молча проникать в существующие flows как
необъяснимое ранжирование или скрытая мутация.

---

## 3. Общая модель взаимодействия

Для всех AI use cases действует один lifecycle:

```text
user intent
  -> typed context
  -> approved read-only tools
  -> AI proposal
  -> deterministic validation
  -> preview with evidence/issues
  -> explicit user confirmation
  -> normal domain command
```

AI может:

- интерпретировать естественный язык;
- выбирать, какие разрешённые read-only tools вызвать;
- сравнивать кандидатов;
- формировать typed proposal;
- объяснять ограничения и alternatives.

AI не может:

- создавать подтверждённые факты без источника;
- заменять permanent entity IDs названием или координатой;
- обходить domain validation;
- выполнять бронирование, оплату, публикацию или destructive mutation без
  отдельного явного пользовательского действия;
- выдавать web search result за объект каталога;
- переписывать locked/fixed user decisions;
- хранить provider keys в мобильном клиенте;
- становиться единственным способом Search, Scenario authoring или Create.

---

## 4. Источники истины и confidence

AI-ответ сам по себе никогда не является authoritative source.

| Уровень | Значение |
|---|---|
| `verifiedProvider` | актуальный ответ разрешённого API или подтверждённая booking/session запись |
| `officialSource` | проверенная официальная страница с URL и временем проверки |
| `catalogSnapshot` | versioned объект Recharge с source/freshness metadata |
| `estimated` | вычисленное или модельное предложение с диапазоном/ограничением |
| `unresolved` | кандидат не сопоставлен с permanent catalog/provider ID |

UI обязан показывать существенную разницу между подтверждённым, проверенным,
оценочным и неизвестным. Устаревшие сведения не становятся точными из-за
уверенной формулировки модели.

---

## 5. Архитектурные границы

1. Domain entities не зависят от OpenAI, другой модели или SDK.
2. AI provider вызывается через backend/application gateway.
3. AI получает минимальные typed DTO и tool descriptions, а не прямой доступ
   к Firestore, UI state или секретам.
4. Tools используют существующие repositories/provider ports.
5. Structured output сначала материализуется в proposal/seed, а не напрямую
   в persisted aggregate.
6. Persisted изменение выполняется существующей domain command/use case после
   validation и подтверждения.
7. Provider choice, data residency, retention, quotas и legal terms требуют
   отдельного Accepted ADR или Approved production integration decision.
8. При выключенном AI ручные и детерминированные flows продолжают работать.

---

## 6. Privacy и безопасность

- Raw prompt считается personal data и не попадает в обычные analytics,
  public Scenario, notifications или logs.
- Exact private locations, booking references, participant contacts и private
  notes не передаются AI без отдельного минимизированного purpose contract.
- Для analytics используются enum/bucket/signals, а не полный prompt или
  provider response.
- Prompt injection из web content не может расширить tool permissions или
  разрешить mutation.
- External content хранится и цитируется только в рамках licence/retention
  условий источника.
- Moderation и safety policy применяются независимо от качества модели.

---

## 7. Cost и reliability policy

- AI/provider calls идут только через server-owned quota и cost ledger.
- У каждого use case есть per-request, daily и monthly budgets.
- Web/live calls выполняются только для shortlist, а не для всей выдачи.
- Static prompt/tool prefixes допускают caching по условиям провайдера.
- Timeouts, retries и concurrency имеют жёсткие limits.
- Kill switch отключает конкретного провайдера или use case без потери
  manual/deterministic flow.
- Деградация возвращает partial typed result или понятный fallback, а не
  выдуманные данные.

---

## 8. Evaluation до rollout

Каждый AI slice обязан иметь versioned evaluation set минимум для:

- соблюдения IDs и schema;
- factual grounding/source attribution;
- hard constraints;
- закрытых/недоступных объектов;
- timezone/DST;
- бюджета и unknown values;
- prompt injection;
- multilingual en/ru/lv;
- отказа provider/quota/offline;
- отсутствия private data в output/telemetry;
- сравнения качества, latency и стоимости с детерминированным baseline.

В production наблюдаются:

- proposal success rate;
- validation blocker rate;
- preview → Save/Edit/Discard;
- доля ручных замен;
- stale/unresolved rate;
- tool calls и cost per accepted result;
- provider failures;
- user-reported incorrect facts.

Рост количества AI-вызовов не считается успехом без роста полезных
подтверждённых результатов.

---

## 9. Delivery gates

| Gate | Требование |
|---|---|
| Product | Approved use-case spec и понятный non-AI fallback |
| Architecture | provider-neutral ports, backend proxy, no mobile secrets |
| Trust | evidence/confidence/freshness model и deterministic validation |
| Privacy | data minimization, retention, telemetry и deletion review |
| Cost | quotas, budget alerts, ledger и kill switch |
| Quality | representative evals и acceptance thresholds |
| Operations | timeout/retry/fallback/rollback runbook |
| Release | feature flag, staged cohort и provider disable path |

Во время активной стабилизации разрешены документация, contracts и
детерминированные mocks только по отдельному Approved slice. Live AI, web,
booking, Firebase и другие production providers остаются выключенными.

---

## 10. Явно не принято этим документом

- выбор AI vendor/model;
- production API credentials;
- разрешение на web scraping;
- автоматическая публикация AI-контента;
- автоматические бронирования или платежи;
- скрытое персональное ранжирование;
- обучение модели на private Recharge data;
- замена rule-based Smart Search без fallback;
- изменение Accepted ADR.
