# RECHARGE — RNT-PUB-01: Rental Trusted Direct-Publish Policy Slice Spec

- Статус: **Draft for review**
- Версия: 0.1 (2026-08-24)
- Канонический type id: `rental`
- Имя implementation slice: `RNT-PUB-01`
- Runtime effect этого документа: **none**.

Bounded prerequisite for `DTL-OBJ-01` §3 (Rental publication-sink
vertical), blocking that slice since 2026-08-24 (см.
`DTL_OBJ_01_OBJECT_OFFER_ENGINE_SLICE_SPEC.md` v0.5, раздел «Rental
publication lifecycle — Blocked»). Approach selected by product owner
2026-08-24: **trusted local/mock direct-publish policy**, not an
explicit approval-transition action — see «Что изменилось / рассмотренные
варианты» ниже.

## Проблема (проверено прямым чтением кода 2026-08-24)

`CreateController.publishDraft()` (`create_controller.dart:3525`) для
Rental идёт по тому же generic-пути, что Event/Place/Activity/FindPeople:
`CreateRepositoryImpl.publishDraft()` (`create_repository_impl.dart:292,
299`) **безусловно** устанавливает `DraftStatus.pendingReview`/
`PublishStatus.pendingReview`. Прямого пути к `published` для Rental
сегодня нет — в отличие от Route, у которого есть собственный
`_publishRouteDraft()`/`RoutePublicationCoordinator`.

Канонический `RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md`:

- §16 (line 912): «`pending_review` отсутствует в Discover» —
  жёсткий запрет, не рекомендация.
- §13.8: «Author не выбирает moderation result. Application policy
  возвращает `pending_review` или trusted direct `published`.»
- §16.1 шаг 12: «policy-selected `pending_review | published` result»
  — часть единого publish pipeline, не отдельная последующая операция
  с точки зрения контракта (хотя реализация вправе смоделировать это
  как два шага — см. §3 ниже).
- §4.2 Operation matrix уже называет `Direct publish` отдельной
  operation: «Только explicit `publish.rental.direct` и trusted
  policy».
- §15.2: `RNT-CRT-01` **сознательно** ограничен mock `pending_review`
  — trusted direct-publish policy добавляется именно этим slice, не
  была упущена в Rental-стабилизации.

Capability-сигнал `publish.rental.direct`/`canPublishRentalDirect` уже
существует в `create_controller.dart` (добавлен во время Rental
Create стабилизации, по образцу Route) — но сегодня ни на что не
влияет, кроме своего значения как булева геттера.

## Что изменилось / рассмотренные варианты

Рассмотрены два варианта (см. предыдущий раунд обсуждения с product
owner):

1. **Trusted local/mock direct-publish policy** (выбран) — publish
   для Rental по умолчанию остаётся `pending_review`, но для
   publisher'ов с `publish.rental.direct` + trusted-policy условием
   результат — `published`, без промежуточного состояния. Соответствует
   §4.2 (Direct publish — уже названная operation) и не требует новой
   UI-поверхности: решение принимает application policy по
   capability, автор его не выбирает (§13.8 дословно).
2. **Explicit approval-transition** (не выбран) — publish всегда
   `pending_review`, плюс новое действие `approve`, переводящее
   `pending_review → published`. Ближе к ребру
   `pending_review --> published: approved` диаграммы §16, но
   требует нового actor'а (mock-moderator/admin), которого сегодня
   для Rental не существует — больше нового scope, чем нужно для
   разблокировки `DTL-OBJ-01`.

Вариант 1 закрывает блокер `DTL-OBJ-01` минимальным, уже частично
подготовленным (существующая capability) изменением.

## 1. Scope

### 1.1 В scope

1. `RentalDirectPublishPolicy` — trusted local/mock policy resolver:
   для данного capability-набора и Rental-черновика решает, авторизован
   ли direct-publish. V1: единственное условие — `publish.rental.direct`
   в `capabilities`. Оставляет явный hook для будущих условий (market
   policy, page-scoped capability для Page publisher — см. §4.2
   canonical-спеки «То же + active membership + page-scoped direct
   publish»), но не реализует их сверх сегодняшнего generic page-capability
   контракта, который уже проверяется на уровне `create.rental`/
   `submit.rental` (не расширяется этим slice).
2. Новый repository-метод, атомарно переводящий уже созданную
   `pending_review`-запись в `published` — вызывается сразу вслед за
   generic publish, только для Rental, только когда policy авторизует.
   Реализован как отдельный шаг (не параметр внутри shared
   `publishDraft()`), чтобы не трогать generic-путь, используемый
   Event/Place/Activity/FindPeople.
3. `CreateController.publishDraft()`: после `_publishCreateDraftUseCase`
   — если `objectType == rental` и policy авторизует — вызов
   promotion-шага; итоговый `published`, используемый для
   `_setState`/analytics/сообщения, — уже promoted-версия.
