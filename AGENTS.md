# RECHARGE — инструкции для coding-агентов

Версия: 2026-08-09. Канонический файл инструкций репозитория.
CLAUDE.md ссылается сюда. При обновлении меняй дату версии.

## Приоритет документов (при конфликте — верхний побеждает)

1. **Accepted ADR** — `docs/adr/` (архитектурные решения)
2. **Spec текущего slice** — активная задача
3. **LAUNCH_STATUS** — `docs/architecture/LAUNCH_STATUS.md`
4. **Product vision** — продуктовое видение (раздел ниже + docs/)

Этот файл описывает правила работы; фактическая архитектура —
в `docs/architecture/ARCHITECTURE_BASELINE.md`. Если код противоречит
Accepted ADR — прав ADR; исправление кода оформляется задачей,
изменение решения — новым ADR, суперсидящим старый.

## Структура репозитория (monorepo)

```
apps/mobile/               # Flutter-приложение
apps/backend/              # Accepted ADR 0019 target; физически ещё не создан
packages/design_system/    # дизайн-токены, общие UI-компоненты
packages/api_contracts/    # контракты данных
docs/adr/                  # ADR (источник истины по решениям)
docs/architecture/         # ARCHITECTURE_BASELINE, LAUNCH_STATUS
```

Слои внутри apps/mobile: domain / data / **application** (контроллеры,
по frozen baseline) / presentation. Дизайн-токены живут в
`packages/design_system`, НЕ в app/theme.

## Команды (рабочая директория обязательна)

- Из корня: Melos-скрипты (см. melos.yaml)
- Или из `apps/mobile/`: `flutter pub get`, `flutter analyze`,
  `flutter test`, `flutter run`
- Перед завершением любого slice: `flutter analyze` и `flutter test`
  должны быть зелёными. Slice без зелёных проверок не считается Done.

## Разрешённые конфликты (решения приняты, не пересматривать молча)

1. **Роли и identity** — по ADR 0013 и ADR 0015:
   `User / Creator / Admin` + capability-based permissions. Viewer —
   обязательно авторизованный User. Creator требует отдельной
   подтверждённой identity verification; Google/Apple auth сам по себе
   Creator не даёт. Creator остаётся тем же личным Viewer-интерфейсом с
   дополнительными create/submit/publish capabilities; пользователь не
   переключается вручную между Viewer и Creator. Professional Page
   (`ManagedPage`) — отдельный рабочий контекст verified Creator с active
   membership и page-scoped capabilities (`manage_page`, `view_insights`,
   `manage_bookings`). Один аккаунт может управлять несколькими страницами и
   переключает только `Personal profile ↔ Professional Page`; Admin tools —
   отдельная capability-gated поверхность, не профиль, workspace или
   publisher. Термин `Pro generator` — legacy UI и не целевая модель.
   Guest mode более не является целевой продуктовой политикой.
2. **ID** — по ADR: ULID/UUID, генерация на клиенте. Временные `loc_*`
   допустимы ТОЛЬКО для несохранённых локальных черновиков и обязаны
   заменяться постоянным ULID при публикации. Все связи между
   сущностями — только по id, без ссылок по имени.
3. **Firebase** — целевой бэкенд (Auth: Google/Apple, Firestore,
   Storage). Текущее состояние — mock datasources. Accepted ADR 0019
   разрешает целевую архитектуру authoritative Booking backend и staged
   contracts/domain work; физическое подключение Firebase, deployment и
   production data processing — только отдельными Approved ECL-03 slices
   после стабилизации и всех Identity/Privacy/Platform gates.
4. **Create Hub** — целевой скоуп 10 типов через единый form engine.
   Базовый runtime всех 10 типов реализован через единый config-driven
   flow и Category System v1.4.3. Специализированные секции конкретных
   типов расширять только по Approved slice spec с отдельными
   acceptance criteria. Реализация этих блоков для уже утверждённых 10
   типов является завершением принятого Create Hub scope и **не
   считается новой фичей**. Новый create-тип сверх этих 10 и backend
   integration в это исключение не входят. Зрелые local/mock cross-feature
   механизмы внутри уже принятых типов разрешены по правилу mature extensions
   текущего stabilization slice и отдельному Approved slice spec.
   В целевой десятке planning-slot занимает **Scenario**. **Quick Plan** —
   отдельный пользовательский utility-flow вне Create Hub и каталога; он
   не считается одиннадцатым Create-типом. `quickPlan` сохраняется внутри
   Create taxonomy только как скрытый read-compatibility тип для legacy drafts.
   Для Event принят канонический продуктовый/доменный контракт
   `docs/product/EVENT_CLASSIFICATION_SPEC.md` v2.2.3. Все будущие Event,
   Booking, admission, inventory, availability и provider slices обязаны
   расширять его, а не создавать параллельную модель. Реализованный
   EVT-CRT-01 остаётся совместимым C0 + schedule-C1 подмножеством и не означает
   готовность полного контракта. Изменение инвариантов требует явной новой
   ревизии/ADR; принятие спецификации само по себе не разрешает Firebase,
   production backend, Payments или provider integration.
