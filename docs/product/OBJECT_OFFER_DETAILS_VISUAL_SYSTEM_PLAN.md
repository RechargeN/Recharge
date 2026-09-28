# RECHARGE — Object / Offer Details Visual System: Plan

Версия: v0.3 (2026-09-05).
Статус: **Approved** (утверждён владельцем продукта — «реализуем по
этому плану»). Этапность зафиксирована в этом документе. Аудит завершён
2026-09-03; foundational visual implementation начата 2026-09-05.
Runtime effect текущей ревизии: Event, Place и Recharge Activity
переведены на общие Object/Offer presentation primitives и tokens без
изменения данных,
callbacks, источников данных или правил CTA. Для Place изменены только
визуальная композиция renderer и immersive-представление существующего
DetailsShell; тот же visual-only переход выполнен для Activity.
Маршрутизация и поведение действий не менялись.

Отношение к `DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md`: Event остаётся
первым эталоном (Этап 8 ниже), но эта визуальная система — более
широкий и главный документ для шести типов; расхождения логики
(Calendar/Organizer), зафиксированные в Execution Log DTL-EVT-01 как
«concurrent drift», подпадают под явное «не затрагиваем» этого плана и
под Этап 12, шаг 1 («очистить текущий Event-slice от изменений, не
относящихся к визуалу») — не решаются здесь и сейчас.

## 1. Границы задачи

**В scope (только визуал):** Place, Event, Recharge Activity,
Find People, Class/Workshop, Bookable Session.

**Вне scope:** Route Details; Scenario Details; Collection/Guide
Details; **Rental Details (отдельный формат, будущая отдельная спека)**;
бизнес-правила; доступность бронирования; авторизация и
capabilities; Save, Share, Calendar, Map, Add to Scenario; источники
данных и backend; правила формирования CTA. Существующие callbacks и
данные не меняются — определяется только то, как переданные данные
выглядят.

## 2. Аудит текущего состояния кода — завершён 2026-09-03

### 2.1 Фактическое покрытие шести типов

| Тип | Public read model / loader | Текущий Details | Статус новой visual system |
|---|---|---|---|
| Place | `DiscoverItemEntity` / общий Discover loader | отдельная visual-композиция внутри `ObjectOfferDetailsRenderer.discoverItem`, immersive shell | реализован визуальный эталон; логика сохранена |
| Event | `PublishedEventDiscoveryEntity` / typed Event loader | отдельная ветка `ObjectOfferDetailsRenderer.event`, immersive shell и Event-карточки | реализован первый визуальный эталон |
| Recharge Activity | `DiscoverItemEntity` / общий Discover loader | отдельная visual-композиция внутри `ObjectOfferDetailsRenderer.discoverItem`, immersive shell | реализован визуальный эталон; логика сохранена |
| Find People | отсутствуют Discover projection и loader | canonical route честно возвращает unavailable/not found | только будущий визуальный fixture; runtime вне этого slice |
| Class / Workshop | отсутствуют Discover projection и loader | canonical route честно возвращает unavailable/not found | только будущий визуальный fixture; runtime вне этого slice |
| Bookable Session | отсутствуют Discover projection и loader | canonical route честно возвращает unavailable/not found | только будущий визуальный fixture; runtime вне этого slice |
Следствие для visual-only scope: все шесть композиций можно определить и
проверить на presentation fixtures. Но подключение Find People,
Class/Workshop и Bookable Session к реальному маршруту требует отдельных
typed public projections/loaders и не входит в этот документ. Visual
слой не должен подменять отсутствующие read contracts generic-map моделью.

### 2.2 Что уже существует и сохраняется

- `DetailsRenderer` остаётся контрактом между shell и renderer.
- `DetailsShell` сохраняет владение app bar, hero-слотом, body и sticky
  action. Добавленный immersive mode сохраняется, но его Event-specific
  цвета должны стать общими Object/Offer-токенами.
