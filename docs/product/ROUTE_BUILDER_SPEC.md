# RECHARGE — Route Builder Spec

Версия: v3.2 (2026-07-20). Статус: целевая продуктовая спецификация.
Уровень: production spec для `CreateObjectType.route` в Create Hub.

Route Builder — единый инструмент создания публикуемого маршрута по
местности. Автор может построить путь по точкам, нарисовать его, записать по
GPS, импортировать из файла или сгенерировать по заданным условиям, а затем
отредактировать геометрию, точки интереса, условия прохождения и публикацию.

Цель продукта — позволить автору подготовить точный, полезный и проверяемый
маршрут без потери данных, скрытых изменений геометрии и зависимости
пользовательского интерфейса от конкретного картографического провайдера.

Связанные документы:

- [VISION.md](VISION.md);
- [CATEGORY_SYSTEM.md](CATEGORY_SYSTEM.md), профиль `outdoor_activity`;
- [S3_CRT_01_CREATE_SPEC.md](S3_CRT_01_CREATE_SPEC.md), общий движок форм;
- [ROUTE_CREATE_BLOCK_SLICE_SPEC.md](ROUTE_CREATE_BLOCK_SLICE_SPEC.md),
  реализация Route-блока в Create Hub;
- [ROUTE_IMPLEMENTATION_ROADMAP.md](ROUTE_IMPLEMENTATION_ROADMAP.md),
  последовательность небольших implementation slices;
- [PLATFORM_FOUNDATION_SPEC.md](../architecture/PLATFORM_FOUNDATION_SPEC.md),
  demo-first/free-first фундамент и production gates;
- [ARCHITECTURE_BASELINE.md](../architecture/ARCHITECTURE_BASELINE.md);
- Accepted ADR «Карты и маршрутизация» после его принятия.

---

## §1. Продуктовый контракт

### Результат создания

Один Route содержит:

- непрерывную упорядоченную геометрию пути;
- форму `oneWay | loop | outAndBack`;
- версионируемый профиль движения и настройки построения;
- дистанцию, длительность, набор и сброс высоты;
- старт, финиш и пользовательские точки с расстоянием от начала;
- сложность, покрытия, маркировку, доступность, сезонность и предупреждения;
- обложку, описание, publisher и обязательную атрибуцию источников;
- immutable-версию опубликованного содержимого.

Route остаётся одним непрерывным путём. Несвязанные геометрии можно
импортировать и объединять только после явного решения разрывов; набор
независимых маршрутов публикуется отдельными объектами.

### Доступ и видимость

Route Create-блок не является публичным инструментом. Его видят только
аутентифицированные `Creator`/`Admin` с выданными capabilities:

```text
create_route | publish_route | manage_route | archive_route
```

Capabilities проверяются при открытии, сохранении, Preview и публикации.
Прямая ссылка не обходит guard. Отдельная роль «доверенный автор» не
создаётся: доверие выражается capability set и audit trail.

После публикации Route становится каталожным объектом. Он появляется только в
результатах Search/Smart Search и на карте активной поисковой выдачи согласно
visibility и market rules; до поискового запроса все Route на основной карте
не загружаются.

### Разделение картографических контуров

| Контур | Карта | Назначение |
|---|---|---|
| Закрытый редактор | MapLibre + лицензированные OSM-derived tiles | тропы, поверхности, anchors и проверка geometry |
| Построение | собственный Valhalla/OpenRouteService adapter | соединение anchors по outdoor graph |
| Поиск и Details | Google Maps SDK | отображение сохранённой polyline |

Routing provider вызывается только при создании или новой редакции Route.
Search, Details и повторное открытие опубликованного Route никогда не
перестраивают путь и не вызывают routing/elevation API.

### Способы создания

Все способы являются равноправными входами одного редактора:

| Способ | Назначение | Источник истины до редактирования |
|---|---|---|
| Построение по точкам | путь по сети дорог и троп | anchors + routing options |
| Свободная линия | путь без доступного графа | подтверждённая polyline |
| GPS-запись | фактически пройденный путь | очищенная запись с provenance |
| Импорт GPX | перенос существующего трека | нормализованная polyline файла |
| Генерация по условиям | предложение пути по времени, дистанции и предпочтениям | принятый автором вариант |

После первого явного редактирования участка его текущая polyline становится
рабочей геометрией, а происхождение сохраняется в `SegmentSource`.

### Профили движения

`RoutingProfileCatalog` — версионируемый каталог, а не закрытый enum. Он может
содержать пешие, беговые, велосипедные, адаптивные, зимние и новые профили без
изменения Route Builder. Каждое определение включает:

- стабильный id и version;
- локализуемые name/description и icon token;
- модель оценки duration и difficulty;
- допустимые routing preferences и их defaults;
- safety limits и validation thresholds;
- mapping для каждого разрешённого routing adapter;
- capability requirements и fallback policy.

Routing preferences также расширяются декларативно. Примеры: предпочитать или
избегать тип покрытия, ограничить уклон, исключить лестницы/паромы, выбрать
step-free путь, минимизировать автомобильный трафик. Редактор показывает
только поддержанные комбинации и объясняет несовместимость до построения.

### Конфигурируемые границы

| Параметр | Правило |
|---|---|
| Минимальная дистанция публикации | задаётся `RouteProductConfig` |
| Максимальная дистанция и длительность | зависят от profile и safety policy |
| Anchors, waypoints и geometry points | лимиты backend capability/config |
| Размер импортируемого файла | лимит `RouteImportConfig` |
| Точность публикуемой geometry | `RouteGeometryEncodingPolicy` |
| Локальная история undo/redo | memory-aware лимит с гарантированным минимумом |
| Единицы хранения | метры, секунды, метры высоты |
| Единицы отображения | локаль и пользовательские настройки |

Форма, редактор, Preview, validator и publish читают одну версию config.
Числовые границы не дублируются в UI, контроллерах или правилах валидации.

### Принцип полноты

Документ описывает целевое поведение действующего продукта. Порядок
реализации в §16 определяет зависимости между частями, но не сокращает
продуктовый контракт.

---

## §2. Термины и инварианты

| Термин | Значение |
|---|---|
| Anchor | опорная точка, управляющая топологией и геометрией |
| Segment | участок Route между двумя anchors |
| Polyline | упорядоченный набор координат segment |
| Waypoint | пользовательская точка, связанная с anchor или segment |
| Source | происхождение геометрии участка |
| Revision | монотонная версия изменяемого состояния |
| Track stats | производные distance, ascent, descent и duration |
| Search projection | облегчённое представление Route для поисковой выдачи |

Инварианты:

1. Route Builder принадлежит feature `create` и подключается к общему
   config-driven движку через `RouteMapBuilderSection`.
