# RECHARGE — Collection / Guide Create Block Spec

Версия: v1.0 (2026-08-20). **Статус: Approved.** Владелец продукта ответил на
все 20 открытых вопросов 2026-08-20; решения и куда каждое из них попало в
тексте — таблица в §20. Документ разрешён как Approved slice spec по правилу
«Create Hub» из
[AGENTS.md](../../AGENTS.md) (разрешённый конфликт №4: реализация блоков для
уже утверждённых 10 типов Create Hub — это завершение принятого scope, а не
новая фича). Документ является канонической спецификацией CLG-CRT-01;
физический runtime ещё не начат и не считается реализованным.

> **v1.0 — канонизация после owner review и contradiction audit.** Все 20
> решений владельца из v0.3 сохранены без пересмотра. Устранены блокеры
> реализации: mini-map geo удалён из сохраняемого fallback snapshot и
> приходит только из live public projection через общий `GeoPoint`; публичная
> Collection read-модель закреплена за Discover, а не за Create; файловый план
> дополнен publication/resolution adapters, Discover Search/Details, DI,
> capability fixtures и тестами; removal-only self-service оформлен как
> отдельная доказуемая команда над active version; self-promotion проверяется
> по типизированному `PublisherRef`; определены Unicode length, budget
> suggestion, unavailable acknowledgement, undo/redo, migration, rollback и
> kill switches. CLG-CRT-01 разрешено начинать только в полном bounded scope
> этой v1.0 и завершать лишь после всех gates §17–19.
>
> **v0.3 — решения владельца перенесены в текст.** `CollectionCatalogObjectType`
> в CLG-CRT-01 сужен с 8 до 5 устойчивых listing-типов — Place, Route,
> Bookable Session, Class/Workshop, Rental; Event,
> Recharge Activity и Find People отложены до CLG-CRT-0x (§9, §14, Вопрос 20).
> Details получает мини-карту live-резолвленных public map points (§13, §14,
> Вопрос 13). Добавлены три
> конкретных числовых лимита: soft-warning при ≥50% пунктов от publisher
> самого автора (§11, Вопрос 3), soft-warning с 31-го пункта (§11, Вопрос 5),
> максимум 300 символов у `curatorNote` (§9, Вопрос 7). Асимметричная
> модерация (удаление — self-service, добавление — под review) стала твёрдым
> решением, не предложением (§3.11, §12, Вопрос 19). `publish.collection.direct`
> подтверждена как отдельная per-type capability, не наследуемая от других
> типов (§6, Вопрос 14). CLG-CRT-02 передвинут из «отдельный gated slice
> когда-нибудь» в «сразу после CLG-CRT-01» (§16, Вопрос 15).
> `CollectionCuratorNotesSection` добавлена в реестр секций
> [VISION.md](VISION.md) (Вопрос 17). §20 «Открытые вопросы» снят — вопросов
> больше нет, раздел заменён итоговым списком решений.
>
> *v0.2 — самопроверка логики перед передачей владельцу* нашла и исправила:
> батчинг live-резолвинга вместо N+1 чтения по одному пункту (§10, §14);
> противоречие между «нет map pin» как будто решённым фактом и тем же
> вопросом в открытых вопросах; нестыковку `excludeRefs` с уже невозможным по
> типам самоссыланием; отсутствие ответа на риск, который сам документ
> называет в §2 («подборка быстро устаревает»); опечатку в §3.4;
> противоречивую формулировку про `highlight` в §7.

Источник задачи: тип **Collection / Guide** утверждён в целевой десятке Create
Hub в [VISION.md:358](VISION.md), секция `ItemsPickerSection` анонсирована
там же ([VISION.md:323](VISION.md)) как переиспользуемая типо-специфичная
секция form engine. Отдельной спецификации блока не существовало — это
первый документ, который её вводит. Проверено по коду: `CreateObjectType.collection`
и запись в `rechargeCreateBlockConfigs` уже существуют
([create_draft_entity.dart](../../apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart),
[create_taxonomy.dart](../../apps/mobile/lib/features/create/application/create_taxonomy.dart)),
но `collectionData`, `CollectionDraftData`, `ItemsPickerSection` и любой Create-код
блока отсутствуют — таксономия готова принять тип, сам блок не реализован.

Ближайший архитектурный прецедент внутри репозитория — механизм добавления
существующих каталожных объектов в черновик, уже принятый и реализованный для
Scenario: [SCENARIO_OBJECT_INTAKE_SLICE_SPEC.md](SCENARIO_OBJECT_INTAKE_SLICE_SPEC.md)
(`ScenarioObjectRef`, `ScenarioIntakeCandidate`, typed outcomes, revision-safe
Apply). Этот документ переиспользует те же принципы (id-only связи, снапшот +
live resolution, явные duplicate/unavailable guard), но не копирует контракт
дословно — Collection проще Scenario: нет расписания, логистики и дней.

## Краткое резюме

- **Что это.** Десятый, последний нераскрытый Create-тип из уже утверждённой
  таксономии — курируемый список ссылок на существующие опубликованные
  объекты Recharge. В CLG-CRT-01 — пять устойчивых listing-типов: Place, Route,
  Bookable Session, Class/Workshop, Rental. Не новый контейнер данных, а
  авторская витрина поверх уже существующего каталога.
- **Референс.** GetYourGuide travel guides / curated lists: тематические
  секции городской страницы, карточка активности с фото/ценой, переход на
  реальную бронируемую позицию, а не на текст. Разбор и перенос — §2.
- **Путь создания — 5 шагов.** Основное + медиа → Состав (`ItemsPickerSection`,
  поиск и добавление объектов) → Заметки куратора → Бюджет и publisher →
  Превью и публикация. Подробно — §7.
- **Что уже готово в коде, что нет.** `CreateObjectType.collection` и запись
  в `rechargeCreateBlockConfigs` уже существуют; сам блок — domain,
  application, presentation, `ItemsPickerSection` — не реализован вообще.
- **Объём этого slice, CLG-CRT-01.** Локальный/mock, без backend и реальной
  модерации — тот же стабилизационный периметр, что у остальных девяти
  Create-блоков. Cross-surface «Add to Collection» (CLG-CRT-02) — следующий
  slice сразу за CLG-CRT-01, не отложенный. План этапов — §16.
- **Статус.** v1.0 Approved 2026-08-20. Все 20 вопросов владельцу отвечены;
  runtime CLG-CRT-01 физически не начат — таблица решений в §20, статус и
  доказательства реализации после начала slice ведутся в `LAUNCH_STATUS.md`.

## Оглавление

§1 Результат · §2 Продуктовый ориентир: GetYourGuide · §3 Зафиксированные
решения · §4 Термины · §5 Границы slice · §6 Доступ и capabilities · §7
Пользовательский поток · §8 Состояние и команды coordinator · §9 Домен и
хранение · §10 Item picker и работа с каталогом · §11 Валидация и
деградация · §12 Публикация и bundle · §13 Discover-интеграция · §14
Repository и use case boundaries · §15 План файлов реализации · §16 Этапы
реализации и gates · §17 Тестовая матрица · §18 Acceptance criteria · §19
Definition of Done · §20 Решения владельца

---

## §1. Результат

Уполномоченный автор получает в Create Hub блок Collection / Guide и может:

1. создать черновик подборки от имени пользователя или закреплённой страницы;
2. описать тему подборки (название, питч, обложка, область/город);
3. найти и добавить в неё существующие опубликованные объекты каталога —
   Place, Route, Bookable Session, Class/Workshop, Rental — через
   `ItemsPickerSection` (почему именно эти пять типов в CLG-CRT-01, а не все
   девять родственных Create-типов — §9, §14);
4. сгруппировать пункты по темам («Top sights», «Hidden gems», «С детьми») —
   опционально, без группировки все пункты идут одним списком;
5. написать короткую авторскую заметку к каждому пункту — почему он в
   подборке — и отметить избранные пункты как «featured»;
6. увидеть preview подборки в том виде, в котором её увидит читатель;
7. опубликовать подборку без ограничения на количество пунктов (`без лимита`
   по VISION.md), с минимальным порогом качества (см. §11).

Читатель не видит редактор. Он получает Collection как карточку в Search/Feed
и как страницу Details со списком живых, актуальных на момент открытия
пунктов и мини-картой с их местоположением — а не замороженный на момент
создания снимок (ключевое продуктовое отличие Collection от Scenario, см. §2
и §13).

## §2. Продуктовый ориентир: GetYourGuide и перенос на Recharge

Пользователь задачи явно указал GetYourGuide как ближайший реализованный
аналог. Это подтверждается публичной структурой их продукта (travel guides и
тематические подборки на страницах направлений):

- город открывается через набор тематических секций — «Top things to do»,
  «Nature & adventure», «Food & drinks», «Day trips», «Uniquely [City]» —
  каждая секция содержит карточки конкретных активностей;
- карточка внутри секции показывает фото, заголовок, длительность, рейтинг и
  цену «от»;
- отдельно существует секция travel inspiration/curated lists — редакционные
  подборки, объединяющие активности по теме (культура, еда, природа, спорт),
  каждая ведёт на реальные бронируемые позиции каталога, а не на внешние
  описания;
- рейтинг и отзывы, привязанные к самой активности, показываются и внутри
  подборки — подборка не дублирует контент, а курирует ссылки на него.

Перенос на Recharge (таблица решений):