5. **Регион запуска** — Рига/Латвия, EUR. Дефолтные координаты
   в конфиге: 56.9496, 24.1052 (сейчас неверные — задача бэклога).
   Локализация en/ru/lv — целевая, фактически НЕ настроена
   (нет lib/l10n) — отдельный slice.
6. **Route ≠ Scenario ≠ Quick Plan** — Route является непрерывным треком
   по местности с anchors/segments/GPX/elevation/POI. Scenario —
   самостоятельный personal/public план из независимых остановок с
   логистикой: city/day/weekend/trip. Quick Plan — лёгкий personal/invited
   план на несколько часов, не публикуется в каталоге и не является
   контейнером Scenario. Разрешён только явный one-way `Expand to
   Scenario`: создаётся новый Scenario ULID без live-связи. Не добавлять
   `RouteMode`, Scenario-поля или Scenario handoff в Route domain model.
   Legacy-код с названиями `scenario route` и Scenario-as-Quick-Plan —
   migration debt, не источник продуктовой модели.

## Текущий slice: СТАБИЛИЗАЦИЯ (активен)

Стабилизация не запрещает зрелые расширения продукта. Разрешено добавлять
локальные и mock-first возможности сверх минимального MVP, если одновременно:

1. Они не противоречат Accepted ADR, доменной модели и принятой продуктовой
   логике, не смешивают разные aggregates и не создают обход capability,
   moderation или Publisher boundaries.
2. Они реализуются в существующих архитектурных слоях и form/config engine,
   не создают параллельную систему или лишнюю связанность.
3. Они не требуют платных сервисов, нового production backend, Firebase,
   provider lock-in или внешней инфраструктуры для базовой работы.
4. Они не создают заметной вычислительной, сетевой, storage- или operational
   нагрузки; тяжёлые интеграции остаются отдельными gated slices.
5. Для них есть Approved slice spec с bounded scope, acceptance criteria,
   миграцией/rollback и тестами.
6. Slice проходит `flutter analyze`, `flutter test`, boundary и diff checks и
   не ухудшает критерии стабилизации.

Такие расширения считаются развитием зрелого приложения и приветствуются.
При сомнении предпочтителен local-first reversible design с provider-neutral
contracts. Новый create-тип сверх принятых 10 и production integration всё ещё
требуют отдельного архитектурного решения; зрелые возможности внутри принятых
типов и общих локальных Create-механизмов разрешены по Approved slice spec.
Identity verification, Professional Page и общий PublisherRef описаны в
ADR 0015 и `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md`. Accepted ADR 0016
и ADR 0017 точечно разрешают во время стабилизации только bounded local/mock
slices IDP-03A/04A/05A: mock access snapshot, пользовательское создание
ManagedPage без предсозданных страниц, owner membership, self-service лимит 3,
pending-заявку модераторам на расширение, локальные уведомления, Admin
experience preview, personal/page workspace switcher, workspace-aware shell,
local publisher defaults и capability guards. Это исключение НЕ разрешает
Firebase, production auth migration, реальные identity/page verification
decisions, authoritative quota approval, backend grants, production page
publication или новый Create scope. Каждый IDP slice проходит собственные
acceptance criteria, `flutter analyze`, `flutter test`, boundary и diff checks;
расширение исключения требует нового Accepted ADR.

Критерии приёмки стабилизации:
1. Рабочее дерево чистое: изменения раскиданы по осмысленным коммитам,
   build/cache-артефакты удалены из индекса и добавлены в .gitignore.
2. `flutter analyze` — 0 ошибок (из apps/mobile).
3. `flutter test` — все тесты проходят; тесты, требующие починки, —
   починить или явно пометить skip с TODO-ссылкой на задачу.
4. Slices в статусе Review перепроверены: либо подтверждены зелёными
   проверками, либо возвращены в Doing с описанием, что сломано.
5. LAUNCH_STATUS.md обновлён до фактического состояния.
6. README заменён с Flutter-заглушки на краткое описание проекта
   и команд.
7. Placeholder-URL (example.com для Privacy/Terms/Support) собраны
   в один конфиг с TODO — не разбросаны по коду.

