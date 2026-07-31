# RECHARGE — Product Vision (полное продуктовое видение)

Версия: 2026-07-30. Приоритет документа: 4 (после ADR, slice spec,
LAUNCH_STATUS — см. AGENTS.md). Описывает ЦЕЛЕВОЕ состояние продукта.
Фактические статусы реализации — в AGENTS.md.

## Продукт

Recharge — мобильное приложение для подбора, создания и управления
досугом: события, локации, маршруты, активности. Запуск: Рига / Латвия,
EUR. Масштабирование: страны, города, языки (en/ru/lv на старте),
валюты — через расширение моделей, без переписывания базы.

## Identity, роли и рабочие контексты

Механизм: роли `User / Creator / Admin` + capability-based permissions по
ADR 0013 и обязательная identity/publisher policy по ADR 0015.
Роль, рабочий контекст и publisher — три разные оси.

1. **User (Viewer)** — базовый личный профиль с обязательной авторизацией.
   НЕ отправляет и не публикует контент.
   Может: поиск, просмотр, участие, отзывы, избранное.
   Auth: Google / Apple Sign-In; unauthenticated guest mode отсутствует.
   Может сохранить разрешённый локальный pre-verification draft, но Submit и
   Publish заблокированы.
   Профиль: Visited places, Photos, Saved list, Upgrade account.

2. **Creator** — после отдельной дополнительной identity verification.
   Google/Apple account, verified email или телефон сами по себе не дают
   Creator. Решение server-owned, проверяемое и аудируемое.
   Creator — тот же личный профиль и тот же consumer UI, но с дополнительными
   create/submit/publish capabilities. Пользователь не переключается вручную
   между Viewer и Creator. При наличии grants личный профиль получает Creator
   tools и может создавать все 10 create-типов от своего имени.
   Профиль: вкладки Created / Visited / Photos, созданные объекты
   со статусами Published / Draft, Quick actions.

3. **Professional Page** — отдельный рабочий контекст verified Creator:
   `ManagedPage` + active membership + page-scoped capabilities
   (`manage_page`, `view_insights`, `manage_bookings` и type-specific grants).
   Страница представляет агентство, спортшколу, компанию, представительство,
   оператора локации или частного поставщика услуг. Контент публикуется ОТ
   ИМЕНИ страницы. Professional Page может ссылаться на физические Place, но
   не является Place. Пользователь начинает с 0 страниц и самостоятельно
   создаёт до 3 owned Professional Pages; четвёртая и последующие требуют
   отдельной одобренной заявки модераторам. Делегированные memberships не
   расходуют ownership quota.
   Термин `Pro generator` остаётся только legacy UI debt и не используется как
   целевое название роли, уровня или workspace.

4. **Admin** — системная роль с отдельными admin capabilities. Admin tools
   открываются как защищённая поверхность и не являются личным профилем,
   Professional Page или рабочим publisher. Admin может использовать
   presentation-only `View as Viewer / Creator / Professional Page`; preview
   не меняет роль, grants, workspace или publisher.

### Active workspace

Пользователь переключает в Settings только:

```text
Personal profile ↔ Professional Page A ↔ Professional Page B ↔ ...
```

`Personal profile` автоматически показывает доступные Creator tools, если
Creator verification и grants действительны. `Professional Page` всегда
разрешается по точному `pageId`, active membership и page-scoped capabilities.
Выбранный workspace — локальное UX preference, а не источник полномочий.
Switcher показывает только созданные пользователем или явно делегированные
страницы. При нулевом списке он предлагает `Create Professional Page`, а не
создаёт демо-страницу автоматически.

Создание owned page 1–3 отправляет пользователю подтверждение `Pending review`
и уведомляет moderator inbox. Попытка страницы 4 создаёт только idempotent
pending-заявку на расширение лимита и уведомляет пользователя и модераторов.

Admin tools располагаются отдельным пунктом Settings и не входят в список
publisher workspaces.

### Модель публикации

