# RECHARGE — Place / Business Create Block Spec

Версия: v1.0 (2026-07-19). Статус: **Approved**.
Уровень: проект slice spec для `CreateObjectType.place` в Create Hub.

> Актуализация: conditional form, обязательность полей, readiness и
> local/mock Creator Assist заменены Approved slice
> [PLACE_ADAPTIVE_CREATE_AI_SLICE_SPEC.md](PLACE_ADAPTIVE_CREATE_AI_SLICE_SPEC.md)
> v1.0 (`PLC-ADP-01`, 2026-07-31). Остальные контракты этого документа
> продолжают действовать.

Этот документ описывает целевую продуктовую и доменную логику блока
создания постоянного места или бизнеса. Версия `v1.0` утверждена владельцем
продукта и является активной slice spec. Решения §23 обязательны для
реализации; отклонения оформляются отдельными slices/ADR с acceptance criteria.

Связанные источники истины:

- [VISION.md](VISION.md) — продуктовая роль Place / Business;
- [CATEGORY_SYSTEM.md](CATEGORY_SYSTEM.md) — категории, подкатегории и
  динамические criteria-профили;
- [S3_CRT_01_CREATE_SPEC.md](S3_CRT_01_CREATE_SPEC.md) — общий Create flow,
  локальный draft и отправка в `pending_review`;
- [SEARCH_FILTERS_TIME_SPEC.md](SEARCH_FILTERS_TIME_SPEC.md) — opening hours,
  open-now, time-fit и travel-fit;
- [S2_DISC_02_MAP_SPEC.md](S2_DISC_02_MAP_SPEC.md) — общий Map/Discover
  contract и Google Maps baseline;
- [ADR 0011](../adr/0011-architecture-freeze.md) — frozen architecture;
- [ADR 0012](../adr/0012-tech-stack-defaults.md) — state, DI, errors и
  telemetry defaults;
- [ADR 0013](../adr/0013-domain-policy-baseline.md) — ownership, lifecycle,
  permissions, moderation, IDs, geo, offline и audit;
- [ADR 0014](../adr/0014-time-fit-ranking.md) — вес time-fit, grouping и
  обязательный kill switch.

При конфликте Accepted ADR и этого документа побеждает ADR. После
утверждения этот документ как spec текущего slice имеет приоритет над
`LAUNCH_STATUS.md` и `VISION.md`. `VISION.md` обновляется синхронно, чтобы
не сохранять противоречие. Отсутствие синхронного обновления блокирует
статус Done, но не отменяет приоритет утверждённой slice spec.

При конфликте с каноническим `CATEGORY_SYSTEM.md` побеждает Category
System, пока изменение каталога не оформлено новой принятой версией.

Для market defaults этот документ использует актуальный контракт
`SEARCH_FILTERS_TIME_SPEC.md`: Riga / `Europe/Riga` / EUR. Исторический
Rezekne default из старого Map checkpoint не применяется к новым Place
drafts и не должен возвращаться через fallback.

### История версии

- `v0.1` — первоначальная сквозная логика Place / Business;
- `v0.2` — устранено смешение рабочих статусов и часов, добавлены
  инварианты, conditional form logic, модель часов, филиалы, provenance,
  freshness, state/error contracts и разрыв между текущим и целевым runtime.
- `v1.0-rc1` — продуктовые развилки закрыты, `PlaceKind` сделан взаимно
  исключающим, форма сокращена до четырёх шагов, добавлены product promise,
  jobs-to-be-done, progressive disclosure и измеримые success criteria.
- `v1.0-rc2` — уточнены alwaysOpen exceptions, overnight, amenities,
  single-draft MVP, locale registry, provenance и natural-place city fallback.
- `v1.0-rc3` — исправлен приоритет slice spec над vision, устранён конфликт
  moderation для URL/contact edits, определены `PlaceEntryType` и границы
  temporary closure, синхронизирована draft policy, добавлена трассировка
  decisions → tests и финальная матрица edge cases.
- `v1.0` — кандидат `rc3` утверждён владельцем продукта как активная slice spec.

### Нормативные слова

- **MUST / MUST NOT** — обязательный инвариант будущей реализации;
- **SHOULD / SHOULD NOT** — рекомендуемое поведение, отступление требует
  причины в slice/PR;
- **MAY** — допустимый вариант реализации.

Русские формулировки «обязан», «запрещено», «требуется» равны MUST.
«Рекомендуется» равно SHOULD. До смены статуса на `Approved` решения ещё
требуют продуктового утверждения владельцем, но внутри документа
трактуются однозначно и не содержат альтернативных вариантов поведения.

### Что описывает документ

Документ одновременно фиксирует:

1. пользовательское поведение Create-блока;
2. доменные инварианты Place;
3. контракт будущей реализации поверх общего form engine;
4. публичную проекцию в Discover/Map/Details;
5. lifecycle, moderation, analytics и проверяемые acceptance criteria.

Документ **не утверждает, что перечисленная логика уже реализована**.
Текущий mock runtime поддерживает только общий Create baseline; разрыв с
целевым состоянием явно перечислен в §9.4.

### Product promise

Creator может за несколько минут добавить на карту полезное реальное место,
не разбираясь в доменной модели Recharge. Пользователь получает не рекламную
анкету, а достоверный ответ на пять вопросов:

1. **Что это?** — понятное название и категория.
2. **Где это?** — подтверждённый pin и пригодное описание входа.
3. **Можно ли прийти?** — open/closed/unknown без ложной уверенности.
4. **Подходит ли мне?** — длительность, цена, amenities и accessibility.
5. **Что делать дальше?** — построить путь, сохранить или перейти на
   официальный внешний ресурс.

Идеальный Place одновременно быстрый для создания, полезный для решения
«куда пойти» и достаточно структурированный для Search/Map/time-fit.

### Product principles

1. **Сначала польза, потом полнота.** Для публикации требуется небольшой
   достоверный минимум; расширенные поля открываются progressive disclosure.
2. **Unknown честнее догадки.** Система не придумывает часы, цену,
   доступность или ownership.
3. **Карта — источник действия.** Place без подтверждённого pin не
   публикуется.
4. **Одна точка — один объект.** Филиалы и независимые объекты не склеиваются
   по бренду или названию.
5. **Последняя проверенная версия остаётся живой.** Material edit не ломает
   публичный объект до модерации.
6. **Внешнее действие прозрачно.** Маршрут остаётся главным CTA; booking и
   сайт явно обозначаются внешними.
7. **Модель не зависит от UI.** Четыре шага — UX-композиция типизированных
   секций общего form engine, а не отдельный Place flow.

### Jobs-to-be-done

| Пользователь | Job | Успешный результат |
|---|---|---|
| Creator-владелец | Добавить свой бизнес/площадку | Place ожидает review, данные можно обновлять |
| Creator-куратор | Добавить полезный парк/POI | Место опубликовано без ложной ownership claim |
| Пользователь Discover | Найти подходящее место рядом | Понимает fit, цену и как добраться |
| Планирующий маршрут | Добавить Place в Quick Plan/Collection | Стабильная ссылка по `placeId` |
| Модератор | Быстро проверить качество и дубли | Понятные reason codes и provenance |

### Success framework

North-star для Place: доля открытий Place Details, завершившихся полезным
действием `route | save | add_to_plan | external_booking`.

Стартовые product targets на первые 30 дней после rollout (пересматриваются
после получения baseline, не являются искусственными тестовыми данными):

| Метрика | Target | Guardrail |
|---|---:|---|
| Начал Place → отправил на review | ≥ 65% | Не повышать за счёт скрытия ошибок |
| Median active create time | ≤ 5 мин | Не считать время background |
| First-pass moderation approval | ≥ 80% | Reject reasons остаются измеримыми |
| Published Place с подтверждённым pin | 100% | Ни одного fallback center pin |
| Duplicate rate после публикации | < 2% | Warning не превращать в blind block |
| ManagedVenue с unknown hours | < 25% | Unknown честнее вымышленных часов |
| Details → meaningful action | ≥ 20% | Внешние CTA не маскируются |
| Crash-free Place create sessions | ≥ 99.5% | Draft recovery обязателен |

Safety guardrails имеют приоритет над conversion: private-address leak,
unsafe URL, потеря draft или создание дубля idempotency retry считаются
blocker defects независимо от агрегированных метрик.

---

## 1. Цель блока

Place / Business позволяет Creator создать постоянный физический объект,
который пользователь может найти на карте, открыть в Discover, сохранить,
посетить и при наличии внешней ссылки перейти к бронированию.

Типичные объекты:

- кафе, ресторан, бар, пекарня;
- музей, галерея, кинотеатр, культурный центр;
- спортзал, корт, бассейн, скалодром;
- парк, пляж, смотровая площадка, природная точка;
- студия, спа, сауна, коворкинг;
- общественный центр, приют, локальный рынок;
- достопримечательность или другая постоянная точка интереса.

Пользовательская ценность Place:

1. понять, что это за место и подходит ли оно под текущий запрос;
2. увидеть точную точку на карте и построить путь;
3. проверить часы работы и статус `open now`;
4. оценить ожидаемое время посещения, цену и удобства;
5. открыть официальный контакт или внешний booking URL;
6. сохранить место или использовать его как точку сценария/подборки.

### 1.1 Неподвижные инварианты

1. Place MUST иметь одну подтверждённую физическую геоточку.
2. Place MUST существовать независимо от отдельных Event/Session.
3. Публичные связи MUST использовать `placeId`, никогда title/address.
4. Один опубликованный Place описывает одну физическую точку обслуживания.
5. Один Place MUST иметь одну каноническую category/subcategory.
6. Market, timezone и currency MUST приходить из конфигурации/геологики,
   а не из hardcoded UI defaults.
7. UI MUST NOT содержать validation, opening-status или publish policy.
8. `unknown` MUST NOT молча превращаться в `false`, `closed`, `free` или
   `always open`.
9. Последняя одобренная revision MUST оставаться публичной, пока material
   edit проходит review.
10. Любая внешняя ссылка MUST быть явно обозначена как переход из Recharge.

### 1.2 Единица Place и филиалы

- Каждый физический адрес/отдельный pin сети является отдельным Place с
  собственным `placeId`, hours, amenities и operational status.
- Бренд или сеть не является Place. После реализации ManagedPage несколько
  филиалов связываются общим `publisherRef` или отдельным `brandId` только
  по утверждённому контракту.
- Нельзя создать один Place «Все филиалы» с несколькими pins.
- Два объекта внутри одного здания могут быть разными Place, если имеют
  самостоятельное название/оператора или пользовательский destination.
