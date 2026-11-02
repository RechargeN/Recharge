# L4 — локализация Release R1 на lv / en / ru

- ID: **LOCALIZATION-L4**
- Версия: **0.13 (v0.12 + решения L4.9 и 9.1: канонические коды языков; review не проведён)**
- Дата: **2026-11-02**
- Статус: **Review — механизм, policy, контракты и миграция серверных R1-поверхностей; языковой review не проведён**
- База: `codex/recharge-integration` @ `01065f6` (L1–L3 + 01–36), ветка `claude/l4-localization`
  (v0.1–v0.2, вершина `af04b1d`); v0.3 — ветка `claude/l4-1-tails` от `af04b1d`;
  v0.4 — ветка `claude/l4-2-create-codes` (база — итог L4.1);
  v0.5 — ветка `claude/l4-3-create-forms` (база — итог L4.2);
  v0.6 — ветка `claude/l4-4-create-forms-deferred` (база — итог L4.3);
  v0.7 — ветка `claude/l4-5-discover` (база — итог L4.4);
  v0.8 — ветка `claude/l4-6-identity-profile` (база — итог L4.5);
  v0.9, v0.10 — тот же worktree поверх v0.8;
  v0.11, v0.12 — ветка `claude/l4-8-error-codes-proposal` от `5ee6308`
- Расширяет: [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md) §12, §17, §21 (OD-10
  LocalizedText — accepted technical contract), F1 Notifications
  (`notification_templates.ts`, BCK13-OD-05 открыт), Latvia roadmap §2.1–2.2, §3.5
- Runtime-эффект: только mobile-клиент (UI-тексты, выбор языка, форматирование)
  и тесты. Backend runtime, схемы, рынки, Firebase, provider и платный перевод
  не менялись.

Зелёные тесты подтверждают полноту ресурсов, контракты и поведение, а **не**
качество перевода. Тексты lv и ru написаны без носителя языка и без Product
Localization review (BCK20-OD-02 открыт).

## 1. Принятая база и её пределы

| Источник | Что есть | Чего нет |
|---|---|---|
| AGENTS.md, конфликт 5 | lv/en/ru — цель для Латвии; `lib/l10n` отсутствовал | Механизма в коде не было |
| Roadmap §2.1–2.2, §3.5 | Market ≠ locale ≠ currency ≠ timezone; LV: `lv-LV`, `en`, `ru`; «пользователь выбирает locale»; lv/en/ru и обязательные тексты — условие приёмки LV | Политика fallback, владения настройкой, языка уведомлений |
| BCK-20 v0.2.29 (Draft) | OD-10 LocalizedText v1: детерминированный market-scoped fallback, typed `translation_missing`/`unsupported_locale`; язык не выводится из рынка | Источник переводов, review workflow (OD-02), Legal copy (OD-05) |
| F1 Notifications | `templateKey#revision` + typed variables (`deadline` — UTC instant); рендер на чтении по `locale` запроса; без fallback между языками; ревизии зафиксированы sha256 | Проверка, что все активные ревизии покрывают три языка с одинаковыми placeholders |
| Mobile до L4 | ~3 тыс. захардкоженных строк (англ. и рус.), сырые серверные коды на экране (`state.message!`, `unavailable: <code>`, `review: under_review`), уведомления всегда запрашивались на `ru`, дедлайн брони — в зоне устройства | Любая локализация |

## 2. Inventory пользовательских поверхностей

Классы текста разделены так:

| Класс | Примеры | Политика L4 |
|---|---|---|
| Пользовательский UI-текст | заголовки, кнопки, состояния, подсказки, accessibility/tooltip | ARB lv/en/ru |
| Локализованное представление сервера | коды ошибок, статусы review/visibility, состояния брони, импорта | stable code в состоянии → каталог/`select` в UI |
| Серверный текст уведомлений | `booking.*` шаблоны rev 1 | сервер рендерит на языке читателя; клиент не переводит |
| Пользовательский контент | названия черновиков, тексты Place/Event, имена | показывается как есть, не переводится (проверено тестом) |
| Developer logs / исключения | `StateError(...)`, `ArgumentError(...)`, assert-тексты адаптеров | не переводятся и не показываются |
| Security audit / аналитика | L1–L3 audit, L3 события | не содержат языка и текста; L4 их не трогает |
| Официальные/юридические тексты | Privacy, Terms, Support (`LegalLinks`) | локализованы только названия ссылок; сами тексты — mandatory copy вне L4 |

Цепочка R1 (по коду базы) и что сделано:

| Звено | Поверхность | L4 |
|---|---|---|
| Mobile UI | shell-навигация (подписи = accessibility), Settings, Profile (сообщения), Sign-in, Auth gate, Splash | мигрировано |
| Mobile UI | Event Booking section/panel | мигрировано; дедлайн — в зоне события |
| Mobile UI | 10 тестовых путей публикации (Event, Place, Rental, Session, Activity, Collection, Find People, Route, Scenario, Class/Workshop) + панели | мигрировано, сырые коды убраны |
| Import/export | Local import section/panel, rollback-диалог | мигрировано; GPX import/export UI — нет (§9) |
| Validation | Sign-in (форма) | мигрировано |
| Validation | Серверные field violations Place/Rental/Collection/Activity: 130 кодов → 115 сообщений и 43 названия полей; таблицы хранят id сообщений, UI их переводит | мигрировано (v0.2) |
| Validation | Локальные проверки Place (56 кодов, 9 разделов), Session (25 кодов), Route (99 кодов → 11 сообщений + 6 семейств, 10 разделов), причины записи Class/Workshop — раньше выводились сырые коды | мигрировано (v0.2) |
| Mobile UI | Details: состояния «недоступно/нет связи/маршрут обновился» (типизированный `notice` вместо русских строк), снэкбары Event/Session/Class/Find People/Discover Details, Visit history | мигрировано (v0.2) |
| Mobile UI | Главная: цена карточек и сохранённых маршрутов, время, радиус, панели продолжения | мигрировано (v0.2); исправлены 2 бага (§5) |
| Server errors | Booking, Content, Media, Publisher eligibility, Platform, Notification content status | каталог + контракт со схемами |
| Server errors | клиентские отказы (`_LocalRefusal`, транспорт) | каталог + скан кода |
| Notifications | inbox: заголовок/текст от сервера, fallback-состояния, фильтры, поиск, empty/error | мигрировано; legacy Scenario-route preview — нет |
| Остальное | Тексты Create-форм, Discover (поиск, карта, рендеры объектов), Identity/Pages, Scenario/Route builders, Profile, Favorites, Visited, AI, маркетинговые шаблоны главной | **не мигрировано** (§9, inventory) |

## 3. Решения до реализации (policy)

### 3.1 Поддерживаемые языки и детерминированный fallback

- UI-языки R1: `en`, `lv`, `ru` (language-only BCP 47 теги). `lv` — латышский
  язык, а не рынок `LV`. EE/LT и их языки (`et`, `lt`) не добавлены.