## Статусы фич (обновлять при изменении)

| Область | Статус |
|---|---|
| Discover (search/map/feed/details) | mock-данные; Search/Filters/time-fit v2 реализован, travel fallback за repository contract |
| Create Hub: 10 типов | config-driven runtime; Place / Business, Event, Find People и Scenario имеют типизированные Create-блоки на mock; Place получил PLC-ADP-01: трёхшаговую адаптивную форму по профилю места, релевантные часы/вход/расходы/контакты и explicit local-demo Creator Assist без автоматической публикации; Event получил local-first пользовательские templates CRT-TPL-01 (несколько шаблонов, выбор, управление и новый независимый draft из последнего шаблона); видимый planning-slot занимает Scenario, `quickPlan` скрыт как legacy read-compatibility type |
| Event Classification v2.2.3 | Accepted canonical product/domain contract; 34 архетипа, полное покрытие Category System v1.4.3 и provider-neutral roadmap. ECL-00–ECL-03B Done. ECL-03A: ADR 0019 Accepted, ECL-03 spec v1.1 Approved и D01-D10 Accepted. ECL-03B: shared Booking v1 JSON schemas/fixtures, immutable fixture-verified Dart DTOs и независимый pure mobile Booking domain/readiness/transition validation; package analyze 0 и 9 tests, mobile analyzer 0 и полный suite 659 passed, boundary 59 прежних suppressions без новых. ECL-03C-P exact transaction-core plan v1.0 в Review: пять callable surfaces, finite general-capacity/explicit unlimited instant-free paths, atomic ledger/usage/audit/outbox/idempotency, exact file map и 38 AC; runtime effect none. Нет client/network/repository/data/application/presentation/DI/Create/backend/Firebase runtime. Физическая ECL-03C реализация требует explicit plan acceptance, post-stabilization backend authorization и production Identity/Platform prerequisites; provider sync/Payments также не реализованы |
| Category System v1.4.3 | реализовано: 28 категорий / 530 подкатегорий, legacy migration; `route` означает только Route; 14 place-only типов поддерживают адаптивный Place Create |
| Auth | mock; целевое по ADR 0015: обязательная авторизация Viewer через Firebase Google/Apple, без guest mode |
| Creator verification / roles / capabilities | IDP-03A local/mock в Review: access snapshot явно содержит Admin и verified Creator; Admin-only presentation preview Viewer/Creator/Professional Page реализован без смены authority; production shell скрывает legacy manual profile-mode selector; production verification НЕ реализована |
| Professional Page / Active workspace / PublisherRef | IDP-03A в Review и IDP-04A в Doing: fixture начинается с 0 страниц; пользователь создаёт страницы сам, ownership limit 3, далее pending-заявка модераторам; exact-ID access, локальные уведомления, Settings switcher и page navigation реализованы. ECL-01 добавил shared PublisherRef и active-workspace default/non-rewrite для Event; остальные 9 Create типов ещё не переведены, production authority gated |
| Отзывы (Review) | запланировано (в MVP) |
| Visit History | VIS-HIST-01 local-first Done: только явная self-reported отметка Place с today/past датой, idempotency place/day, несколько дат и удаление; v1 demo-seed игнорируется, v2 начинается пустым; booking/view/favorite/GPS автоматически не считаются посещением |
| Smart Search | реализовано: rule-based parser, история и route-intent; mock-хранилище |
| AI assistance platform | AI-PLAT-LOCAL-01 Done: отдельный provider-neutral local/mock foundation с immutable transient contracts, versioned prompt registry, en/ru/lv locale contracts, redaction до gateway, bounded validation, read-tool allowlist, typed failures, kill switches, session quota, explicit deterministic fallback и zero-cost ledger; зарегистрирован в DI, но не подключён к Scenario, Place, Smart Search или UI; production provider/network/secrets/persistence остаются gated |
| Quick Plan | локальный лёгкий план остановок реализован частично; runtime-черновик получил стабильные id/revision и явный one-way `Expand to Scenario` через SCN-SB-03; остаётся personal/invited utility вне Create Hub/Discover, legacy Scenario/Route naming требует cleanup |
| Scenario Builder | самостоятельный Latvia-wide city/day/weekend/trip продукт по Accepted Scenario spec v1.7; canonical domain/schema v2/mapper/validation/readiness и personal Create runtime с catalog/custom/time-block composer, undo/redo, autosave/readiness реализованы; Quick Plan имеет только explicit one-way conversion; own-car, manual locked legs и official planned-transport snapshots работают с обязательной честной пометкой `not live`; SCN-FUEL-CLEANUP-01 Done удалил fuel consumption/price/budget UI, fuel-поля/вычисление и legacy derived component из normalized runtime, сохранив car, duration/distance и explicit `travel_extra`; SCN-AI-01 остаётся скрытым optional local-demo experiment; SCN-LV-DATA-01 и SCN-LV-DATA-02A–02E Done обеспечивают static GTFS foundation, picker, atomic Apply/Recheck/Replace, offline fallback, telemetry и rollback; SCN-INTAKE-01A–01D и parent Done: Details/Search/Map поддерживают auth-only single/ordered batch Add to Scenario, owner-scoped target/new private target, placement/review, atomic Apply, privacy-safe telemetry, surface kill switches и 360 dp/150% accessibility gate. Transport snapshot остаётся внутренним механизмом, основной UI должен показывать понятные planned/not-live freshness и Recheck states. Public/unlisted publish, external AI/live planning, transfers/fares/booking и explicit legacy migration write ещё не реализованы |
| Route Builder (creation) | Route-only spec v3.2; RTE-01–07 Done; RTE-08–11 Review. RTE-11 реализует GPS start/pause/resume/finish, foreground/background permissions, crash-safe chunked AES-256-GCM journal с ключом в platform secure storage, восстановление без auto-resume, fail-closed filtering, preview-карту, privacy trim, явные gap decisions и atomic `recordedGps` apply; 22 GPS unit + 1 end-to-end widget test зелёные, targeted analyzer чист. До Done нужны Android/iOS device-проверки и общий stabilization gate. Безопасные GPX inspection/import/apply/export и UI также реализованы локально; production adapters — последующие gates |
| Локализация en/ru/lv | не настроена |
| Бронирование | MVP: редирект на externalBookingUrl; оплата — post-MVP |
| Геолокация | Discover current location остаётся mock в центре Riga; Route GPS recording подключён через `geolocator` и изолирован provider-neutral port |

