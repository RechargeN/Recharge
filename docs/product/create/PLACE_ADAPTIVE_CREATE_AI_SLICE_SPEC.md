# RECHARGE — Adaptive Place Create + Local Creator Assist

Версия: v1.0 (2026-07-31).
Статус: **Approved**.
Slice: `PLC-ADP-01`.
Runtime: local/mock-first, без live AI, web и Firebase.

## 1. Решение и приоритет

Этот slice завершает уже принятый `CreateObjectType.place` и не является новым
Create-типом или новой каталоговой сущностью.

В пределах условной формы, обязательности полей, readiness и local/mock
Creator Assist этот документ заменяет конфликтующие правила
`PLACE_CREATE_BLOCK_SPEC.md` v1.0. Остальные правила исходной Place spec,
Accepted ADR и общие архитектурные границы продолжают действовать.

Связанные источники:

- `PLACE_CREATE_BLOCK_SPEC.md`;
- `CATEGORY_SYSTEM.md`;
- `AI_PRODUCT_STRATEGY.md`;
- `S3_CRT_01_CREATE_SPEC.md`;
- `docs/architecture/LAUNCH_STATUS.md`.

## 2. Проблема

Текущий Place runtime одинаково спрашивает у музея, кафе, парка и памятника:

- часы работы;
- тип входа и цену;
- типичный чек;
- полный набор amenities;
- short и full description;
- публичные контакты;
- ручные latitude/longitude.

Это противоречит Place model. `pointOfInterest` определён как самостоятельный
destination без управляемого входа, но текущая validation всё равно требует
`entryType`. Пустые нерелевантные поля удлиняют создание и провоцируют
вымышленные `free`, `alwaysOpen` и amenities.

## 3. Product promise

Creator сообщает только то, без чего место нельзя идентифицировать и найти.
Остальные поля:

- появляются по смыслу выбранной подкатегории;
- включаются явным намерением пользователя;
- могут быть добавлены позднее через edit;
- никогда не превращают отсутствие сведений в ложный факт.

## 4. Общий минимальный контракт

Для каждого Place обязательны:

- валидный PublisherRef и capability;
- title;
- канонические category/subcategory;
- точный подтверждённый representative pin;
- formatted address или location label;
- market/country/timezone из runtime/geo policy.

Не являются универсально обязательными:

- short/full description;
- cover/gallery;
- opening hours;
- admission/price/typical spend;
- amenities;
- contacts/booking;
- visit duration;
- entrance/access hint.

Category, subcategory и profile выбираются по стабильным IDs. Никакие связи не
создаются по display name.

## 5. Декларативные профили

UI не содержит списков исключений. Application resolver возвращает
`PlaceCreationPolicy` для выбранной подкатегории.

### 5.1 Профили

| Profile | Примеры | Поведение |
|---|---|---|
| `simplePoi` | monument, memorial, sculpture, public art, landmark, viewpoint | Минимальная форма; description/cover рекомендуются; hours/admission/spend/contacts скрыты |
| `publicSpace` | парк, площадь, пляж, набережная | Минимальная форма; access restrictions, hours и admission включаются только явно |
| `naturalDestination` | природная точка, сад, озеро, пещера | Минимальная форма; weather/safety/seasonality предлагаются по необходимости |
| `culturalVenue` | музей, галерея, кино, культурный центр | Description и cover обязательны; hours обязательны; admission опционален |
| `hospitality` | кафе, ресторан, бар, пекарня | Description/cover/hours обязательны; typical spend и contacts опциональны; admission скрыт |
| `activityVenue` | gym, spa, sauna, escape room, bowling | Description/cover/hours обязательны; spend/booking/amenities опциональны |
| `paidAttraction` | zoo, aquarium, amusement park, observation deck | Description/cover/hours обязательны; admission поддерживается; amenities/contacts опциональны |
| `balanced` | неизвестная или новая Place-подкатегория | Без вымышленных defaults; description/cover рекомендуются; optional groups доступны |

### 5.2 Требование поля

Каждое поле имеет один режим:

```text
hidden | optional | recommended | required
```

- `hidden` — поле не рендерится, не блокирует и не попадает в публичную
  projection;
- `optional` — доступно в `Добавить подробности`;
- `recommended` — не блокирует publish, но входит в readiness;
- `required` — блокирует переход/publish.

Новая Place-подкатегория MUST иметь явный профиль либо использовать
зафиксированный `balanced` fallback. Coverage test обязан проверять все
подкатегории, допустимые для `place`.

## 6. Неоднозначные места

Подкатегория задаёт профиль по умолчанию, но не является абсолютной истиной.

Примеры:

- botanical garden может быть открытым public space или managed attraction;
- landmark может иметь отдельную платную музейную часть;
- public park может иметь сезонные часы или платный вход.

В `Добавить подробности` Creator может включить:

- controlled access/opening hours;
- admission;
- typical spend;
- public contacts;
- external booking;
- amenities;
- visit planning.

Это расширяет форму только после явного действия. Выбор минимального профиля
не позволяет опубликовать заведомо несовместимый managed business: taxonomy,
title и активированные коммерческие поля проверяются на consistency и
moderation.

## 7. Description и media

Стандартная форма показывает одно поле `Описание`.

- Для `simplePoi`, `publicSpace`, `naturalDestination` оно recommended и не
  блокирует публикацию.
- Для managed профилей оно required.
- `fullDescription` никогда не является частью минимального пути и открывается
  только действием `Добавить подробное описание`.
- Старые short/full значения сохраняются.

Cover:

- recommended для простых/public/natural Place;
- required для managed профилей;
- отсутствие cover не создаёт вымышленное изображение; карточка использует
  существующее category-native placeholder/icon.

Gallery всегда optional и скрыта в дополнительных сведениях.