| GetYourGuide | Recharge Collection / Guide |
|---|---|
| Тематические секции на странице города | Опциональные секции внутри Collection (`sections`), группировка по теме |
| Карточка активности: фото, длительность, рейтинг, цена «от» | `CollectionItemDraft.snapshot`: обложка, заголовок, тип, индикатор цены — тот же паттерн карточки, что у объекта в Search |
| Curated list ссылается на реальные бронируемые позиции | Item — это `id`-ссылка на существующий опубликованный объект Recharge, не внешний URL и не свободный текст (см. §5, инвариант из AGENTS.md о связях только по id) |
| Editorial narrative вокруг подборки | Общее описание Collection (`NameDescription`) + короткая авторская заметка к каждому пункту (`curatorNote`) |
| Cross-links: активность видна и в общей выдаче, и в подборке | Объект в Collection продолжает жить своей обычной карточкой в Search/Feed/Map; Collection не «отбирает» его, а добавляет второй способ его найти |
| Rating/price показываются актуальными на момент просмотра | Collection Details резолвит пункты **на момент открытия**, а не хранит замороженные цифры (иначе подборка быстро устаревает и подрывает доверие — ключевой риск редакционных списков) |

Главное продуктовое решение, вытекающее из этого анализа: Collection — это
**курируемая витрина существующего каталога**, а не контейнер новых данных.
Она не создаёт параллельную копию Place/Event/Route; она добавляет ручную,
авторскую точку входа к уже существующим объектам, ровно как это делает
GetYourGuide guide-страница по отношению к своим bookable activities.

Что сознательно не переносится:
- рейтинги/отзывы у самой Collection — Review для Create-объектов пока не в
  MVP репозитория (VISION.md, статус «Отзывы»), Collection не опережает это;
- бронирование внутри подборки — GetYourGuide продаёт билет прямо со страницы
  guide; Recharge Booking — MVP-redirect на `externalBookingUrl`, и это
  поведение уже есть на уровне самого объекта (Event/Session), Collection не
  добавляет второй checkout;
- SEO-контентная редакция силами платформы — GetYourGuide travel guides часто
  пишет штатная редакция; в Recharge автор Collection — обычный verified
  Creator, без отдельной редакционной роли.

Риск, отмеченный выше («подборка быстро устаревает и подрывает доверие»), не
закрывается одним только live-резолвингом на Details — живые данные показывают
актуальную карточку конкретного пункта, но не говорят читателю, *когда автор
последний раз действительно пересматривал состав*. Список из 10 пунктов, где
7 стали `unavailable`, живым резолвингом не спасти. Общий `updatedAtUtc` для
этого непригоден: он меняется и при правке обложки или текста и не доказывает,
что автор видел актуальный состав. Поэтому preview фиксирует типизированный
`CollectionCompositionReview` для точной revision: `reviewedAtUtc`,
`draftRevision` и набор подтверждённых unavailable refs (§9). Любая мутация
состава инвалидирует review. Опубликованная проекция показывает «состав
проверен» по `reviewedAtUtc`; доля `unavailable` в active version остаётся
сигналом автору о новой ревизии, а не публичной оценкой качества (§3.10, §13).

## §3. Зафиксированные решения

Эти пункты — инвариант блока (по аналогии с §2
`ROUTE_CREATE_BLOCK_SLICE_SPEC.md`), принятый владельцем 2026-08-20, не
предмет пересмотра по ходу реализации CLG-CRT-01:

1. Collection / Guide — подборка ссылок на существующие опубликованные
   объекты Recharge с авторской курацией (заметка, порядок, опциональная
   группировка). Она не является источником собственных бронируемых
   сущностей и не дублирует их данные как источник истины.
2. Пункт подборки хранит связь только по `{objectId, objectType}` (ADR-
   инвариант id-only связей). Свободный текст, внешние URL и ad hoc места без
   id не допускаются как элементы v1 — это предотвращает появление
   неуправляемого второго источника данных о месте/событии. Добавление чужого
   опубликованного объекта в Collection не требует согласия или уведомления
   его автора (implicit consent, Вопрос 2) — публикация в общем каталоге уже
   подразумевает, что объект можно легитимно курировать и цитировать, как и в
   обычном Search; notify-инфраструктура для CLG-CRT-02 не входит в этот slice.
3. Создание доступно `Creator` или `Admin` с `create.collection`, на общих
   основаниях — без более высокого барьера входа, чем у остальных 9 типов
   (Вопрос 1). Права разделены так же, как у Route: `create.collection`,
   `submit.collection`, `publish.collection.direct`, `moderate.collection`,
   `manage.collection`, `archive.collection`. Наличие одного права не
   подразумевает остальные — в частности, `publish.collection.direct` не
   наследуется от direct-publish доверия других типов (Event, Place и т.д.):
   это отдельная per-type capability, и первая Collection любого автора
   всегда проходит `submit`/`moderate`, пока владелец страницы не получит
   именно её (Вопрос 14, детали процесса — §6).
4. Автор указывается каноническим `PublisherRef {type: user | page, id}`;
   публикация от чужого имени требует Publisher/ManagedPage capability
   enforcement (см. IDP-слайсы). Снимок пункта также хранит типизированный
   `PublisherRef?`, а не неоднозначный `publisherId`.
5. Данные пункта в Collection показываются **live** на Details (текущие
   заголовок/обложка/цена/статус и разрешённая источником public map point),
   а не замороженным снимком.
   Кэшированный снимок используется только для быстрого рендера карточки
   Collection в списках и обязан обновляться best-effort, не считаться
   источником истины. Geo не сохраняется в snapshot и никогда не показывается
   из fallback: отзыв или изменение public location должен действовать при
   следующем live read без утечки старой координаты.
6. Если объект внутри подборки снят с публикации, удалён или потерял доступ
   — он не показывается публичному читателю, но остаётся видимым автору в
   редакторе с явным предупреждением «больше недоступен» и не удаляется
   молча из данных подборки (recoverable state, не destructive auto-cleanup).
7. Collection не может содержать саму себя, другую Collection или Scenario в
   v1 (см. §5) — это устраняет циклы и логистическую сложность, не относящуюся
   к назначению блока.
8. `без лимита` из VISION.md означает отсутствие верхнего предела количества
   пунктов, а не отсутствие минимального порога качества публикации (см. §11).
9. Все лимиты, разрешённые типы объектов, budget policy, feature flags и
   наборы категорий приходят из
   конфигурации блока (`collection_create_config.dart`, см. §15), не
   зашиваются в UI — тот же принцип, что и у Route (решение №12 в
   [ROUTE_CREATE_BLOCK_SLICE_SPEC.md](ROUTE_CREATE_BLOCK_SLICE_SPEC.md),
   далее по документу — «RCB»).
10. Минимальный порог пунктов (§11) — это **publish-time gate**, не
    постоянно поддерживаемый инвариант. Объекты внутри уже опубликованной
    Collection могут естественно стать `unavailable` со временем (см. §2);
    Collection не снимается с публикации автоматически и не требует
    повторной проверки только из-за естественного decay — но автор получает
    в редакторе явный сигнал «Х из Y пунктов больше недоступны», а не только
    молчаливо более короткий публичный список.
11. Изменение уже опубликованной версии асимметрично (Вопрос 19, финальное
    решение). **Удаление** пункта — отдельная removal-only команда с
    `baseVersionId`, expected revision/hash, `manage.collection`, точным
    publisher access и audit. Доверенный reducer сам строит новую active
    версию как подмножество прежней и отклоняет любую одновременную правку
    текста, порядка, секций, highlight, media, visibility или publisher.
    Поэтому операция не требует `submit`/`moderate`. Архивирование — отдельная
    lifecycle-команда с `archive.collection`, не разновидность removal bundle.
    **Добавление** или любая representational-правка продолжает требовать
    новую проверенную версию для автора без `publish.collection.direct`.
12. `CollectionCatalogObjectType` в CLG-CRT-01 ограничен пятью устойчивыми
    listing-типами — Place, Route, Bookable Session, Class/Workshop, Rental
    (Вопрос 20, финальное решение). Event, Recharge Activity и Find People по
    своей природе time-bound (одноразовое occurrence проходит, набор
    участников закрывается) — смешивать их с устойчивыми listing-типами в
    первой версии увеличивает риск decay из §2; они входят отдельным
    CLG-CRT-0x после того, как появится способ показать «предстоящие даты»
    внутри карточки пункта вместо бинарного ready/unavailable. Детали — §9,
    §14.
13. Published read projection принадлежит `features/discover`, как уже
    принятый `PublishedRouteDiscoveryPort`. Create строит immutable publication
    bundle и пишет через порт; Search/Feed/Details не импортируют Create domain.
    Collection отсутствует на основной карте и не получает фиктивную точку.

## §4. Термины

- **Collection** — опубликованная неизменяемая версия подборки (по аналогии
  с `RouteVersion`), содержащая ordered items, sections, авторские заметки.
- **CollectionDraftData** — типизированные данные блока внутри
  `CreateDraftEntity.collectionData`.
- **CollectionItemDraft** — один пункт подборки: ссылка на объект + безопасный
  fallback-снимок без geo + заметка куратора.
- **CollectionSectionDraft** — опциональная тематическая группа пунктов
  внутри подборки (аналог секций «Top sights» у GetYourGuide).
- **ItemsPickerSection** — типо-специфичная секция form engine, отвечающая за
  поиск, добавление, группировку и переупорядочивание пунктов. Название
  зафиксировано в VISION.md:323.
- **curatorNote** — короткая авторская заметка к пункту («почему это здесь»).
- **sourceStatus** — состояние ссылки на объект: `ready`, `stale`,
  `unavailable` (переиспользует терминологию `ScenarioSourceStatus`).
- **CollectionCompositionReview** — подтверждение, что автор просмотрел
  live-resolved состав конкретной revision и осознанно принял unavailable
  пункты; инвалидируется любой мутацией состава.