Каждый публикуемый объект имеет `publisher: {type: user | page, id}`.
Карточка показывает издателя (имя, аватар, verified). Верификация
личности Creator и верификация Professional Page — разные server-owned
состояния; ни одно не выводится автоматически из другого.

Активный workspace задаёт publisher по умолчанию для нового Create draft:
personal → `{type: user, id: userId}`, page → `{type: page, id: pageId}`.
Существующий draft сохраняет свой `PublisherRef`: переключение workspace не
переписывает publisher молча. Admin tools никогда не становятся publisher.

Для международного рынка Professional Page и content envelope поддерживают
stable country/market codes, IANA timezone, ISO currency и locale metadata.
Регистрационные, налоговые и KYC-поля зависят от страны и не являются
универсально обязательными. UI labels локализуются, а persisted roles,
workspace types, capabilities и publisher types остаются стабильными кодами.

### Идентификаторы

ULID, генерация на клиенте (по ADR). Временные `loc_*` — только для
несохранённых локальных черновиков, замена на ULID при публикации.
Все связи — только по id: `publisherId`+`publisherType` у контента,
`authorId`/`objectId` у отзыва, `{objectId, objectType}` в избранном,
список id точек у маршрута. Денормализация (кэш имени издателя)
допустима для отображения; источник истины — документ по id.
Deep links: `recharge://{objectType}/{id}`.

## Дизайн

Токены и общие компоненты — в `packages/design_system`.
Основной тёмно-зелёный `#0B3028`, белый, soft gray. Чистый минимализм,
много воздуха, скруглённые карточки. Никаких hex в виджетах.

## Навигация

Навигация зависит от active workspace, но не от наличия Creator grants:

| Active workspace | Bottom nav |
|---|---|
| Personal profile: Viewer или Creator | **Home · Favorites · Smart Search · Notifications · Profile** |
| Professional Page | **Page · Content · Create · Notifications · Account** |

В personal workspace Creator остаётся тем же Viewer-интерфейсом. Creator tools
доступны из Profile и Create Hub; центральный Smart Search не заменяется.

В Professional Page workspace центральная кнопка `Create` открывает Create Hub
с active page publisher. `Content` показывает материалы только выбранной
страницы. `Account` открывает личный аккаунт, Settings, переключение workspace
и logout, поэтому не называется `Profile` и не смешивается с page profile.
Smart Search остаётся доступен через consumer Home/Search, но не занимает
центральную позицию page workspace.

Обычный Search и Map не являются отдельными пунктами personal bottom nav и
открываются кнопками на Home.

## Экраны

### Home
- Верхняя зона: логотип, кнопки Search и Map
- Categories: горизонтальный скролл (All, Sport, Walks, Games...)
- Ленты: Nearby, Popular, For you, New, Quick events — каждая с View all
- Правило: Home не перегружаем — только быстрые входы-сценарии,
  полные фильтры глубже (Search / Map / Filters)

### Search (центр выбора условий)
- Каноническая основа Search / Filters / time-fit flow:
  [SEARCH_FILTERS_TIME_SPEC.md](SEARCH_FILTERS_TIME_SPEC.md). Спецификация
  утверждена и реализована в приложении отдельным slice после ADR по ranking
  и завершения стабилизации. Текущий mock runtime использует детерминированный
  travel-time fallback за интерфейсом репозитория; live routing подключается
  без изменения доменных формул.
- Отдельная от Smart Search функция и отдельный экран. Вход из Home,
  не из bottom nav. Обычная строка ищет буквальный текст и не
  запускает SmartQueryParser.
- Собирает: что, где, когда, с кем, бюджет, настроение, время в запасе
- Компактная строка с активными условиями чипами
- Чипы даты, состава группы, бюджета и радиуса — самостоятельные
  интерактивные контролы, а не только сводка. Каждый открывает компактный
  выбор с пресетами, сбросом и кастомным значением там, где применимо.
- Быстрые сценарии: «Near me now», «For two», «Low budget», «1 hour»,
  «Calm evening»