## 8. Hours, access и price

`Place.openingHours` описывает регулярную доступность Place. Event schedule
остаётся отдельной моделью.

- `simplePoi`: hours скрыты, `availabilityKind = none`;
- `publicSpace/naturalDestination`: hours optional после включения access
  restrictions;
- managed profiles: hours required; `unknown` допустим с warning;
- отсутствие hours не означает `alwaysOpen` или `closed`.

Admission:

- скрыт для `simplePoi` и `hospitality`;
- optional для public/natural/cultural;
- поддерживается `paidAttraction`;
- отсутствие admission не означает `free`;
- `notApplicable` сохраняется только для legacy/read compatibility и
  нормализованной projection, но не показывается как обязательный вопрос.

Typical spend:

- не связан с admission;
- скрыт для simple POI;
- optional для hospitality/activity profiles.

## 9. Location UX

- Creator ставит pin на карте; raw latitude/longitude не являются обычными
  полями формы.
- Timezone определяется runtime/geo policy и показывается read-only.
- Для объекта без почтового адреса достаточно location label.
- `entranceHint` в UI называется `Как найти место` и доступен только когда
  полезен.
- Private residential address policy и duplicate detection сохраняются.

## 10. Смена профиля и миграция

Смена category/subcategory:

- не удаляет введённые данные автоматически;
- несовместимые значения сохраняются в draft как inactive;
- inactive значения не валидируются и не публикуются;
- возврат к совместимому профилю восстанавливает их;
- явная очистка выполняется только после подтверждения.

Legacy draft:

- загружается без потери;
- nullable hours/pricing не получают вымышленные defaults;
- старые `notApplicable`, unknown hours и descriptions round-trip;
- mapper сохраняет unknown fields.

## 11. Readiness

Детерминированный readiness engine возвращает:

- blocking issues;
- recommended improvements;
- активный profile;
- полноту для Discover card;
- полноту для hard filters;
- unresolved factual gaps.

Publish определяет validator, не AI. Recommended сведения можно дополнить
после публикации через edit flow.

## 12. Local Creator Assist

`PLC-ADP-01` реализует честный local/mock-first помощник:

```text
typed draft
  -> provider-neutral PlaceEnrichmentPort
  -> transient proposal
  -> deterministic readiness preview
  -> explicit Apply / Discard
  -> normal controller commands
  -> normal validation/publish
```

Proposal может предложить:

- PlaceKind;
- category/subcategory из утверждённой taxonomy;
- короткий draft description;
- recommended visit duration;
- один уточняющий вопрос;
- список missing/recommended сведений.

Proposal содержит:

- transient id;
- source draft revision;
- mode = localDemo;
- field-level suggestions;
- evidence/source level;
- confidence;
- disclosures.

Apply:

- требует совпадения draft revision;
- изменяет только явно подтверждённые suggestions;
- не публикует Place;
- не создаёт permanent catalog ID;
- не перезаписывает непустой пользовательский текст без отдельного выбора.

UI обязательно показывает `Local demo` и сообщает, что live facts не
проверялись.

## 13. Trust, privacy и ranking

- AI/model output не является authoritative source.
- Hours, prices, accessibility и amenities без evidence не предлагаются как
  подтверждённые факты.
- Hard filters используют только confirmed data.
- AI description не повышает ranking только из-за наличия текста.
- Raw prompt, exact private location и media не уходят внешнему provider в
  этом slice.
- Proposal не сериализуется в Place draft.
- Manual flow работает при отсутствии/ошибке helper.

## 14. Не в scope

- live AI/LLM SDK;
- web search, scraping и official-source verification;
- image recognition;
- Firebase/backend gateway;
- автоматическая публикация или moderation decision;
- personalization/ranking model;
- localization infrastructure;
- polygon и multiple entrances;
- создание нового Create-типа.

## 15. Failure и rollback

| Сбой | Поведение |
|---|---|
| Пустой draft | Helper показывает минимальные недостающие сведения |
| Неизвестная подкатегория | `balanced` profile без вымышленных required facts |
| Helper exception | Ручная форма продолжает работать |
| Draft изменился | Apply отклоняется; требуется Regenerate |
| Нет уверенной классификации | Proposal задаёт один вопрос и не мутирует draft |
| Скрытое поле содержит legacy data | Оно сохраняется в draft, но исключается из active projection |

Rollback:

- helper отключается удалением optional coordinator/registration;
- adaptive policy может быть возвращена к `balanced`;
- persisted Place schema и старые drafts не удаляются.

## 16. Acceptance criteria

1. Monument/POI публикуется без hours, admission, spend, contacts,
   description и cover при наличии минимального location contract.
2. POI UI не показывает `Free entry`, часы или booking по умолчанию.
3. Museum требует description, cover и честный hours mode.
4. Cafe не спрашивает admission, но поддерживает hours и typical spend.
5. Public space не получает `alwaysOpen` без явного выбора.
6. Full description и gallery не находятся в минимальном пути.
7. Raw coordinates и editable timezone отсутствуют в обычном UI.
8. Category selection не требует второго confirmation tap.
9. Смена profile не уничтожает inactive values и не публикует их.
10. Каждый place-compatible subcategory покрыт profile resolver test.
11. Readiness отличает blocking, recommended и unknown.
12. Helper маркирован `Local demo`, не использует сеть и возвращает transient
    proposal с evidence/confidence.
13. Generate не меняет draft.
14. Apply требует совпадения revision и явного подтверждения.
15. Helper не предлагает неподтверждённые hours/price/accessibility/amenities.
16. Manual Create работает без helper.
17. Mapper round-trip и legacy migration сохраняют unknown/inactive data.
18. Targeted unit/widget tests, `flutter analyze`, полный `flutter test`,
    boundary и diff checks зелёные.