- Публичные конструкторы и callback-сигнатуры существующих
  `ObjectOfferDetailsRenderer.discoverItem` и `.event` сохраняются на
  visual-only этапе. Legacy `.rental` временно остаётся технически на
  прежнем месте до отдельного Rental Details slice, но не входит в эту
  visual system.
- `EventDetailsPage`, `RentalDetailsPage`, resolver, router и providers
  остаются координаторами данных/действий; visual slice не меняет их
  поведение.
- Route, Scenario и Collection остаются отдельными renderer families и
  не затрагиваются.

### 2.3 Что перерабатывается визуально

| Файл | Решение |
|---|---|
| `apps/mobile/lib/features/discover/presentation/renderers/object_offer_details_renderer.dart` | оставить orchestration и существующие входы; заменить Event-private визуальную сборку на общие primitives и type composition |
| `apps/mobile/lib/features/discover/presentation/renderers/object_offer_section_matrix.dart` | расширить до явной visual-конфигурации шести типов; legacy Rental section order не считается частью этой матрицы и сохраняется только для обратной совместимости |
| `apps/mobile/lib/features/discover/presentation/shell/details_shell.dart` | сохранить immersive API; убрать зависимость общей геометрии от Event-named токенов |
| `packages/design_system/lib/src/recharge_theme.dart` | добавить общие `objectOffer*` токены и мигрировать Event-визуал с локальных/Event-only значений |
| `apps/mobile/test/features/discover/presentation/renderers/` | добавить общие visual fixtures, composition и adaptive/golden tests по шести типам |

Добавлен presentation-файл `object_offer_visual_primitives.dart` с
общей основой: content sheet, surface card, metrics strip, single-image
hero, type badge, hero action surface/button, utility-menu surface и
sticky action shell. Галерея, Details header, Publisher, Timeline и
Location будут обобщаться только после появления второго реального
потребителя с тем же контрактом. Файл не содержит eligibility,
navigation, persistence или вычисление CTA.

### 2.4 Что не трогаем в visual-only реализации

- `apps/mobile/lib/app/presentation/event_details_page.dart` — Save,
  Share, Calendar, Scenario intake, Map, analytics и CTA wiring;
- `apps/mobile/lib/features/discover/presentation/pages/rental_details_page.dart`
  — внешний handoff;
- `apps/mobile/lib/app/application/details_resolution_providers.dart` и
  `apps/mobile/lib/app/router/app_router.dart` — loader registration и
  маршрутизация;
- все `domain/`, `data/`, Create, Booking, auth/capability и backend
  файлы;
- Route/Scenario/Collection renderers и их тестовые эталоны.

### 2.5 Dirty-checkout guard

Рабочее дерево содержит много несвязанных пользовательских изменений.
Каждый кодовый этап обязан начинаться с узкого diff только по file map
выше; запрещены broad formatting, массовое восстановление файлов и
изменение соседних slices. До начала visual-кода Event-прототип
разделяется на «визуал сохранить» и «логику не изменять», без удаления
чужих или предшествующих изменений.

## 3. Общая анатомия экрана

Одна визуальная грамматика для всех шести типов (общий шаблон, не
обязательный одинаковый набор карточек):

1. immersive hero; 2. верхние действия; 3. маркер типа объекта;
4. перекрывающий hero основной лист; 5. заголовок и первичные факты;
6. строка ключевых метрик; 7. publisher/organizer/provider;
8. типоспецифичные карточки; 9. место или способ получения;
10. нижний отступ под CTA; 11. фиксированный sticky CTA.

## 4. Общие визуальные токены

Через design system, без локальных hex и случайных размеров: фон
экрана; фон карточек; основной и вторичный текст; акцентные цвета;
цвета статусов; радиусы листа/карточек/кнопок; границы; тени;
горизонтальные отступы; расстояния между секциями; высоты hero и CTA;
типографическая шкала; размеры и стиль иконок.

## 5. Библиотека визуальных блоков