- Несколько входов одного объекта не создают несколько Place: основной pin
  остаётся один, дополнительные entrances — post-MVP typed subentities.
- Большая территория (парк, пляж) в MVP представляется representative pin;
  polygon/geometry boundary — post-MVP и не подменяет основной pin.

---

## 2. Доменная граница

### 2.1 Что является Place

Place — постоянная физическая локация с собственной идентичностью,
координатами и жизненным циклом. Место продолжает существовать независимо
от конкретного события, сеанса или предложения.

### 2.2 Что не является Place

| Пользователь хочет создать | Правильный тип | Причина |
|---|---|---|
| Концерт в клубе в пятницу | Event | Главная сущность — событие во времени |
| Бронь корта на 18:00 | Bookable Session | Главная сущность — доступный временной слот |
| Прогулочный трек | Route | Главная сущность — непрерывная геометрия пути |
| План «кофе → музей → прогулка» | Quick Plan | Это набор независимых остановок |
| Скидка или специальное предложение | Post-MVP Offer, если будет утверждён | Предложение не определяет место |
| Выездная услуга без постоянной точки | Не Place | Нет постоянной публичной геолокации |

### 2.3 Связь Place с другими объектами

- Event и Bookable Session могут ссылаться на Place только по `placeId`.
- Временная площадка события может храниться как snapshot location без
  создания отдельного Place.
- Place не хранит внутри себя список событий как источник истины. Список
  «События здесь» строится обратным запросом по `placeId`.
- Collection и Quick Plan могут хранить ссылки на Place по `id`.
- Название места никогда не используется как связь между сущностями.
- ManagedPage представляет издателя/бренд, а Place — физический объект.
  Одна страница может управлять несколькими Place.

### 2.4 Place и Business

Это один Create type и одна доменная сущность. Различие задаётся взаимно
исключающим `PlaceKind`, а не отдельным flow:

```text
PlaceKind = managedVenue | publicSpace | pointOfInterest
```

- `managedVenue` — кафе, музей, спортзал, студия, сауна, общественный центр
  или другая площадка с оператором и управляемым доступом;
- `publicSpace` — парк, пляж, площадь или общедоступная территория;
- `pointOfInterest` — памятник, видовая точка, достопримечательность или
  иной самостоятельный destination без управляемого входа.

Коммерческий статус не является отдельным enum: и коммерческий музей, и
бесплатный общественный центр могут быть `managedVenue`. Категория отвечает
на вопрос «что пользователь там делает», а `PlaceKind` — «как пользователь
взаимодействует с физической точкой». Это не новая категория и не участвует
в Category System.

---

## 3. Зафиксированные решения final candidate

Ниже приведены согласованные между собой решения `v1.0-rc3`. Они не имеют
статуса Accepted до подтверждения владельцем продукта, но дальнейшие
разделы не содержат альтернативного поведения.

| ID | Решение v1.0-rc3 | Обоснование |
|---|---|---|
| P1 | Business и публичные места создаются одним типом Place | Единая карта, Details и Discover projection |
| P2 | Для публикации обязательна точная геоточка | Place без координат не выполняет основную функцию |
| P3 | Обязателен `formattedAddress` или `locationLabel`; почтовый адрес не является универсальным blocker | У природных и части загородных мест нет формального адреса |
| P4 | У Place одна каноническая категория и одна подкатегория | Не размывает фильтры; дополнительные свойства идут через criteria и amenities |
| P5 | Cover обязателен; gallery опциональна | Совпадает с текущим Create baseline |
| P6 | MVP: regular/alwaysOpen/unknown + exceptions; seasonal входит в target Phase 2; закрытие — отдельный operational overlay | Даёт честный MVP без потери целевой модели |
| P7 | Внутренней оплаты и бронирования в MVP нет; Place MAY иметь общую внешнюю booking landing page | Конкретный слот остаётся Bookable Session |
| P8 | Похожий объект рядом даёт предупреждение, но не блокирует публикацию автоматически | Совпадение названия и координат ещё не доказывает дубль |
| P9 | Существенные изменения опубликованного Place отправляются на повторную модерацию | Защищает карту, название, категорию и медиа от подмены |
| P10 | Пользовательские предложения правок чужого Place — post-MVP | Требуют отдельной очереди доверия и модерации |
| P11 | Place создаёт Creator с capability `create.place`; User сначала включает Creator mode | Роли остаются по ADR 0013, UI-уровни не становятся ролями |
| P12 | Claim/verified business, polygon и multiple entrances — post-MVP | Для них нужны отдельные evidence/geometry contracts |

---

## 4. Владение и права

### 4.1 Publisher

Каждый Place публикуется от имени:

```text
PublisherRef {
  type: user | page
  id: ULID/UUID
}
```

Привязка только по ID. Отображаемое имя издателя не является источником
прав. До реализации ManagedPage UI может позволять публикацию только от
текущего User, но модель не должна закрывать будущий `page` publisher.

### 4.2 Capabilities

Рекомендуемый набор проверок:

- `create.place` — начать и сохранить draft;
- `publish.place` — отправить Place на модерацию;
- `manage_place` — редактировать, архивировать и восстанавливать Place;
- `manage_page` — публиковать от имени ManagedPage;
- `moderate_content` — approve/reject/hide;
- `admin_delete_content` — окончательное удаление по политике.

Роль сама по себе не даёт право. Контроллер/use case проверяет capability
до операции; UI только скрывает или блокирует недоступное действие.

### 4.3 Ownership cases

- Creator может создать независимое публичное место, не заявляя юридическое
  владение бизнесом.
- Поле `relationshipToPlace` фиксирует `owner | staff | visitor | curator`.
- Значение `owner` или `staff` не считается верификацией бизнеса.
- Верификация владельца, badge verified и claim flow — отдельный post-MVP
  процесс.
- Контакты частного лица не публикуются автоматически как контакты места.

---

## 5. Жизненный цикл

Используются состояния ADR 0013:

```text
draft
  -> pending_review
  -> published
  -> archived
  -> deleted

pending_review -> draft       (creator отменил отправку, если review не начат)
pending_review -> draft       (rejected: исправить и отправить повторно)
published      -> hidden      (moderation/system restriction)
hidden         -> published   (moderator restored)
archived       -> published   (owner restored, при необходимости review)
```

Диаграмма иллюстрирует основной путь. Нормативным является полный список
переходов в матрице §5.1, включая delete. Переход, отсутствующий в матрице,
запрещён и возвращает typed domain failure.

Правила:

- `draft` видит только владелец и разрешённые collaborators;
- `pending_review` не попадает в публичные Search/Map/Feed;
- `published` доступен по стабильному `placeId` и deep link;
- `archived` скрыт из выдачи, но восстанавливается владельцем;
- `hidden` управляется модерацией или системой;
- `deleted` является soft-delete на 30 дней;
- hard delete выполняется после retention или по legal request;
- все переходы пишутся в audit trail.

### 5.1 Матрица переходов lifecycle

| From | Action | Actor/precondition | To | Публичная версия |
|---|---|---|---|---|
| draft | submit | publisher + `publish.place`, validation green | pending_review | нет |
| pending_review | withdraw | publisher, review ещё не locked | draft | нет |
| pending_review | approve | moderation | published | новая approved revision |
| pending_review | request_changes | moderation + reason codes | draft | предыдущая approved, если это edit |
| published | submit material edit | publisher + expected revision | published + pending revision | предыдущая approved |
| published | archive | publisher + `manage_place` | archived | скрыта |
| archived | restore | publisher + policy checks | published или pending_review | по решению material policy |
| published | hide | moderation/system | hidden | скрыта |
| hidden | restore | moderation | published | последняя approved |
| draft/archived | delete | publisher | deleted | скрыта |
| published/hidden | delete | owner request + policy | deleted | tombstone/скрыта |

Недопустимый transition возвращает typed domain failure и не изменяет ни
локальную, ни публичную revision.

### 5.2 Состояние работы самого места

Lifecycle сущности не смешивается с рабочим статусом физического объекта:

```text
PlaceOperationalStatus = operating | temporarilyClosed | permanentlyClosed
```

- `temporarilyClosed` оставляет Details и сохранённые ссылки доступными,
  но место не считается открытым;
- `temporarilyClosed` хранит обязательный `closedFromLocalDate`, опциональные
  `closedUntilLocalDate` и public note; underlying hours не удаляются;
- `permanentlyClosed` показывается в Details и исключается из обычной
  выдачи, пока владелец не архивирует объект или модератор не подтвердит
  иной статус;
- `archived` означает решение владельца о публикации, а не физическое
  состояние бизнеса.

Нормативная семантика temporary closure:

- `closedFromLocalDate` обязателен;
- `closedUntilLocalDate` опционален и, если задан, не раньше start date;
- обе даты трактуются в timezone Place, без UTC-полуночи;
- границы включительны: closure действует с 00:00 start date до 00:00 дня,
  следующего за `closedUntilLocalDate`;
- null end date означает закрытие без заявленной даты открытия;
- после окончания интервала статус вычисляется по underlying hours;
- изменение pin/timezone инвалидирует closure evaluation до повторной
  валидации локальных дат.

При вычислении opening status приоритет такой:

```text
permanentlyClosed
  > active temporarilyClosed interval
  > date exception
  > seasonal schedule
  > regular weekly schedule / alwaysOpen
  > unknown
```

---

## 6. Общий пользовательский flow

Целевой flow использует единый config-driven form engine. Отдельная
`PlaceCreatePage` не создаётся.

```text
Create Hub
  -> выбор Place / Business
  -> восстановление существующего draft или новый draft
  -> 4 шага с progressive disclosure
  -> локальное автосохранение
  -> preview + final validation
  -> duplicate check
  -> отправка в pending_review
  -> moderation
  -> published
  -> Discover / Map / Details
```

Финальная структура из четырёх шагов:

1. **Что за место** — kind, relationship, название, категория,
   подкатегория, короткое описание и язык контента.
2. **Где и когда** — address/location label, pin confirmation, timezone,
   hours/status, рекомендуемая длительность.
3. **Что внутри** — criteria, amenities, accessibility, entry/price,
   контакты, полное описание, cover и gallery. Необязательные группы
   свёрнуты и открываются по намерению пользователя.
4. **Проверка** — полноценный Details preview, blocking errors, warnings,
   duplicate candidates и submit.

Минимальный путь не заставляет Creator заполнять несуществующие часы,
цену, контакты или длинное описание. Для publish обязательно только:

- `placeKind`, `relationshipToPlace` и publisher context;
- title, category, subcategory, short description и content locale;
- market, pin confirmation и address **или** location label;
- обязательные criteria выбранного профиля;
- честно выбранные hours mode и entry type, включая `unknown`;
- cover image;
- успешные permission, safety, duplicate и validation checks.

Порядок может адаптироваться под экран, но доменные секции и валидация не
должны зависеть от конкретной визуальной разбивки на шаги.

Progressive disclosure MUST NOT скрывать ошибки: если скрытая опциональная
группа содержит введённые невалидные данные, шаг получает error state и
группа раскрывается при переходе к ошибке.

Обязательные для publish поля, включая `entryType` и hours mode, MUST NOT
находиться внутри свёрнутых опциональных групп. Collapsed-группы содержат
только опциональные поля; обязательное поле всегда видно без дополнительного
действия пользователя.

### 6.1 Состояния form flow

```text
initializing
  -> editing.clean
  -> editing.dirty
  -> saving
  -> editing.clean
  -> validating
  -> preview
  -> checkingDuplicates
  -> readyToSubmit
  -> submitting
  -> submitted.pendingReview

saving/submitting -> recoverableFailure -> editing.dirty
initializing       -> migrationRequired -> editing | blockedWithRecovery
any editable state -> permissionLost -> readOnlyDraft
```

- Navigation между шагами не меняет lifecycle draft.
- `editing.clean/dirty` описывает только локальную save revision.
- `preview` не замораживает draft: любое изменение создаёт новую revision и
  инвалидирует предыдущие validation/duplicate results.
- Submit разрешён только для revision, для которой завершены save,
  validation, duplicate check и media readiness.
- Back/cancel никогда не удаляет draft без отдельного confirmation.

### 6.2 Conditional form logic

| Условие | Показывать/требовать | Очистить при смене |
|---|---|---|
| managedVenue | hours choice; address или locationLabel; contacts рекомендованы | Ничего автоматически |
| publicSpace | pin + address или locationLabel; hours MAY быть unknown | Venue-only contacts после confirmation |
| pointOfInterest | pin + locationLabel; hours MAY быть unknown | Venue-only contacts после confirmation |
| hours = regular | weekly periods + exceptions | seasons после confirmation |
| hours = seasonal (Phase 2) | seasons + exceptions | regular periods после confirmation |
| hours = alwaysOpen | date exceptions closedAllDay/customHours разрешены по D19 | periods/seasons после confirmation |
| hours = unknown | объяснение/warning | periods/seasons после confirmation |
| status = temporarilyClosed | from/until/note | Closure dates при возврате operating |
| status = permanentlyClosed | reason + confirmation | Temporary closure dates |
| entryType = free | pricing note optional | Entry price range немедленно |
| entryType = paid/mixed | entry price range | Ничего автоматически |
| entryType = notApplicable | typical spend MAY остаться, entry price скрыт | Entry price range немедленно |
| entryType = unknown | сильное warning, цены скрыты | Entry price range после confirmation |
| external booking enabled | booking HTTPS URL | URL при выключении после confirmation |
| category/subcategory changed | новый criteria profile | Только несовместимые criteria после confirmation |

Правило destructive field reset:

1. UI показывает, какие данные станут несовместимыми;
2. пользователь подтверждает смену;
3. controller выполняет одну atomic update;
4. операция доступна как единый undo в текущей session;
5. draft сохраняется уже после согласованного перехода.

### 6.3 Progress и completeness

- Прогресс шага вычисляется application selector'ом из обязательных полей
  активной конфигурации.
- `completeness` — подсказка, не moderation score и не ranking signal.
- 100% completeness не гарантирует publish: async checks могут вернуть
  duplicate/media/permission error.
- Неактивные скрытые поля не уменьшают progress.
- UI MUST показывать первый blocking section и общее число ошибок, но не
  заменять field-level сообщения одним общим snackbar.

### 6.4 Reference journeys

#### A. Владелец добавляет кафе

1. Выбирает Place → `managedVenue` → relationship `owner`.
2. Выбирает Food & Drinks / Coffee, вводит короткое описание.
3. Находит адрес, проверяет pin, задаёт regular split hours.
4. Указывает typical spend, amenities, website/общую booking page и cover.
5. Preview показывает карту, open status и внешний CTA.
6. Duplicate check не находит совпадение; Place уходит в pending review.
7. До approve бизнес не получает verified badge только из-за owner claim.

#### B. Куратор добавляет парк

1. Creator выбирает `publicSpace` → relationship `curator`.
2. Выбирает Outdoor/Nature category, ставит pin и location label.
3. Почтового адреса нет; hours = alwaysOpen только если это достоверно,
   иначе unknown.
4. Отмечает free entry, weather dependency, accessibility и amenities.
5. Добавляет cover и отправляет. Отсутствие business contacts не даёт error.

#### C. Creator добавляет смотровую точку

1. Выбирает `pointOfInterest`, category и короткое описание.
2. Подтверждает representative pin и entrance hint.
3. Указывает unknown hours, recommended visit 30 минут, free entry.
4. Time-fit остаётся unknown по opening status, но duration помогает
   пользователю планировать посещение.

#### D. Оператор временно закрывает место

1. Открывает published Place с `manage_place`.
2. Устанавливает temporarilyClosed, даты и public note.
3. Underlying weekly hours сохраняются.
4. Auto-check + audit применяют operational overlay без ручного review.
5. После `closedUntilLocalDate` место автоматически возвращается к
   underlying hours; пустой edit не обновляет ranking freshness.

---

## 7. Создание и восстановление draft

### 7.1 Новый draft

При выборе Place controller:

1. создаёт локальный `loc_*` draft ID;
2. устанавливает `objectType = place`;
3. берёт market/city/timezone/currency из runtime config через DI;
4. устанавливает `availabilityKind = openingHours` только после выбора
   режима с расписанием; нельзя создавать вымышленные default-часы;
5. выбирает предложенную категорию только как визуальный preset — Creator
   должен подтвердить её перед публикацией;
6. создаёт `publisherRef` из текущего контекста пользователя;
7. запускает локальное автосохранение.

### 7.2 Возврат в Create

Если есть незавершённый Place draft:

- показывается «Продолжить» с датой последнего изменения;
- пользователь может продолжить его или создать новый;
- по D18 MVP хранит один активный Place draft на пользователя;
- создание нового требует явного решения по существующему: продолжить,
  удалить с confirmation или завершить отправку;
- новый draft никогда не перезаписывает существующий молча;
- multi-draft repository — Phase 2; миграция legacy single draft сохраняет
  все введённые данные и исходную revision.

### 7.3 Автосохранение

- debounce: рекомендуемо 500–1000 мс после изменения;
- немедленное сохранение при переходе между шагами и уходе приложения в
  background;
- отсутствие сети не блокирует редактирование;
- состояние save: `saved | saving | unsaved | failed`;
- при ошибке данные остаются в памяти, показывается retry;
- publish никогда не стартует, пока актуальная версия draft не записана;
- конфликт sync: last-write-wins + явное предупреждение пользователю по
  ADR 0013.

---

## 8. Секции и поля формы

### 8.1 IdentitySection

| Поле | Тип | Обязательность | Правило |
|---|---|---|---|
| `title` | text | да | 2–100 символов после trim |
| `placeKind` | enum | да | managedVenue/publicSpace/pointOfInterest |
| `relationshipToPlace` | enum | да | owner/staff/visitor/curator |
| `shortDescription` | text | да | 20–180 символов |
| `fullDescription` | multiline | нет | Если заполнено: 50–5000 символов |
| `contentLocale` | enum | да | Из supported locale registry; MVP: en/ru/lv |
| `languages` | multiselect | нет | Из того же registry; MVP: en/ru/lv/other |

Запрещено:

- добавлять телефон, email или URL в title;
- писать только caps lock без смысловой причины;
- использовать misleading название другого бизнеса;
- вводить рекламные промокоды в title.

`contentLocale` не означает локаль интерфейса и не заменяет `languages`
(языки обслуживания/контента в месте). Набор поддерживаемых локалей приходит
из runtime locale registry, а не из hardcoded enum в UI. В MVP хранится одна
основная версия title/descriptions. Параллельные переводы одного Place —
post-MVP typed localizations, а не дубли Place по языку.

### 8.2 CategorySection

1. Показываются только категории/подкатегории, где Place присутствует в
   `applicableTypes` канонического Category System.
2. Creator выбирает одну категорию и одну подкатегорию.
3. Сохраняются стабильные `categoryId` и глобальный `subcategoryId`.
4. При смене подкатегории несовместимые dynamic criteria удаляются только
   после confirmation; общие совпадающие поля сохраняются.
5. Пользовательские tags ограничены политикой каталога и модерацией.
6. Категория не определяется автоматически только по названию.

### 8.3 DynamicCriteriaSection

- получает criteria profile выбранной подкатегории;
- рендерит поля из общего field dictionary;
- пишет значения по стабильным `fieldId`;
- не содержит per-category switch в UI;
- обязательность определяется профилем;
- скрытое из-за смены профиля значение не публикуется как активный
  критерий, но может временно храниться для undo внутри draft session.

### 8.4 LocationSection

| Поле | Обязательность | Логика |
|---|---|---|
| `marketCityId` | да | Из registry, не свободная строка |
| `countryCode` | да | ISO-код из market/address |
| `city` | да | Канонический locality; если его нет — market city из registry |
| `formattedAddress` | условно | Вместе с locationLabel: хотя бы одно обязательно |
| `addressComponents` | если доступны | country/city/district/street/number/postalCode |
| `latitude/longitude` | да | Валидная подтверждённая точка |
| `locationLabel` | условно | Обязательно, если нет почтового адреса |
| `entranceHint` | нет | До 300 символов, без чувствительных данных |
| `timezoneId` | да | IANA timezone, определяется системой |
| `locationAccuracy` | да | rooftop/interpolated/approximate/manual |

```text
PlaceLocationDraft {
  marketCityId
  countryCode
  city
  district?
  formattedAddress?
  addressComponents?
  point: GeoPoint
  locationLabel?
  entranceHint?
  timezoneId
  accuracy
  pinConfirmed: bool
  geocodedAtUtc?
}
```

Flow локации:

1. пользователь ищет адрес или ставит pin;
2. provider возвращает candidates;
3. выбор candidate заполняет address components и pin;
4. пользователь проверяет/двигает pin;
5. после ручного перемещения координаты становятся источником истины, а
   address помечается как требующий reverse-geocode refresh;
6. timezone определяется по точке/market, не вводится свободным текстом;
7. publish требует явного подтверждения pin.