- Разрешение (`AppLocalePolicy.resolve`), строго по порядку:
  1. явный выбор пользователя (`en`/`lv`/`ru`);
  2. первый язык из списка языков устройства, чей language subtag поддержан
     (`lv-LV` → `lv`, `ru_RU` → `ru`, `en-GB` → `en`);
  3. `MarketConfig.defaultLocaleCode` активного рынка (сейчас `en`).
- Неподдерживаемые теги (`et`, `lt`, `de`, `uk`) пропускаются и никогда не
  отображаются на «похожий» язык. Fallback обязан быть поддержанным языком
  (иначе конструктор политики падает).
- Внутри ресурсов fallback между языками нет: каждый ключ обязан быть в lv/en/ru
  (§7, проверка 1). Виджет вне делегатов приложения получает английский —
  тот же детерминированный fallback (`context.l10n`).

### 3.2 Источник выбора и неподдерживаемая locale

- Единственный владелец — `LocaleController` (`lib/core/localization`):
  выбор `system | en | lv | ru`, языки устройства, разрешённый код.
- MaterialApp получает только разрешённый язык (`locale:`), собственное
  разрешение Flutter не используется; смена языков устройства обновляет
  контроллер (`didChangeLocales`).
- Сохранённое неизвестное значение (например, будущее `et`) игнорируется как
  `system` и **не перезаписывается**.

### 3.3 Владение настройкой, logout/login

- Настройка принадлежит **установке приложения (устройству)**:
  `FlutterSecureStorage`, ключ `app.locale_preference.v1`, без id аккаунта.
- Действует до входа (Sign-in, Splash), переживает выход; следующий аккаунт на
  том же устройстве видит тот же язык, пока не сменит. Очистка сессии при
  выходе (`auth.session`, `auth.user`) этот ключ не трогает.
- Серверного языка аккаунта в R1 нет (BCK-06 его не содержит) — **gap L4-G02**.
- Legacy-поле `explore_settings_<userId>.language` (локальное, по аккаунту,
  по умолчанию `ru`) больше не управляет UI; оно оставлено read-compatible, без
  миграции и без переписывания сохранённых данных (L4-G07).

### 3.4 Timezone каждого пользовательского отображения

| Значение | Зона | Почему |
|---|---|---|
| Дедлайн подтверждения брони (mobile) | IANA-зона события (`PublishedEventDiscoveryEntity.timezoneId`) | время события; раньше показывалось в зоне устройства — исправлено |
| `{deadline}` в шаблоне уведомления (сервер) | `Europe/Riga` (как было) | effect не несёт зону события; R1 = только LV — **gap L4-G03** |
| Время прихода уведомления в inbox | зона устройства | момент читателя, не локальное время объекта |
| Срок unlisted-ссылки Scenario, срок согласия Find People, конец периода восстановления импорта | зона устройства | момент без локального календаря объекта |
| Даты событий, расписаний, Visit History вне мигрированных экранов | без изменений | экраны не мигрированы; L4 их семантику не трогал |

Язык меняет только запись: в тестах один и тот же UTC-instant даёт одинаковое
местное время во всех языках, включая полночь и обе стороны DST.

### 3.5 Язык уведомлений (F1)

- Producer (Booking outbox v2) и effect **не содержат языка**: envelope с
  лишним полем отклоняется как `invalid_effect`, поэтому язык инициатора
  (например, организатора, отменившего событие) не может попасть к получателю.
- При enqueue закрепляется `templateKey#revision`, policy revision и typed
  variables; текст не сохраняется.
- Язык выбирается **при чтении** запросом получателя (`listInbox.locale`);
  mobile передаёт текущий язык `LocaleController` (`lv` → wire `lv-LV`).
  Отсутствующая настройка = `system` → язык устройства → fallback `en`.
  Неподдерживаемый или отсутствующий `locale` в запросе отклоняется сервером.
- Retry/replay/реконсиляция работают по receipt и создают один элемент;
  язык на это не влияет (проверено: сбой записи → retry → один элемент,
  читается на трёх языках).
- Compatibility: элемент рендерится той ревизией, что закреплена; новая
  активная ревизия не переписывает историю; удалённая из реестра ревизия
  даёт `template_unavailable` без текста и без перезаписи. На клиенте
  `unsupported_locale`/`template_unavailable` показываются локализованным
  сообщением, без подстановки другого языка.

### 3.6 Механизм и точные файлы

Один механизм — Flutter `gen-l10n` (ARB), по `ARCHITECTURE_BASELINE` (`lib/l10n`,
`lib/generated/l10n`). Параллельных словарей по feature нет.

| Файл | Назначение |
|---|---|
| `apps/mobile/l10n.yaml`, `pubspec.yaml` (`flutter_localizations`, `intl: 0.20.2` — точная версия, которую требует `flutter_localizations` SDK; при обновлении Flutter меняется вместе с ним, `generate: true`) | конфигурация |
| `apps/mobile/lib/l10n/app_{en,lv,ru}.arb` | ресурсы (en — шаблон с описаниями) |
| `apps/mobile/lib/generated/l10n/*` | сгенерировано `flutter gen-l10n`, закоммичено; свежесть проверяет тест |
| `lib/core/localization/app_locale_policy.dart` | языки, разрешение, wire-mapping уведомлений |
| `lib/core/localization/locale_preference_store.dart`, `locale_controller.dart`, `locale_providers.dart` | хранение и владелец выбора |
| `lib/core/localization/l10n_context.dart` | `context.l10n` с детерминированным fallback |
| `lib/core/localization/user_message_catalog.dart` | stable code → текст |
| `lib/core/localization/recharge_formats.dart` | деньги, числа, даты в зоне объекта |
| `lib/app/app.dart`, `bootstrap.dart`, `main.dart`, `di/service_locator.dart`, `di/notifications_inbox_composition.dart` | подключение |
| мигрированные экраны (§2) | замена строк, typed сообщения |
| `tool/l10n_inventory.dart`, `test/fixtures/l10n/unlocalized_baseline.json` | inventory (весь / только интерфейс, по слоям) и ratchet по интерфейсу |

Предложения не собираются конкатенацией переводов: состояния передаются в
сообщение как placeholders одного шаблона, падежи/числа — через ICU
`plural`/`select` (CLDR: en `one/other`, lv `zero/one/other`, ru `one/few/many/other`).

## 4. Ошибки: stable code → локализованный текст

- Сервер возвращает типизированный код; в состоянии контроллеров хранится
  **код** (например, `EventBookingMessage(refused, refusalCode: 'sold_out')`,
  `message: 'validation_failed'`), текст строится только в UI.