Hero gallery; Type badge; Details header; Primary facts; Metrics strip;
Publisher card; Text section card; Timeline/schedule card; Attribute
list; Requirements card; Pricing card; Availability presentation;
Location card; Terms card; Status banner; Sticky CTA shell. Компоненты
отвечают только за отображение, не решают, можно ли выполнить действие.

## 6. Матрица состава по типам

- **Place:** факты о месте, часы, доступность, расходы, контакты,
  локация.
- **Event:** дата, место, метрики, организатор, описание, расписание,
  локация.
- **Recharge Activity:** формат, длительность, интенсивность,
  требования, инвентарь, место.
- **Find People:** цель, формат встречи, состав группы, требования,
  организатор, точка встречи.
- **Class/Workshop:** направление, уровень, формат, преподаватель,
  материалы, расписание, место.
- **Bookable Session:** услуга, длительность, формат, provider,
  представленная доступность, место.
Здесь определяется только порядок и внешний вид блоков — не правила,
по которым данные появляются.

Rental намеренно отсутствует в матрице: у него будет другой Details
формат. До утверждения отдельной спеки сохраняется прежний Rental layout.

## 7. Условное отображение секций

Для каждого блока: заполненное состояние; отсутствие данных (весь блок
скрывается или допустим компактный вариант); длинный текст; переданный
статус; одна фотография vs галерея. Visual system обрабатывает уже
переданное состояние, не вычисляет его.

## 8. Event как первый эталон

immersive hero; перекрывающий белый лист; иерархия заголовка;
компактные первичные факты; metrics strip; organizer; about; schedule;
location; sticky CTA. После утверждения — эталон визуального языка;
остальные типы получают свой состав карточек.

## 9. Макеты остальных пяти типов

Шесть конфигураций одного шаблона, не шесть независимых дизайнов:

```text
Object / Offer shell
        ↓
данные и тип объекта
        ↓
собственный порядок и набор визуальных секций
```

Сначала утверждается состав экранов, затем — перенос в Flutter.

## 10. Адаптивность

Референсный размер; 375 dp; 360 dp; масштаб текста 150%; длинные
заголовки/имена publisher/адреса; отсутствие изображения; одна и
несколько фотографий; safe area сверху/снизу; отсутствие overflow;
читаемость sticky CTA. Минимальная интерактивная зона — 44×44 dp.

## 11. Visual acceptance

На тип: эталонный экран; вариант без необязательных секций; вариант с
длинным контентом; вариант без hero-изображения; golden/screenshot
comparison; проверка 360dp/150%. Отдельно — подтвердить, что Route,
Scenario и Collection не задеты.

## 12. Порядок реализации

1. Очистить текущий Event-slice от изменений, не относящихся к
   визуалу.
2. Ввести общие токены и визуальные primitives.
3. Довести Event до утверждённого эталона.
4. Реализовать Place и Recharge Activity.
5. Реализовать Find People и Class/Workshop.
6. Реализовать Bookable Session.
7. Добавить visual tests и regression-проверки для шести типов.
8. Проверить analyzer, tests, boundaries и diff.
9. Только после отдельного согласования — переходить к логике
    действий.

## Стадия сейчас

**Этапы 1–2 завершены:** аудит/file map зафиксированы; добавлены общие
`objectOffer*` tokens; Event использует общие content sheet, card,
metrics strip, hero action surface и sticky action shell. Данные,
callback-логика, resolver и router не менялись.

**Этап 3 завершён:** Event откалиброван по структуре
референса (включая горизонтальный Schedule header при достаточной ширине
и адаптивный перенос), создан читаемый 430×932 golden с bundled Roboto и
Material Icons. Golden использует детерминированный hero fallback и
home-route без back button; media и shell navigation проверяются отдельно
и не маскируют геометрию контентных блоков.