- **PublishedCollectionDiscoveryEntity** — active read projection для
  Search/Feed/Details, которой владеет Discover; не authoring draft и не
  источник истины для исходных объектов.

## §5. Границы slice

### Входит (CLG-CRT-01)

- типизированные Collection-данные в общем `CreateDraftEntity`;
- декларативная конфигурация шагов Collection в едином form engine;
- `ItemsPickerSection`: поиск по каталогу опубликованных объектов, добавление,
  удаление, переупорядочивание, опциональная группировка по секциям;
- заметка куратора и флаг «featured» на уровне пункта;
- application coordinator и use cases черновика;
- capability-guards на вход, сохранение, публикацию и управление;
- autosave, восстановление черновика, bounded undo/redo для операций со
  списком и секциями;
- provider-neutral интерфейс поиска по каталогу и детерминированный mock-
  адаптер для разработки/тестов (переиспользует существующий Discover/Search
  read-контракт, не создаёт параллельный индекс);
- валидация, preview, публикационный bundle и поисковая проекция;
- live-резолвинг пунктов на Details с деградацией при недоступности объекта;
  public geo для mini-map приходит только из текущей source projection и не
  сохраняется в fallback snapshot (Вопрос 13, §13, §14);
- локальная immutable publication store + Discover read projection,
  Search/Feed card, Details list и mini-map без основной map pin;
- миграция schema, feature flags и recoverable rollback из §15;
- тесты domain, application, data, widget и end-to-end.

### Не входит без отдельного разрешающего gate

- добавление объекта в Collection **из** Details/Search/Map («Add to
  Collection» по аналогии с SCN-INTAKE) — переиспользуемый паттерн, но
  отдельный CLG-CRT-02 slice (см. §16); приоритизирован сразу за CLG-CRT-01
  (Вопрос 15), но остаётся отдельным intent-контрактом со своим capability и
  UX-поверхностями, не входит в этот slice;
- Event, Recharge Activity и Find People как допустимые типы пункта —
  отложены до отдельного CLG-CRT-0x (Вопрос 20, §3.12, §9, §14);
- вложенные Collection, ссылки на Scenario или Quick Plan внутри Collection;
- собственные рейтинги/отзывы Collection;
- редакционные/платформенные подборки (курируемые не автором-Creator, а
  Admin/редакцией) — это другая продуктовая роль, не описанная текущими ADR;
- Firebase, production backend, реальная модерация — используются mock-
  адаптеры и локальное состояние, как у всех текущих Create-блоков;
- монетизация показа подборки (платное продвижение, спонсорские слоты).

## §6. Доступ и capabilities

| Операция | Обязательная capability | Дополнительная проверка |
|---|---|---|
| открыть новый Collection | `create.collection` | авторизованная сессия |
| сохранить свой черновик | `create.collection` | ownership publisher |
| отправить на проверку | `submit.collection` | readiness и publisher access |
| опубликовать без проверки | `publish.collection.direct` | trusted capability, readiness |
| принять/отклонить версию | `moderate.collection` | sealed request, reason code при отказе |
| изменить опубликованную версию | `manage.collection` | доступ к исходному Collection |
| архивировать | `archive.collection` | доступ к publisher |

Guard работает на тех же трёх уровнях, что и у Route (§4 RCB): router не
открывает блок без capability, application перепроверяет право перед каждой
мутацией и публикацией, backend остаётся окончательной точкой авторизации
после подключения. Публикация от имени страницы работает только после
Publisher/ManagedPage capability enforcement (тот же прочерченный статус, что
у остальных типов). `publish.collection.direct` — независимая per-type
capability, не унаследованная от direct-publish доверия других типов; первая
Collection любого автора всегда проходит `submit`+`moderate` (Вопрос 14,
обоснование — §3.3).

## §7. Пользовательский поток

Пять шагов — тот же счёт и ритм, что заявлен для Event в VISION.md, чтобы
блок не выглядел исключением на фоне остальных девяти типов. «Шаг 0» ниже —
служебный guard входа, он не входит в счёт «пять шагов» (та же условность,
что и у Route: см. «Шаг 0 — Вход» в `ROUTE_CREATE_BLOCK_SLICE_SPEC.md`).

### Шаг 0 — Вход и guard

Create Hub показывает Collection / Guide только при `create.collection`.
После выбора типа проверяются сессия, capability, выбранный publisher и
market. При отказе черновик не создаётся, показывается понятная причина.

### Шаг 1 — Основное + медиа

Общие секции form engine: `NameDescription` (название, короткий питч, полное
описание, категория/подкатегория — по умолчанию `travel_tours /
hidden_gems_tour` из `CreateBlockConfig`), `Media` (обложка + галерея),
`Location` в упрощённом виде — `Area` (свободный текстовый регион/город, не
точный pin; Collection описывает область, а не физическую точку — этим она
явно отличается от Place).

### Шаг 2 — Состав (`ItemsPickerSection`)

Ядро блока. Автор:

- ищет среди пяти допустимых в CLG-CRT-01 типов — Place, Route, Bookable
  Session, Class/Workshop, Rental (§3.12) — по названию, категории и area
  внутри уже опубликованного каталога Recharge (read-only переиспользование
  существующего поискового индекса, без нового источника данных); объекты из
  той же `areaLabel`, что и сама Collection, получают мягкий приоритет в
  выдаче — не единственные результаты, а поднятые выше (Вопрос 10);
- добавляет один или несколько объектов за раз;
- по умолчанию все пункты идут в один неявный список; опционально создаёт
  именованные секции («Top sights», «Hidden gems») и распределяет пункты
  между ними;
- переупорядочивает пункты и секции drag-and-drop;
- удаляет пункт (не удаляет исходный объект — только связь).

Дубликат `{objectId, objectType}` внутри одной Collection запрещён на уровне
команды `addItem` (та же идемпотентность, что у Scenario intake, §13.1
`SCENARIO_OBJECT_INTAKE_SLICE_SPEC.md`). Сама Collection и любая другая
Collection/Scenario недоступны как объект для добавления (см. §3.7).

### Шаг 3 — Заметки куратора (`CollectionCuratorNotesSection`)

Отдельная типо-специфичная секция form engine (вторая новая секция блока,
наравне с `ItemsPickerSection`, см. §15; уже добавлена в реестр секций
[VISION.md](VISION.md)).
Для каждого добавленного пункта — отдельный компактный редактор:

- `curatorNote` — короткая авторская заметка, максимум **300 Unicode grapheme
  clusters** (пользовательских символов, не UTF-16 code units; Вопрос 7),
  значение приходит из `collection_create_config.dart`, не зашито в UI;
- `highlight` — переключатель «featured». В отличие от прочтения GetYourGuide
  в §2, где «Top sights» — это отдельная секция, а не флаг на карточке,
  здесь `highlight` — независимый флаг на каждом пункте без ограничения
  количества; сколько пунктов пометить — решает автор, технического лимита
  нет;
- быстрый переход между пунктами без возврата на шаг 2, live-счётчик
  заполненных заметок как soft-подсказка качества (не блокирует публикацию).

### Шаг 4 — Бюджет и публикатор

Секция `Pricing` в урезанном для Collection виде — не транзакционная цена, а
**индикатор бюджета** (`Free / $ / $$ / $$$`), выставляемый автором вручную
или предложенный детерминированной `CollectionBudgetSuggestionPolicy`.
Suggestion использует медиану `priceFromMinorUnits` только у ready-пунктов с
normative price в валюте market, требует не менее двух цен и покрытия не ниже
`budgetSuggestionMinPriceCoverage` (50% пунктов), затем применяет пороги
`MarketBudgetTierConfig`; mixed/unknown currency не конвертируется и не даёт
suggestion. Подсказка никогда не записывает поле без явного выбора автора и
не перезаписывает manual tier после изменения состава. Мультивалютное
агрегирование не входит в CLG-CRT-01. Publisher, market и visibility
(`public / unlisted`) — как у остальных типов; размещение выбора publisher
рядом с последними шагами, а не в начале, совпадает с уже принятым паттерном
Find People (`hosts`-шаг «Publisher, visibility, communication, and sharing»
идёт пятым из шести, а не первым) — Collection не вводит новый порядок.

### Шаг 5 — Превью и публикация

Preview показывает Collection ровно в том виде, в каком её увидит читатель:
секции, карточки пунктов с live-данными (или явным «недоступно» для
проблемных), заметки куратора, счётчик пунктов и мини-карту с pin всех
резолвленных пунктов (§13, Вопрос 13). Блокирующие ошибки отделены
от предупреждений (см. §11). После успешного live resolve автор подтверждает
preview; coordinator записывает `CollectionCompositionReview` для текущей
revision и точного набора unavailable refs. Любая последующая мутация
items/sections инвалидирует это подтверждение. После повторной проверки
capability публикация формирует bundle (§12); для профиля без
`publish.collection.direct` версия уходит на модерацию, прежняя active-версия
остаётся видимой до решения.

## §8. Состояние и команды coordinator

```dart
enum CollectionCreateStatus {
  restoring,
  editing,
  searchingCatalog,
  validating,
  readyToPublish,
  publishing,
  published,
  failure,
}

class CollectionCreateState {
  CollectionCreateStatus status;
  int step;
  CollectionDraftData draft;
  List<CollectionCatalogSearchResult> searchResults;
  List<CollectionValidationIssue> issues;
  int revision;
  int persistedRevision;
  List<CollectionHistoryEntry> undoStack;
  List<CollectionHistoryEntry> redoStack;
}
```