4. Analytics: `create_publish_succeeded` получает опциональный
   `'direct_publish': true` параметр только когда promotion применён
   (allowlist уже проверенных примитивных значений, не текст).
5. Тесты: policy resolver (authorized/not authorized), repository
   promotion (idempotent — повторный вызов на уже-published не
   дублирует и не ошибается разрушительно), controller integration
   (без capability — pendingReview, с capability — published).

### 1.2 Вне scope

- Page-scoped direct-publish capability поверх сегодняшнего generic
  membership-контракта (уже покрыт существующим `create.rental`/
  `submit.rental` page-membership кодом — не расширяется).
- Explicit approval-transition/moderation UI (вариант 2, отклонён).
- Реальный backend, любая сетевая проверка trusted policy.
- Rental publication-sink vertical (`RentalPublicationIndexSink`,
  `PublishedRentalDiscoveryPort`, adapter, loader) — это `DTL-OBJ-01`
  §3/§4, начинается после этого slice, использует его результат
  (`published`-статус) как предпосылку для `sink.activate(...)`.
- Изменение generic `CreateRepositoryImpl.publishDraft()` сигнатуры —
  остаётся как есть для всех остальных типов.
- Route/Session/Collection/иные типы — publish policy только Rental.

## 2. Предлагаемый file map

| Файл | Тип | Назначение |
|---|---|---|
| `apps/mobile/lib/features/create/domain/usecases/resolve_rental_direct_publish_usecase.dart` | новый | Trusted policy resolver — `bool call({required List<String> capabilities})` (или эквивалент), детерминированный, без I/O |
| `apps/mobile/lib/features/create/domain/repositories/create_repository.dart` | правка | Новый interface-метод `Future<CreateDraftEntity> promoteRentalToPublished({required String userId, required String rentalId})` |
| `apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart` | правка | Реализация: загрузить draft по id, проверить `objectType == rental && publishStatus == pendingReview`, перевести в `published`/`ModerationStatus.none` (без искусственного "approved" — trusted publish не эквивалентен модерации), сохранить; идемпотентно возвращает уже-published запись без изменений при повторном вызове |
| `apps/mobile/lib/features/create/application/controllers/create_controller.dart` | правка | `publishDraft()`: точечная ветка после `_publishCreateDraftUseCase` — вызов resolver + (при авторизации) promotion; `_setState`/analytics используют promoted-результат |
| тесты resolver | новый | authorized/not authorized, отсутствующий capability |
| тесты repository promotion | новый | pendingReview→published переход, idempotency на повторном вызове, no-op для не-Rental/не-pendingReview |
| тесты controller integration | новый | end-to-end: без capability результат pendingReview (текущее поведение не изменилось), с capability результат published |

Ни один файл `DTL-OBJ-01` §3/§4 (`rental_publication_index_sink.dart`,
`published_rental_discovery_port.dart`, adapter, loader,
`RentalDetailsPage`, `app_router.dart`) не входит в этот slice — они
остаются в `DTL-OBJ-01` и начинаются только после `RNT-PUB-01` Done.

## 3. Acceptance criteria

- **PUB-AC-01.** `pending_review` Rental listing никогда не
  видим Discover (уже верно сегодня, потому что `sink.activate` не
  существует и не входит в этот slice — этот AC фиксирует инвариант,
  который `DTL-OBJ-01` §3 обязан сохранить, вызывая `sink.activate`
  только для promoted/`published` результата).
- **PUB-AC-02.** Без `publish.rental.direct` publish Rental
  ведёт себя идентично сегодняшнему — `pending_review`, без promotion
  вызова, 0 regressions для существующих `rental_controller_test.dart`
  тестов.
- **PUB-AC-03.** С `publish.rental.direct` publish Rental
  завершается в `published` состоянии за один логический вызов
  `CreateController.publishDraft()` (два repository-вызова внутри —
  реализационная деталь, не наблюдаемая пользователем как
  промежуточное состояние).
- **PUB-AC-04.** Promotion идемпотентна: повторный вызов на уже
  `published` записи не создаёт вторую запись и не изменяет
  `publishedAtUtc`.
- **PUB-AC-05.** Policy resolver не содержит capability-проверок для
  других типов (`publish.route.direct` и т.п. не читается/не влияет).
- **PUB-AC-06.** `flutter analyze --no-pub`, `flutter test --no-pub`,
  boundary gate, `git diff --check` — зелёные.
- **PUB-AC-07.** `LAUNCH_STATUS.md` обновлён фактическим статусом
  реализации, не только намерением.

## 4. Rollback

1. Удалить `resolve_rental_direct_publish_usecase.dart`.
2. Убрать `promoteRentalToPublished` из интерфейса и реализации
   репозитория.
3. Убрать точечную ветку в `CreateController.publishDraft()`.
4. Rental publish возвращается к сегодняшнему поведению — всегда
   `pending_review`, без regressions для уже существующих тестов.