**Этап 4 — Place и Recharge Activity завершены:** оба используют цепочку
hero → overlapping sheet → essentials → metrics → publisher → optional
cards → location → sticky CTA. Составы управляются отдельными
`placeProfileSections` и `activityProfileSections`. У Place зависят от
данных publisher, описание и часы; у Activity — organizer, описание /
highlights и переданные schedule slots. Полей intensity, requirements и
inventory в текущем `DiscoverItemEntity` нет, поэтому visual layer не
рисует вымышленные значения или пустые заглушки. Все прежние действия
сохранены: Save, Share, Add to Scenario, Search/Create similar, Route
actions, Mark visited, Map и CTA. Вторичные действия доступны через
Share-меню без изменения callbacks. Для обоих типов созданы 430×932
golden-эталоны.

Узкие проверки этапа: Activity + Place + Event + три golden + DetailsShell
widget tests — 45 passed, включая 360dp/150%. Отдельный
`discover_details_parity_test.dart` сейчас не компилируется из-за уже
существующих несвязанных рассинхронизаций Create/Identity
(`sessionData`, `moderationRepository`); visual slice эти файлы не меняет.
Targeted analyzer — 0 issues для mobile и design system; boundary —
0 violations, 71/71 существующих suppressions; diff/whitespace check —
чисто.

**Этап 5 — Find People и Class/Workshop завершены (presentation-only):**
добавлены типизированные, строго presentation-only
`FindPeopleVisualPreviewProps`/`ClassWorkshopVisualPreviewProps`
(`object_offer_visual_preview_props.dart`) — не domain/read-model, не
временный loader, не подключены к router/DI/providers. Новые
`.findPeoplePreview`/`.classWorkshopPreview` конструкторы
`ObjectOfferDetailsRenderer` используют те же shared primitives
(`ObjectOfferContentSheet`/`ObjectOfferCard`/`ObjectOfferMetricsStrip`/
`ObjectOfferSingleImageHero`/`ObjectOfferStickyActionShell`), что Event/
Place/Activity. Секции — `FindPeopleDetailsSection`/
`ClassWorkshopDetailsSection` в `object_offer_section_matrix.dart`, рядом
с Event/Place/Activity. Верхние действия — только Save+Share (без
utility-меню: у этих типов пока нет реального набора Discover-действий,
которые имело бы смысл туда класть). Оба типа получили собственный
спокойный accent (`findPeopleAccent`/`classWorkshopAccent` в
`RechargeTheme`) и honest-metrics поведение: строка метрик скрывается
целиком, если задано меньше двух значений — не вычисленный и не
выдуманный третий столбец. Каждая секция — presence-based: пусто в
props → секции нет, не пустая карточка. Добавлены 430×932 golden-эталоны
для обоих типов (`object_offer_find_people_reference.png`,
`object_offer_class_workshop_reference.png`) и 360dp/150% тесты
(обычная фикстура + фикстура с намеренно длинными title/organizer-или-
teacher/address — overflow не найден, оба типа переиспользуют уже
проверенные на Event/Place/Activity primitives).

Узкие проверки этапа: 59 passed (Activity/Place/Event/Find People/Class
Workshop widget-тесты + 5 golden + DetailsShell/DetailsShell
accessibility). Targeted analyzer — 0 issues (mobile + design system).
Boundary — 0 violations, 71/71 существующих suppressions, бюджет не
тронут. `git diff --check` — чисто (только CRLF-notices).

**Find People и Class/Workshop утверждены владельцем продукта** (визуальный
вердикт: «оба соответствуют общей системе Event/Place/Activity. Иерархия,
метрики, publisher, карточки, акценты и sticky CTA выглядят согласованно.
При этом набор секций действительно различается по типу.»).