`CreateState` остаётся владельцем общего lifecycle (save status, publisher,
общий draft) — Collection-состояние содержит только данные специализированного
блока, тот же принцип, что зафиксирован для Route (§6 RCB).

Команды coordinator:

- `initializeCollection`;
- `searchCatalog`, `clearCatalogSearch`;
- `addItem`, `removeItem`, `moveItem`;
- `addSection`, `renameSection`, `removeSection`, `moveSection`;
- `setCuratorNote`, `toggleHighlight`;
- `setBudgetIndicator`;
- `undo`, `redo` (bounded config; новая мутация очищает redo);
- `acknowledgeCompositionReview` (только после fresh resolve текущей revision);
- `validate`, `buildPreview`, `publish`.

Каждая команда мутации пунктов защищена `draftRevision` guard: устаревший
результат поиска или параллельная мутация не может молча перезаписать более
новое состояние (тот же паттерн защиты от stale-ответов, что у Route §6 и
Scenario intake §17.2). Item/section mutation и undo/redo увеличивают revision
и очищают `compositionReview`; ограничение истории приходит из config.

## §9. Домен и хранение

### Встраивание в общий черновик

В `CreateDraftEntity` добавляется nullable `CollectionDraftData? collectionData`
с симметричными `copyWith`/`clearCollectionData`, ровно по образцу
`routeData`/`findPeopleData`. Для `objectType == collection` это единственный
типизированный источник данных; `sectionData` не хранит копию списка пунктов.

### Типы

```dart
// v1 (CLG-CRT-01) ограничен пятью устойчивыми listing-типами (§3.12, Вопрос 20).
// `bookableSession` здесь — это offering/сервис (сауна, корт, фотостудия),
// объект переживает свои конкретные слоты, а не одна дата бронирования.
// event, activity, findPeople сознательно исключены до CLG-CRT-0x — см. §14.
enum CollectionCatalogObjectType {
  place,
  route,
  bookableSession,
  classWorkshop,
  rental,
}

enum CollectionSourceStatus { ready, stale, unavailable }

enum CollectionBudgetTier { free, low, medium, high }

class CollectionObjectRef {
  const CollectionObjectRef({required this.objectId, required this.objectType});

  final String objectId;
  final CollectionCatalogObjectType objectType;

  String get stableKey => '${objectType.name}:$objectId';
}

class CollectionItemSnapshotDraft {
  const CollectionItemSnapshotDraft({
    required this.title,
    this.coverMediaId,
    this.categoryLabel,
    this.publisherRef,
    this.priceFromMinorUnits,
    this.currency,
    this.checkedAtUtc,
  });

  final String title;
  final String? coverMediaId;
  final String? categoryLabel;
  final PublisherRef? publisherRef;
  final int? priceFromMinorUnits;
  final String? currency;
  final DateTime? checkedAtUtc;
  // Privacy invariant: persisted fallback snapshot никогда не содержит geo.
}

class CollectionItemDraft {
  const CollectionItemDraft({
    required this.id,
    required this.ref,
    required this.snapshot,
    required this.sourceStatus,
    required this.order,
    this.sectionId,
    this.curatorNote = '',
    this.highlight = false,
  });

  final String id;
  final CollectionObjectRef ref;
  final CollectionItemSnapshotDraft snapshot;
  final CollectionSourceStatus sourceStatus;
  final int order;
  final String? sectionId;
  final String curatorNote;
  final bool highlight;
}

class CollectionSectionDraft {
  const CollectionSectionDraft({
    required this.id,
    required this.title,
    required this.order,
  });

  final String id;
  final String title;
  final int order;
}

class CollectionCompositionReview {
  const CollectionCompositionReview({
    required this.draftRevision,
    required this.reviewedAtUtc,
    required this.acknowledgedUnavailableStableKeys,
  });

  final int draftRevision;
  final DateTime reviewedAtUtc;
  final Set<String> acknowledgedUnavailableStableKeys;
}

class CollectionDraftData {
  const CollectionDraftData({
    required this.schemaVersion,
    required this.publisherRef,
    required this.areaLabel,
    this.areaId,
    this.anchorLatitude,
    this.anchorLongitude,
    required this.budgetTier,
    required this.sections,
    required this.items,
    this.compositionReview,
  });

  final int schemaVersion;
  final PublisherRef publisherRef;
  final String areaLabel;
  final String? areaId;

  /// Added 2026-08-23: a single reference point for the whole area this
  /// guide covers (set via typed live-search or a manual map tap in the
  /// Basics step) — not the location of any individual item, and not part
  /// of ranking's exact-match `areaId` matching. Used for area-boost
  /// display context and as the fallback center for the Discover mini map
  /// when no item has its own live geo yet.
  final double? anchorLatitude;
  final double? anchorLongitude;
  final CollectionBudgetTier? budgetTier;
  final List<CollectionSectionDraft> sections;
  final List<CollectionItemDraft> items;
  final CollectionCompositionReview? compositionReview;
}
```

### Инварианты модели

- `CollectionItemDraft.id` — стабильный локальный id пункта (ULID при
  публикации), не совпадает с `ref.objectId`;
- `order` — плотный (без пропусков) индекс внутри своей секции (или внутри
  «без секции»); каждая команда `moveItem`/`moveSection` пересчитывает `order`
  всех элементов затронутого scope, а не хранит разреженные значения —
  предотвращает расхождение сортировки между клиентами после серии частичных
  правок;
- `sectionId`, указывающий на несуществующую секцию — невалидное состояние,
  отклоняется на уровне `CollectionDraftMapper`;
- один и тот же `CollectionObjectRef.stableKey` не встречается дважды среди
  `items`;
- `CollectionObjectRef.objectType` не включает `collection` и `scenario` —
  enum физически не даёт создать такую ссылку (см. §3.7) — и в CLG-CRT-01 не
  включает `event`, `activity`, `findPeople` по той же причине (§3.12);
- новый ввод `curatorNote` не превышает 300 Unicode grapheme clusters;
  legacy over-limit значение сохраняется mapper-ом и блокирует публикацию до
  осознанной правки, а не делает черновик невосстановимым;
- `compositionReview.draftRevision` совпадает с текущей revision, а
  acknowledged unavailable keys являются подмножеством текущих items; иначе
  review считается отсутствующим;
- `areaLabel` — display/fallback текст; `areaId`, если присутствует, —
  канонический ID для ranking, связь не строится по имени;
- `publisherRef` захватывается при создании draft из active workspace, хранится
  в typed payload и никогда не переписывается последующим workspace switch;
  смена publisher возможна только явной разрешённой командой.

### Mapper и schema version

`CollectionDraftMapper` выполняет строгую двустороннюю конвертацию, хранит
`collectionSchemaVersion`, отклоняет неизвестную будущую major-версию и
мигрирует известные старые версии без потери исходного payload — тот же
контракт надёжности, что и у `RouteDraftMapper`/`ScenarioDraftMapper`.
Экспериментальное pre-v1 geo в snapshot при чтении отбрасывается и никогда не
попадает в public projection; это privacy-cleanup, а не источник fallback map.

## §10. Item picker и работа с каталогом

`ItemsPickerSection` не создаёт новый поисковый индекс. Она читает через
provider-neutral интерфейс:

```dart
abstract interface class CollectionCatalogSearchRepository {
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  );
}

class CollectionCatalogSearchQuery {
  const CollectionCatalogSearchQuery({
    required this.text,
    required this.allowedTypes,
    required this.marketCityId,
    this.categoryId,
    this.areaId,
    this.areaLabel,
    this.excludeRefs = const <CollectionObjectRef>{},
  });

  final String text;
  // Реализация ограничена пятью значениями CollectionCatalogObjectType в v1.
  final Set<CollectionCatalogObjectType> allowedTypes;
  final String marketCityId;
  final String? categoryId;
  final String? areaId;
  // Ranking boost, не hard-фильтр (Вопрос 10): совпадающие по area результаты
  // поднимаются выше, объекты вне area не скрываются из выдачи.
  final String? areaLabel;
  final Set<CollectionObjectRef> excludeRefs;
}

class CollectionCatalogSearchResult {
  const CollectionCatalogSearchResult({
    required this.ref,
    required this.snapshot,
  });

  final CollectionObjectRef ref;
  final CollectionItemSnapshotDraft snapshot;
}
```

Реализация читает только опубликованные объекты (тот же контракт видимости,
что у обычного Search) и не возвращает draft/pending_review записи других
авторов. Локальный/mock-адаптер в стабилизационном slice использует
существующие demo/fixture каталоги объектов, не создаёт отдельный источник
данных.

Ranking сначала использует точное совпадение `marketCityId` и `areaId`. Если
канонического `areaId` у одной стороны нет, допустим только вторичный
детерминированный boost по normalized `areaLabel`; он не создаёт id-связь и
не скрывает остальные результаты. UI явно остаётся глобальным каталогом с
мягким local-first порядком, а не hard geo filter.

`excludeRefs` передаёт уже добавленные в текущий черновик пункты, чтобы UI не
предлагал повторное добавление на этапе поиска, а не только отклонял его
постфактум на уровне `addItem`. Циклическое самоссылание (Collection на саму
себя или на другую Collection/Scenario) отдельно ничем не гасится в поиске —
оно структурно невозможно, потому что `CollectionCatalogObjectType` не
включает `collection`/`scenario`: `allowedTypes` в запросе физически не может
их запросить (см. §9, инвариант модели).

## §11. Валидация и деградация

### Блокирует публикацию

- нет `submit.collection` / `publish.collection.direct` или доступа к
  publisher;