- Recent searches, Quick plans
- `/search` — компактный стартовый экран выбора; фактическая выдача
  открывается отдельно на `/discover/results`. История обычных запросов
  записывается автоматически только после запуска выдачи.
- Quick plans открывают Scenario Builder в preview-first режиме: сначала
  готовый план с итогами, мини-картой и последовательностью точек, затем
  по желанию — полный редактор.
- Блоки фильтров:
  - Что: событие / место / маршрут / быстрый план / люди
  - Когда: сейчас / сегодня / завтра / выходные / другое время
  - Где: текущая локация / город / выбрать на карте / радиус
  - Кто: один / пара / друзья / семья / компания
  - Бюджет: бесплатно / до 10 / 10–25 / 25–50 / другое
  - Настроение/Интерес: активное · спокойное · еда · природа · ночь ·
    культура · спорт · общение
  - Время в запасе: 30 мин / 1 час / 2–3 часа / полдня
- Кнопка результата: «Show N options» (с количеством найденного)
- Search влияет на: Maps, Categories, Feed, Route/Quick plan

### Smart Search
- Отдельная от обычного Search функция и центральный экран bottom nav только
  в personal workspace Viewer/Creator.
- Запрос можно ввести текстом или голосом; оба входа передают
  один естественный запрос в SmartQueryParser.
- Пользователь пишет запрос обычным языком («Хочу сегодня вечером
  что-то спокойное рядом, до 20 €») → система показывает чипы
  «понятых параметров» → лучшие варианты + альтернативы
- Парсинг за интерфейсом `SmartQueryParser` (domain):
  MVP — rule-based (ключевые слова, 3 языка); после релиза — LLM
  через DI без изменения UI. Голосовой ввод — post-MVP.
- Результат идёт в общий filter flow

### AI в Recharge

- AI — общий capability layer, а не отдельная роль, сущность каталога или
  замена domain-логике.
- Варианты использования включают AI Scenario Generation, LLM Smart Search,
  персональные рекомендации, Creator assist, помощь с восстановлением Scenario
  и quality/review assistance.
- Первый подробно специфицированный use case — AI Scenario Generation:
  естественный запрос преобразуется в проверяемый typed Scenario preview с
  sources, freshness, confidence, issues и alternatives.
- AI формирует proposal; permanent IDs, schedule/readiness, применение,
  booking и publish остаются за repositories, providers, validators и явными
  действиями пользователя.
- Каноническая стратегия:
  [AI_PRODUCT_STRATEGY.md](AI_PRODUCT_STRATEGY.md).

### Map (часть общей выдачи, не отдельный экран)
- Провайдер: Google Maps
- Зона поиска (радиус) визуально на карте, объекты внутри неё
- Верхний блок фильтров: 1-я строка всегда видна (Где, Что делаем,
  Дата, С кем), 2-я раскрывается (Бюджет, Время, Ещё)
- Левая шторка: скрыта (доступна как «ручка»); открывается по нажатию
  на объект/группу; показывает объекты в точке нажатия (один или
  несколько по схожему адресу); карточка: фото, время, длительность,
  название, сводка; автозакрытие при смене положения карты
- Кластеризация: группы объектов числом

### Feed и Details
- Feed показывает те же объекты, что и карта — единое состояние фильтров
- Details (карточка): главный блок (название, время, место, цена,
  участники, Сохранить / Поделиться), издатель (publisher + verified),
  «О событии», «Что вас ждёт» (чеклист), мини-карта локации, CTA

### Бронирование (MVP)
- «Записаться» / «Забронировать» → редирект на внешний сайт
  организатора (`externalBookingUrl` у Event / Bookable Session;
  у Place допустима только общая official booking landing page)
- Ссылка на конкретную дату, услугу или слот моделируется
  Bookable Session, а не Place
- Оплата и бронь внутри Recharge — post-MVP; структура закладывается
  расширяемо (Booking-сущность, ManagedPage.bookings)

### Отзывы и рейтинги (в MVP)
- `Review`: id, authorId, objectId, objectType, оценка, текст, дата
- Средний рейтинг и количество отзывов — на объекте (денормализация)
- Оставлять может любой авторизованный User