Дополнительные правила:

- latitude ∈ `[-90, 90]`, longitude ∈ `[-180, 180]`;
- отсутствие формального locality у пляжа, леса или видовой точки не
  блокирует publish: `city` получает канонический market city, а
  пользовательская идентификация идёт через `locationLabel`;
- точка `(0,0)` не запрещается математически, но для market Riga является
  явным out-of-market error;
- публикация MVP разрешена только внутри поддерживаемого launch market;
  объект вне Riga сохраняется как draft, но не публикуется;
- несоответствие выбранного market и reverse-geocoded country/city является
  blocking error до повторного подтверждения/исправления;
- перенос pin после подтверждения сбрасывает `pinConfirmed`;
- изменение pin инвалидирует timezone, duplicate check и travel preview;
- provider place ID MAY храниться как provenance hint, но не заменяет
  Recharge `placeId` и не является обязательным публичным полем;
- location permission нужна только для центрирования карты на пользователе;
  отказ не блокирует manual search/pin flow;
- target map provider — Google Maps согласно vision/baseline, но domain
  работает через provider-neutral ports.

Если provider недоступен:

- draft можно сохранить;
- pin можно поставить вручную на fallback-карте;
- publish разрешён только при валидных координатах и market;
- provider error не превращается в координаты центра города.

Privacy:

- частный домашний адрес запрещён для публичного Place, если это не
  подтверждённый публично посещаемый бизнес;
- `entranceHint` не должен содержать коды домофона, персональные телефоны
  или другие секреты;
- координаты не округляются для опубликованного публичного Place.

### 8.5 OpeningHoursSection

Режим:

```text
PlaceHoursMode = regular | alwaysOpen | seasonal | unknown
```

#### Regular

- один день может иметь несколько интервалов, например 09:00–13:00 и
  14:00–18:00;
- единственным источником истины overnight является `closesNextDay`;
  UI-ввод `close < open` лишь предлагает установить этот флаг до сохранения;
- одинаковые и пересекающиеся интервалы одного дня объединяются после
  confirmation или выдаются как validation error;
- закрытый день хранится явно;
- времена хранятся как минуты от локальной полуночи;
- timezone хранится на Place.

#### Always open

- означает 24/7;
- не создаёт семь копий одинаковых правил в UI;
- projection может материализовать правила в data mapper.

#### Seasonal

- содержит интервалы дат действия сезона;
- внутри сезона используется weekly schedule;
- вне сезона opening status = closed, а не unknown;
- перекрывающиеся сезоны запрещены.

#### Unknown

- допустимо для любого kind, когда расписание действительно неизвестно;
- для managedVenue показывается сильное warning и предложение добавить
  официальный источник, но publish не блокируется;
- `openNow` получает `unknown`, не `open`;
- UI не показывает вымышленное «Открыто круглосуточно».

#### Exceptions

Исключение по `LocalDate` имеет приоритет над weekly/seasonal rule:

```text
OpeningException {
  id
  localDate
  kind: closedAllDay | customHours
  periods[]
  publicNote?
}
```

Поддерживаются праздники, ремонт и разовые изменения. DST нормализуется по
правилам `SEARCH_FILTERS_TIME_SPEC.md`; UI не выполняет UTC-расчёты.

#### Operational closure overlay

Временное/постоянное закрытие редактируется рядом с hours, но сохраняется
в `PlaceOperationalStatus`, а не в `PlaceHoursMode`:

- для `temporarilyClosed` обязательна дата начала;
- дата окончания опциональна;
- public note — опционально до 200 символов;
- по окончании интервала применяется сохранённое underlying schedule;
- `permanentlyClosed` не уничтожает исторические hours;
- operational overlay всегда сильнее exceptions и weekly periods.

#### Типизированная модель hours

```text
PlaceHoursDraft {
  mode: regular | alwaysOpen | seasonal | unknown
  weeklyPeriods: List<LocalOpeningPeriod>
  seasons: List<SeasonalHoursRule>
  exceptions: List<OpeningException>
}

LocalOpeningPeriod {
  id: local-or-permanent-id
  dayOfWeek: 1..7                 // ISO Monday..Sunday
  openMinute: 0..1439
  closeMinute: 0..1439
  closesNextDay: bool
}

SeasonalHoursRule {
  id
  startLocalDate: YYYY-MM-DD
  endLocalDate: YYYY-MM-DD        // inclusive
  weeklyPeriods: List<LocalOpeningPeriod>
}
```

Инварианты модели:

- `regular` требует хотя бы один weekly period;
- `alwaysOpen` не содержит weekly periods/seasons; date exceptions разрешены
  по D19, например закрытие парка в отдельный праздник;
- `seasonal` требует хотя бы один непустой season;
- `unknown` не содержит periods/seasons/exceptions в MVP;
- `startLocalDate <= endLocalDate`;
- сезоны не пересекаются;
- period имеет положительную длительность строго меньше 24 часов;
- при `closesNextDay = false` требуется `closeMinute > openMinute`;
- при `closesNextDay = true` длительность равна
  `(1440 - openMinute) + closeMinute` и остаётся меньше 24 часов;
- `closeMinute < openMinute` при false — invalid state, не implicit overnight;
- 24/7 задаётся только `alwaysOpen`, не периодом 00:00–00:00 или одинаковыми
  overnight-границами;
- интервалы проверяются на overlap и после переноса overnight-хвоста на
  следующие сутки;
- исключение одной даты может отменить и период, начавшийся накануне;
- date/time calculations принадлежат domain/application use case.

Текущий Search contract кодирует overnight как `close < open`. Mapper
переводит typed `closesNextDay=true` в эту wire-форму и обратно на data
boundary. UI/domain не используют сравнение минут как второй источник истины.

Текущий `DiscoverOpeningHoursRule` покрывает weekly periods и date
exceptions, но не сезонные date ranges. До включения Phase 2 Discover
contract MUST быть расширен типизированным seasonal rule. Нельзя генерировать
бесконечный список date exceptions или silently терять сезон в mapper.

#### Маппинг в availability

| Place state | Discover `availabilityKind` | Opening status |
|---|---|---|
| regular/alwaysOpen/seasonal | `openingHours` | Вычисляется по rules |
| unknown | `none` | `unknown` |
| temporarilyClosed active | underlying kind сохраняется | `closed` overlay |
| permanentlyClosed | underlying kind сохраняется для истории | `closed` overlay |

Operational status MUST передаваться отдельным полем projection. Если
consumer его не поддерживает, Place нельзя ошибочно показать как открытый.

### 8.6 VisitPlanningSection

| Поле | Тип | Правило |
|---|---|---|
| `recommendedVisitMinutes` | int? | 10–1440, используется time-fit |
| `minimumVisitMinutes` | int? | > 0 и <= recommended, если задано |
| `allowsShortVisit` | bool | требует minimumVisitMinutes |
| `bestTimeWindows` | list | локальные день/время + короткая причина |
| `busyTimeNotes` | text? | До 300 символов, без неподтверждённых точных прогнозов |
| `weatherDependent` | bool | Для outdoor place |
| `arrivalBufferMinutes` | int | 0–120, default 0; вход/парковка/подготовка |
| `exitBufferMinutes` | int | 0–120, default 0; выход до обратной дороги |

`bestTimeWindows` — рекомендация для Details/ranking, но не часы работы.
Они не могут делать закрытое место открытым.

Маппинг в Discover time-fit:

- `recommendedVisitMinutes` → `durationMinutes`;
- `allowsShortVisit` → `allowsPartialAttendance` (техническое имя общей
  projection не должно появляться в Place UI);
- `minimumVisitMinutes` → `minimumVisitDurationMinutes`;
- arrival/exit buffers → общие onsite buffers;
- travel return safety margin добавляется отдельно и не записывается в
  Place draft.

### 8.7 AmenitiesSection

- данные берутся из `AmenityTaxonomy`, а не из списка внутри виджета;
- список фильтруется по формату и категории места;
- выбранные значения сохраняются как стабильные amenity IDs;
- общие стартовые группы: accessibility, transport, family, pets,
  facilities, food, sport/equipment, safety, outdoor;
- `wheelchairAccessible`, туалет, парковка и pet-friendly не выводятся из
  описания автоматически;
- хранение tri-state явно: `amenityIds` = подтверждённое «есть»;
  `amenityUnknownIds` = Creator явно выбрал «не знаю»; отсутствие ID в обоих
  sets = `notStated`, которое consumers трактуют как unknown, не false;
- подтверждённое «нет» в MVP не моделируется. Phase 2 MAY добавить
  `amenityConfirmedAbsentIds`, не перегружая отсутствие ID;
- Details показывают только подтверждённые true, а Filters различают
  true/unknown/notStated и не исключают неуказанное без явной policy.

### 8.8 PricingSection

```text
PlaceEntryType = free | paid | mixed | notApplicable | unknown
```

Нормативная семантика:

| Value | Значение | Допустимые денежные поля |
|---|---|---|
| `free` | Вход во всё Place бесплатный | Entry prices очищены; typical spend MAY остаться |
| `paid` | Для посещения требуется платный вход | Entry price from обязателен, to опционален |
| `mixed` | Есть бесплатный и платный доступ/зоны | Entry price from обязателен + пояснение |
| `notApplicable` | Концепции входного билета нет, например кафе | Entry prices очищены; typical spend доступен |
| `unknown` | Creator не может подтвердить условия | Entry prices очищены; показывается warning |

`free` и `notApplicable` не взаимозаменяемы: бесплатный музей имеет free
entry, а кафе без входного билета — notApplicable.

Поля:

- `entryType` — обязателен;
- `entryPriceFrom` / `entryPriceTo` — для paid/mixed;
- `typicalSpendFrom` / `typicalSpendTo` — опциональный ориентир;
- `currencyCode` — из market config, для Riga `EUR`;
- `pricingNote` — до 300 символов;
- `officialPricingUrl` — опциональный HTTPS URL.

Инварианты:

- суммы неотрицательные;
- для каждого диапазона `from <= to`;
- paid/mixed требуют `entryPriceFrom`; mixed также требует `pricingNote`;
- free/notApplicable/unknown очищают entry price range;
- типичный чек не означает стоимость входа;
- цены не используются как обещание бронирования;
- пользователь видит дату последней проверки цены.

### 8.9 ContactAndLinksSection

Опциональные публичные поля:

- официальный сайт;
- публичный телефон места;
- публичный email;
- внешний booking URL;
- официальные social links из разрешённого списка providers.

Правила:

- URL только `https`, кроме разрешённых системных deep links;
- `javascript:`, `data:` и произвольные app schemes запрещены;
- телефон нормализуется, но отображается в пользовательском формате;
- booking URL подписывается как внешний переход;
- Place booking URL ведёт только на общую официальную landing page места;
  ссылка на конкретную дату/услугу моделируется Bookable Session;
- приложение не обещает доступность слота и не обрабатывает оплату;
- ссылки проходят abuse/safe-link проверку на data/application boundary;
- tracking parameters платформы не добавляются без consent policy.

Moderation policy:

- phone/email edit проходит auto-check + audit и MAY применяться сразу;
- добавление или изменение website, pricing, booking или social URL является
  material edit: последняя approved ссылка остаётся публичной до review;
- safe-link automation не отменяет pending revision для нового домена;
- удаление опасной ссылки MAY применяться немедленно с audit.

`VISION.md` сейчас явно закрепляет `externalBookingUrl` за Event /
Bookable Session. После approval Decision D13 этой slice spec расширяет
контракт для Place только общей official landing page; конкретный слот
по-прежнему остаётся Bookable Session. Синхронное обновление `VISION.md`
обязательно для Done по D20.

### 8.10 MediaSection

| Поле | MVP | Правило |
|---|---|---|
| `coverImage` | обязательно | Одно основное изображение |
| `gallery` | опционально | Рекомендуемо до 12 изображений |
| `altText` | желательно | Для accessibility |
| `attribution` | условно | Обязательно, если этого требует источник |

Pipeline:

1. локальный выбор файла;
2. проверка типа, размера и повреждений;
3. client preprocessing: orientation, compression, preview;
4. локальная ссылка в draft;
5. upload с progress/retry после подключения backend;
6. orphan cleanup для удалённых/брошенных media;
7. moderation scan;
8. постоянные media IDs до публикации.

Запрещены чужие изображения без права использования, QR-коды/контакты как
замена описанию, explicit content и вводящие в заблуждение фотографии.

### 8.11 ProvenanceAndFreshness (системная секция)

Эти данные не вводятся как обычные marketing fields, но нужны для доверия,
moderation и безопасного ranking:

```text
PlaceDataProvenance {
  sourceType: creatorSubmission | ownerSubmission | staffSubmission
  submittedByUserId
  relationshipClaim
  createdAtUtc
  lastConfirmedAtUtc
  hoursConfirmedAtUtc?
  pricingConfirmedAtUtc?
  contactsConfirmedAtUtc?
}
```

- `sourceType` выводится детерминированно: `owner → ownerSubmission`,
  `staff → staffSubmission`, `visitor | curator → creatorSubmission`;
  auth context подтверждает автора, но значение не даёт verified badge;
- timestamps обновляются только явным подтверждением/сохранением
  соответствующей секции, а не простым открытием формы;
- устаревшие данные получают UI note, но не меняются автоматически;
- freshness для ranking не должна обновляться от пустого save или смены
  несмыслового metadata;
- сторонний catalog import отсутствует в MVP. При его появлении потребуется
  отдельный source type, license/attribution и reconciliation policy;
- публичный Details MAY показывать «Обновлено» или «Часы подтверждены», но
  MUST NOT называть объект verified business без claim/verification flow.

### 8.12 Неприменимые общие поля

Общий form engine MUST скрывать для Place:

- event start/end и registration deadline;
- participant min/max/current;
- registration/approval/waitlist switches;
- event recurrence и schedule slots;
- внутреннюю booking/payment configuration.

Place не получает искусственную capacity. В Discover projection
`capacity` и `participantsCount` остаются `null`, поэтому capacity status =
`unknown`. Если пользователь явно применил общий `onlyAvailable` filter,
Place обрабатывается строго по принятой Search policy, а UI не подставляет
фиктивное available.

---

## 9. Целевая draft-модель

Общие поля Create остаются в `CreateDraftEntity`. Place-specific данные не
должны бесконечно расширять общую сущность nullable-полями. Целевой runtime
использует типизированную модель секции и mapper на storage boundary.

```text
PlaceDraftData {
  schemaVersion: int
  placeKind: PlaceKind
  relationshipToPlace: PlaceRelationship
  publisherRef: PublisherRef
  location: PlaceLocationDraft
  hours: PlaceHoursDraft
  operationalStatus: PlaceOperationalStatusDraft
  visitPlanning: PlaceVisitPlanningDraft
  amenityIds: Set<String>
  amenityUnknownIds: Set<String>
  pricing: PlacePricingDraft
  contacts: PlaceContactsDraft
  provenance: PlaceDataProvenance
}
```

Сериализованная форма может временно жить в
`sectionData['place_details']`, но:

- presentation не читает raw map напрямую;
- mapper валидирует schema version;
- migration выполняется в data layer;
- неизвестные новые поля сохраняются при forward-compatible round trip,
  если storage contract это поддерживает;
- доменная валидация работает с typed values;
- опубликованный Place имеет постоянный ULID/UUID; все `loc_*` IDs секций,
  periods, exceptions и media заменяются до publish result.

### 9.1 Архитектурные границы реализации

- `domain` содержит typed entities, value objects, repository interfaces и
  pure validation/evaluation use cases;
- `data` содержит draft mappers, migrations, datasource adapters и Failure
  mapping; Firestore/Google provider DTO не пересекают boundary;
- `application` оркестрирует save/validation/duplicate/publish и хранит
  immutable state через Riverpod `Notifier`/`AsyncNotifier` по ADR 0012;
- `presentation` рендерит config/sections, отправляет intents и показывает
  state/errors; вычисления hours, geo, price и permissions в UI запрещены;
- `app/di` является composition root через `get_it`; feature получает
  runtime config/provider ports constructor injection;
- Create и Discover не импортируют presentation/application друг друга;
  связь проходит через repository/API projection contract;
- общие value contracts, нужные нескольким packages, живут в
  `packages/api_contracts` только после утверждённого contract slice;
- новый top-level module или изменение boundaries требует ADR 0011 workflow.

### 9.2 Публичная Place-модель

Минимальный целевой контракт:

```text
Place {
  id
  publisherRef
  title
  shortDescription
  fullDescription?
  contentLocale
  categoryId
  subcategoryId
  tags
  criteria
  placeKind
  location
  hours
  operationalStatus
  visitPlanning
  amenityIds
  amenityUnknownIds
  pricing
  contacts
  media
  provenance
  lifecycleStatus
  moderationStatus
  createdAtUtc
  updatedAtUtc
  publishedAtUtc
  contentRevision
}
```

`lifecycleStatus`, `moderationStatus` и `operationalStatus` — три независимые
оси и MUST NOT кодироваться одним enum:

| Ось | Примеры | Кто меняет |
|---|---|---|
| Lifecycle | draft/pendingReview/published/archived/hidden/deleted | publish/moderation/owner policy |
| Moderation | none/pending/approved/rejected | moderation workflow |
| Operational | operating/temporarilyClosed/permanentlyClosed | owner/moderation operational edit |

`contentRevision` монотонно увеличивается на server-accepted edit. Локальная
save revision имеет отдельный counter и не притворяется server revision.

API/Firestore DTO подключается отдельным backend slice через data source и
`packages/api_contracts`. UI и domain не импортируют Firestore.

### 9.3 Идентичность и deep links

- Канонический deep link строится по immutable `placeId`.
- Human-readable slug MAY присутствовать только для display/SEO и не
  является ключом lookup.
- Rename не меняет `placeId` и не ломает Favorites/Collections/Events.
- После допустимого merge старый ID должен резолвиться через explicit
  redirect/tombstone, а не fuzzy title search.
- Archived/closed Place по прямой ссылке возвращает typed availability
  state, а не generic 404.

### 9.4 Текущее состояние и целевой разрыв

На дату 2026-07-19 Create-scope v1.0 реализован в mock runtime. Текущая
граница между готовым Create-блоком и будущими backend/consumer slices:

| Область | Сейчас | Требование этой спецификации |
|---|---|---|
| Form engine | Четыре Place-шага в общем config-driven Create Hub | Готово для MVP Create scope |
| Draft storage | Schema v3 + typed `PlaceDraftData` в versioned `place_details`, single active draft | Готово для MVP; multi-draft repository — Phase 2 |
| Location | Google Map/manual coordinates, explicit pin confirmation, accuracy, market/timezone config | Address search/reverse-geocode provider подключается отдельным provider slice |
| Hours | Regular/alwaysOpen/unknown, split/overnight, exceptions и operational overlay | Seasonal — Phase 2 |
| Amenities | Config taxonomy + true/explicitUnknown/notStated | Backend registry/sync подключаются отдельно |
| Publisher | Typed `PublisherRef`, deterministic provenance и `create.place` guard | ManagedPage publisher ждёт Publisher slice |
| Media | Cover/gallery mock refs, guard 12 и validation | Upload/readiness/scan/orphan cleanup ждут backend media slice |
| Publish | Autosave, validation/warnings, duplicate policy, permanent IDs и local idempotent `pending_review` | Server idempotency/media/duplicate recheck ждут backend slice |
| Moderation | Статусы без полного workflow | Revisions, reason codes, audit и auto-hide |
| Discover | Независимый mock datasource | Backend projection Create Place → Discover |
| Details | Общая Discover details | Place-specific blocks/CTA/related content |

Следствие: Create-блок не следует повторно заменять raw-полями или
обходить validators. Оставшиеся moderation, Discover, Details и backend-разрывы
закрываются отдельными slices из §24.

---

## 10. Валидация

### 10.1 Когда запускается

- field validation — после blur и при попытке перейти дальше;
- section validation — при завершении шага;
- full validation — перед preview и publish;
- asynchronous checks — URL safety, duplicate candidates, media state;
- UI отображает результаты, но правила находятся в use cases/validators.

```text
PlaceValidationIssue {
  code: stable-string
  severity: error | warning
  sectionId
  fieldId?
  messageKey
  messageParams
}
```

Domain возвращает stable code/field path, application добавляет context,
presentation локализует `messageKey`. Raw русские/английские тексты не
являются validation contract и не сохраняются в draft.

### 10.2 Blocking errors

Публикация блокируется, если:

- нет права `publish.place`;
- отсутствуют `placeKind`, `relationshipToPlace` или валидный publisherRef;
- отсутствуют title, short description, категория или подкатегория;
- обязательный текст нарушает ограничения длины §8.1;
- `contentLocale` отсутствует в supported locale registry;
- подкатегория не допускает `ContentType.place`;
- нет валидного market/city;
- нет подтверждённых координат;
- одновременно отсутствуют formatted address и location label;
- timezone отсутствует или невалиден;
- cover отсутствует или upload не завершён;
- gallery содержит более 12 изображений;
- hours mode или `entryType` не выбран;
- выбран regular или включённый Phase 2 seasonal режим без valid periods;
- periods пересекаются или имеют некорректные границы;
- exception имеет неверную дату;
- цена отрицательна или `from > to`;
- paid/mixed не имеют `entryPriceFrom`, либо mixed не имеет pricing note;
- внешний URL небезопасен/невалиден;
- обязательный dynamic criterion не заполнен;
- локальные IDs не удалось заменить постоянными;
- одновременно сохранены несовместимые availability representations;
- draft изменился после последней успешно провалидированной revision.

### 10.3 Warnings

Не блокируют публикацию, но требуют видимого подтверждения:

- похожее название и категория в радиусе duplicate check;
- approximate pin;
- `managedVenue` без formatted address, опубликованный по locationLabel +
  подтверждённому pin;
- нет opening hours (`unknown`);
- entry type = unknown;
- нет публичных контактов;
- нет recommended visit duration;
- малоинформативное описание;
- только одно изображение;
- Creator указал `owner/staff`, но бизнес не verified;
- цена давно не подтверждалась.

### 10.4 Normalization

- trim и схлопывание повторных пробелов;
- Unicode сохраняется, сравнение дублей использует нормализованную форму;
- city/category IDs нормализуются только registry mapper'ами;
- URL canonicalization не должна менять смысл ссылки;
- timestamps хранятся UTC, schedule — локальные минуты + timezone;
- пустая строка превращается в `null` только в data mapper для nullable
  поля, но не маскирует обязательную валидацию.

---

## 11. Поиск дублей

Duplicate check выполняется перед отправкой на модерацию и повторно на
backend после его подключения.

### 11.1 Candidate scoring

Сигналы:

- расстояние между pins;
- нормализованное название и aliases;
- одинаковый телефон, официальный домен или social handle;
- совпадение категории;
- совпадение адреса;
- transliteration en/ru/lv.

Стартовая UX-политика:

- до 100 м + сильное совпадение названия — показать candidates;
- одинаковый официальный домен/телефон — высокий риск дубля независимо от
  небольшого расхождения pin;
- предупреждение не является автоматическим merge;
- Creator может открыть существующий Place, отменить создание или выбрать
  «Это другое место» с коротким объяснением;
- moderator видит duplicate score и объяснение;
- merge Place — post-MVP административная операция с redirect старого ID.

Не следует фиксировать числовой backend threshold в UI. Значения должны
жить в policy config после реализации сервера.

---

## 12. Preview и публикация

### 12.1 Preview

Preview максимально повторяет будущий Details и показывает:

- cover/gallery;
- название, category и краткое описание;
- map pin и адрес;
- текущий opening status и ближайшее изменение;
- recommended visit duration;
- entry/typical spend;
- amenities/accessibility;
- publisher;
- внешние ссылки с явной маркировкой;
- предупреждения о неполных данных.

Preview не использует отдельную копию draft. Он строится через mapper из
текущей revision, чтобы избежать расхождения с publish payload.

### 12.2 Publish command

```text
PublishPlaceCommand {
  draftId
  expectedRevision
  publisherRef
  idempotencyKey
}
```

Последовательность:

1. проверить auth/session и capabilities;
2. сохранить актуальный draft;
3. выполнить full validation;
4. выполнить/получить duplicate check;
5. убедиться, что media готовы;
6. заменить `loc_*` IDs постоянными;
7. собрать payload через mapper;
8. отправить idempotent publish command;
9. получить постоянный `placeId` и `pending_review`;
10. сохранить mapping draft ID → place ID;
11. показать success screen и ожидаемый следующий статус;
12. записать analytics и audit event.

Повторный tap, timeout или retry с тем же idempotency key не создаёт второй
Place.

### 12.3 Ошибки publish

- offline/timeout — draft сохранён, доступен retry;
- unauthorized/revoked session — refresh или forced logout по auth policy;
- permission denied — publish прекращается без потери draft;
- conflict — загрузить server revision, показать выбор/merge policy;
- media failed — retry только media, не создавать новый Place;
- validation changed — показать актуальные field errors;
- duplicate suspected by server — вернуть candidates в review step;
- unknown — correlation ID для support, draft остаётся редактируемым.

Infra exception MUST быть преобразован на data boundary в typed failure:

```text
PublishPlaceFailure =
  offline
  | timeout
  | unauthorized
  | permissionDenied
  | staleRevision
  | validationRejected(fieldErrors)
  | duplicateReviewRequired(candidates)
  | mediaNotReady(mediaIds)
  | rateLimited(retryAfter)
  | featureDisabled
  | serverUnavailable
  | unknown(correlationId)
```

| Failure | Retry автоматически | Действие UI |
|---|---|---|
| offline/timeout/serverUnavailable | только bounded policy | Сохранить draft, показать retry |
| unauthorized | один token refresh | Login/forced logout при повторе |
| permissionDenied | нет | Read-only draft + объяснение |
| staleRevision | нет | Conflict resolution |
| validationRejected | нет | Перейти к первому field error |
| duplicateReviewRequired | нет | Показать candidates |
| mediaNotReady | media retry | Вернуть в MediaSection |
| rateLimited | после retryAfter | Показать время повторной попытки |
| featureDisabled | нет | Draft доступен, publish временно закрыт |
| unknown | нет автоматически | Support correlation ID |

Автоматический retry command обязан сохранять тот же idempotency key.

---

## 13. Модерация

### 13.1 Первичная модерация

После submit статус `pending_review`. Проверяются:

- существование и корректность локации;
- дубли;
- соответствие категории;
- права на media и запрещённый контент;
- misleading title/description;
- подозрительные контакты/URL;
- spam velocity: baseline не более 100 publish actions/day;
- связь Creator с местом показывается как заявленная, не подтверждённая.

Результат:

- approve → `published`;
- reject with changes → обратно в редактируемый `draft` с reason codes;
- hide → `hidden` при abuse/security issue;
- suspected duplicate → review/merge queue, не автоматическое удаление.

Минимальные machine-readable reason codes:

```text
invalid_location
duplicate_suspected
wrong_category
insufficient_description
misleading_identity
unsafe_external_link
media_rights_or_policy
private_address_or_contact
prohibited_content
spam_or_velocity
ownership_claim_requires_evidence
other_with_comment
```

- Creator получает локализованное объяснение и список затронутых sections;
- internal moderator notes не раскрываются;
- `other_with_comment` требует безопасный публичный комментарий;
- resubmit создаёт новую revision и сохраняет связь с предыдущим decision;
- reject не удаляет draft и media, пока действует retention policy.

### 13.2 Правки опубликованного Place

Рекомендуемая модель — published revision + pending revision. Пока
существенные изменения проверяются, публичной остаётся последняя
одобренная версия.

Существенные изменения:

- title;
- publisher/ownership;
- category/subcategory;
- перенос pin более чем на policy threshold;
- place kind;
- cover или большая замена gallery;
- новый или изменённый website/pricing/booking/social URL;
- восстановление permanently closed места.

Операционные изменения могут применяться без полной повторной модерации,
но пишутся в audit и проходят автоматические проверки:

- hours и временное закрытие;
- телефон/email;
- цены;
- amenities;
- entrance hint;
- короткие исправления описания без policy flags.

Точный список должен быть конфигурируемым на backend, а не зашитым в UI.

### 13.3 Жалобы

- один пользователь учитывается один раз на Place;
- при `>= 5` уникальных reporters за 24 часа Place auto-hidden;
- жалобы всё равно попадают в moderation review;
- owner получает нейтральное уведомление без раскрытия reporters;
- восстановление выполняется только разрешённым moderation action;
- report reason и evidence не публикуются в Details.

---

## 14. Публикация в Discover

Place mapper создаёт Discover projection без прямого импорта Create feature
в Discover feature.

Минимальные поля projection:

```text
DiscoverPlaceProjection {
  objectId
  objectType = place
  placeKind
  title
  subtitle
  contentLocale
  categoryId
  subcategoryId
  coverImageUrl
  marketCityId
  timezoneId
  latitude
  longitude
  addressLine
  operationalStatus
  amenityIds[]
  amenityUnknownIds[]
  entryType
  priceAmount?
  currencyCode
  availabilityKind = openingHours | none
  openingHours[]
  durationMinutes?
  allowsPartialAttendance
  minimumVisitDurationMinutes?
  publisherRef
  publishedAtUtc
  updatedAtUtc
}
```

До Firebase Discover продолжает читать собственный mock datasource. Нельзя
передавать `CreateDraftEntity` напрямую в Discover presentation.

### 14.1 Search и Feed

- Place участвует в общем `DiscoverQuery`;
- category/subcategory, geo radius, price, amenities и open-now работают
  как общие фильтры;
- place без известных часов при `openNow=true` попадает в группу
  «Время не подтверждено», если это допускает текущая query policy;
- geo + freshness остаются baseline ranking по ADR;
- time-fit boost применяется только при подтверждённом fit;
- обновление часов не должно бесконечно давать freshness boost — ranking
  использует meaningful content freshness с anti-gaming policy;
- permanently closed исключается из стандартной выдачи.

### 14.2 Map

- Place реализует общий MapObject contract;
- marker использует стабильный `placeId`;
- marker type/category определяет визуальный стиль через design system;
- tap открывает preview sheet, затем Details;
- координаты Place — источник marker position;
- cluster/radius работают вместе с другими MapObject types;
- place нельзя связывать с другим объектом по title.

### 14.3 Time-fit

Opening hours применяются по `SEARCH_FILTERS_TIME_SPEC.md`:

1. query window переводится в локальные даты timezone Place;
2. exception перекрывает weekly/seasonal schedule;
3. overnight interval корректно переходит на следующие сутки;
4. учитывается outbound и опциональный return travel;
5. для return применяется place safety margin из policy config;
6. непрерывные интервалы не суммируются через закрытый разрыв;
7. `recommendedVisitMinutes` даёт full-fit;
8. `minimumVisitMinutes` может дать partial-fit;
9. неизвестные hours/duration дают `unknown`, не ложный `fits`.

Ranking MUST следовать ADR 0014:

- без `timeWindow` остаётся только geo + freshness baseline;
- `doesNotFit` исключается hard filter;
- `unknown` остаётся отдельной неподтверждённой группой без boost;
- default `timeFitWeight = 0.20`, clamp `[0, 0.30]`;
- kill switch отключает boost без отключения filtering/grouping/badges;
- zero-result relaxation предлагается пользователю и не меняет query сама.