- меньше минимального числа пунктов — порог **3** (Вопрос 4, финальное
  решение; подборка из 1–2 пунктов не несёт курационной ценности), значение
  из конфигурации, не хардкод виджета;
- `curatorNote` длиннее 300 Unicode grapheme clusters (Вопрос 7);
- пустой `title`/`areaLabel` или обложка не пройдена media safety;
- дубликат `stableKey` среди items;
- `sectionId` пункта не соответствует ни одной существующей секции;
- ссылка внутри items указывает на `collection`/`scenario`/`event`/`activity`/
  `findPeople` (структурно невозможно — enum их не содержит в CLG-CRT-01, но
  проверяется defensively на границе mapper, см. §9);
- preview построен для другой revision, чем публикуемая.
- отсутствует `CollectionCompositionReview` текущей revision либо набор
  подтверждённых unavailable refs не совпадает с результатом fresh resolve.

### Требует просмотра, но не блокирует

- пункт в `sourceStatus == unavailable` на момент preview — автор явно решает
  удалить его или подтвердить публикацию без публичной карточки; сам статус
  не блокирует, но acknowledgement текущей revision обязателен;
- доля ready-пунктов, чей live `PublisherRef` входит в набор publisher-ов,
  контролируемых автором Collection, ≥50% (Вопрос 3) — предупреждение о риске
  self-promotion, не блокировка; snapshot используется только для ранней
  подсказки, publish-time расчёт всегда live;
  честный владелец бизнеса с гидом по нескольким своим точкам не наказывается;
- добавление 31-го пункта (Вопрос 5) — мягкая подсказка разбить на секции
  или несколько Collection, количество пунктов остаётся `без лимита` по
  VISION.md;
- пустая `curatorNote` у части пунктов (soft-подсказка качества);
- секция без единого пункта;
- `budgetTier` не совпадает с фактическим ценовым диапазоном добавленных
  объектов по `CollectionBudgetSuggestionPolicy`.

Набор «контролируемых автором publisher-ов» для soft-warning включает личный
`PublisherRef` actor-а и только те page refs, для которых access snapshot
подтверждает active membership и право публикации. Local/mock coordinator
получает этот набор из identity application provider; production backend в
будущем выводит его из verified server context. Клиентский snapshot пункта не
может сам расширить этот набор.

### Fallback при недоступности поиска каталога

Если `CollectionCatalogSearchRepository` временно недоступен, автор может
повторить запрос или продолжить работу с уже добавленными пунктами и
заметками — поиск не блокирует остальной черновик, ошибка привязана только к
шагу 2.

## §12. Публикация и bundle

Перед записью application строит один канонический bundle, тот же принцип,
что у Route (§9 RCB) и Scenario:

```text
collectionId
collectionVersionId
publisherRef
content envelope (title, descriptions, media, market, areaId/label, budgetTier,
visibility)
sections (ordered)
items (ordered, with ref + curatorNote + highlight)
compositionReview (reviewedAtUtc + reviewed revision)
publishAttemptId
```

Публикация идемпотентна: повтор одного `publishAttemptId` не создаёт вторую
Collection. Backend (или локальный crash-recoverable adapter до его подключения)
записывает bundle атомарно; частичный успех не показывается как публикация.
Effective idempotency key — `(actorId, commandType, requestId)`; actor и
capabilities приходят из trusted context. Replay того же key и payload hash
возвращает сохранённый receipt, тот же key с другим hash даёт стабильный
`idempotency_conflict`. PublisherRef из bundle сверяется с access context и
не принимается как доказательство authority.
Local adapter использует staged write + verified commit marker для version,
active pointer, audit и idempotency receipt; restart восстанавливает только
полностью проверенный commit. Corrupt entry изолируется typed failure без
удаления остальных Collection records.
Опубликованная версия неизменяема; **добавление** пункта или любая правка
представления создаёт новую версию по тем же правилам moderation/direct-
publish, что и остальные типы (§3.3, §6).

Removal-only исключение (§3.11, Вопрос 19) не принимает произвольный новый
bundle от клиента:

```text
CollectionRemovalOnlyCommand
actor context (server/application-derived)
collectionId
baseVersionId
expectedBaseRevisionOrHash
removedItemRefs (non-empty subset of active items)
requestId
```

Доверенный reducer проверяет `manage.collection`, exact publisher access,
active base/hash и что каждый ref существует; затем сам строит новую active
версию, отличающуюся только отсутствием этих refs и нормализованным порядком.
Любая попытка передать новые items, тексты, sections, highlight, media,
visibility или publisher отклоняется стабильным `removal_only_conflict`.
Replay того же requestId идемпотентен; команда и diff попадают в audit.
Архивирование не использует этот контракт: это отдельная idempotent lifecycle-
команда с `archive.collection` и publisher access.

## §13. Discover-интеграция

### Object type

Collection — самостоятельный тип в общей выдаче Search/Feed. В отличие от
Find People (явно зафиксированного как полноценный `MapObject`), у Collection
нет одной физической координаты — только описательная `areaLabel`. Она
участвует в Search/Feed по тексту/категории/area в любом случае.

Collection **никогда не становится pin-объектом основной карты Discover**
(Вопрос 12, финальное решение) — она живёт только в Search/Feed и в своей
Details. Это не мешает Details показывать собственную мини-карту (ниже) —
две разные поверхности: общая карта Discover показывает точечные объекты,
Details одной Collection показывает точки её собственных пунктов.

Search/Feed не подставляет Collection фиктивные latitude/longitude и не
пропускает её через point-radius filter. В v1 она фильтруется по text,
category, market и canonical area (либо display-label fallback); map surface
получает только mappable subset без Collection. Общее состояние фильтров
сохраняется, но list и map закономерно имеют разные projection capabilities.

**Реализовано иначе, чем описано абзацем выше на момент написания (пересмотрено
владельцем при реализации CLG-CRT-01, 2026-08-22).** Слияние Collection в
`DiscoverItemEntity` через nullable `GeoPoint? publicMapPoint`/`distanceKm`
требовало бы делать non-null поля этой сущности nullable — а от них уже
зависят все 9 остальных типов (фильтр по радиусу, сортировка по дистанции,
рендер маркера везде эти поля читают как гарантированно ненулевые). Это
breaking change с реальным риском сломать что-то в Place/Event/Route/Session/
Activity/FindPeople без отдельного теста на каждый — риск был признан
непропорциональным для этого инкремента.

Вместо этого реализована отдельная секция «Guides», читающая
`PublishedCollectionDiscoveryPort` параллельно основной ленте, не смешанная
с ranking/фильтрами точечных объектов: `CollectionDiscoverSection` (виджет),
`activeCollectionsProvider`/`collectionByIdProvider`/
`collectionResolvedItemsProvider` (в `app/application/`, не в
`features/discover/application/` — тот же слой композиции, что и у
`scenario_object_intake_providers.dart`, иначе получается cross-feature
import прямо в фиче), отдельная `CollectionDetailsPage` со своим маршрутом
`/collection/details/:collectionId` вместо ветки внутри общего
`DiscoverDetailsPage`. `DiscoverItemEntity`/`discover_repository_impl.dart`/
`discover_results_page.dart`/`discover_details_page.dart` не изменены.
Единая с точечными объектами лента/ranking — следующий отдельный gate, не
входит в CLG-CRT-01.

### Карточка Search/Feed

Обложка, название, `areaLabel`, количество пунктов, budget-индикатор,
до 3 превью-обложек первых пунктов (коллаж, как у карточки Scenario с
несколькими остановками).

### Details

- header: обложка, название, описание, area, budget, автор/publisher;
- список секций (или единый список, если секций нет) с пунктами;
- каждый пункт резолвится **на момент открытия** через обычный read-репозиторий
  соответствующего типа (Place/Route/Bookable Session/…), не через
  кэшированный снимок — снимок используется только как fallback при
  временной недоступности live-чтения, помеченный как «может быть
  неактуально», но fallback никогда не содержит и не показывает geo;
- **мини-карта** с pin всех резолвленных пунктов, у которых есть публичная
  точка (Вопрос 13, финальное решение) —
  `CollectionResolvedItem.publicMapPoint` из §14; значение живёт только в
  текущем read result. Пункты без публичной локации (приватная/approximate по правилам
  своего типа) остаются в списке, но не появляются на мини-карте — Collection
  не переопределяет privacy-правила источника (§3.5);
- пункт, ставший `unavailable`, публично скрывается из списка и с мини-карты
  без ошибки — читатель не видит битых карточек; автор в своём редакторе
  видит и предупреждение по конкретному пункту, и агрегированный сигнал по
  всей Collection («3 из 10 пунктов недоступны — рассмотрите ревизию»), см.
  §3.10;
- тап по пункту (в списке или на мини-карте) ведёт на обычный Details этого
  объекта — Collection не дублирует его данные, а маршрутизирует к
  первоисточнику (прямое повторение того, как GetYourGuide guide ведёт на
  реальную activity-страницу).

Мини-карта показывается только при наличии хотя бы двух distinct public map
points; для одной или нуля точек карта не рендерится. Для Route source-adapter
использует его уже опубликованную Discover start-point projection и не
упрощает Route aggregate до новой Collection-координаты.

### Consistency

Так же, как Route не даёт Search смешать overview и full geometry разных
версий (§9 RCB), Collection Details не должен показывать пункты из
неопубликованной ревизии — читает только `active` версию Collection.

## §14. Repository и use case boundaries