2. Presentation не выполняет расчёты и не вызывает provider напрямую.
   Геометрия, показатели, валидация и оркестрация живут в domain/application.
3. Runtime работает с типизированным `RouteSectionData`.
   `sectionData['route_map']` — только сериализованное представление mapper.
   `draftId`, publisher, общая revision, sync и основание published version
   принадлежат общему Create draft envelope и не дублируются внутри Route.
4. Каждый segment хранит source и provenance. Ошибка, импорт, GPS, свободная
   линия и успешное построение никогда не смешиваются в один boolean.
5. Waypoint data вводятся пользователем; `distanceFromStartM` и расстояние до
   нити всегда производные. Проекция сначала использует сохранённый
   `segmentId`. Километры или мили существуют только в отображении.
6. Черновик, уже полученная geometry и локальные правки сохраняются,
   восстанавливаются и экспортируются без сети. Операции, которым нужны tiles,
   routing или elevation, явно переходят в недоступное/retryable состояние и
   не имитируют успешный результат.
   Недоступность provider не блокирует работу и не меняет геометрию молча.
7. Все связи идут по id. Постоянные id создаются на клиенте как ULID/UUID;
   временные `loc_*` заменяются до публикации.
8. Creator renderer, consumer renderer, tiles, routing, elevation и storage —
   отдельные зависимости за интерфейсами.
9. Market, язык, единицы, профиль и продуктовые лимиты приходят из config.
10. Published revision immutable. Любая правка опубликованного Route создаёт
    новый draft и следующую версию.
11. Любая автоматическая операция показывает результат до применения и
    становится одной обратимой пользовательской операцией.
12. Приложение не заявляет безопасность или проходимость пути на основании
    одного ответа provider. Автор видит происхождение и предупреждения.
13. Route section хранит только ids подготовленных media assets. Raw-файлы,
    санитайзинг, upload и lifecycle принадлежат общему media pipeline Create.
14. Квантование и упрощение публикуемой geometry выполняются над копией для
    публикации, не изменяя source geometry черновика без ведома автора.
15. Опубликованная geometry immutable и не перестраивается автоматически после
    обновления OSM. Проверка создаёт issue или новый draft-кандидат.
16. Consumer-контур получает только сохранённую geometry. Он не знает routing
    provider и не может инициировать построение.

---

## §3. Пользовательский поток

### Шаг 0 — Проверка доступа

Create Hub показывает Route только при `create_route`. Отсутствующая
`publish_route` разрешает готовить и передавать draft на проверку, но не
публиковать. Publisher выбирается из доступных автору `{type: user | page,
id}` и повторно проверяется перед publish.

### Шаг 1 — Основное

Автор задаёт:

- название, описание и обложку;
- publisher;
- активность из `RoutingProfileCatalog`;
- форму Route;
- предпочтения построения: покрытия, уклоны, паромы, лестницы, доступность,
  тип поверхности и другие поддерживаемые выбранным профилем параметры.

Профиль и форма можно изменить позднее. Если геометрия уже существует,
редактор до применения показывает, какие участки будут перестроены, а какие
сохранят исходную форму.

### Шаг 2 — Выбор исходной геометрии

Автор выбирает любое действие:

- построить по точкам;
- нарисовать свободную линию;
- начать или продолжить GPS-запись;
- импортировать GPX;
- сгенерировать варианты по условиям;
- открыть ранее сохранённый draft.

Способы можно комбинировать по участкам. Добавление второй геометрии предлагает
`Append`, `Insert`, `Replace` или `Cancel`; доступные варианты зависят от
топологии. Ни один существующий участок не удаляется без Preview и
подтверждения.

### Шаг 3 — Редактор трека

Основной экран содержит карту, elevation chart, список участков, панель
инструментов и живую сводку.

Доступные действия:

- add, move, reorder и delete anchor;
- drag-to-reroute;
- изменить способ построения выбранного segment;
- split и merge segments;
- trim начала или конца записи;
- сгладить выбранный GPS/freehand segment с Preview;
- `Close loop` и `Build return path`;
- Retry, Replace и Accept для fallback;
- редактировать geometry на карте или через доступный список координат;
- undo/redo до начала текущей сессии и восстановление последнего autosave.

Живая сводка показывает distance, auto/effective duration, ascent, descent,
минимальную и максимальную высоту, долю покрытий, долю direct/fallback и
актуальные предупреждения. Выбор точки на elevation chart подсвечивает её на
карте, и наоборот.

### Шаг 4 — Точки и условия

Tap по нити создаёт waypoint. Каталог типов версионируется и включает как
минимум:

```text
start | finish | viewpoint | water | wc | caution | rest | food |
parking | transport | shelter | crossing | custom
```

`start` и `finish` связаны с соответствующими anchors. Для loop они могут
указывать на один anchor, оставаясь разными семантическими точками.

Автор задаёт:

- category и criteria profile;
- difficulty и требуемый уровень подготовки;
- поверхности и маркировку по участкам или для Route целиком;
- доступность старта и финиша;
- BestTimeToVisit, сезонность и временные ограничения;
- versioned good-to-know ids;
- предупреждения с точкой или диапазоном километража;
- фотографии waypoint;
- ручную duration с обязательным пояснением при существенном расхождении.

Фотографии waypoint проходят общий media pipeline до загрузки: проверку
сигнатуры, удаление EXIF/GPS/device metadata, нормализацию ориентации и
подготовку доступного описания. Route section сохраняет только `photoIds` и
не получает raw path, имя файла или upload credentials.

### Шаг 5 — Проверка

Preview повторяет опубликованный Route:

- обложка, publisher и дата актуальности;
- карта с segment styles и waypoint;
- elevation chart;
- distance, duration, difficulty, shape, ascent и descent;
- старт, финиш, доступ и точки по километражу;
- поверхности, условия, предупреждения и атрибуция;
- полнота локализуемых полей.

Проверка разделяет ошибки, которые блокируют публикацию, и предупреждения,
которые автор должен просмотреть. Каждое сообщение ведёт к конкретному полю,
segment или waypoint и предлагает допустимое действие.

### Шаг 6 — Публикация и дальнейшие изменения

Publish повторно валидирует текущую revision, заменяет временные ids,
загружает media, фиксирует provider references и отправляет immutable snapshot
с idempotency key. Повторный tap или сетевой retry не создаёт дубль.

После публикации автор может:

- создать новую revision из опубликованной версии;
- обновить предупреждения и условия;
- сравнить geometry и метаданные версий;
- отменить draft, не затрагивая опубликованную версию;
- опубликовать новую версию;
- восстановить прежнюю версию как новый draft;
- архивировать Route или вернуть его в публикацию согласно permissions.