## Правила разработки

1. UI не содержит бизнес-логику; контроллеры — в слое application.
2. Сложная логика — в usecases; новый usecase → интерфейс
   в domain/repositories.
3. Все сущности имеют ULID `id`; связи только по id. Publisher-модель:
   контент публикуется от имени `{type: user | page, id}`.
4. Create-типы — только через form engine и декларативный конфиг
   секций; НЕ создавать отдельный флоу-код на тип. Секции могут быть
   типо-специфичными (RouteMapBuilder, RecurrenceSchedule и т.д.).
5. Не хардкодить регион/язык/валюту — enum + модель.
6. Данные из бэкенда — только через data/datasources; UI и domain
   не знают про Firestore.
7. Дизайн-токены и общие компоненты — в packages/design_system.
   Основной цвет: #0B3028, стиль: минимализм, скруглённые карточки.
8. Не трогать без запроса: сгенерированные файлы (*.g.dart,
   *.freezed.dart), docs/adr (только новые ADR, не правка старых),
   assets.
9. Перед крупным куском — план файлов без кода, ждать подтверждения.
   После изменений — краткий список затронутых файлов.
10. Ссылки/детали продуктового видения (экраны, filter flow, роли UI,
    10 create-типов) — см. docs/product/VISION.md (перенести туда
    текущий CLAUDE-контент; до переноса — раздел ниже).

## Product vision (кратко; приоритет 4)

Recharge — приложение подбора и создания досуга: события, места,
маршруты, активности. Ядро: единый filter flow
search → filters → map → feed → details с одним общим состоянием
фильтров (обычный Search, Smart Search, карта, категории, лента). В личном
workspace Viewer и Creator используют один bottom nav:
Home / Favorites / Smart Search / Notifications / Profile. Creator tools
открываются внутри Profile/Create Hub, а не заменяют Smart Search. В
Professional Page workspace навигация:
Page / Content / Create / Notifications / Account; активная страница
переключается только в Settings. Admin tools не являются workspace или
publisher. Search и Map — кнопки на Home. Карта: радиус-зона, двухстрочный
блок фильтров, левая шторка объектов. Quick Plan быстро собирает личный или
invited план на несколько часов и не попадает в каталог. Scenario Builder
создаёт самостоятельный city/day/weekend/trip план с логистикой и итогами;
Scenario может быть personal, unlisted или public template. Route Builder
создаёт отдельный непрерывный трек с GPX, elevation и POI по километражу;
Route, Scenario и Quick Plan — разные aggregates. Основная карта использует
Google Maps, outdoor renderer Route Builder утверждается отдельным ADR. Отзывы и
рейтинги — в MVP.
Find People — полноценный MapObject в общей выдаче.