### Scenario Builder

- Scenario — самостоятельный personal/public план из независимых мест,
  событий, активностей и Route-items. Он не является Route и не является
  расширенной формой Quick Plan.
- Форматы: city, day, weekend и trip; один или несколько дней, локальное время,
  порядок и длительность остановок, логистика между ними, бюджет, ограничения,
  alternatives, stay и planned transport согласно capability gates.
- Personal Scenario доступен обычному User. Unlisted share и public template
  включаются независимо только после готовности backend token, publisher,
  capabilities и moderation runtime.
- Варианты создания: вручную, из выбранных Search/Map объектов, из Quick Plan
  через one-way Expand, из public template и через AI-generated preview.
- AI generation является опциональным entry mode того же Scenario aggregate,
  а не отдельным типом плана. Детали:
  [SCENARIO_AI_GENERATION_SPEC.md](SCENARIO_AI_GENERATION_SPEC.md).
- Каноническая логика создания:
  [SCENARIO_BUILDER_SPEC.md](SCENARIO_BUILDER_SPEC.md).

### Quick Plan

- Quick Plan — отдельный лёгкий personal/invited план «сегодня / вечером / в
  субботу»: обычно одна дата, 30 минут–6 часов и 2–8 остановок.
- Он живёт вне Create Hub и каталога, не имеет publisher, public lifecycle,
  Discover card или Review. Допустимы private, invited и unlisted coordination.
- Явное `Expand to Scenario` создаёт новый Scenario ULID и переносит выбранные
  допустимые остановки snapshot-ом. Quick Plan остаётся неизменным; live-связи
  и автоматического обратного преобразования нет.

### Route Builder (ключевая уникальность)

- Route — публикуемый непрерывный трек по местности, а не городской план.
- Создание: tap-to-route по графу троп, GPX import, intentional off-trail,
  локальное drag-to-reroute, loop/out-and-back/one-way.
- Точки интереса привязаны к нити и получают автоматические км-отметки.
- Details: фото, рейтинг, дистанция, длительность, сложность, форма,
  elevation, условия, точки по километражу и Start route.
- Каноническая спецификация создания:
  [ROUTE_BUILDER_SPEC.md](ROUTE_BUILDER_SPEC.md).
- GPS recording, offline maps и turn-by-turn navigation — post-MVP.

### Favorites
- Вкладки: All, Events, Places, Routes
- Карточки: превью, ключевая информация, статус
- Действия: открыть, удалить, поделиться

### Notifications
- Фильтры: All, New, Напоминания, Обновления
- Типы: напоминание о событии, изменение времени, новое предложение,
  подтверждение бронирования, запрос оценки
- Статусы: время, приоритет, прочитано/новое

## Create Hub (целевой скоуп: 10 типов)

Доступ: Creator (все типы). Viewer может получить разрешённое локальное
personal/pre-verification authoring без Submit/Publish; остальные действия
проверяются identity, capability и Publisher guards.

### Архитектура: единый form engine, НЕ 10 отдельных флоу
- Общий скелет (невидим пользователю): черновики (save/load),
  навигация по шагам, оркестрация валидации, загрузка медиа, превью,
  публикация, статусы Draft/Published
- Секции — переиспользуемые компоненты:
  - Общие: NameDescription, Media, Location, Pricing, Capacity
  - Типо-специфичные:
    - `RouteMapBuilderSection` — карта, рисовка маршрута (Route)
    - `RecurrenceScheduleSection` — одноразовое / повторяющееся,
      дни недели, серии на неделю/месяц (Event, Bookable Session)
    - `BestTimeToVisitSection` — когда лучше посещать (Route, Place)
    - `AmenitiesSection` — удобства/возможности (WC, душ, бар,
      парковка, доступность, оборудование). Набор ЗАВИСИТ ОТ ФОРМАТА:
      секция читает category и показывает только релевантные группы.
      Источник — справочник `AmenityTaxonomy` (группы + привязка
      к форматам), НЕ хардкод. Переиспользуется в Event, Place,
      Bookable Session — у каждого свои наборы из справочника.
      Выбранное отображается иконками в Details.
    - `InventorySection` — единицы, залог (Rental)
    - `ItemsPickerSection` — подборка существующих объектов (Collection)
    - `ScenarioContextSection`, `ScenarioComposerSection`,
      `ScenarioLogisticsSection`, `ScenarioReviewSection` — самостоятельные
      секции Scenario внутри общего Create form engine