---

## §4. Построение и редактирование

### Построение по точкам

Первый tap создаёт anchor. Каждый следующий создаёт новый anchor и pending
segment. `RoutingService` строит участок по выбранному profile и options.

Автор может закрепить routing options на весь Route либо переопределить их для
segment. Переопределение хранится явно и отображается в инспекторе участка.

### Свободная линия

Во время рисования координаты собираются с частотой, зависящей от масштаба,
затем локально очищаются от дрожания и упрощаются для Preview. До применения
показываются исходная и нормализованная линии, изменение distance и число
точек. Автор может принять результат, изменить tolerance или отменить.

Свободная линия получает source `freehand`, не выдаётся за путь по графу и
показывается отдельным стилем. Начало и конец становятся anchors; длинная
линия получает дополнительные editable anchors без изменения своей формы.

### Намеренный прямой участок

Режим действует на следующий segment или на выбранный диапазон. Segment
строится прямой линией с source `intentionalDirect` и отображается пунктиром.
Перед применением автор видит предупреждение, что линия не подтверждает
наличие прохода.

### Drag-to-reroute

Drag выбранного segment:

1. проецирует точку касания на polyline;
2. вставляет новый anchor;
3. заменяет один segment двумя;
4. перестраивает только выбранную часть.

Для GPX, GPS и freehand исходная форма вне выбранного диапазона сохраняется.
Редактор показывает Preview и новое происхождение изменяемого участка.

### Операции с anchors и segments

- перенос anchor перестраивает только смежные routed/generated segments;
- direct segments пересчитываются локально;
- imported/recorded/freehand segments меняются только после Preview;
- split сохраняет provenance обоих результатов;
- merge совместимых sources объединяет polylines без изменения формы;
- merge разных sources требует выбрать итоговый способ построения;
- удаление anchor объединяет соседей одной атомарной операцией;
- удаление segment с waypoint сначала показывает Preview новых привязок;
- waypoint можно перепроецировать на выбранный соседний segment, явно оставить
  вне нити либо отменить удаление; молчаливое удаление waypoint запрещено;
- если однозначная перепроекция невозможна, waypoint получает состояние
  `unresolved` и блокирует публикацию до решения автора;
- удаление первого/последнего anchor переносит start/finish после confirmation;
- при результате менее двух anchors draft сохраняется, но не публикуется.

### Операции с формой

- `Close loop` создаёт явный segment `last → first` выбранным способом;
- `Build return path` предлагает `Mirror outward path` или отдельное построение;
- mirror создаёт reverse sequence с `derivation=mirrored`;
- фактически записанное или импортированное обратное плечо сохраняется как
  собственная original geometry;
- смена profile перестраивает только segments, для которых разрешён reroute;
- изменение shape/profile/options после появления geometry всегда показывает
  affected segments и является одной undo operation.

### Генерация по условиям

Автор задаёт старт, форму, целевую distance или duration, допустимый диапазон,
profile и routing preferences. `RouteGenerationService` возвращает несколько
различимых вариантов с geometry, показателями, ограничениями и provenance.

Генератор:

- не применяет вариант автоматически;
- объясняет существенные отклонения от условий;
- не создаёт Route из частичного или устаревшего ответа;
- позволяет закрепить segment и перегенерировать остальные;
- после принятия сохраняет результат как source `generated`;
- переводит ручное изменение segment в source `routed`, `freehand` или direct,
  сохраняя ссылку на исходную генерацию в audit metadata.

### Undo/redo и транзакционность

- пользовательская команда применяется атомарно;
- async provider response не создаёт отдельную команду;
- undo увеличивает `geometryRevision`, поэтому поздний ответ не возвращает
  отменённое изменение;
- redo очищается после новой команды;
- история ограничивается по памяти, но гарантирует минимум из config;
- autosave фиксирует только завершённые команды;
- после аварийного закрытия предлагается последняя целая revision.

---

## §5. GPS-запись

### Состояния

```text
idle | requestingPermission | recording | paused | recovering |
processing | completed | failed
```

Переходы управляются `RouteRecordingController`. UI не обращается к platform
location API напрямую.

### Сбор данных

- foreground и background permissions запрашиваются по необходимости и с
  объяснением цели;
- запись не начинается до явного действия автора;
- сохраняются coordinate, elevation при наличии, accuracy, monotonic time и
  признак источника;
- частота адаптируется к скорости, accuracy и battery state в пределах config;
- точки с неприемлемой accuracy не теряются молча: они исключаются из рабочей
  линии, но учитываются в quality summary;
- pause не соединяет разрыв автоматически;
- restart восстанавливает активную запись из локального журнала;
- остановка создаёт Preview до добавления geometry в draft.

### Обработка записи

Pipeline работает над локальной копией:

1. отделяет паузы, телепорты и недостоверные points;
2. определяет gaps;
3. сглаживает шум без срезания реальных поворотов;
4. считает raw stats до display simplification;
5. предлагает trim начала/конца и решение каждого gap;
6. удаляет timestamps из публикуемого payload;
7. создаёт source `recordedGps` и quality issues.

Для gap доступны `Keep gap`, `Connect as direct`, `Route between` и
`Split import`. Публикация непрерывного Route требует решить каждый gap.

### Приватность и безопасность записи

- точная запись хранится локально encrypted-at-rest средствами платформы;
- координаты не попадают в analytics, logs, notifications или crash data;
- экран и системный indicator явно показывают активную запись;
- автор может удалить незавершённую запись и локальный recovery journal;
- начало и конец можно автоматически скрыть на настраиваемый радиус только
  через Preview; опубликованная geometry никогда не обрезается без ведома
  автора;
- battery warning не останавливает запись автоматически;
- при отзыве permission запись безопасно приостанавливается и сохраняется.

---

## §6. Доменная модель

