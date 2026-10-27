# L4 — локализация Release R1 на lv / en / ru

- ID: **LOCALIZATION-L4**
- Версия: **0.2 (v0.1 + доработка пробелов G08–G10: валидация Create, Details, главная, сырые коды)**
- Дата: **2026-10-27**
- Статус: **Review — механизм, policy, контракты и миграция серверных R1-поверхностей; языковой review не проведён**
- База: `codex/recharge-integration` @ `01065f6` (L1–L3 + 01–36), ветка `claude/l4-localization`
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
| `apps/mobile/l10n.yaml`, `pubspec.yaml` (`flutter_localizations`, `intl` из SDK pin, `generate: true`) | конфигурация |
| `apps/mobile/lib/l10n/app_{en,lv,ru}.arb` | ресурсы (en — шаблон с описаниями) |
| `apps/mobile/lib/generated/l10n/*` | сгенерировано `flutter gen-l10n`, закоммичено; свежесть проверяет тест |
| `lib/core/localization/app_locale_policy.dart` | языки, разрешение, wire-mapping уведомлений |
| `lib/core/localization/locale_preference_store.dart`, `locale_controller.dart`, `locale_providers.dart` | хранение и владелец выбора |
| `lib/core/localization/l10n_context.dart` | `context.l10n` с детерминированным fallback |
| `lib/core/localization/user_message_catalog.dart` | stable code → текст |
| `lib/core/localization/recharge_formats.dart` | деньги, числа, даты в зоне объекта |
| `lib/app/app.dart`, `bootstrap.dart`, `main.dart`, `di/service_locator.dart`, `di/notifications_inbox_composition.dart` | подключение |
| мигрированные экраны (§2) | замена строк, typed сообщения |
| `tool/l10n_inventory.dart`, `test/fixtures/l10n/unlocalized_baseline.json` | inventory и ratchet |

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
  диагностики, на экран не выводится.
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
| L4-G01 | Идентификаторы locale расходятся: UI `lv/en/ru`; уведомления `lv-LV/en/ru`; синтетическая market-capability фикстура `lv-LV/en-LV/ru-LV`; roadmap `lv-LV/en/ru`. Сопоставление есть только в адаптере уведомлений | канонизация по BCK-20 OD-10 (profile revision) |
| L4-G02 | Нет серверного языка аккаунта; выбор только на устройстве. Нет offline-каналов (push/e-mail), где язык нужен при доставке | продуктовая policy + BCK-06/BCK-13 контракт |
| L4-G03 | `{deadline}` в уведомлении рендерится в `Europe/Riga`, а не в зоне occurrence | новая ревизия шаблона/переменная зоны до не-Riga событий и EE/LT |
| L4-G04 | Названия Category System (28/530) без переводов: датасет содержит только ids | источник переводов (BCK20-OD-02/06) |
| L4-G05 | Тексты Privacy/Terms/Support — обязательная локальная копия; локализованы только названия ссылок | Legal/mandatory-copy manifest (BCK20-OD-05) |
| L4-G06 | Языковой review lv/ru не проведён | Product Localization owner/носители, BCK20-OD-02 |
| L4-G07 | Legacy `explore_settings.language` (по аккаунту, `ru`) и выбор валюты EUR/USD в Settings — mock без эффекта; валюта по-прежнему из данных | продуктовое решение об удалении |
| L4-G08 | Частично закрыт в v0.2 (валидация Create, Details, главная). Осталось ≈ 2 827 литералов в 183 файлах (эвристика): `features/create` 1 521 (тексты форм), `features/discover` 763 (поиск, карта, рендеры; часть — mock-данные и ключевые слова парсера), `identity` 117, `scenarios` 111, `explore` 100 (Profile), `app/presentation` 34 (Scenario intake), `auth` 23 (маркетинговые шаблоны главной; заголовки секций служат ключами виджетов), прочее ≤ 28 | следующие срезы; ratchet запрещает рост |
| L4-G09 | Аудит v0.2: сырых кодов на экранах больше нет (guard-тест). Открыто: Library, Quick Plan, Route/Scenario sync, Privacy intake и Identity Session не перечисляют коды в схемах, поэтому контракт «схема ↔ каталог» для них невозможен; их UI показывает английские предложения, учтённые в inventory | перечислить коды в схемах (владельцы модулей), затем добавить семейства в каталог |
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