```dart
abstract interface class CollectionCatalogSearchRepository {
  Future<List<CollectionCatalogSearchResult>> search(
    CollectionCatalogSearchQuery query,
  );
}

abstract interface class CollectionItemResolutionRepository {
  Future<Map<String, CollectionResolvedItem>> resolveMany(
    List<PublishedCollectionItemRef> refs,
  );
}

class CollectionResolvedItem {
  const CollectionResolvedItem({
    required this.ref,
    required this.card,
    required this.status,
    this.publicMapPoint,
  });

  final PublishedCollectionItemRef ref;
  final CollectionResolvedCardProjection card;
  final PublishedCollectionItemStatus status;
  // Только live public projection; shared GeoPoint, не persisted snapshot.
  final GeoPoint? publicMapPoint;
}

abstract interface class CollectionPublicationRepository {
  Future<CollectionPublishReceipt> publish(CollectionPublishBundle bundle);
  Future<CollectionPublishReceipt> removeItemsOnly(
    CollectionRemovalOnlyCommand command,
  );
}

abstract interface class CollectionPublicationIndexSink {
  Future<void> activate(PublishedCollectionVersion version);
  Future<void> archive(String collectionId);
}

abstract interface class PublishedCollectionDiscoveryPort {
  Future<List<PublishedCollectionDiscoveryEntity>> loadActiveCollections();
  Future<PublishedCollectionDiscoveryEntity?> getActiveCollection(String id);
}
```

`CollectionCatalogSearchRepository` и `CollectionPublicationRepository`
и `CollectionPublicationIndexSink` принадлежат Create authoring domain.
`PublishedCollectionDiscoveryEntity`,
`PublishedCollectionItemRef`, `PublishedCollectionItemStatus`,
`CollectionResolvedItem`, resolution repository
и read-port принадлежат Discover domain. Discover не импортирует
`CollectionDraftData`/Create application; data adapter переводит immutable
publication record в read projection. Это повторяет направление зависимости
`PublishedRouteDiscoveryPort` и не создаёт cross-feature domain import.
App-level `CollectionPublicationDiscoveryAdapter` — единственная composition-
граница, реализующая Create sink и Discover port поверх Discover local
datasource, ровно по прецеденту Route. Если canonical publish уже committed,
а projection sync упал, повтор того же idempotency key проверяет receipt и
повторяет только sync; второй Collection/version не создаётся.

`resolveMany` — не деталь реализации, а обязательная часть контракта: Details
одной опубликованной Collection может держать десятки пунктов до пяти
разных типов (§9). Первая версия этого раздела предлагала `resolveLive(ref)`
по одному пункту — при открытии Details с N пунктами это N последовательных
или параллельных чтений там, где остальной репозиторий уже принял паттерн
батч-чтения (`DiscoverQuery` для Map/Feed, `ScenarioObjectIntakeIntent.candidates`
для intake). Правильная реализация группирует `refs` по `objectType` и
выполняет один батч-запрос на каждый затронутый тип через уже существующие
read-репозитории Place, Route, Bookable Session, Class/Workshop, Rental —
`CollectionItemResolutionRepository` сам не хранит и не кэширует данные
объектов, это Discover-owned диспетчер, а не шестой источник истины. Каждый
source adapter возвращает только уже разрешённую для публичного Discover
проекцию; private/exact geo не принимается контрактом.

Семантика «этот конкретный пункт для читателя сейчас неактуален» остаётся
внутри домена соответствующего типа, а не переизобретается в Collection:
адаптер каждого типа сам решает, когда отдать Discover-проекции
`PublishedCollectionItemStatus.unavailable` вместо `ready`. Authoring-
координатор отдельно отображает свежий результат проверки в свой
`CollectionSourceStatus`; Discover не импортирует Create enum, а Create не
определяет внутренние правила актуальности чужих доменов. Collection не
вводит собственного понятия «прошедшее» или «закрытое» — иначе домену
Collection пришлось бы знать внутренние правила чужих доменов, что нарушает
границы слоёв (правило 6 AGENTS.md, «данные из бэкенда — только через
data/datasources»). Именно эта граница ответственности и стала причиной
сузить v1 до устойчивых listing-типов (Вопрос 20, финальное решение, §3.12):
у Event, Recharge Activity и Find People понятие «неактуально» — это не
редкое исключение, а нормальное состояние в течение жизни объекта (прошедшее
occurrence, закрытый набор), и переносить его в общий `ready`/`unavailable`
без отдельного «предстоящая дата» на карточке значило бы либо часто
показывать честный, но обескураживающий «недоступно», либо тихо соврать.
Их подключение — отдельный CLG-CRT-0x, когда на карточке пункта появится
способ показать это состояние не бинарно.

`ItemsPickerSection` (presentation) не хранит бизнес-логику дедупликации,
лимитов или resolve — она отправляет intents в coordinator и рендерит
переданное состояние, тот же принцип разделения слоёв, что и у
`RouteMapBuilderSection` (правило 1 AGENTS.md).

## §15. План файлов реализации

### Новые файлы

```text
apps/mobile/lib/features/create/domain/entities/collection_draft_data.dart
apps/mobile/lib/features/create/domain/entities/collection_item_draft.dart
apps/mobile/lib/features/create/domain/entities/collection_publication_data.dart
apps/mobile/lib/features/create/domain/entities/collection_validation_issue.dart
apps/mobile/lib/features/create/domain/repositories/collection_catalog_search_repository.dart
apps/mobile/lib/features/create/domain/repositories/collection_publication_index_sink.dart
apps/mobile/lib/features/create/domain/repositories/collection_publication_repository.dart
apps/mobile/lib/features/create/domain/usecases/validate_collection_draft_usecase.dart
apps/mobile/lib/features/create/domain/usecases/build_collection_publication_bundle_usecase.dart
apps/mobile/lib/features/create/domain/usecases/remove_collection_items_only_usecase.dart
apps/mobile/lib/features/create/application/collection_create_config.dart
apps/mobile/lib/features/create/application/collection_budget_suggestion_policy.dart
apps/mobile/lib/features/create/application/collection_create_coordinator.dart
apps/mobile/lib/features/create/application/state/collection_create_state.dart
apps/mobile/lib/features/create/data/models/collection_draft_mapper.dart
apps/mobile/lib/features/create/data/models/collection_publication_model.dart
apps/mobile/lib/features/create/data/datasources/collection_catalog_search_mock_datasource.dart
apps/mobile/lib/features/create/data/datasources/collection_publication_local_datasource.dart
apps/mobile/lib/features/create/data/repositories/collection_catalog_search_repository_impl.dart
apps/mobile/lib/features/create/data/repositories/collection_publication_repository_impl.dart
apps/mobile/lib/features/create/presentation/widgets/collection_create_block.dart
apps/mobile/lib/features/create/presentation/widgets/items_picker_section.dart
apps/mobile/lib/features/create/presentation/widgets/collection_curator_notes_section.dart
apps/mobile/lib/features/discover/domain/entities/published_collection_discovery_entity.dart
apps/mobile/lib/features/discover/domain/repositories/collection_item_resolution_repository.dart
apps/mobile/lib/features/discover/domain/repositories/published_collection_discovery_port.dart
apps/mobile/lib/features/discover/data/datasources/published_collection_discovery_local_datasource.dart
apps/mobile/lib/features/discover/data/repositories/collection_item_resolution_repository_impl.dart
apps/mobile/lib/features/discover/presentation/widgets/collection_details_mini_map.dart
apps/mobile/lib/app/adapters/collection_publication_discovery_adapter.dart
apps/mobile/test/support/collection_create_test_support.dart
apps/mobile/test/unit/collection_create_coordinator_test.dart
apps/mobile/test/unit/collection_budget_suggestion_policy_test.dart
apps/mobile/test/unit/collection_draft_mapper_test.dart
apps/mobile/test/unit/validate_collection_draft_usecase_test.dart
apps/mobile/test/unit/collection_publication_repository_test.dart
apps/mobile/test/unit/collection_item_resolution_repository_test.dart
apps/mobile/test/unit/collection_publication_discovery_adapter_test.dart
apps/mobile/test/unit/discover_repository_collection_test.dart
apps/mobile/test/widget/collection_create_block_test.dart
apps/mobile/test/widget/collection_discover_details_test.dart
apps/mobile/test/widget/create_hub_collection_test.dart
```

### Изменяемые файлы

```text
apps/mobile/lib/features/create/domain/entities/create_draft_entity.dart
apps/mobile/lib/features/create/data/models/create_draft_model.dart
apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart
apps/mobile/lib/features/create/application/create_runtime_defaults.dart
apps/mobile/lib/features/create/application/create_providers.dart
apps/mobile/lib/features/create/application/state/create_state.dart
apps/mobile/lib/features/create/application/controllers/create_controller.dart
apps/mobile/lib/features/create/presentation/pages/create_hub_page.dart
apps/mobile/lib/features/create/presentation/pages/create_page.dart
apps/mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart
apps/mobile/lib/features/identity/application/identity_workspace_providers.dart
apps/mobile/lib/features/identity/data/datasources/mock_identity_fixture.dart
apps/mobile/lib/app/application/active_create_publisher_provider.dart
apps/mobile/lib/features/discover/domain/entities/discover_item_entity.dart
apps/mobile/lib/features/discover/domain/repositories/discover_repository.dart
apps/mobile/lib/features/discover/data/repositories/discover_repository_impl.dart
apps/mobile/lib/features/discover/presentation/pages/discover_details_page.dart
apps/mobile/lib/features/discover/presentation/pages/discover_map_page.dart
apps/mobile/lib/features/discover/presentation/pages/discover_results_page.dart
apps/mobile/lib/features/discover/presentation/widgets/discover_feed_section.dart
apps/mobile/lib/app/di/service_locator.dart
apps/mobile/test/widget/create_page_test.dart
apps/mobile/test/widget/discover_details_page_test.dart
docs/architecture/LAUNCH_STATUS.md
```