```dart
class RouteSectionData {
  int geometryRevision;
  RouteShape shape;                    // oneWay | loop | outAndBack
  String? turningAnchorId;             // required for outAndBack
  String routingProfileId;             // versioned catalog id
  int routingProfileVersion;
  RoutingPreferences preferences;
  List<RouteAnchor> anchors;
  List<RouteSegment> segments;
  List<RouteWaypoint> waypoints;
  RouteConditions conditions;
  List<RouteSourceIssue> sourceIssues;
  TrackStats stats;                    // derived cache
}

class RouteAnchor {
  String id;
  GeoPoint point;
}

class RouteSegment {
  String id;
  String fromAnchorId;
  String toAnchorId;
  int order;
  SegmentSource source;
  SegmentDerivation derivation;
  RoutingPreferences? preferencesOverride;
  List<GeoPoint> polyline;
  SegmentRawStats? rawStats;
  double distanceM;
  int? ascentM;
  int? descentM;
  int? providerDurationSec;
  bool needsReview;
  RoutingFailureCode? fallbackReason;
  ProviderReference? provider;
  SourceProvenance provenance;
  int geometryRevision;
}

enum SegmentSource {
  routed,
  generated,
  freehand,
  recordedGps,
  importedGpx,
  intentionalDirect,
  fallbackDirect,
}

enum SegmentDerivation { original, mirrored }

class SourceProvenance {
  String sourceId;
  int sourceRevision;
  DateTime createdAt;
  String? parentSegmentId;
  String? algorithmVersion;
}

class ProviderReference {
  String code;
  String attribution;
  String licenseId;
  String dataVersion;
}

class RouteWaypoint {
  String id;
  String? anchorId;
  String? segmentId;
  GeoPoint point;
  String typeId;                       // versioned taxonomy id
  WaypointTrackState trackState;
  double? distanceFromStartM;          // derived; null outside track
  double? distanceFromTrackM;          // derived
  String? note;
  List<String> photoIds;
  AccessInfo? access;
}

enum WaypointTrackState { onTrack, offTrackConfirmed, unresolved }

class RouteConditions {
  String? difficultyId;
  List<String> surfaceIds;
  bool? isMarked;
  BestTimeToVisit? bestTime;
  List<String> goodToKnowIds;
  DateTime? verifiedAt;
  ManualDuration? manualDuration;
}

class ManualDuration {
  int seconds;
  String? reason;                      // required above deviation threshold
}

class RouteSourceIssue {
  String id;
  String code;                         // versioned taxonomy code
  String? segmentId;
  IssueSeverity severity;
  Map<String, num> safeMetrics;
}

class TrackStats {
  int geometryRevision;
  String calculationModelId;
  int calculationModelVersion;
  double distanceM;
  int? ascentM;
  int? descentM;
  double? minElevationM;
  double? maxElevationM;
  int autoDurationSec;
  int effectiveDurationSec;
  double directDistanceM;
  double fallbackDistanceM;
  Map<String, double> surfaceDistanceM;
}

class RouteGeometryEncodingPolicy {
  String id;
  int version;
  double coordinateQuantizationM;
  double maxSimplificationErrorM;
  int maxPublishedPoints;
}
```

`GeoPoint` содержит latitude, longitude и optional elevation. Все числа
проверяются на конечность и допустимый диапазон.

### Топология

Порядок прохождения задаёт `RouteSegment.order`; anchor не имеет независимого
порядкового номера и может встречаться в цепочке несколько раз.

| Shape | Инвариант ordered segment chain |
|---|---|
| `oneWay` | первый `fromAnchorId` отличается от последнего `toAnchorId` |
| `loop` | последний `toAnchorId` равен первому `fromAnchorId` |
| `outAndBack` | цепочка возвращается к старту и проходит через `turningAnchorId` |

У фактического обратного плеча могут быть собственные anchors и geometry.
`outAndBack` требует общий start/finish и одну явно выбранную точку разворота,
но не требует геометрического зеркалирования или одинакового числа участков.

### Provenance

`source` отвечает на вопрос, как получен текущий участок. `derivation`
фиксирует зеркальную копию, а `provenance` связывает результат с исходной
операцией. Поэтому ошибка сети, решение автора, импорт и запись не теряют
смысл после сохранения, миграции или публикации.

---

## §7. Сервисы и конкурентные операции

```dart
abstract class RoutingService {
  Future<RouteResult> routeBetween(RouteRequest request);
}

abstract class RouteGenerationService {
  Future<List<GeneratedRouteCandidate>> generate(GenerationRequest request);
}

abstract class ElevationService {
  Future<ElevationResult> elevationFor(ElevationRequest request);
}
```

Provider warnings преобразуются в versioned `RouteSourceIssue`. Raw provider
message не сохраняется и не используется как пользовательский текст.

Профиль приложения не обязан совпадать с provider profile. Adapter выполняет
явное versioned mapping и возвращает применённые capabilities/options. Если
provider проигнорировал preference, автор видит предупреждение до принятия.

### Защита от устаревших ответов

Каждая команда над геометрией увеличивает `geometryRevision`. Применение
успешного ответа для текущей revision и пересчёт stats её не увеличивают.

Ответ применяется, только если:

- draft и segment существуют;
- `geometryRevision`, request id и endpoints совпадают;
- profile/options не изменились;
- результат не был заменён, принят вручную или отменён.

Поздний ответ игнорируется без toast и регистрируется только безопасной
метрикой. Pending operations логически отменяются при undo, удалении,
перестроении, замене geometry и закрытии редактора.

### Сетевое поведение

- timeout, concurrency, retry и backoff задаются remote config по operation;
- queued request повторно валидируется перед отправкой;
- retry разрешён только для транзиентных ошибок и всегда bounded;
- idempotency key используется для мутаций;
- cache key включает нормализованный запрос, profile/options/data version;
- cache не содержит user id/draft id и применяется только по license policy;
- circuit breaker отключает деградировавшего provider;
- health-based adapter может выбрать совместимый provider без изменения
  доменного контракта и с сохранением новой attribution.

Типизированные ошибки:

```text
offline | timeout | quota | unauthorized | noRoute | unsupportedOption |
invalidResponse | cancelled | storageFull | permissionDenied | unknown
```

### Fallback

При невозможности построения:

1. существующая geometry не меняется;
2. pending segment получает различимое состояние ошибки;
3. автору доступны Retry, Choose another method и Cancel;
4. `Accept direct` явно создаёт `fallbackDirect` с причиной;
5. принятие является одной undo operation;
6. segment остаётся `needsReview=true`, пока автор отдельно не подтвердит
   намеренный direct или не заменит его.

Приложение не создаёт fallback автоматически так, будто это успешный путь.

---

## §8. Импорт и экспорт GPX

### Безопасный вход

- `.gpx`, XML GPX 1.0/1.1;
- размер и число source points задаются `RouteImportConfig`;
- DTD, external entities и network resolution запрещены;
- NaN/Infinity, координаты вне диапазона и пустые candidates отклоняются;
- parsing и нормализация выполняются с bounded memory/time;
- исходный файл никогда не изменяется.

### Выбор и объединение

Парсер перечисляет все непустые `<trk>` и `<rte>` с именем, distance,
duration при наличии, point count, bounds и quality summary.

Автор может:

- импортировать один candidate;
- импортировать несколько candidates в заданном порядке;
- соединить endpoints через routing, direct или свободную линию;
- оставить candidates отдельными Route;
- отменить импорт.