- Каталог покрывает enum-ы схем `booking_error.code` (32), `content_result.failureCode` (31),
  `media_result.failureCode` (23), `publisher_eligibility.reason` (8),
  `platform/error.code` (15), `notifications_result.contentStatus` (3) — каждый код
  либо конкретным сообщением, либо явно общим (`unsupported_*` → «обновите
  приложение», `idempotency_conflict` → общий текст), либо «не ошибка»
  (`eligible`, `rendered`). Каталог не содержит кодов, которых нет в схеме.
- Неизвестный код → безопасный общий текст; код остаётся в состоянии для
  диагностики, на экран не выводится. Отсутствующий код при ошибке чтения
  объекта (`PublicationTexts.unavailable`) → тот же общий текст `errorGeneric`
  (v0.3; раньше подставлялся `unknown` → «не удалось подтвердить результат»,
  что относится к неподтверждённой записи, а не к чтению).
- Тексты ошибок не называют репортёра, приватные условия брони, другой аккаунт
  или провайдера; параметры сообщений — только числа, stable ids и уже
  локализованные фрагменты (проверено allowlist-тестом).

## 5. Форматирование

`RechargeFormats`: деньги — валюта из значения `Money` (EUR как данные, USD
остаётся USD на любом языке). v0.2 исправила на главной два нарушения: цена
печаталась с жёстко зашитым `EUR` вместо валюты `Money`, а время события — в
зоне устройства вместо зоны объекта (устройство используется, только если у
объекта нет зоны); числа — разделители языка; даты/время — в зоне
объекта; при отсутствии данных дат intl (виджет вне делегатов) — встроенный
`en_US`, как и fallback текста.

## 6. Market / currency / domain не меняются

Смена языка не меняет `MarketConfig` (LV, EUR, `Europe/Riga`, координаты),
ids, revisions, idempotency keys, enum values, schema versions, timestamps и
сохранённые данные. EE/LT остаются выключенными (`status: disabled` в схеме и
фикстурах), в mobile их нет.

## 7. Обязательные проверки → тест → результат (на этом дереве)

| # | Проверка | Тест | Результат |
|---|---|---|---|
| 1 | Coverage lv/en/ru: ключи, placeholders, plural/select, корректность, свежесть генерации; положительный контроль | `test/unit/localization/arb_coverage_test.dart` (+`test/support/l10n/arb_checker.dart`) | зелёный; контроль ловит 8 классов дефектов и устаревший generated |
| 2 | Контракт: схемные коды R1 ↔ каталог; клиентские отказы; положительный контроль нового кода | `server_error_contract_test.dart` (mobile); `notification_localization_l4.test.ts` (backend: effect → policy → template → 3 языка, контроль нового ключа/пропуска языка/дрейфа placeholders) | зелёные |
| 3 | Смена языка, перезапуск, неподдерживаемый язык, logout/login тем же и другим пользователем | `locale_policy_test.dart`; `settings_page_test.dart` (L4) | зелёные |
| 4 | Три языка на одном объекте: ids, timestamps, рынок, валюта неизменны | `event_booking_section_test.dart` (L4), `notification_localization_l4.test.ts`, `settings_page_test.dart` | зелёные |
| 5 | EUR, дроби, даты, полночь, DST (осень и весна), plural | `formats_test.dart`; backend deadline midnight/DST | зелёные |
| 6 | Реальная серверная ошибка → Flutter adapter → controller → локализованный UI | `event_booking_ui_stand_test.dart` (L4, lv/ru, stand B2); `page_access_revocation_stand_test.dart` (`capability_denied` → текст, stand D3.1) | см. §10 |
| 7 | Producer → template → recipient: 3 языка, инициатор ≠ получатель, нет настройки, retry, версии | backend `notification_localization_l4.test.ts`; `notifications_inbox_client_test.dart` (stand F1); `f2_client_test.dart` (stand F2) | backend зелёный; стенды — §10 |
| 8 | UI на трёх языках: длинные строки, 360 dp, ×2 шрифт, overflow, обрезанные действия | `event_booking_section_test.dart`, `local_import_section_test.dart`, `settings_page_test.dart`, `notifications_page_test.dart` (L4) | зелёные; найдена и исправлена неоднозначность ru «Отменить импорт» (кнопка = подтверждение) |
| 9 | Контент, секреты, приватные параметры не идут через перевод/логи; ни один экран не выводит сырой код | `l10n_boundary_test.dart` (включая guard на `Text(...code)` с положительным контролем); backend: effect без языка | зелёные; guard нашёл 4 места с сырыми кодами (Place/Session/Route Create, Class reasons) — исправлены |
| 2a | Каждый id сообщения в таблицах валидации и каждый код локальных проверок Place/Session/Route имеет свой текст на трёх языках | `content_validation_feedback_test.dart`, `server_error_contract_test.dart` (скан кода валидаторов) | зелёные |
| 10 | EE/LT market flags и доступность не изменились | `l10n_boundary_test.dart`; diff по `apps/backend/config`, `packages/api_contracts/schema` пуст | зелёные |

## 8. Fallback policy (итог)

1. Явный выбор → 2. язык устройства по subtag → 3. `MarketConfig.defaultLocaleCode` (`en`).
Внутри ресурсов fallback между языками нет (каждый ключ есть в трёх файлах).
Виджет без делегатов → английский. Неизвестный код ошибки → общий локализованный
текст. Уведомление без текста на языке читателя → локализованное «недоступно
на вашем языке», другой язык не подставляется. Неизвестный server enum в
`select` → «неизвестно» на языке UI.

## 9. Gaps и непокрытые строки

| ID | Gap | Что нужно |
|---|---|---|
| L4-G01 | Закрыт в v0.13 (§22): `lv-LV`, `en`, `ru` для API и данных, `lv` внутри UI и ARB | — |
| L4-G02 | Нет серверного языка аккаунта; выбор только на устройстве. Нет offline-каналов (push/e-mail), где язык нужен при доставке | продуктовая policy + BCK-06/BCK-13 контракт |
| L4-G03 | `{deadline}` в уведомлении рендерится в `Europe/Riga`, а не в зоне occurrence | новая ревизия шаблона/переменная зоны до не-Riga событий и EE/LT |
| L4-G04 | Названия Category System (28/530) без переводов: датасет содержит только ids | источник переводов (BCK20-OD-02/06) |
| L4-G05 | Тексты Privacy/Terms/Support — обязательная локальная копия; локализованы только названия ссылок | Legal/mandatory-copy manifest (BCK20-OD-05) |
| L4-G06 | Языковой review lv/ru не проведён | Product Localization owner/носители, BCK20-OD-02 |
| L4-G07 | Legacy `explore_settings.language` (по аккаунту, `ru`) и выбор валюты EUR/USD в Settings — mock без эффекта; валюта по-прежнему из данных | продуктовое решение об удалении |
| L4-G08 | Частично закрыт в v0.2 (валидация Create, Details, главная). v0.3 отделила не-интерфейс (§12): весь inventory — 2 827 литералов в 183 файлах (эвристика), из них 290 в 19 файлах — mock-данные, сиды, словарь парсера, демо-граф и GTFS; **только интерфейс — 2 537 в 164 файлах**: `features/create` 1 424 (тексты форм), `features/discover` 587 (поиск, карта, рендеры), `identity` 117, `scenarios` 111, `explore` 100 (Profile), `app/presentation` 34 (Scenario intake), `core/config` 28, `auth` 23 (маркетинговые шаблоны главной; заголовки секций служат ключами виджетов), прочее ≤ 22. По слоям (интерфейс): presentation 1 737, application 360, domain 309, data 77, прочее 54 | следующие срезы; ratchet по интерфейсу запрещает рост |
| L4-G09 | Закрыт в v0.12 (§21): коды шести модулей перечислены в схемах, контракт «схема ↔ каталог» покрывает их | — |
| L4-G10 | Переквалифицирован в v0.2: строки legacy Scenario-route preview на экран не выводятся (список действий пуст), они только подставляются как данные предзаполнения Create (title/subtitle/q). Переводить их нельзя — это изменило бы данные черновика | migration debt Scenario/Route, не UI-локализация |