- Тип = декларативный конфиг: набор секций, порядок, обязательность.
  Каждый тип для пользователя выглядит идеально заточенным под себя.
  Новый тип = новый конфиг (+ при необходимости новая секция).

### Типы
1. **Event** — событие с датой/временем; одноразовое или повторяющееся
   (серии на неделю/месяц) · 1–8 ч · 1–500+
   Поток создания (5 шагов): 1) Основное + Медиа · 2) Локация +
   Расписание · 3) Возможности (Amenities) · 4) Цена + Участники ·
   5) Превью + Публикация
2. **Recharge Activity** — лёгкая активность: прогулка, coffee walk,
   sunset walk · 30 мин–4 ч · 1–10
3. **Route** — непрерывный маршрут по местности: трек, GPX, elevation,
   условия и POI по километражу · 15 мин–8 ч · 1–8
4. **Place / Business** — постоянное место/бизнес на карте (парк, кафе,
   музей); каноническая логика создания —
   [PLACE_CREATE_BLOCK_SPEC.md](PLACE_CREATE_BLOCK_SPEC.md)
5. **Bookable Session** — спот/услуга/бронь: сауна, фотосессия, корт ·
   30 мин–3 ч · 1–20
6. **Scenario** — городской, однодневный, weekend или trip-план из независимых
   объектов с расписанием, логистикой и итогами; personal authoring доступен
   User, distribution включается отдельными capabilities
7. **Find People** — поиск компании; полноценный MapObject
   (в общей выдаче и на карте) · 30 мин–1 день · 2–20
8. **Class / Workshop / Experience** · 45 мин–4 ч · 1–30
9. **Rental / Equipment** — аренда вещей/транспорта · 1 ч–3 дня · 1+
10. **Collection / Guide** — подборка идей и мест · без лимита

Quick Plan не является одиннадцатым Create-типом: это отдельный utility-flow
вне Create Hub и каталога. Legacy `quickPlan` в текущей Create taxonomy —
migration debt до завершения Approved Scenario migration slices.

## Ключевая логика (инвариант)

Единый filter flow: **search → filters → map → feed → details**
- Обычный Search и Smart Search имеют разные UI, поведение, историю и
  точки входа. Они не являются двумя режимами одного экрана.
- Только после явного применения условий обе функции пишут в общую
  модель `DiscoverQuery`, которую используют Map, Feed и Details.
- Карта — часть общей логики выдачи, не второстепенный экран
- Все данные через единые модели (domain/entities)
- UI не хранит бизнес-логику

## Базовые сущности

`User`, `Profile`, `ManagedPage`, `Publisher`, `Event`, `Place`,
`Category`, `Filter`, `MapObject`, `Scenario`, `QuickPlan`, `Review`, `CreateDraft`,
`Booking` (расширяемо, MVP — минимум), `AmenityTaxonomy` (группы
удобств + привязка к форматам)

## Post-MVP (не реализовывать без запроса)

Оплата и бронь внутри Recharge, голосовой ввод Smart Search,
LLM-парсинг, AI Scenario Generation и остальные AI use cases по отдельным
Approved specs/gates, офлайн-маршруты, модерация Creator-заявок, chat,
recommendations engine, полноценная internal web admin console,
countries/cities catalogs, premium placement, analytics-дашборды,
onboarding by region, professional web cabinet, partner accounts.

Ограниченный capability-gated вход `Admin tools` в текущем mobile target не
означает полноценную admin panel: массовая модерация, sensitive verification,
audit и access administration целево выносятся в защищённую internal web
console по отдельному Approved scope.