Каждый `<trkseg>` сохраняет gap boundary. Endpoints на расстоянии в пределах
config tolerance могут быть соединены после подтверждения. Больший gap всегда
требует явного решения.

Отдельные `<wpt>` показываются на Preview и могут быть:

- импортированы как Route waypoint с сопоставлением типа;
- привязаны к ближайшему segment;
- оставлены вне нити с предупреждением;
- пропущены по одному или все вместе.

Неподдерживаемые extension fields перечисляются до импорта и не попадают в
published payload.

### Определение формы

- `oneWay` сохраняет порядок points;
- `loop` использует существующее замыкание либо предлагает способ закрытия;
- `outAndBack` определяет turning region и различает зеркальный путь и
  фактическую запись обратно;
- низкая уверенность никогда не приводит к автоматической обрезке;
- выбранная автором форма сохраняется вместе с confidence и решением импорта.

### Нормализация

1. Провалидировать XML и coordinates.
2. Выделить candidates, gaps и waypoint.
3. Удалить точные дубликаты, сохранив start/end и границы gaps.
4. Найти аномалии timestamps/elevation/speed на raw points.
5. Выбрать editable anchors без изменения исходной формы.
6. Посчитать raw distance/elevation stats до simplification.
7. Упростить только display geometry с сохранением topology и error bound.
8. Создать ordered `importedGpx` segments и provenance.
9. Запросить недостающую elevation только после согласия на внешний обмен.
10. Показать итоговый Preview и применить импорт одной транзакцией.

После редактирования участка его raw stats инвалидируются и пересчитываются по
новой geometry. Остальные imported segments сохраняют raw stats и форму.

### Экспорт

Автор может экспортировать текущий draft или опубликованную version в GPX:

- `<trk>` содержит полную упорядоченную geometry;
- Route waypoints экспортируются как `<wpt>`;
- elevation включается только при наличии достоверных данных;
- timestamps не синтезируются;
- private notes, internal ids, issues и provider credentials исключаются;
- attribution/license metadata добавляются согласно provider policy;
- экспорт доступен без сети для локально сохранённой geometry.

### Конфиденциальность импорта

Filename, author/device metadata, timestamps и extensions не публикуются и не
попадают в telemetry. Timestamps используются только локально для расчётов и
аномалий, если автор не выбрал их сохранение в личном исходнике. Временная
копия приложения удаляется после commit/cancel импорта.

---

## §9. Поисковая проекция и пользовательское отображение

Publish создаёт два согласованных payload с одним `routeId`, `versionId` и
`geometryHash`:

```dart
class RouteSearchProjection {
  String routeId;
  String versionId;
  String marketId;
  GeoPoint startPoint;
  GeoBounds bounds;
  String overviewEncodedPolyline;
  double distanceM;
  int effectiveDurationSec;
  int? ascentM;
  String routingProfileId;
  String difficultyId;
  List<String> categoryIds;
  List<String> searchTokens;
}

class PublishedRouteGeometry {
  String routeId;
  String versionId;
  String geometryHash;
  String fullEncodedPolyline;
  List<PublishedRouteSegment> segments;
  List<PublishedRouteWaypoint> waypoints;
  ElevationProfile? elevationProfile;
  List<ProviderReference> providers;
  int encodingPolicyVersion;
}
```

### Search

- обычная выдача читает metadata без полной geometry;
- карта поисковой выдачи запрашивает projections только для активного viewport;
- `overviewEncodedPolyline` имеет отдельный строгий point/error budget;
- одинаковый `routeId` дедуплицируется между страницами и viewport queries;
- полная geometry загружается только при выборе Route или открытии Details;
- выход Route из viewport освобождает renderer objects и memory cache;
- фильтры используют category/profile/distance/duration/difficulty, а не
  анализ полной polyline на клиенте.

### Google Maps rendering

Consumer adapter декодирует сохранённую polyline и создаёт Google Maps
`Polyline`; он не обращается к routing service. Route может проходить по тропе,
которой нет на подложке Google. В этом случае линия остаётся точной, а UI
показывает нейтральную подсказку, что часть троп может отсутствовать на базовой
карте.

OSM/provider attribution Route показывается рядом с Google attribution и не
заменяет её. Tap по overview открывает карточку Route; Details использует
full geometry и waypoint.

### Обновления картографических данных

Обновление OSM graph запускает фоновую проверку опубликованных Route, но не
меняет их. Найденный разрыв, restriction или заметное расхождение создаёт
`RouteSourceIssue` и draft-кандидат. Только автор с `manage_route` может
просмотреть diff и выпустить новую immutable version.

---

## §10. Расчёты и аналитика маршрута

### Дистанция

Для routed/direct/generated segment distance считается по сохранённой
polyline. Для untouched GPX/GPS используется raw distance до simplification.
После изменения участка его показатели полностью пересчитываются.

Общая distance — сумма ordered segments. Общие endpoints не учитываются
дважды. Mirror является самостоятельным обратным участком.

### Высота

Ascent/descent считаются после фильтрации spikes по versioned calculation
model. Приоритет источников:

1. достоверные raw elevation;
2. self-hosted elevation dataset;
3. разрешённый elevation provider;
4. `unknown`.

Отсутствие elevation не превращается в ноль. UI скрывает недостоверные chips,
объясняет причину и не рисует ложный плоский профиль.

### Длительность

`RouteEstimatePolicy` выбирает versioned model по routing profile, distance,
elevation, surfaces, direct share и доступным ограничениям. Каталог profiles
задаёт базовую скорость, влияние уклона и применимые коэффициенты; значения не
зашиваются в presentation.

Приоритет автоматической оценки:

1. локальная versioned model с полным набором данных;
2. та же model с явно отмеченными missing inputs;
3. provider estimate как дополнительный сигнал, если разрешено profile;
4. unavailable, если корректная оценка невозможна.

Ручная duration не удаляет автоматическую. Пользовательский ввод хранится
единым `ManualDuration` в conditions; `TrackStats` содержит только auto и
effective. `effectiveDurationSec = manualDuration?.seconds ?? autoDurationSec`.
Reason обязателен, если отклонение превышает threshold текущего profile.

### Поверхности и сложность

Поверхности агрегируются из подтверждённых provider data и ручной разметки.
Ручная разметка имеет приоритет и provenance. Unknown distance показывается
отдельно, а не распределяется между известными типами.

Difficulty рассчитывается как рекомендация из profile, distance, elevation,
surface и technical attributes. Автор выбирает итоговое taxonomy value;
расхождение с рекомендацией создаёт review warning, но не скрытую замену.

### Пересчёт

Stats пересчитываются после принятой geometry command с debounce из config.
Cache действителен только при совпадении `geometryRevision`, model version и
всех input hashes, включая `ManualDuration`. Background recalculation не
перезаписывает пользовательский ввод.