## 10. Проверки исполнения

Результаты gates этого дерева фиксируются в описании изменения и в отчёте
сессии, а не здесь. Backend runtime не менялся (только тест), поэтому полный
Emulator-набор не обязателен; затронутые стенд-гейты (B2, C3, D3.1–D3.7, F1,
F2, I3, J2) запускают изменённые Flutter-клиенты против локального Emulator.

## 11. Не входит

Платный или машинный перевод, новые языки и рынки, production/cloud, изменение
схем и доменной семантики, переписывание сохранённых уведомлений, перевод
пользовательского контента и официальных названий.

## 12. v0.3 (L4.1): хвосты v0.2 и честный inventory

Ветка `claude/l4-1-tails` от `af04b1d`. Runtime-эффект: одна строка
отображения (`PublicationTexts.unavailable`), тестовые ключи формы входа и
регистрация `LocationSearchRuntimeConfig` в DI (исправление дефекта базы);
backend, схемы, ARB-ключи и сохранённые данные не менялись.

| Что | Изменение | Проверка |
|---|---|---|
| Ошибка чтения объекта без кода | `PublicationTexts.unavailable(null)` → «Недоступно: {errorGeneric}» на lv/en/ru вместо `errorUnknownOutcome`; известный код — своё сообщение, неизвестный — общий текст, сам код не выводится | `test/unit/localization/publication_texts_test.dart` (красный до правки, зелёный после); стенды публикации C3, D3.1–D3.7, I3, J2 |
| Версия `intl` | `intl: any` → `intl: 0.20.2` (pin `flutter_localizations` SDK); `pubspec.lock` не изменился (sha256 до/после совпадает) | `flutter pub get --offline` |
| `integration_test/auth_flow_test.dart` | сценарий восстановлен по текущей навигации: гость → `bottom-nav-profile` → auth gate роутера (Sign-in с origin `/profile`) → вход mock-учёткой → Profile, выбран в нижнем меню. Язык зафиксирован override `localeControllerProvider` (`en`). Гость получается через repository-обёртку без восстановления сессии: mock-репозиторий на чистой установке сам входит demo-аккаунтом. У Sign-in появились стабильные ключи `sign-in-email`, `sign-in-password`, `sign-in-submit` (не из текста) | Android AVD (Medium Phone API 36): зелёный. Первый прогон нашёл дефект базы (с `01065f6`): `LocationSearchRuntimeConfig` не был зарегистрирован в DI (регистрацию удалил `8f53854`), а `createControllerProvider` читает его через `sl` — Profile и Create реального приложения падали `StateError`. Исправлено регистрацией в `service_locator.dart`; регрессия — `test/unit/app_dependencies_create_controller_test.dart` (реальный `setupDependencies()` собирает Create-контроллер; красный до правки) |
| Inventory | явный список не-интерфейса `nonInterfaceFiles` с причиной у каждого (mock-данные Discover/Create, `published_*_discovery_local_datasource`, сид уведомлений, `app/testing/`, словарь `smart_search_parser`, демо-граф маршрута, GTFS); разбивка по слоям presentation/application/domain/data; `--json` = baseline только интерфейса | `unlocalized_ratchet_test.dart`: рост по интерфейсу запрещён; baseline без исключённых файлов; каждое исключение существует, имеет причину и не лежит в `presentation`; положительный контроль |

Итог inventory (эвристика, литералы): весь — 2 827 в 183 файлах (как в v0.2);
не-интерфейс — 290 в 19 файлах; **только интерфейс — 2 537 в 164 файлах**.
Ratchet теперь считает только интерфейс; переклассификация не перевела ни
одной строки. В слое data вне списка остаются 77 литералов (например,
`collection_publication_local_datasource.dart`, адаптеры Google Places): они
не проверены как не-интерфейс и остаются в счёте.

Evidence прогонов v0.2 на `af04b1d`:
[L4_LOCALIZATION_VERIFICATION_2026_10_27](../verification/L4_LOCALIZATION_VERIFICATION_2026_10_27.md).

## 13. v0.4 (L4.2): Create — коды вместо предложений

Ветка `claude/l4-2-create-codes`, база — итог L4.1. Domain и application слоя
Create больше не формируют предложений: валидаторы и контроллер отдают
стабильный код и числовые параметры, текст строит presentation. Wire-, enum-
значения, коды проверок, ids и сохранённые данные не менялись.

| Что | Было | Стало |
|---|---|---|
| Issue-сущности Scenario, Find People, Event (вкл. Access, Classification, пресеты входа), Collection, Class/Workshop, Quick Plan → Scenario | поле `message` с английским предложением | `message` удалено; `code` + `params: Map<String, int>` (лимиты длины, число пунктов, single/series) |
| `ValidateCreateAvailabilityUseCase` | поле → предложение | поле → id `availability.validation.<code>` (10 кодов) |
| `CreateState.message`, `scenarioGenerationError`, `placeEnrichmentError` | ~80 русских/английских предложений, сырые `reasonCode`/`failure.name` в тексте (Route, Collection), имя шаблона пользователя в тексте | стабильный код `CreateNotice.*` (78 кодов); причины отказа сервера остаются диагностикой и на экран не идут; имя шаблона (пользовательский контент) в сообщение не передаётся |
| `validationErrors` (ошибки полей) | смесь предложений и сырых id (`place.validation.<code>`, `rental.validation.<code>`, `activity.validation.<code>` выводились как текст — найдено в L4.2) | только id `<семейство>.validation.<code>`; один резолвер `CreateTexts.fieldError` (presentation) |
| Пояснения Event Access и Scenario transit | предложения в application | `EventAccessDisclosureTopic`, `ScenarioTransitWarning`, статус по `freshness`; формулировки planned/not-live — по Scenario spec v1.7 |