### 14.4 Reviews и rating projection

Review/ratings входят в целевой MVP продукта, но не являются полями Create
Place и реализуются отдельным feature slice:

- Review связывается с Place только по `placeId`;
- Creator не задаёт initial rating и review count;
- aggregate rating строится Review repository/backend projection;
- отсутствие Reviews отображается как «Нет отзывов», не rating 0;
- archive/temporary closure не удаляют Reviews;
- merge/soft delete требуют отдельной reference migration policy;
- moderation Place и moderation Review остаются разными workflows;
- до реализации Review slice UI не показывает mock rating как реальные
  пользовательские данные.

---

## 15. Place Details

Порядок блоков:

1. media hero;
2. title, category, rating state, save/share/report;
3. opening status и ближайшее изменение;
4. адрес, mini-map, построить путь;
5. краткое и полное описание;
6. цена/типичный чек;
7. amenities и accessibility;
8. recommended duration и best time;
9. контакты/официальный сайт/внешний booking;
10. publisher;
11. связанные Events/Sessions через запрос по `placeId`;
12. отзывы после реализации Review slice.

Правила CTA:

- основной CTA по умолчанию — `Маршрут`;
- при наличии внешнего booking URL дополнительный CTA — `Забронировать
  на сайте`;
- телефон/email открываются только по явному tap;
- внешняя ссылка сопровождается сообщением, что пользователь покидает
  Recharge;
- закрытое место не скрывает маршрут, но CTA booking может быть disabled
  при permanently closed;
- unknown hours показывается как «Часы работы не подтверждены».

---

## 16. Редактирование, архив и закрытие

### 16.1 Редактирование

- доступно только при `manage_place` для publisher;
- форма открывает новую draft revision из последней server revision;
- UI показывает, какая версия сейчас опубликована;
- autosave не меняет публичный Place;
- submit использует optimistic concurrency по `contentRevision`;
- конфликт не перезаписывается молча;
- после approve pending revision становится текущей.

### 16.2 Архивирование

- требуется confirmation;
- Place исчезает из Search/Map/Feed;
- прямой owner preview остаётся доступен;
- Favorites могут показывать «Место архивировано»;
- связанные Event/Session не удаляются, но получают предупреждение о
  недоступной привязке;
- восстановление сохраняет тот же `placeId`.

### 16.3 Permanently closed

- owner может пометить место закрытым без немедленного удаления;
- Details остаётся доступным для сохранённых ссылок;
- система предлагает архивировать Place;
- восстановление operating status является существенной правкой;
- исторические Reviews/links не переносятся на новый Place автоматически.

### 16.4 Delete

- обычное удаление — soft delete;
- retention 30 дней;
- восстановление возможно в retention window при наличии права;
- hard delete после retention очищает/анонимизирует данные по policy;
- ссылки из Collections/Plans обрабатываются как unavailable reference, а
  не перенаправляются по имени.

---

## 17. Analytics и наблюдаемость

События не содержат description, точный адрес, телефон, email или media
URL. Допустимы IDs и агрегированные значения.

Рекомендуемые события:

| Event | Trigger | Ключевые параметры |
|---|---|---|
| `create_place_started` | выбран Place | entry_point, publisher_type |
| `create_place_step_viewed` | открыт шаг | step_id, draft_revision |
| `create_place_field_error` | validation error | field_id, error_code |
| `create_place_location_confirmed` | подтверждён pin | accuracy, market_city_id |
| `create_place_duplicate_warning` | найдены candidates | candidate_count, score_band |
| `create_place_previewed` | открыт preview | completeness_band |
| `create_place_draft_saved` | save success | save_reason, offline |
| `create_place_publish_attempted` | tap publish | warning_count |
| `create_place_publish_failed` | publish failure | failure_code, retryable |
| `create_place_submitted` | получен pending_review | place_id |
| `create_place_published` | moderation approve | place_id, review_duration_band |
| `create_place_edit_submitted` | отправлена revision | material_change_types |
| `place_external_booking_opened` | внешний переход | place_id, provider_domain_class |

Технические сигналы:

- save/publish latency;
- geocoder/map provider failures;
- media upload retries;
- duplicate check latency;
- validation error distribution;
- moderation reject reasons;
- projection lag Create → Discover;
- invalid opening-hours/DST telemetry;
- correlation by user/session/build только при допустимом consent.

До реализации названия событий, version/status и допустимые параметры MUST
быть зарегистрированы в `docs/analytics/EVENT_CATALOG.md`; таблица выше —
product contract, а не обход analytics governance.

### 17.1 Performance и reliability targets

- local draft open/save SHOULD укладываться в 500 мс p95 на среднем
  поддерживаемом устройстве;
- synchronous field validation SHOULD укладываться в 100 мс;
- map gestures и form input не блокируются geocoder/duplicate/media I/O;
- provider calls cancellable; устаревший response не применяет данные к
  новой draft revision;
- thumbnail decode/compression выполняются вне критического UI path;
- длинная gallery не загружается целиком в full resolution;
- приложение переживает background/terminate между любыми шагами без
  потери последней успешно сохранённой revision;
- timeout не интерпретируется как success;
- publish success показывается только после подтверждённого idempotent
  result с постоянным Place ID;
- Map/Discover performance сохраняет thresholds принятого Map spec.

---

## 18. Безопасность и abuse controls

- capability check выполняется на каждом command boundary;
- publisher ID берётся из auth context, не доверяется входному полю UI;
- все URL проверяются и открываются безопасным механизмом;
- rich text/HTML не принимается без sanitizer policy;
- EXIF location удаляется или нормализуется media pipeline;
- private contact data не публикуется по умолчанию;
- publish velocity baseline — 100/day на Creator;
- duplicate/spam/suspicious link checks не заменяют moderation;
- audit trail хранит create/edit/publish/archive/hide/delete actions;
- immutable audit доступен только admin/moderation;
- kill switch должен уметь отключить publish Place без отключения чтения
  уже опубликованных объектов.

---

## 19. Accessibility и локализация

- все labels являются l10n keys для en/ru/lv, не строками в config;
- даты/часы отображаются в timezone Place и locale пользователя;
- валюта приходит из market/object, не хардкодится в UI;
- map pin имеет текстовую альтернативу адресом/location label;
- ошибки связаны с конкретными полями и читаются screen reader;
- выбор pin не должен быть единственным способом ввести локацию;
- изображения поддерживают alt text;
- color не является единственным индикатором open/closed/error;
- tap targets и contrast следуют design system.

Фактическая l10n инфраструктура en/ru/lv пока не реализована и должна быть
подключена отдельным slice. Это не повод вводить новые hardcoded strings.

---

## 20. MVP scope

Этот scope соответствует decision ledger §23. Seasonal hours отнесены в
Phase 2, а общая external booking landing page включена в MVP.

### В MVP

- единый Place / Business type;
- identity и одна категория/подкатегория;
- dynamic criteria;
- точный pin, адрес/location label и timezone;
- regular/alwaysOpen/unknown hours, overnight и date exceptions;
- recommended/minimum visit duration;
- amenities/accessibility из taxonomy;
- entry price и typical spend;
- контакты и общий внешний booking URL;
- cover + gallery;
- локальный draft, validation, preview;
- duplicate warning;
- `pending_review` publish lifecycle;
- Discover projection, Search/Map/Details;
- owner edit/archive/closed status;
- report/auto-hide policy;
- analytics/audit contracts.

### Не входит в MVP

- внутренняя оплата;
- внутреннее бронирование столов/кортов/услуг;
- verified business claim;
- user-suggested edits чужого Place;
- автоматический merge дублей;
- web business cabinet;
- массовый импорт филиалов;
- real-time occupancy/popular times;
- чат с бизнесом;
- premium placement;
- AI-генерация описаний/категорий;
- полноценная admin panel;
- рекомендации на основе Reviews;
- автоматическое создание Place из сторонних картографических каталогов.
- seasonal hours UI/evaluation;
- multiple entrances и polygon geometry.

---

## 21. Acceptance criteria спецификации реализации

### Domain и data

- [ ] Place имеет постоянный ULID/UUID и `PublisherRef`.
- [ ] Place-specific runtime типизирован; presentation не читает raw map.
- [ ] Все связи Event/Session/Collection используют `placeId`.
- [ ] Draft serialization имеет schema version и migration tests.
- [ ] Все `loc_*` IDs заменяются до успешной публикации.
- [ ] Firestore/API скрыты за data source/repository boundary.

### Create flow

- [ ] Place запускается из общего config-driven Create Hub.
- [ ] Все четыре пользовательских шага и вложенные sections сохраняются и
  восстанавливаются.
- [ ] Обязательные поля остаются видимыми и не скрываются в collapsed groups.
- [ ] Второй Place draft не перезаписывает активный без явного решения.
- [ ] Offline save не блокирует заполнение.
- [ ] Смена категории корректно обрабатывает dynamic criteria.
- [ ] Pin подтверждается явно, city/timezone берутся из runtime/geo logic.
- [ ] Hours поддерживают split day, overnight и exceptions.
- [ ] Preview строится из той же revision, что publish payload.

### Validation и publish

- [ ] Blocking rules выполняются вне UI.
- [ ] Warnings видимы и подтверждаемы.
- [ ] Duplicate candidates показываются до submit.
- [ ] Повторный publish с тем же idempotency key не создаёт дубль.
- [ ] Ошибка publish не удаляет draft.
- [ ] Success возвращает постоянный ID и `pending_review`.
- [ ] Все пять `PlaceEntryType` соблюдают семантику §8.8.

### Discover

- [ ] Published Place появляется в Feed/Map/Details через projection.
- [ ] Open-now корректно различает open/closed/unknown.
- [ ] Overnight, exceptions и DST покрыты тестами.
- [ ] Time-fit учитывает travel и return safety margin.
- [ ] Permanently closed исключается из обычной выдачи.
- [ ] Deep link использует стабильный `placeId`.

### Lifecycle и безопасность

- [ ] Material edit не заменяет одобренную публичную revision до review.
- [ ] URL edits и operational contact edits следуют разным moderation paths.
- [ ] Temporary closure соблюдает inclusive local-date boundaries.
- [ ] Archive/restore сохраняет ID.
- [ ] Soft delete использует retention 30 дней.
- [ ] 5 уникальных reports/24h приводят к auto-hide.
- [ ] Все commands проверяют capabilities.
- [ ] URL/contact/media проходят соответствующие safety checks.
- [ ] Audit фиксирует все lifecycle transitions.