---

## §11. Валидация

Правила подключаются декларативно через Route config. Общий form engine
проверяет capabilities, publisher, category, media references и локализуемые
поля; Route validator отвечает за геометрию и маршрутные данные.

### Блокирует публикацию

1. Обязательные общие поля заполнены и publisher доступен автору.
2. Profile, shape и options имеют поддерживаемые versioned ids.
3. Есть минимум два anchors; ids уникальны; coordinates валидны.
4. Ordered topology соответствует shape.
5. Каждый segment имеет geometry, согласованные endpoints и provenance.
6. Distance/duration находятся в границах актуального config/profile.
7. Loop замкнут; outAndBack содержит turning region и обратный путь.
8. Start/finish связаны с допустимыми anchors и содержат required access data.
9. Каждый waypoint ссылается на существующий anchor/segment либо явно
   подтверждён как расположенный вне нити.
10. Все gaps разрешены.
11. Нет pending/failed operation, влияющей на публикуемый snapshot.
12. Нет повреждённой section или незавершённой migration.
13. Geometry/media укладываются в актуальный backend contract.
14. Все временные ids заменены.
15. Provider license допускает публикацию результата и attribution сохранена.
16. Published request содержит текущую content/geometry revision.
17. Ни один waypoint не находится в состоянии `unresolved`.
18. Все обязательные media assets sanitized и находятся в допустимом для
    publish состоянии.
19. Published geometry и производные показатели соответствуют одной версии
    `RouteGeometryEncodingPolicy`.

### Требует просмотра

1. Waypoint расположен дальше config threshold от segment.
2. Есть геометрический разрыв или резкий скачок без подтверждённого direct.
3. Импорт/запись содержит speed/elevation/accuracy anomaly.
4. Direct или fallback превышает долю, заданную safety policy.
5. Остался `fallbackDirect` или low-quality recorded segment.
6. Нить самопересекается либо повторяет участок неоднозначно.
7. Manual duration существенно отличается от auto.
8. Elevation, surface или accessibility data неполны.
9. Difficulty существенно отличается от рекомендации.
10. Условия давно не подтверждались либо содержат сезонное ограничение.
11. Generated result отклоняется от заданной distance/duration.
12. Часть routing preferences не поддержана использованным adapter.
13. Квантование или упрощение заметно меняет geometry, stats либо положение
    waypoint относительно исходного draft.

Warnings имеют стабильные ids, severity, связь с полем/segment/waypoint и
действие `Fix`, `Review` или `Accept`. Повторная validation не создаёт
дубликаты. Принятие warning фиксирует code, revision и author id, но не
удаляет сам факт из publish audit.

### Лимиты и деградация

Лимиты файла, anchors, waypoint, geometry, media, undo и local storage
приходят из versioned config. При достижении soft limit редактор предлагает
simplify/split/export. Hard limit блокирует только конкретную операцию, не
мешая сохранить, экспортировать или исправить draft.

---

## §12. Хранение, синхронизация и версии

`RouteSectionDataMapper` сериализует модель в data общего section envelope
`route_map`. Envelope владеет `sectionSchemaVersion` и `sectionRevision`;
общий Create draft владеет `draftId`, publisher, `contentRevision`, sync и
`basedOnPublishedVersionId`. Общая draft schema и route section schema
мигрируются независимо.

### Локальное хранение

1. autosave выполняется после завершённой команды и при уходе приложения в
   background;
2. запись атомарна: новая revision заменяет старую только после checksum;
3. последний целый snapshot и recovery journal хранятся отдельно;
4. storage failure видим автору и не выдаётся за успешное сохранение;
5. raw map не проходит дальше data boundary;
6. mapper имеет round-trip/fixture tests для каждой поддерживаемой schema;
7. unknown enum изолирует только несовместимую часть и блокирует publish;
8. derived data после migration пересчитываются;
9. удаление повреждённой geometry требует confirmation и не удаляет общие
   поля draft.

### Синхронизация

- каждая запись использует base revision и idempotency key;
- одинаковые revisions дедуплицируются;
- изменения общих полей могут merge по field revision;
- параллельные изменения geometry никогда не объединяются автоматически;
- conflict screen показывает обе версии, дату, устройство и Preview diff;
- автор выбирает local, remote или сохраняет обе как отдельные drafts;
- queued media и draft sync имеют независимые retry/status;
- logout не удаляет несинхронизированный draft без явного решения.

### Публикация и версии

`PublishedRouteVersion` immutable и содержит:

- `routeId`, `versionId`, version number и previousVersionId;
- publisher reference и author audit reference;
- normalized content snapshot;
- geometry payload и content hash;
- config/taxonomy/calculation model versions;
- provider references и attribution;
- createdAt, publishedAt и moderation status.

Редактирование опубликованного Route всегда создаёт draft от конкретной
version. Publish использует optimistic concurrency: если появилась более новая
version, автор сначала сравнивает изменения. Rollback создаёт следующую
version из выбранного snapshot, сохраняя непрерывную историю.

Архивирование меняет статус Route, а не удаляет версии. Безвозвратное удаление
регулируется отдельной retention/privacy policy и permissions.

### Модерация и безопасность публикации

- publish создаёт версию в состоянии, определённом moderation policy;
- статус `processing | published | changesRequested | rejected | hidden`
  доступен автору вместе со стабильными reason codes;
- замечание связывается с полем, waypoint, segment или Route целиком;
- модерация никогда не редактирует geometry или авторский текст молча;
- исправление создаёт draft от проверенной version и сохраняет audit trail;
- срочный safety report может временно скрыть опубликованную version, не
  удаляя историю и личный draft автора;
- повторная публикация неизменённого content hash не создаёт новую version;
- permissions разделяют создание, публикацию, модерацию, архивирование и
  восстановление.

---

## §13. Карты, провайдеры и эксплуатация

Выбор creator renderer, OSM-derived tiles, routing, elevation, attribution,
privacy и fallback ownership фиксируется Accepted ADR. Целевая topology:
MapLibre в закрытом редакторе, self-hosted outdoor routing для Латвии и Google
Maps SDK в Search/Details. Domain contracts остаются provider-neutral.

### Точность публикуемой геометрии

`RouteGeometryEncodingPolicy` задаёт точность в метрах, а не числом знаков
после запятой. Одна version policy определяет coordinate quantization,
максимальную ошибку simplification и предел published points. Значения
выбираются по назначению Route, требованиям provider/backend, размеру payload
и privacy policy; UI не содержит собственных округлений.

Publish pipeline:

1. создаёт копию current geometry;
2. сохраняет обязательные endpoints, anchors, turning point и gap boundaries;
3. применяет quantization и topology-safe simplification;
4. повторно проверяет непрерывность и shape;
5. перепроецирует waypoint на published segments;
6. пересчитывает distance, elevation summaries и
   `distanceFromStartM` по published geometry;
7. показывает Preview diff, если изменение превышает review threshold;
8. сохраняет policy id/version и итоговый content hash в published version.

Draft source geometry остаётся неизменной. GPX-export draft использует
текущую локальную geometry; экспорт published version воспроизводит именно
опубликованную geometry. Это исключает расхождение между карточкой, stats и
скачиваемым треком.

### Production topology

| Компонент | Требование |
|---|---|
| Creator map adapter | MapLibre behind interface, licensed OSM-derived tiles |
| Routing adapter | self-hosted Valhalla/OpenRouteService candidate after ADR |
| Consumer map adapter | Google Maps polyline from stored geometry only |
| Backend proxy | credentials, authorized-author rate limits, cache policy, audit |
| Publish projection | overview/full geometry with matching version/hash |
| Config service | profiles, limits, feature availability, kill switches |
| Observability | safe metrics, SLOs, alerts без точной geometry |

Публично извлекаемый SDK identifier допустим только после security review и
ограничения по platform/package/API. Routing/elevation credentials остаются
на backend и не передаются клиенту. Секреты не хранятся в приложении, git,
fixtures, analytics или logs.

### Надёжность

Для routing, generation, elevation, draft sync, projection и publish
определяются отдельные SLI/SLO:

- success rate без пользовательских отмен;
- latency p50/p95/p99;
- stale response rejection;
- crash-free operations;
- autosave recovery success;
- publish idempotency;
- provider quota/circuit-breaker state;
- search projection/full geometry consistency.

Alert threshold и error budget фиксируются в runbook. Деградация routing или
elevation не лишает автора доступа к сохранённому draft, freehand, GPS, GPX и
export. Она не влияет на просмотр уже опубликованных Route.

### Атрибуция и лицензии

- каждая карта показывает обязательную кликабельную attribution;
- `ProviderReference` сохраняется на segment и в published version;
- adapter не позволяет сократить обязательный текст;
- export соблюдает license/attribution policy;
- смена provider не переписывает provenance существующей geometry;
- обновление условий provider проходит legal review до включения config.

Google Routes API не является источником сохраняемой geometry по стандартному
контракту. Geometry публикуется только из authored GPS/GPX/freehand data либо
из provider/self-hosted engine, условия которого явно разрешают долговременное
хранение и повторное отображение результата.

### Конфиденциальность платформы

- точная geometry, waypoint и адрес старта отсутствуют в telemetry/logs;
- внешняя передача coordinates происходит только по раскрытой privacy policy;
- server cache не связывает geometry с user без продуктовой необходимости;
- retention, encryption, access audit и deletion определены для drafts,
  recordings, published versions и recovery data;
- support tooling показывает минимально необходимую информацию и требует
  capability/audit trail.

Точность опубликованной geometry не считается механизмом анонимизации.
Скрытие чувствительного начала/конца выполняется отдельной явной операцией с
Preview и никогда не подменяется техническим округлением координат.

### Доступность

- drag/gesture не являются единственным способом действия;
- anchors, segments и waypoint доступны через упорядоченные списки;
- sources различаются рисунком линии, иконкой, текстом и семантикой;
- карта, elevation chart и validation summary имеют screen-reader labels;
- touch targets, contrast, focus order и dynamic text соответствуют design
  system;
- все критические действия доступны с клавиатуры и assistive technology;
- attribution не перекрывается overlays и доступна без точного жеста.

### Производительность

- editor открывает локальный draft без ожидания сети;
- pan/zoom и drag сохраняют целевую плавность на поддерживаемых устройствах;
- тяжёлые parsing, simplification и calculations выполняются вне UI thread;
- geometry рендерится по уровням детализации без изменения stored source;
- memory pressure уменьшает display detail и history, но не source geometry;
- budget startup, interaction latency, memory и battery задаётся performance
  baseline и проверяется на representative fixtures.

---

## §14. Тестовая стратегия

### Unit и property-based

- topology всех shapes и операций split/merge/mirror;
- projection waypoint на самопересекающуюся нить;
- delete segment с reproject/off-track/unresolved waypoint outcomes;
- stale response и command revisions;
- calculations, missing data и cache invalidation;
- validation deduplication и config boundaries;
- mapper round-trip/migrations;
- GPX parser, hostile XML, gaps и anomaly detection;
- GPS filtering/recovery;
- idempotency и conflict decisions.
- `ManualDuration` и effective duration при смене calculation model;
- geometry encoding: topology preservation, error bound и повторный расчёт.

Property-based tests генерируют geometry с дубликатами, экстремальными
координатами, разрывами, самопересечениями и разной длиной. Инварианты
topology, id uniqueness, finite stats и round-trip должны сохраняться.

### Contract и integration

- creator map, routing и consumer map adapters проходят свои contract suites;
- provider fixtures не используют live network в обычном test run;
- publish проверяется с media upload, retry и concurrent version;
- waypoint media проверяются на signature, EXIF/GPS strip и id-only boundary;
- search projection проверяется на pagination, viewport, deduplication и LOD;
- background GPS проверяется на permission revoke, restart и battery state;
- sync проверяется на airplane mode, reconnect и geometry conflict.

### Widget, golden и accessibility

- все способы создания и empty/error/loading states;
- Preview diff перед destructive transform;
- elevation-map bidirectional selection;
- warnings с переходом к источнику;
- large text, screen reader, contrast и keyboard navigation;
- narrow/wide screens и поддерживаемые локали.

### End-to-end

Критические пути:

1. построить по точкам → добавить waypoint → опубликовать;
2. записать GPS в background → восстановить → очистить → опубликовать;
3. импортировать multi-track GPX → решить gaps/wpt → экспортировать;
4. потерять сеть во время редактирования → локально сохранить целостный draft →
   восстановить связь и синхронизировать без потери revision;
5. сгенерировать варианты → закрепить segment → изменить → опубликовать;
6. изменить опубликованный Route → разрешить conflict → выпустить новую version.

---

## §15. Критерии готовности продукта