ARB (lv/en/ru): ICU select `scenarioValidationIssue`, `findPeopleValidationIssue`,
`eventValidationIssue`, `collectionValidationIssue`, `classWorkshopValidationIssue`,
`activityValidationIssue`, `rentalValidationIssue`, `createAvailabilityIssue`,
`quickPlanConversionIssue`, `createNotice`, `createFieldIssue`,
`eventAdmissionPresetIssue`, `eventAccessDisclosure`, `scenarioTransitStatus`,
`scenarioTransitWarning`; plural-сообщения с int-плейсхолдерами
`findPeopleLengthIssue`, `findPeopleMaxLengthIssue`, `collectionMinItemsIssue`,
`collectionCuratorNoteLengthIssue`, `collectionItemCountHighIssue`,
`createPlaceGalleryLimit` (CLDR: en one/other, lv zero/one/other, ru
one/few/many/other). Тексты Activity переиспользуют уже переведённые
`validation*` серверной таблицы. Allowlist плейсхолдеров расширен одним
числом `min` (нижняя граница длины, как `max`).

Проверки: `server_error_contract_test.dart` (L4.2) сканирует коды каждого
валидатора, контроллера и формы, требует свой текст на трёх языках и не
допускает snake_case-кода в тексте; положительный контроль — неизвестный
id/код даёт безопасный общий текст; отдельный тест запрещает `message: '…'`
в domain-валидаторах и контроллере. Существующие unit/widget-тесты проверяют
коды или английский fallback, проверки не ослаблены.

Обоснованные исключения (помечены `// l10n-ignore` с причиной): тексты
developer-исключений (`ArgumentError`, `StateError`, `assert`, `toString`) в
domain/application; предзаполнение нового черновика, которое дальше
становится пользовательским контентом (`'Day 1'` первого дня Scenario,
`'Expanded Quick Plan'` и описание при развёртывании Quick Plan); ключевые слова
поиска небезопасного адреса в Find People. Вне объёма L4.2: подписи форм
(`*_create_config.dart`, `create_taxonomy.dart`, `PlaceCreationPolicy.label` —
заход L4.3), названия категорий (G04).

Inventory «только интерфейс»: 2 537 → 2 123 (138 файлов); весь — 2 413.

## 14. v0.5 (L4.3): формы Create реализованных типов

Ветка `claude/l4-3-create-forms`, база — итог L4.2. Формы Place, Event (с
Admission, Inventory, Classification и шаблонами), Activity, Rental,
Collection, Create Hub и страница успеха берут текст только через
`context.l10n`. Движок форм остался config-driven, отдельного flow-кода на
тип нет.

| Что | Было | Стало |
|---|---|---|
| Виджеты форм (16 файлов) | ~500 английских/русских литералов | ARB-ключи `createForm*` (lv/en/ru) |
| Шаги в `*_create_config.dart` | `title`/`description` — предложения | `titleId`/`descriptionId` (ARB id); один резолвер `createFormText(l10n, id)` |
| `CreateBlockConfig` (`create_taxonomy.dart`) | название, описание и подписи типа; UI склеивал «New ${title.toLowerCase()}» | полей текста нет; select-сообщения `createObjectType*` по стабильному `CreateObjectType` (название, описание, подписи места и цены, «новый», «создать», «бесплатно», старт UTC) |
| Профили Place (`PlaceCreationPolicy`) | `label`/`description` в domain | поля удалены; select по `PlaceCreationProfileId` |
| Удобства Place/Event/Session | `label` + группа-предложение | только `id` и стабильный `group`; select `createAmenityLabel`/`createAmenityGroup` |
| Варианты enum в выпадающих списках и превью | «очеловеченное» имя enum или сырое `.name` (Rental, Activity, превью Event: `Admission: booking`, `Visibility: public`) | `createOptionText(l10n, value)` — select `createOption` по `Тип_значение`, определение типа через pattern matching (не зависит от обфускации) |
| Деньги в превью | «`2500 minor EUR`», `basePrice.toStringAsFixed(0) EUR` | `RechargeFormats.money` с валютой из `Money` |
| Дни недели | «Mon…Sun» | `RechargeFormats.weekdayShort` (intl по языку) |
| Числа | «occurrence(s)», «unit(s)», «blocking issue(s)» | ICU plural (CLDR lv/en/ru) |
| Пользовательский контент | имя шаблона и `linkedPlaceId` вставлялись в предложения; хост внешней ссылки в тексте | в сообщения не передаётся: имя шаблона показано отдельной строкой как есть, id не показывается |

Найдено и исправлено тестами 360 dp: переполнения строк навигации Rental и
Collection, заголовка Place со статусом сохранения, карточки AI, нижней
панели `CreateFlowBottomBar` (design_system) и выпадающих списков без
`isExpanded` (Event, Activity).

Проверки: `create_blocks_small_screen_test.dart` (группа L4.3) — Place,
Event, Activity, Rental на lv/en/ru при 360 dp и шрифте ×1/×2: нет
overflow, основное действие шага прокручивается в видимую область и
нажимается; Collection — то же в `collection_create_block_test.dart` (там
есть фейки координатора). Зелёные тесты не подтверждают качество перевода.

Обоснованные исключения (`// l10n-ignore`): данные предзаполнения seed в
`create_page.dart` (описания «Drafted from…», маркер `Route steps: `, который
потом разбирается обратно, адрес/место/город по умолчанию), шаблон памятки
безопасности Rental (предзаполнение, которое правит владелец). Названия
категорий по-прежнему не переводятся (G04): превью показывает
`createTaxonomyLabelForPath`.

Inventory «только интерфейс»: 2 123 → 1 631 (115 файлов); весь — 1 921.

## 15. v0.6 (L4.4): Find People, Session, Class/Workshop, Route, Scenario

Ветка `claude/l4-4-create-forms-deferred`, база — итог L4.3. Формы Find People,
Session, Class/Workshop, Route (редактор, запись GPS, модерация) и Scenario
(composer, транспорт, расписание, генерация), а также лист «Add to
Scenario» берут текст только через `context.l10n`.

| Что | Было | Стало |
|---|---|---|
| Виджеты пяти форм и страница модерации Route | ~500 литералов | ARB-ключи `createFindPeople*`, `createSession*`, `createClass*`, `createRoute*`, `createScenario*` |
| Шаги `find_people/route/session/class_workshop/scenario_create_config.dart` | `title`/`description`, подписи пресетов Session | `titleId`/`descriptionId`/`labelId`, тот же резолвер `createFormText` |
| Варианты enum (одобрение, видимость, уровень, транспорт, темп, вид пункта Scenario, источник и состояние сегмента Route, свежесть расписания) | «очеловеченное» или сырое `.name` | `createOptionText` (select `createOption`) |
| Правила дома и права со-организатора Find People | `_enumLabel(id)` из стабильного id | select `createFindPeopleHouseRule` / `createFindPeopleCohostRight` по id |
| Дни недели Session | «Mon…Sun» | `RechargeFormats.weekdayShort` |
| «Add to Scenario» (`scenario_object_intake_*`) | контроллер хранил предложения; в UI сырые `objectType.name`/`sourceStatus.name`, ISO-даты, текст `FormatException` | контроллер хранит `ScenarioObjectIntakeNotice`; UI — select по стабильным значениям, даты через `RechargeFormats` (фиксированный старт — в зоне объекта, неизвестная зона → UTC с пометкой), разработческий текст исключения не показывается |