`create_taxonomy.dart` **не входит** в изменяемые файлы — `CreateBlockConfig`
для Collection там уже существует и подтверждён кодом (см. заголовок
документа); подключение выполняется через registry/config/coordinator
существующего form engine, без изменения таксономии.

Discover-файлы — обязательная часть CLG-CRT-01, а не «синхронизированная»
внешняя задача: без них AC Search/Details/mini-map и DoD недостижимы.
`discover_map_page.dart` меняется только для явного доказательства, что
Collection не получает fake marker; существующая Map-логика остальных типов
не переписывается.

### Конфигурационные константы CLG-CRT-01

Все значения — поля `collection_create_config.dart`, не хардкод в UI (§3.9):

| Константа | Значение | Источник |
|---|---|---|
| `minPublishableItemCount` | 3 | Вопрос 4 |
| `curatorNoteMaxLength` | 300 grapheme clusters | Вопрос 7 |
| `selfPublisherShareWarningThreshold` | 50% | Вопрос 3 |
| `itemCountSoftWarningThreshold` | 30 (предупреждение с 31-го) | Вопрос 5 |
| `budgetSuggestionMinPriceCoverage` | 50%, минимум 2 цены | Вопрос 18 |
| `maximumHistoryEntries` | bounded, default 50 | общий Create history pattern |
| `collectionCreateEnabled` | true только в local/mock slice | rollback |
| `collectionPublishingEnabled` | false до publish gates, затем true local/mock | rollback |
| `collectionDiscoverEnabled` | false до projection gates, затем true local/mock | rollback |

`MarketBudgetTierConfig` содержит market/currency и пороги low/medium/high;
конкретные EUR-пороги Riga demo задаются в runtime defaults, а не в widget или
универсальном domain. Unknown/mixed currency fail closed to «no suggestion».

### Миграция и rollback

- `collectionSchemaVersion = 1`; ранее typed Collection payload в runtime не
  существовал, поэтому миграция additive и не переписывает другие Create types.
- Legacy generic `CreateObjectType.collection` draft без `collectionData`
  открывается read-compatible generic form с явным предложением начать новый
  typed draft; автоматическое угадывание items из `sectionData` запрещено.
- Unknown future major payload сохраняется byte-for-byte и открывается
  read-only с typed failure; silent downgrade запрещён.
- Pre-v1 experimental `snapshot.location` игнорируется при чтении и не
  переносится: stale geo не является recoverable public data.
- Rollback выключает publishing и Discover projection flags, но не удаляет
  drafts/publication records. После отката автор может экспортировать или
  продолжить локальный draft после повторного включения совместимой версии.
- Ни rollback, ни миграция не меняют `PublisherRef`, item refs или active
  version молча.

### Telemetry и privacy

Единственное событие slice — `collection_create_action`. Allowlist полей:
enum `action`, enum `result`, enum `sourceType`, bucket item/unavailable counts,
step и feature-flag state. Запрещены query text, title/description/curatorNote,
object/collection/publisher/user IDs, raw price, area label, coordinates,
media URLs и free-form error. Stable error code допускается. Mini-map и live
resolution не логируют точки даже в local demo.

## §16. Этапы реализации и gates

| Этап | Приоритет | Результат | Gate выхода |
|---|---|---|---|
| CLG-CRT-01 | сейчас | typed draft, mapper, `ItemsPickerSection`, config, coordinator, mock catalog search, локальный idempotent publish, Search/Details интеграция (список + мини-карта) на mock-данных | unit/widget/e2e тесты §17, `flutter analyze` 0 |
| CLG-CRT-02 | сразу за CLG-CRT-01 (Вопрос 15) | «Add to Collection» из Details/Search/Map по образцу SCN-INTAKE (versioned intent, target chooser, revision-safe Apply) | отдельный Approved slice spec, свои AC |
| CLG-CRT-0x | после появления «предстоящая дата» на карточке пункта | Event, Recharge Activity, Find People как допустимые типы (Вопрос 20) | отдельный Approved slice spec, свои AC |
| CLG-CRT-03 | после стабилизации | Publisher/ManagedPage capability enforcement, реальная модерация, backend-хранение | Accepted ADR/backend gate, тот же порядок, что у остальных 9 типов |

CLG-CRT-01 — единственный этап, который эта спецификация разрешает начинать
прямо сейчас. CLG-CRT-02 приоритизирован владельцем как следующий сразу за
ним (Вопрос 15) — без него ценность курации ограничена, автору приходится
держать в голове, что добавить, вместо добавления «на лету» — но он всё
равно требует собственного Approved slice spec с типизированным intent-
контрактом, не входит в объём этого документа. CLG-CRT-0x и CLG-CRT-03
остаются отдельными gated этапами.

## §17. Тестовая матрица

### Domain

- дедупликация `stableKey` при `addItem`;
- порядок пунктов и секций остаётся консистентным после `moveItem`/`moveSection`;
- mapper round-trip не теряет draft/item `PublisherRef`, `curatorNote`/
  `highlight`/`budgetTier` и composition review; snapshot geo отсутствует;
- миграция схемы идемпотентна;
- validation codes стабильны и детерминированы (min items, orphan section,
  invalid ref type, `curatorNote` > 300 grapheme clusters);
- emoji/ZWJ/combining-mark cases считаются пользовательскими символами, а
  legacy over-limit payload восстанавливается с issue без потери текста;
- item/section mutation и undo/redo инвалидируют composition review;
- bounded undo/redo сохраняет точный порядок и очищает redo после новой мутации;
- soft-warning срабатывает на ровно 50% доле publisher-а и не срабатывает
  ниже порога (граничные значения, Вопрос 3);
- soft-warning на количестве пунктов срабатывает с 31-го, не с 30-го
  (Вопрос 5).

### Application/data

- capability matrix для всех операций и publisher types;
- active workspace задаёт publisher только новому draft; переключение
  workspace не переписывает восстановленный Collection draft;
- stale search response не применяется после смены query/revision;
- `excludeRefs` действительно исключает уже добавленные и запрещённые типы;
- недоступный catalog search не блокирует остальной черновик;
- publish idempotency и атомарность bundle;
- staged-write failures/restart recovery/corrupt-record isolation не создают
  partial active version и не теряют last-known-good records;
- removal-only reducer принимает только subset active refs, проверяет base
  revision/hash и не позволяет изменить ни одно другое поле;
- provider DTO не протекает в domain;
- `resolveMany` группирует запрос по `objectType` в один батч на тип, не
  выполняет по одному чтению на пункт;
- decay после публикации (пункт стал `unavailable` пост-фактум) не отзывает
  Collection и не требует новой версии, но агрегированный счётчик недоступных
  пунктов в редакторе автора обновляется корректно;
- `areaLabel` в поиске — ranking boost: объекты вне area не исчезают из
  результатов, только опускаются ниже совпадающих; exact `areaId` сильнее
  normalized-label fallback (Вопрос 10);
- удаление пункта или архивирование Collection у автора без
  `publish.collection.direct` не создаёт `pendingReview`/`moderate` запрос;
  добавление пункта или изменение текста — создаёт (Вопрос 19), но обе
  self-service операции всё равно требуют свои `manage.collection`/
  `archive.collection` и publisher access;
- budget suggestion проверяет median, coverage, market currency, mixed/
  unknown fallback и сохранение manual override;
- live resolver не возвращает private/exact geo, fallback snapshot никогда не
  рисует pin после source privacy change;
- telemetry allowlist не пропускает query/content/IDs/raw prices/area/geo;
- Discover Search/Feed показывает Collection без fake coordinates, point-
  radius не применяется к list-only projection, основная Map её не получает.

### Widget/accessibility

- шаги доступны с клавиатуры и screen reader;
- список пунктов имеет keyboard-доступную альтернативу drag-and-drop для
  переупорядочивания;
- unavailable-пункт в редакторе визуально и текстово помечен, без скрытого
  удаления;
- mini-map не показывается при 0–1 public points, при 2+ использует только
  live points и имеет list/keyboard alternative;
- undo/redo и composition acknowledgement доступны с клавиатуры и screen reader;
- small/large text, светлая/тёмная тема, узкий экран не ломают flow.

### End-to-end

1. Уполномоченный автор создаёт Collection из 3+ пунктов разных допустимых
   типов, добавляет заметки, публикует.
2. Читатель находит Collection в Search, открывает Details, видит live-данные
   пунктов и мини-карту с их точками, переходит на Details конкретного
   объекта.
3. Объект внутри опубликованной Collection снимается с публикации — читатель
   больше не видит его в списке и на мини-карте, автор видит предупреждение
   в редакторе.
4. Повтор публикации не создаёт дубликат Collection.
5. Пользователь без `create.collection` не открывает редактор по прямой ссылке.
6. Автор без `publish.collection.direct` удаляет пункт из уже опубликованной
   Collection — изменение применяется сразу, без ухода в `pendingReview`;
   тот же автор добавляет новый пункт — версия уходит на модерацию.
7. Source отзывает public geo: следующий Details read убирает pin, а временно
   недоступный live read не восстанавливает старую координату из snapshot.
8. Collection видна в Search/Feed по market/area, отсутствует на основной Map
   и не получает фиктивный radius/distance.
9. Feature flags выключают publication/Discover без удаления сохранённых
   drafts и active local records; повторное включение восстанавливает данные.

## §18. Acceptance criteria

- **CLG-AC-01:** Collection подключён как специализированный блок общего
  Create Hub, без отдельного form engine.