### Quality gates

- [ ] Unit tests покрывают validators, mappers, hours и migrations.
- [ ] Controller tests покрывают save/retry/publish/conflict.
- [ ] Widget tests покрывают основной flow и ошибки.
- [ ] Integration test покрывает create → pending review → published
  projection на тестовом backend после его появления.
- [ ] `flutter analyze` — 0 ошибок.
- [ ] `flutter test` — все тесты зелёные.
- [ ] `git diff --check` — зелёный.
- [ ] Каждое решение D1–D25 связано минимум с одной проверкой §22.

---

## 22. Обязательная тестовая матрица

| ID | Сценарий | Ожидаемый результат |
|---|---|---|
| PL-01 | Новый Place draft | Runtime market Riga, timezone Europe/Riga, EUR |
| PL-02 | ManagedVenue без address, но с locationLabel и pin | Publish allowed; address warning |
| PL-03 | Public POI без address, но с label и pin | Publish allowed |
| PL-04 | Нет pin | Publish blocked |
| PL-05 | Provider offline, pin поставлен вручную | Draft/save работают; publish после подтверждения pin |
| PL-06 | Подкатегория не допускает Place | Publish blocked |
| PL-07 | Смена подкатегории | Несовместимые criteria требуют confirmation |
| PL-08 | Split hours в один день | Оба периода сохраняются |
| PL-09 | UI-ввод 22:00–02:00 | До save явно нормализован `closesNextDay=true` |
| PL-10 | Holiday exception closed | Weekly rule перекрыт исключением |
| PL-11 | Unknown hours + openNow | Status unknown, не open |
| PL-12 | Temporarily closed до даты | До даты closed, затем underlying schedule |
| PL-13 | Free entry | Entry prices очищены |
| PL-14 | Price from больше to | Publish blocked |
| PL-15 | Небезопасный booking URL | Publish blocked |
| PL-16 | Duplicate candidate рядом | Warning + существующий Place доступен для просмотра |
| PL-17 | Повторный tap publish | Создан один Place |
| PL-18 | Timeout publish | Draft сохранён, retry использует тот же command |
| PL-19 | Media upload failed | Publish blocked, остальные данные сохранены |
| PL-20 | Успешный submit | Постоянный ID, статус pending_review |
| PL-21 | Approve | Place появляется в Discover projection |
| PL-22 | Material edit | Старая approved revision остаётся публичной |
| PL-23 | Hours-only edit без policy flags | Auto-check + audit, ручной review не требуется |
| PL-24 | Archive | Исчезает из Search/Map, ID сохраняется |
| PL-25 | Restore | Возвращается с тем же ID |
| PL-26 | 5 уникальных reports/24h | Auto-hidden + moderation review |
| PL-27 | Один user отправил report повторно | Считается один reporter |
| PL-28 | Place time-fit с return trip | Применён place safety margin |
| PL-29 | DST ambiguous opening boundary | Консервативная нормализация по time spec |
| PL-30 | Conflict двух устройств | LWW policy + явное предупреждение |
| PL-31 | Pin вне launch market | Draft сохраняется, publish blocked |
| PL-32 | Pin перемещён после confirmation | Confirmation/duplicate/timezone results сброшены |
| PL-33 | Два филиала одной сети | Два Place ID, общий publisher возможен |
| PL-34 | 00:00–00:00 regular period | Validation error; 24/7 задаётся alwaysOpen |
| PL-35 | Overnight period пересекает период следующего дня | Validation error |
| PL-36 | Temporarily closed + weekly open | Operational overlay возвращает closed |
| PL-37 | Closure закончилась | Возвращается underlying hours без потери данных |
| PL-38 | Stale expected revision | Typed staleRevision, публичная версия не затронута |
| PL-39 | Rename Place | Deep link/Favorites продолжают работать по ID |
| PL-40 | User без create.place | Read-only/upgrade UX, publish command не вызывается |
| PL-41 | Один контент на ru при UI en | Сохраняется contentLocale=ru, Place ID один |
| PL-42 | Permanently closed direct link | Details показывает закрытие, не generic 404 |
| PL-43 | Empty save опубликованного Place | Ranking freshness не обновляется |
| PL-44 | Specific dated booking URL как Place | SHOULD-подсказка предлагает Session; автоматически publish не блокируется |
| PL-45 | Нет ни formattedAddress, ни locationLabel | Publish blocked |
| PL-46 | Unknown hours у managedVenue | Publish allowed после сильного warning |
| PL-47 | alwaysOpen + holiday closedAllDay | В дату exception closed, в остальные даты open |
| PL-48 | Изменён website/booking URL | Pending revision; старая approved ссылка публична |
| PL-49 | Изменён валидный phone/email | Auto-check + audit, применяется без manual review |
| PL-50 | Temporary closure заканчивается 20 июля | Closed до 21 июля 00:00 local, затем underlying hours |
| PL-51 | entryType=paid без entryPriceFrom | Publish blocked |
| PL-52 | entryType=notApplicable после paid | Entry prices очищены, typical spend сохранён |
| PL-53 | Новый Place при активном draft | Требуется continue/delete/submit; overwrite запрещён |
| PL-54 | relationship=visitor/curator | sourceType=creatorSubmission, verified badge отсутствует |
| PL-55 | Amenity отсутствует в обоих sets | notStated/unknown, не false |
| PL-56 | closeMinute < openMinute и closesNextDay=false | Invalid state |
| PL-57 | Нет shortDescription | Publish blocked; fullDescription не заменяет short |
| PL-58 | Gallery содержит 13 изображений | Тринадцатое не добавляется, данные не теряются |
| PL-59 | Place с booking URL открыт в Details | Primary CTA Route, booking — secondary external CTA |
| PL-60 | Approved Place spec расходится с VISION | Slice не получает Done до синхронизации VISION |

---

## 23. Product decision ledger v1.0-rc3

Final candidate использует только решения ниже. В реализации нельзя молча
вернуть отвергнутую альтернативу.

| ID | Зафиксированное решение | Фаза | Проверки |
|---|---|---|---|
| D1 | Business, public space и POI — одна сущность Place | MVP | PL-02, PL-03, PL-33 |
| D2 | `PlaceKind = managedVenue / publicSpace / pointOfInterest` | MVP | PL-02, PL-03 |
| D3 | Pin обязателен; дополнительно требуется address или locationLabel | MVP | PL-04, PL-05, PL-45 |
| D4 | Short description обязателен, full description опционален | MVP | PL-57 |
| D5 | Unknown hours разрешён всем kinds; managedVenue получает warning | MVP | PL-11, PL-46 |
| D6 | Regular/alwaysOpen/overnight/exceptions — MVP; seasonal — Phase 2 | По фазам | PL-08, PL-09, PL-10, PL-29, PL-34, PL-35, PL-47, PL-56 |
| D7 | Gallery максимум 12 изображений | MVP | PL-58 |
| D8 | Duplicate UX radius стартует со 100 м из policy config | MVP | PL-16 |
| D9 | Material edit list §13.2 требует повторной модерации | MVP | PL-22, PL-48 |
| D10 | Permanently closed доступен по direct link с явным статусом | MVP | PL-42 |
| D11 | Создание доступно Creator с `create.place`; User включает Creator mode | MVP | PL-40 |
| D12 | Claim/verified business не входит в MVP | Phase 2+ | PL-54 |
| D13 | Place MAY иметь official booking landing page; dated slot — Session | MVP | PL-15, PL-44, PL-48 |
| D14 | Один representative pin; entrances/polygon не входят в MVP | Phase 2+ | PL-33 |
| D15 | Hours/price/phone/email — auto-check; новые URL — material review | MVP | PL-23, PL-48, PL-49 |
| D16 | Одна content locale; переводы не создают дубли Place | MVP | PL-41 |
| D17 | Route — primary CTA; external booking — secondary CTA | MVP | PL-59 |
| D18 | Один активный Place draft на пользователя; multi-draft — Phase 2 | По фазам | PL-53 |
| D19 | Exceptions разрешены для regular/alwaysOpen; при unknown запрещены | MVP | PL-10, PL-11, PL-47 |
| D20 | Approved slice spec выше VISION; VISION sync обязателен для Done | MVP | PL-60 |
| D21 | `PlaceEntryType` использует семантику §8.8 без implicit defaults | MVP | PL-13, PL-51, PL-52 |
| D22 | Temporary closure использует inclusive local-date boundaries §5.2 | MVP | PL-12, PL-36, PL-37, PL-50 |
| D23 | Amenities используют true/explicitUnknown/notStated; false отложен | MVP | PL-55 |
| D24 | Provenance sourceType детерминирован relationship claim | MVP | PL-54 |
| D25 | Content locales приходят из runtime registry | MVP | PL-41 |

Для D6 runtime schema резервирует `seasonal`, но MVP UI его не предлагает.
Неизвестный future enum вызывает migration/unsupported state, а не silently
fallback к `regular`.

D20 не меняет порядок источников истины из `AGENTS.md`: Accepted ADR остаётся
выше текущей slice spec. Требование синхронизации защищает документацию от
дрейфа и является Definition of Done, а не условием приоритета.

Для окончательного утверждения владелец продукта подтверждает весь ledger
одним решением. Если решение меняет Accepted ADR, создаётся новый ADR, а
старый не редактируется молча.

---

## 24. План реализации после утверждения

Рекомендуемая последовательность будущих slices:

1. **PLACE-DOMAIN-01** — типизированные модели, config и validators.
2. **PLACE-DRAFT-02** — storage schema, migrations и autosave revisions.
3. **PLACE-LOCATION-03** — address/pin/timezone contracts и provider ports.
4. **PLACE-HOURS-04** — regular/alwaysOpen/unknown, split/overnight,
   exceptions и operational closure overlay.
5. **PLACE-FORM-05** — секции общего form engine и preview.
6. **PLACE-PUBLISH-06** — duplicate check, media readiness, idempotent command.
7. **PLACE-DISCOVER-07** — projection, Feed/Map/Details и time-fit.
8. **PLACE-LIFECYCLE-08** — edit revisions, archive, reports и audit.
9. **PLACE-BACKEND-09** — Firebase/API adapters после стабилизации mock runtime.
10. **PLACE-EXPANSION-P2** — seasonal hours, claim/verification,
   entrances/polygon и user-suggested edits отдельными criteria.

Каждый slice получает отдельные acceptance criteria, тесты и обновление
`LAUNCH_STATUS.md`. Новые фичи не должны обходить активные stabilization
gates репозитория.