Тексты, где смысл важнее стиля, перенесены без изменения английского
смысла: приватность GPS (точки хранятся зашифрованными на устройстве, пока
трек не применён; геопозиция запрашивается только для записи Route), «planned / not live» в Scenario по spec v1.7 (транспорт и
расписание — план, не live-данные), 18+ / согласие / область показа в Find
People. lv/ru для них написаны агентом и **требуют проверки носителем и
юристом** до запуска (L4-G01).

Исключения (`// l10n-ignore`): пример запроса генератора Scenario остаётся
английским — генератор разбирает ключевые слова (открытый вопрос, как и
`smart_search_parser`); предзаполнение «Day 1» / «Expanded Quick Plan» —
пользовательский контент, который потом правит автор.

Найдено полным прогоном тестов: id шагов и пресетов пяти новых конфигов не
были подключены к `createFormText`, резолвер молча возвращал пустую строку,
и заголовки шагов были пустыми. Подключены все 44 id; новый
`create_form_texts_test.dart` требует непустой текст для каждого id из
`*_create_config.dart` на lv/en/ru. В листе «Add to Scenario» название
сценария и остановки больше не передаётся в сообщение: локализованная
подпись («After:», «Selected stop 2:») и название как есть показываются
рядом; заголовок успеха и название сценария — отдельными строками.

Найдено и исправлено тестами 360 dp: выпадающие списки без `isExpanded`
(Class/Workshop, Route, Scenario, Session) и статус сохранения в заголовке
Find People при шрифте ×2.

Проверки: `create_blocks_small_screen_test.dart` (группа L4.3 расширена) —
все шаги Find People, Session, Class/Workshop, Route и Scenario на lv/en/ru
при 360 dp и шрифте ×1/×2: нет overflow, основное действие шага видно и
нажимается. Зелёные тесты не подтверждают качество перевода.

Inventory «только интерфейс»: 1 631 → 1 100 (89 файлов); весь — 1 390.
Остаток — Discover (L4.5), профиль, workspace, Quick Plan, избранное,
посещённые места.

## 16. v0.7 (L4.5): Discover

Ветка `claude/l4-5-discover`, база — итог L4.4. Details (рендереры
Object/Offer, совместимый и Route), поиск, результаты, карта, лента, Smart
Search, домашний экран Discover, категории, лист выбора для Scenario берут
текст только через `context.l10n`.

| Что | Было | Стало |
|---|---|---|
| Рендереры и страницы Discover | ~700 литералов, много русских «по решению слайса» | ARB-ключи `discover*` (lv/en/ru) |
| Даты Event, Session, Find People, Class/Workshop | ручные таблицы `_ruWeekdayShort`/`_ruMonthGenitive`, функции `*LabelRu` | `RechargeFormats` (intl по языку) над значением, уже переведённым в зону объекта (`TimezoneRepository`); новые `wall*`-форматтеры не применяют зону повторно |
| Дни недели в часах работы | «Понедельник…» | `RechargeFormats.weekdayLong` |
| Деньги | `€12`, `12 EUR`, `_currencySymbol` | `RechargeFormats.money` с валютой из `Money`; бюджетные фильтры EUR-only подписаны как EUR |
| Расстояния, высоты, длительности | `2.3 км`, `45 min`, `2 h` | `discoverKm`/`discoverMetersText`/`discoverDuration` (число по языку, единица из ARB) |
| `DiscoverException` | русское `message` из data-слоя | только `code`; `message` — необязательная заметка разработчика, на экран не идёт |
| Лента (`DiscoverFeedController`) | русские предложения в `state.message`, которые показывались | `DiscoverFeedNotice` (код) → текст в презентации |
| Окно времени поиска | английский текст исключения домена в SnackBar | `TimeWindowIssue` (код) → `discoverTimeWindowIssue` |
| Выбор для Scenario | английские предложения из адаптера | `ScenarioIntakeIssue` (код) |
| Сырые коды на экране | `objectType.name`, статусы, id поверхностей, `typeId` точек, `profileId`, `difficultyId`, форма Route, id слота | select по стабильному значению; неизвестный код — нейтральный текст, не код |
| Сохранённые поиски | показывался английский заголовок и подзаголовок, записанные при сохранении | формат хранения не менялся; экран строит текст из сохранённого запроса |

Пользовательский контент в сообщения не передаётся: названия, имена,
заметки, id, языки, текст запроса показываются как есть рядом с
локализованной подписью («Equipment:», «Selected stop 2:»). Тест границы
дополнен только числами (минуты, часы, дни, возраст, позиции в списке).

Обоснованные исключения (`// l10n-ignore`): сообщения разработчика
(`ArgumentError`, `assert`), отладочный вывод, демо-названия объектов
подборки, legacy-поля сохранённого поиска, предзаполнение Create с карты и
домашнего экрана, названия городов рынка, названия категорий (G04),
стабильные id секций домашнего экрана (ключи виджетов). Парсер Smart Search
(`smart_search_parser.dart`) не трогался: он понимает английский и частично
русский, поэтому запросы-подсказки для lv отправляются по-английски
(открытый вопрос).

Время активностей старого формата без зоны объекта (слоты Activity, часть
локальных объектов Discover) показывается в зоне устройства, как и раньше.

Проверки: группы «L4.5: … in lv, en and ru at 360 dp» в
`search_page_test.dart` (результаты поиска) и
`discover_details_page_test.dart` (Details) — без переполнений при шрифте
×1/×2, интерфейсная строка на языке читателя. Зелёные тесты не подтверждают
качество перевода.

Найдено и исправлено: подпись «Читать далее» в Details переполнялась на 20
px на lv/ru при шрифте ×2 (теперь `Flexible`). Тесты рендереров Details,
написанные под прежний русский интерфейс, запускаются в локали ru (их
ожидания — прежняя русская копия; числа и деньги теперь по CLDR, например
`2,5 ч`, `40,00 €`, даты intl `12 сент. 2026 г.`). Тесты страниц без
делегатов локализации проверяют английский fallback. Семь golden-эталонов
Details (`object_offer_*_reference.png`) пересняты в ru: изменились формат
дат, денег и метка типа; все семь просмотрены вручную. При просмотре
найдены и исправлены: английские метки типа (PLACE, ACTIVITY, SESSION,
CLASS / WORKSHOP, FIND PEOPLE) в ru/lv, цена Class/Workshop в виде
`25 EUR` (теперь `RechargeFormats.minorUnits` с числом знаков валюты) и
день недели со строчной буквы в часах работы.