| ID | Проверяемый результат | Покрытие |
|---|---|---|
| RB-AC-01 | Все пять способов создания приводят к одной валидной typed model | unit + integration |
| RB-AC-02 | `oneWay`, `loop`, `outAndBack` сохраняют topology после edit, save и restore | property + mapper |
| RB-AC-03 | Profile/options берутся из versioned catalog и не зашиты в UI | boundary + widget |
| RB-AC-04 | Свободная линия показывает нормализацию до применения и сохраняет provenance | unit + widget |
| RB-AC-05 | GPS переживает pause, background, restart и permission revoke без скрытой потери | platform integration |
| RB-AC-06 | GPX импортирует несколько tracks и waypoint только через явные решения автора | parser + widget |
| RB-AC-07 | GPX export не раскрывает private/internal data и восстанавливает geometry/waypoint | round-trip + privacy |
| RB-AC-08 | Search загружает overview только для активной выдачи/viewport, а full geometry — после выбора Route | end-to-end |
| RB-AC-09 | Generation возвращает сравнимые варианты и ничего не применяет автоматически | contract + widget |
| RB-AC-10 | Late provider response не меняет отменённую или новую revision | concurrency unit |
| RB-AC-11 | Fallback различим, требует явного принятия и остаётся reviewable | unit + widget |
| RB-AC-12 | Waypoint сохраняет id-связь и корректный `distanceFromStartM` после reroute/split/merge/delete; удаление не уничтожает waypoint молча | property + mapper + widget |
| RB-AC-13 | Elevation и duration не подставляют ложные нули при missing data | unit + golden |
| RB-AC-14 | Calculation model/profile/config versions входят в derived cache и публикацию | unit + contract |
| RB-AC-15 | Autosave/recovery не восстанавливают половину операции | fault injection |
| RB-AC-16 | Geometry conflict никогда не разрешается скрытой перезаписью | repository integration |
| RB-AC-17 | Publish идемпотентен и фиксирует immutable version с permanent ids | integration + contract |
| RB-AC-18 | Новая публикация не изменяет предыдущую version; rollback создаёт новую | repository integration |
| RB-AC-19 | Validator одинаково применяет config в editor, Preview и publish | unit + widget |
| RB-AC-20 | Attribution присутствует на карте, в snapshot и export согласно policy | legal checklist + test |
| RB-AC-21 | Точная geometry отсутствует в telemetry, logs и crash payload | privacy integration |
| RB-AC-22 | Provider keys отсутствуют в client/git/logs и управляются через approved path | security gate |
| RB-AC-23 | Circuit breaker и kill switch деградируют сервис без потери draft | resilience integration |
| RB-AC-24 | Accessibility позволяет завершить создание без drag-only действий | accessibility end-to-end |
| RB-AC-25 | Performance и battery budgets соблюдаются на representative fixtures/devices | performance gate |
| RB-AC-26 | Все migrations и supported GPX fixtures проходят round-trip без потери смысла | fixture suite |
| RB-AC-27 | Все критические пути §14 проходят на поддерживаемых платформах и локалях | release end-to-end |
| RB-AC-28 | Замечания модерации адресны, не меняют content молча и сохраняют version audit | moderation integration |
| RB-AC-29 | Фотографии waypoint покидают устройство только после санитайзинга; Route хранит только media ids | privacy + boundary integration |
| RB-AC-30 | Published geometry, stats, waypoint distances и GPX export соответствуют одной encoding policy/version | property + publish contract |
| RB-AC-31 | `ManualDuration` хранит seconds/reason вместе, а effective duration детерминирован при save/migration/recalculation | unit + mapper |
| RB-AC-32 | Route Create недоступен без `create_route`; publish недоступен без `publish_route`, включая deep link | capability integration |
| RB-AC-33 | Опубликованный Route появляется только в активной поисковой выдаче согласно visibility/market rules | search integration |
| RB-AC-34 | Search projection и full geometry имеют одинаковые route/version/hash и не смешиваются между версиями | contract + repository |
| RB-AC-35 | Search/Details рисуют saved polyline на Google Maps и не вызывают routing/elevation services | boundary + end-to-end |
| RB-AC-36 | Обновление OSM создаёт issue/draft-кандидат и не меняет published geometry автоматически | integration + audit |

Product-ready означает одновременное выполнение RB-AC-01–RB-AC-36,
утверждённые ADR/runbooks и зелёные обязательные repository gates.

---

## §16. Порядок реализации

| Workstream | Зависит от | Содержание | Выходной gate |
|---|---|---|---|
| RB-01 Domain foundation | — | typed model, provenance, topology, mapper, calculations, validation | unit + property + fixtures |
| RB-02 Editor core | RB-01 | anchors, segments, freehand, shapes, undo/redo, autosave, elevation UI | controller + widget + golden |
| RB-03 GPX | RB-01 | secure import/export, multi-track, waypoint, gaps, normalization | parser + round-trip + privacy |
| RB-04 GPS recording | RB-01 | permissions, background journal, recovery, processing, quality | platform + fault injection |
| RB-05 Routing platform | RB-01, Accepted ADR | MapLibre creator adapter, licensed tiles, self-hosted routing, profiles, cache, attribution | contract + resilience + runbook |
| RB-06 Generation | RB-01, RB-05 | condition model, candidates, compare, partial regeneration | contract + widget |
| RB-07 Points/conditions | RB-01, RB-02 | waypoint projection, access, taxonomy, warnings | unit + widget |
| RB-08 Sync/versioning | RB-01 | conflict handling, immutable versions, rollback, archive | repository + contract |
| RB-09 Publish | RB-02–RB-08 | Preview, validation, media, idempotent publish, moderation handoff | end-to-end + security |
| RB-10 Operational readiness | RB-03–RB-09 | SLO, privacy, legal, accessibility, performance, support runbooks | full release gate |

Workstreams могут выполняться параллельно только после своих зависимостей.
Каждый завершён при зелёных `flutter analyze`, полном `flutter test`, boundary
gate, профильных проверках из таблицы и отсутствии новых allowlist violations.

Порядок не разрешает обходить активную стабилизацию репозитория и не меняет
приоритет Accepted ADR. Он описывает безопасную последовательность поставки
полного продуктового контракта этого документа.

---

## §17. Решения, обязательные до production-включения

1. Принять ADR «Карты и маршрутизация»: MapLibre creator, licensed OSM tiles,
   self-hosted Latvia routing и Google Maps consumer topology.
2. Утвердить routing profile catalog, capability mapping и ownership config.
3. Утвердить provider contracts, лицензии, attribution и экспорт результатов.
4. Утвердить privacy/retention policy для GPS, GPX, drafts и published data.
5. Утвердить backend payload/media limits и simplify/split UX.
6. Утвердить versioning, moderation, archive и deletion contracts.
7. Зафиксировать SLI/SLO, alert thresholds, quotas и disaster runbooks.
8. Добавить versioned surface, waypoint и good-to-know taxonomy seeds.
9. Зафиксировать supported devices, local storage и battery baselines.
10. Подтвердить accessibility, localization и legal release checklists.