- **CLG-AC-02:** вход, сохранение, публикация, управление и архивирование
  проверяют соответствующие capabilities из §6.
- **CLG-AC-03:** `CreateDraftEntity` хранит типизированный `collectionData`;
  `sectionData` не дублирует список пунктов; typed payload содержит канонический
  `PublisherRef`, который не переписывается workspace switch.
- **CLG-AC-04:** пункт хранит только `{objectId, objectType}` + снимок;
  свободный текст/внешний URL как замена ссылке не допускается.
- **CLG-AC-05:** дубликат `stableKey` внутри одной Collection невозможен ни
  через `addItem`, ни через mapper round-trip.
- **CLG-AC-06:** `CollectionCatalogObjectType` в CLG-CRT-01 содержит ровно пять
  значений — Place, Route, Bookable Session, Class/Workshop, Rental; Collection,
  Scenario, Event, Recharge Activity, Find People недоступны как ссылка.
- **CLG-AC-07:** секции и порядок пунктов сохраняют консистентность после
  add/remove/move; orphan `sectionId` — validation issue, не runtime-ошибка.
- **CLG-AC-08:** публикация блокируется при количестве пунктов меньше
  сконфигурированного минимума.
- **CLG-AC-09:** `unavailable`-пункт не блокирует публикацию, но требует явного
  `CollectionCompositionReview` текущей revision и никогда не удаляется молча.
- **CLG-AC-10:** Details резолвит пункты live на момент открытия одним
  батч-запросом на каждый затронутый `objectType` через `resolveMany`, не
  последовательными вызовами по одному пункту; кэшированный снимок
  используется только как явно помеченный fallback без geo.
- **CLG-AC-11:** удаление/снятие с публикации объекта скрывает его из
  публичного Collection Details без ошибки интерфейса.
- **CLG-AC-12:** публикация идемпотентна по `publishAttemptId`, bundle
  атомарен, key/hash conflict fail closed; staged restart recovery не считает
  partial commit публикацией и сохраняет last-known-good records.
- **CLG-AC-13:** Search индексирует Collection по тексту/категории/area;
  Collection никогда не создаёт pin на основной Discover-карте (финальное
  решение, §13), не получает fake coordinate/distance и не проходит point-
  radius filter как точечный объект.
- **CLG-AC-14:** `ItemsPickerSection` не содержит бизнес-логику дедупликации,
  лимитов и resolve — это ответственность domain/application слоёв.
- **CLG-AC-15:** provider SDK/DTO не протекает в domain/application-контракты
  каталожного поиска.
- **CLG-AC-16:** лимиты, допустимые типы, минимум пунктов, budget policy,
  history bound и feature flags приходят из конфигурации, не хардкодятся в UI.
- **CLG-AC-17:** autosave revision-safe, недоступность catalog search не
  ломает остальной черновик.
- **CLG-AC-18:** все ошибки имеют стабильный code и recoverable действие там,
  где восстановление возможно.
- **CLG-AC-19:** unit, widget, accessibility и end-to-end тесты из §17
  проходят.
- **CLG-AC-20:** `flutter analyze` — 0 ошибок, `flutter test` полностью
  зелёный, фактический статус отражён в `LAUNCH_STATUS.md`.
- **CLG-AC-21:** минимум пунктов проверяется только при публикации; после
  публикации decay пунктов до `unavailable` не отзывает и не блокирует
  Collection автоматически, но автор видит агрегированный счётчик
  недоступных пунктов в своём редакторе (§3.10).
- **CLG-AC-22:** Details показывает мини-карту при наличии минимум двух
  distinct live `publicMapPoint`; пункты без публичной локации остаются в
  списке, но не выводятся на карту, fallback geo запрещён (§13).
- **CLG-AC-23:** поиск в `ItemsPickerSection` поднимает объекты той же
  `areaId` (или normalized-label fallback), что и Collection, выше в выдаче,
  но не скрывает и не блокирует объекты из других area (§10).
- **CLG-AC-24:** новый `curatorNote` длиннее `curatorNoteMaxLength` (300
  grapheme clusters) не принимается UI и не публикуется; mapper сохраняет
  legacy over-limit текст и возвращает validation issue вместо потери draft.
- **CLG-AC-25:** доля ready-пунктов с live `PublisherRef` из набора
  publisher-ов, контролируемых автором Collection, ≥
  `selfPublisherShareWarningThreshold` (50%) — non-blocking предупреждение;
  stale snapshot не является publish-time authority.
- **CLG-AC-26:** добавление пункта сверх `itemCountSoftWarningThreshold` (30)
  показывает мягкую подсказку разбить подборку, не блокирует и не ограничивает
  реальное количество пунктов.
- **CLG-AC-27:** removal-only reducer с `baseVersionId` и expected hash сам
  строит subset active version, требует `manage.collection` и publisher
  access, идемпотентен и отклоняет любой сопутствующий diff; archive требует
  отдельную `archive.collection`. Добавление/representational edit без
  `publish.collection.direct` требует новую проверенную версию (§3.11, §12).
- **CLG-AC-28:** `CollectionItemSnapshotDraft` не содержит geo; live public
  point использует shared `GeoPoint` только в Discover read result. Отзыв geo
  источником убирает pin и не раскрывается через fallback.
- **CLG-AC-29:** Published Collection read contracts принадлежат Discover;
  Discover не импортирует Create domain/application, boundary gate не получает
  новую suppression.
- **CLG-AC-30:** `CollectionBudgetSuggestionPolicy` использует median только
  при достаточном price coverage и одной market currency, применяет injected
  market thresholds, не сохраняет suggestion и не перезаписывает manual tier.
- **CLG-AC-31:** undo/redo bounded, revision-safe, сохраняет порядок и
  инвалидирует composition review; новая мутация очищает redo.
- **CLG-AC-32:** schema-v1 migration/unknown-major/legacy generic fallback и
  rollback из §15 проходят тесты без destructive rewrite.
- **CLG-AC-33:** `collectionCreateEnabled`, `collectionPublishingEnabled` и
  `collectionDiscoverEnabled` fail closed независимо; выключение не удаляет
  drafts или active local records.
- **CLG-AC-34:** Search/Feed, Details и mini-map физически входят в CLG-CRT-01
  и покрыты unit/widget/e2e тестами; это не внешний «синхронный» slice.
- **CLG-AC-35:** capability fixtures по умолчанию дают verified Creator
  `create.collection`/`submit.collection`, но не выдают
  `publish.collection.direct`; первая Collection идёт в mock review path.
- **CLG-AC-36:** `collection_create_action` содержит только allowlisted
  enum/bucket/code поля; query, content, IDs, raw price, area и geo отсутствуют
  в telemetry во всех success/failure/disabled paths.

## §19. Definition of Done

CLG-CRT-01 считается завершённым, когда выполнены CLG-AC-01–36, а
опубликованная Collection проходит доказуемую цепочку:

```text
authorized author
→ typed draft with picked catalog items from five stable listing types
→ current-revision composition review
→ validated immutable version with no persisted geo snapshot
→ idempotent publish bundle
→ active Discover-owned Search/Feed projection without a main-map pin
→ Details with live-resolved items, a live-only mini-map, and source links
```

Красивый picker без capability enforcement, идемпотентной публикации и
live-резолвинга на Details не считается готовым блоком. Так же не считается
Done Create-only реализация без Discover projection, rollback и полного
stabilization gate.

## §20. Решения владельца

Все вопросы, которые эта спека не могла закрыть сама, отвечены владельцем
2026-08-20. Таблица ниже — итог; куда именно в документе попало каждое
решение, для быстрой сверки при чтении.

| Вопрос | Ответ | Где в спеке |
|---|---|---|
| 1. Кто может создавать | A — общий бар | §3.3 |
| 2. Согласие автора объекта | A — implicit consent | §3.2 |
| 3. Лимит на объекты publisher | B, порог 50% | §11, §15, AC-25 |
| 4. Минимум пунктов | A — 3 | §11, §15, AC-08 |
| 5. Верхний soft-limit | B, порог 30 | §11, §15, AC-26 |
| 6. Обязательность заметки | A — опционально | §7 (Шаг 3) |
| 7. Лимит `curatorNote` | B — 300 grapheme clusters | §7, §9, §11, §15, AC-24 |
| 8. Медиа в заметке | A — только текст | §9 (`curatorNote: String`) |
| 9. Устройство секций | A — только заголовок | §9 (`CollectionSectionDraft`) |
| 10. Область поиска | B — мягкий приоритет | §7, §10, §17, AC-23 |
| 11. Inline-создание объекта | A — только существующее | §5 («не входит») |
| 12. Видимость на карте | A — никогда | §13, AC-13 |
| 13. Мини-карта на Details | B — добавлена | §9, §13, §14, §15, AC-22 |
| 14. Порог публикации | B — per-type capability | §3.3, §6 |
| 15. Приоритет CLG-CRT-02 | A — сразу за CLG-CRT-01 | §16 |
| 16. Scenario как тип пункта | C — отложено | §3.7 (без изменений) |
| 17. Реестр секций VISION.md | A — обновлено сейчас | [VISION.md](VISION.md) |
| 18. Индикатор бюджета | B — опционален с автоподсказкой | §7 (Шаг 4), без изменений |
| 19. Асимметрия модерации | B — удаление self-service | §3.11, §12, AC-27 |
| 20. Скоротечные типы | B — сужен до 5 типов | §3.12, §9, §14, AC-06 |

Источники по референсному продукту: [GetYourGuide](https://www.getyourguide.com/),
[GetYourGuide Trip Inspiration](https://www.getyourguide.com/explorer/travel-inspiration/).