Inventory «только интерфейс»: 1 100 → 485 (53 файла); весь — 774. В Discover
(без парсера и мок-данных) — 0. Остаток — профиль, workspace страниц,
Quick Plan, избранное, посещённые места, уведомления.

## 17. v0.8 (L4.6): Identity, Profile, Scenario builder и прочее

Ветка `claude/l4-6-identity-profile`, база — итог L4.5. Workspace switcher,
Professional Page (workspace, публичная страница, редактор профиля,
приглашения в команду), Profile, Scenario library, Scenario builder
(legacy Quick Plan), избранное, посещённые места, входящие уведомления и
UI-привязка AI assist берут текст только через `context.l10n`
(398 новых ключей, lv/ru написаны агентом, не проверены носителем).

| Что | Было | Стало |
|---|---|---|
| Контроллеры Identity (workspace, приглашения, редактор профиля, публичная страница) | английские предложения в `message` | только коды (`workspace_switched`, `invitation_sent`, серверный код как есть …) → `identity*Notice` в презентации |
| Локальные уведомления Identity | английский заголовок и текст, собранные в контроллере | `templateCode` + `templateCount` в событии и модели (поля необязательны, старые записи читаются); заголовок и текст строит экран входящих; имя страницы — как есть |
| `ProfileRoleSummary` | английские заголовки, подзаголовки, действия | стабильные id (`creator`, `smart_prompts` …) → `profileRole*` |
| Оценка маршрута Scenario builder | английские предложения в state | `ScenarioFitLevel` + `ScenarioFitInsight(kind, minutes, price, distanceKm)` → `quickPlanFit*` |
| Избранное, посещённые места | русские сообщения ошибок в state | коды `favorites_load_failed` / `visits_load_failed` |
| Уведомление фоновой записи Route (Android) | английский текст | `lookupAppLocalizations` по языку приложения из `LocaleController` |
| Числа, деньги, расстояния, даты | `12 EUR`, `Under 20`, `2.3 km`, `May 4 · 10:00` (месяц зашит, зона устройства) | `RechargeFormats.money` / `decimal`, `discoverUnder`, `discoverDistanceKm`; дата созданного события — `RechargeFormats.dateTime` в зоне объекта (неизвестная зона → UTC с пометкой) |
| Сырые коды на экране | статусы публикации и приглашений Quick Plan (`pendingReview`, `pending`) | select по стабильному значению; неизвестный — нейтральный текст |
| Описания ключей ARB | — | экран и роль строки («Profile page — button label»), не цитата английского текста |

Роли и термины (Creator, Professional Page, Admin) в lv/ru пока оставлены
по-английски — до глоссария L4.7. Не переводятся: `recharge_taxonomy.dart`,
`recharge_category_criteria.dart`, `recharge_taxonomy_seed.dart` (G04),
сид уведомлений. `// l10n-ignore` с причиной: сообщения разработчика,
предзаполнение Create, текст запросов-подсказок для поиска, синонимы поиска
во входящих, промпты и заглушки AI assist, метаданные GPX и iCalendar,
бренд, названия городов рынка, стабильные id секций и полей.

**Inventory: эвристика была слабее, чем считалось.** Правило «Заглавное
слово + пробел + буква» пропускало одиночные слова (`'Venue'`), фразы с
«I», дефисом или скобкой (`'I have permission…'`, `'Read-only draft'`,
`'Purchase (e.g. …)'`), КАПС и строки, начинающиеся с числа
(`'${n} published items'`). v0.8 ужесточает правило для presentation-кода:
считается любой литерал со словом, кроме id, путей, MIME, URL, кодов
(`UTC`, `EUR`) и составных имён типов (`EventCapacityMode`); контрольные
примеры — в `unlocalized_ratchet_test.dart`. Тест не ослаблен: baseline
перестроен по более строгому правилу.

Итог: по прежнему правилу «только интерфейс» 492 → 0. По новому — 0 в
файлах L4.6 и 183 в 37 файлах вне L4.6: `features/create` 153 (подписи и
подсказки форм Place, Rental, Find People, Session, Event, Route,
Scenario, Class/Workshop), `features/discover` 30 (поиск, совместимый
рендерер Details). Это долг заходов L4.3–L4.5, который прежняя эвристика
не видела; ratchet запрещает его рост. Весь inventory — 512 (329 —
файлы-исключения).

Проверки: группы «… : lv/en/ru at 1x/2x 360 dp» (общий хелпер
`test/support/l10n/l10n_screen_harness.dart`, прокрутка до конца страницы)
в тестах workspace switcher, Profile, приглашений в команду, Scenario
builder, избранного и посещённых мест. Найдено и исправлено: карточка
избранного фиксированной высоты переполнялась при шрифте ×2 (теперь растёт),
заголовки Scenario builder и чипы условий переполнялись на 360 dp во всех
языках (теперь `Expanded`/`Flexible`). Зелёные тесты не подтверждают
качество перевода.

## 18. v0.9 (L4.7): подготовка языкового review (G06)

Тот же worktree, поверх L4.6. Сделано только то, что не требует
ревьюеров:

- [LOCALIZATION_GLOSSARY.md](LOCALIZATION_GLOSSARY.md) — 19 терминов с
  определением, предложением lv/ru и фактическим употреблением в ARB.
  Найдены расхождения: Creator («Creator» и «autors/автор»), Session (ru
  «сессия», «сеанс», «занятие»), Rental (ru «аренда» и «прокат»),
  Class/Workshop (ru «мастер-класс» и «воркшоп»), Collection (lv
  «kolekcija» — коллекция, ru «подборка» — выборка), unlisted
  («по ссылке» и «ссылка по приглашению»), Details, одна ru-строка с
  «Личный Scenario». ARB не правился: каждое расхождение ждёт решения
  ревьюера.
- `tool/l10n_export.dart <файл.csv>` — выгрузка всех 2 551 ключей: ключ,
  описание, плейсхолдеры, en, lv, ru, статус (`unreviewed`), файлы, где
  ключ используется. Пишет только вне репозитория. У 7 ключей нет
  использований в `lib/` (`commonLoading`, `commonSave`,
  `createScenarioPublicTransport`, `createScenarioOwnCar`,
  `discoverMapArea`, `discoverSmartSearchIdea`,
  `discoverMoodRechargeRoute`) — кандидаты на удаление после review.