**Этап 6 — Bookable Session завершён (presentation-only):** добавлен
типизированный, строго presentation-only `BookableSessionVisualPreviewProps`
(`object_offer_visual_preview_props.dart`) — не domain/read-model, не
временный loader, не подключён к router/DI/providers. Новый
`.bookableSessionPreview` конструктор `ObjectOfferDetailsRenderer`
использует те же shared primitives, что Event/Place/Activity/Find People/
Class Workshop. Секции — `BookableSessionDetailsSection` в
`object_offer_section_matrix.dart`: hero, header (услуга + формат), metrics
(цена + длительность), provider (переиспользует `_PreviewPublisherCard` с
подписью «Специалист»), about, availability («представленная доступность» —
уже принятый и отформатированный список слотов, переиспользует
`_PreviewBulletListCard`, ничего не вычисляется), location, sticky CTA.
Верхние действия — Save+Share, без utility-меню (как у Find People/Class
Workshop). Собственный спокойный accent —
`bookableSessionAccent`/`bookableSessionAccentSurface` в `RechargeTheme`.
Honest-metrics поведение сохранено (строка метрик скрывается целиком при
< 2 значений). Каждая секция presence-based. Добавлен 430×932 golden-эталон
(`object_offer_bookable_session_reference.png`) и 360dp/150% тесты (обычная
фикстура + фикстура с намеренно длинными title/provider/address — overflow
не найден, все использованные виджеты уже проверены на предыдущих типах).

Узкие проверки этапа: 65 passed (Activity/Place/Event/Find People/Class
Workshop/Bookable Session widget-тесты + 6 golden + DetailsShell/DetailsShell
accessibility). Targeted analyzer — 0 issues (mobile renderer/matrix/props
файлы + design system). Boundary — 0 violations, 71/71 существующих
suppressions, бюджет не тронут. `git diff --check` — чисто (только
CRLF-notices). Scoped `git status` подтверждает: тронуты только файлы этого
этапа, ничего постороннего.

**Bookable Session утверждён владельцем продукта.**

**Решение владельца продукта от 2026-09-05 — Rental исключён.** Rental
имеет другой Details-формат и больше не является седьмой конфигурацией
Object / Offer Details. Выполненная ранее пробная адаптация отменена:
`RentalDetailsPage` снова использует non-immersive shell, Rental hero,
карточки и CTA вернулись к прежней самостоятельной сборке; временные
`rentalAccent*`, Object/Offer Rental widget-test и golden удалены. Данные,
форматирующие функции, условия CTA и `PublishedRentalDiscoveryEntity` не
менялись. Legacy `.rental` constructor и `rentalDetailsSections` пока
остаются на прежнем техническом месте только для обратной совместимости;
их перенос в отдельный renderer family относится к будущей Rental Details
спеке, а не к этому visual-only slice.

**Этапы 7–8 — общая visual regression для шести типов.** В итоговую
матрицу входят Event, Place, Recharge Activity, Find People,
Class/Workshop и Bookable Session; для них сохраняются шесть 430×932
golden-эталонов. `.findPeoplePreview`, `.classWorkshopPreview` и
`.bookableSessionPreview` остаются presentation-only и не подключены к
router/DI/providers; Event/Place/Recharge Activity используют существующие
runtime данные и callbacks. Итоговый единый focused-прогон после исключения
Rental: **66/66 passed** (composition, callbacks, adaptive 360dp/150%, шесть
golden и `DetailsShell`). Существующий самостоятельный Rental Details
проверен отдельно: **3/3 passed**, включая неизменные условия CTA. Targeted
analyzer для изменённых mobile-файлов и `RechargeTheme` — **0 issues**;
boundary — **0 violations**, **71/71** существующих suppressions; scoped
`git diff --check` — чисто.

Предыдущий repo-wide baseline текущего dirty checkout остаётся внешним
блокером: `flutter analyze --no-pub` показывал 40 issues, а
`flutter test --no-pub` — 865 passed / 58 failed из-за незавершённых
Create/Identity API (`sessionData`, `actorUserId`, `moderationRepository`,
Place location-search API, `promoteRentalToPublished`). Эти файлы не входят
в visual slice и здесь не исправляются.