- `tool/l10n_screenshots.dart <папка>` — PNG экранов на lv/en/ru, 360 dp,
  шрифт ×1 и ×2 (каждый экран прокручивается до конца). Снимки делают
  существующие 3-языковые виджет-тесты при
  `--dart-define=L10N_SHOTS_DIR`; без него ничего не пишется и ничего не
  сравнивается (это не golden). Для съёмки грузятся настоящие Roboto и
  Material Icons из Flutter SDK. Покрыты: настройки, Booking, импорт,
  входящие, формы Create, Collection, результаты поиска, Details, Profile,
  workspace switcher, приглашения в команду, Scenario builder, избранное,
  посещённые места. Нет 3-языкового теста, а значит и снимка: страница
  публикации и домашний экран Discover.

Статус review:

| Язык | Ревьюер (BCK20-OD-02) | Глоссарий | Строки | Скриншоты |
|---|---|---|---|---|
| lv | не назначен | не проверен | не проверены | не просмотрены |
| ru | не назначен | не проверен | не проверены | не просмотрены |

Правки переводов по итогам review — отдельным заходом и только с
ревьюерами. Зелёные тесты не подтверждают качество перевода.

## 19. v0.10: строки Create и Discover, которые не видела старая эвристика

Тот же worktree, поверх v0.9. Закрыт долг из §17: 183 → 0 по строгому
правилу inventory (весь inventory — 329, все в файлах-исключениях);
baseline пуст (`{}`), 137 новых ключей (lv/ru написаны агентом, не
проверены). Кроме литералов на экран выходили сырые значения, теперь они
проходят через select:

| Было на экране | Стало |
|---|---|
| Тип события, роль посетителя, состояние и актуальность доступности (очеловеченные wire names) | `createEventArchetype`, `createEventParticipationMode`, `createEventAvailabilityState`, `createEventAvailabilityFreshness`; контрольный тест `create_enum_labels_test.dart` |
| Причины дубля Place (`title match`) | `createPlaceDuplicateReason` |
| Тип объекта Collection, вид и профиль GPX | `createCollectionObjectType`, `createRouteGpxKind`, `createOption` |
| Статус проверки страницы и роль в команде (L4.6) | `identityVerificationStatus`, `identityRelationship` |
| Даты ISO (следующая дата Event, слоты Find People, подтверждение и блоки Rental) | `RechargeFormats.dateTime` в зоне объекта |
| Код ошибки в сообщении GPS (`… safely (code)`) | текст без кода |
| Числа `toStringAsFixed`, размер файла | `RechargeFormats.decimal`, единицы из ARB |

В ICU-парсере gen-l10n `date` зарезервировано как значение select, поэтому
у `createEventParticipationMode` значения с префиксом `mode_`.

Найдено тестами и исправлено: кнопка подтверждения зоны Session
переполнялась на lv/ru при шрифте ×2 (теперь `Flexible`).

Что осталось намеренно, с причиной:

- id полей и профилей критериев категории как подписи (`field.id`,
  `result.profile.id`) — словарь категорий, G04;
- редактируемые поля дат Find People и окон регистрации Event показывают и
  принимают ISO UTC: это формат ввода, не отображение;
- подпись цены Session `€ Fixed` содержит евро, как и прежняя логика формы;
- суммы Rental в младших единицах (`… minor`) показаны как есть, потому что
  форма так их и вводит;
- предзаполнение Create, запросы-подсказки поиска, название города рынка,
  бренд, примеры форматов (RRULE) — `// l10n-ignore` с причиной.

Зелёные тесты не подтверждают качество перевода.

## 20. v0.11 (L4.8, L4.9): предложения без изменений кода

Ветка `claude/l4-8-error-codes-proposal` от `5ee6308`. Только документы.

- [L4.8](LOCALIZATION_L4_8_ERROR_CODES_PROPOSAL.md): фактические коды отказов
  шести модулей, что из них доходит до экрана, варианты и заявка по
  `CONTRACT_CHANGE_TEMPLATE`. Ждёт решений D1–D8 владельца API-контрактов.
  Уточнение к L4-G09: английских предложений в этих модулях после L4.6 нет,
  экраны показывают общий текст; у Privacy intake нет ни callable, ни клиента.
- [L4.9](LOCALIZATION_L4_9_DECISION_REQUESTS.md): запросы решений 9.1–9.6
  (G01, G02, G03, G07, G04, G05). Ни одно решение не принято, подзаходы не начаты.

## 21. v0.12 (L4.8 этап B): контракт кодов отказов

Владелец одобрил вариант A
([предложение](LOCALIZATION_L4_8_ERROR_CODES_PROPOSAL.md) §8). L4-G09 закрыт для
шести модулей: Library, Quick Plan, Scenario, Route, Privacy intake, Identity
Session. Данные на проводе не менялись.

- Схемы отказов и фикстуры (valid, invalid, forward), enum в
  `identity_session_result`.
- Backend принимает только коды своего модуля на уровне типов; контрактный тест
  сравнивает их со схемами.
- 21 новый ключ (lv/ru написаны агентом, не проверены). «Нет» и «нет доступа»
  дают один текст `errorNotFound`, чтобы сообщение не раскрывало чужой объект.
- Экраны показывают текст каталога; незнакомый код даёт прежний текст экрана.
- Privacy intake покрыт контрактом и каталогом, на экран не выходит: callable и
  клиента нет.

Зелёные тесты не подтверждают качество перевода.

## 22. v0.13 (L4.9.1): канонические коды языков

Решения владельца по L4.9 записаны в
[LOCALIZATION_L4_9_DECISION_REQUESTS.md](LOCALIZATION_L4_9_DECISION_REQUESTS.md) §0.
Ветка `claude/l4-9-1-locale-ids` от `849411d`.

- `AppLocalePolicy.canonicalLocaleOf` и `canonicalTag` — единственное
  сопоставление; `notificationWireLocale` удалён, `LocaleController.apiLocale`.
- Тело Content на границе API (`canonicalContentBody`) называет `contentLocale`,
  `languages` и ключи `altText` канонически. Сохранённые черновики с `lv` не
  переписываются: сопоставление делается при каждой отправке.
- Backend принимает `lv-LV` и по-прежнему `lv`, для старых клиентов и сохранённых
  ревизий.
- Новые Professional Page хранят канонические коды; старые записи читаются как есть.
- Синтетические фикстуры: `en-LV` и `ru-LV` заменены на `en` и `ru`. Новая ревизия
  схемы market-capability не понадобилась: все рынки отключены, формат не менялся.
  `localeNormalizationProfileRevision` есть только в спецификации, в runtime его нет.
- Не менялось: `supportedServiceLanguages` (языки обслуживания, значения `lv` и
  `other`) — это не идентификатор локали API. Решить при необходимости отдельно.
- Известный край: запрос с `lv`, отправленный до обновления и повторённый после него
  с тем же ключом идемпотентности, сервер может счесть конфликтом.

`tool/l10n_export.dart --review <lv|ru>` готовит пакет ревьюера: ключ, контекст,
исходный текст, перевод, точная ревизия, колонки вердикта (Accept, Amend, Reject) и
замечаний. Ревьюеры не назначены, статус Pending.
