# RECHARGE — RNT-PUB-01: Rental Trusted Direct-Publish Policy Slice Spec

- Статус: **Draft for review**
- Версия: 0.3 (2026-08-24) — 4 точечных архитектурных исправления после
  второго review: отдельный verified-Creator сигнал (не capability),
  context строится из сохранённого `published.rentalData.publisherRef`
  (не из изменяемого `_activePublisherRef`), policy инжектируется
  (не hardcoded constant), promotion — настоящий conditional write
  через `_conditionalSaveQueues`, не read-then-write. См. «Что
  изменилось в v0.3».
- Версия: 0.2 (2026-08-24) — уточнены identity/membership/fail-closed
  требования и промежуточный-сбой invariant после review; v0.1 §1–§3
  были верны по направлению, но недостаточно точны в authorization-
  контракте. См. «Что изменилось в v0.2».
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

## Что изменилось в v0.2

v0.1 сворачивал весь authorization-контракт в один булев resolver по
единственному условию (`publish.rental.direct` в capabilities). Review
потребовал точности по 8 пунктам; проверка кода вскрыла один
структурный факт, которого v0.1 не знал:

**Page-scoped membership сегодня нигде не доходит до
`CreateController`.** Прямым чтением подтверждено: `AuthUserEntity`
(`auth_user_entity.dart`) несёт только плоский глобальный
`capabilities: List<String>`, без page-scoped вариантов строк и без
отдельного «verified» поля; `activeCreatePublisherProvider`
(`app/application/active_create_publisher_provider.dart`) отдаёт
только `PublisherRef {type, id}` активного workspace — ни статуса
membership, ни его свежести. Ни один код-путь `create.rental`/
`submit.rental` сегодня не проверяет membership вообще — не только
`publish.rental.direct`. Значит «page требует active exact-page
membership» v0.1 не реализовал не потому, что забыл, а потому что
подходящего сигнала не существует ни для одной Rental-операции —
это pre-existing gap, не regression этого slice.

Решение v0.2: **Page publisher direct-publish осознанно fail-closed**
в этом bounded slice — resolver возвращает `notAuthorized` для
`PublisherType.page` безусловно, с явным `reasonCode`, а не тихим
`false`. Real page-membership-aware authorization для Rental publish —
отдельный, более крупный prerequisite (потребовал бы протянуть
membership-статус из `features/identity` через app-level provider вниз
в `CreateController`, которого сегодня нет ни для одной Rental
capability), не нужен для разблокировки `DTL-OBJ-01` (`OBJ-AC-03`
требует хотя бы один реальный publish→render путь, не именно Page).
Personal-publisher direct-publish полностью специфицирован ниже и
достаточен.

**Коррекция к формулировке выше** (v0.3): «без отдельного `verified`
поля» было неточно — такое поле существует, но не на `AuthUserEntity`
(который `CreateController` уже использует для `capabilities`), а на
`IdentityAccessSnapshot.isVerifiedCreator`
(`identity_access_snapshot.dart:32`), достижимом через
`identityWorkspaceControllerProvider.state.accessSnapshot`. Найдено
только на третьем review-раунде — см. «Что изменилось в v0.3» п.1.
Вывод про Page membership (`memberships`/`ManagedPageMembershipEntity`
на том же snapshot) не меняется — тот сигнал по-прежнему нигде не
доходит до `CreateController`, и product owner подтвердил, что
полная Page-membership-интеграция для этого slice не требуется.

## Что изменилось в v0.3

Второй review нашёл 4 точечных архитектурных дефекта в v0.2 —
направление (authorization contract, fail-closed Page, promotion
contract) осталось верным, но реализационные детали были неточны:

1. **`isVerifiedCreator` — отдельный сигнал, не подмена capability.**
   v0.2 предполагал, что отсутствие `publish.rental.direct` уже
   «подразумевает не-verified», по аналогии с тем, как сегодня
   работают `create.rental`/`submit.rental` (mock-proxy). Это было
   ошибочное обобщение: `IdentityAccessSnapshot.isVerifiedCreator`
   существует как отдельный, уже используемый в другом месте
   (`identity_workspace_state.dart:65`, `effectiveExperience`) сигнал,
   и именно его нужно проверять, а не выводить verification из
   capability-присутствия. `RentalDirectPublishContext` получает
   `isVerifiedCreator: bool` полем; resolver — новый `reasonCode:
   creator_unverified`.
2. **Context строится из `published.rentalData.publisherRef`, не
   `_activePublisherRef`.** `_activePublisherRef` — это *текущее*
   состояние контроллера (активный workspace *сейчас*), которое
   пользователь мог переключить между моментом, когда draft был
   сохранён с одним `PublisherRef`, и моментом publish-вызова.
   `PublishCreateDraftUseCase` → `CreateRepositoryImpl.publishDraft()`
   (прямым чтением подтверждено, `create_repository_impl.dart:289`)
   уже переносит `rentalData` (вместе с его `publisherRef`) на
   возвращаемую `published`-сущность без изменений последнего — это
   и есть источник истины про то, **чей** это черновик, не текущий
   controller state. Аналогично `promoteRentalToPublished` получает
   `published.id` (итоговый, уже де-`loc_`-фицированный id), не любой
   более ранний draft id.
3. **Policy инжектируется, не hardcoded constant.** v0.2's
   `RentalDirectPublishPolicy.current.isTrusted = true` как глобальная
   константа делает `PUB-AC-08` (`isTrusted == false` даёт
   `pending_review`) непроверяемым через реальный wiring — константа
   истинна всегда, false-ветку можно было бы протестировать только
   вызвав resolver напрямую в обход policy-источника, что не
   покрывает controller wiring. Policy становится параметром
   конструктора `CreateController` с безопасным default `false`; явное
   `isTrusted: true` — decision местной/mock DI-композиции
   (`create_providers.dart`), не значение по умолчанию домена.
4. **Promotion — настоящий conditional write, не read-then-write.**
   v0.2's `load → validate → saveDraft` в repository не атомарен: между
   `loadDraft` и `saveDraft` есть `await`-граница, во время которой
   Dart's single-threaded кооперативный scheduler может выполнить
   другую операцию для того же `userId` (ещё один `saveDraft`, вторая
   параллельная попытка promotion) — последняя запись молча
   выигрывает, без обнаружения конфликта. Прямым чтением
   `create_local_datasource.dart` подтверждено: у datasource уже есть
   ровно такой механизм для этого — `_conditionalSaveQueues`
   (per-`userId` очередь `Future`, см. `saveRouteDraftIfCurrent`
   строки 512–583) — сериализует конкурентные условные записи для
   одного пользователя и проверяет ожидаемое состояние **внутри**
   очереди, до записи. Promotion обязана использовать тот же паттерн
   через новый datasource-метод, не собственный repository-уровневый
   read-then-write.

## 1. Scope

### 1.1 Authorization contract (пункты review round 1 — 1–4, 6–7; round 2 — 1, 2)

```text
RentalDirectPublishContext {
  actorUserId: StableId
  isVerifiedCreator: bool
  capabilities: Set<String>
  draftPublisherRef: PublisherRef
  isPolicyTrusted: bool
}

RentalDirectPublishDecision {
  authorized: bool
  reasonCode: authorized
             | creator_unverified
             | capability_missing
             | policy_untrusted
             | page_membership_unsupported
             | not_owner
}
```

`resolveRentalDirectPublish(context) → RentalDirectPublishDecision`
эволюционирует один explicit `switch`/цепочку early-return проверок,
**в этом порядке** (первая непройденная — reasonCode):

1. `isVerifiedCreator` — отдельный от capability сигнал (round-2
   review: глобальная capability не заменяет verification). Источник —
   `IdentityAccessSnapshot.isVerifiedCreator`
   (`creatorVerificationStatus == verified`), не `AuthUserEntity`.
   Иначе `creator_unverified`.
2. `capabilities.contains('publish.rental.direct')`. Иначе
   `capability_missing`.
3. `isPolicyTrusted` — **отдельный** от capability и от verification
   сигнал (canonical §4.2: «explicit `publish.rental.direct` **и**
   trusted policy» — самостоятельное условие). Не capability-строка, а
   bounded local/mock policy toggle — см. §1.3
   `RentalDirectPublishPolicy` ниже. Иначе `policy_untrusted`.
4. `draftPublisherRef.type == PublisherType.page` → всегда
   `page_membership_unsupported` (см. «Что изменилось в v0.2» —
   сознательный, раскрытый fail-closed, не проверка membership,
   которой не из чего быть; подтверждено product owner — полная
   Page-membership-интеграция для этого slice не требуется).
5. `draftPublisherRef.type == PublisherType.user &&
   draftPublisherRef.id != actorUserId` → `not_owner` (round-1 review
   пункт 2: personal `PublisherRef` обязан совпадать с actor'ом —
   черновик, созданный от имени одного user, не может быть
   direct-published действием другого).
6. Иначе `authorized`.

Resolver — чистая функция, без I/O, без доступа к репозиторию/сети.
`isVerifiedCreator` проверяется первым — соответствует порядку в
canonical §4.2 Operation matrix, где «Verified Creator» называется
раньше конкретной capability в каждой ячейке personal-колонки.

### 1.2 Promotion contract — conditional write (round-1 review 4–7; round-2 review 4)

Слой datasource (`create_local_datasource.dart`) получает новый метод:

```text
enum RentalPromotionStatus { promoted, alreadyPublished, conflict, invalidExistingData }

class RentalPromotionResult {
  RentalPromotionStatus status
  CreateDraftModel? persisted   // non-null для promoted/alreadyPublished
}

Future<RentalPromotionResult> promoteRentalDraftIfCurrent({
  required String userId,
  required String expectedRentalId,
})
```

Реализация — **точно по паттерну `saveRouteDraftIfCurrent`**
(`create_local_datasource.dart:512–583`, тот же
`_conditionalSaveQueues[_draftKey(userId)]`):

1. Ставится в очередь на ключ `_draftKey(userId)` — сериализуется с
   любой другой conditional/unconditional записью для того же
   пользователя (round-2 review пункт 4: устраняет
   `await`-окно между чтением и записью, в котором конкурентная
   операция могла молча выиграть).
2. **Внутри** очереди, непосредственно перед записью: загружает
   текущий persisted draft; если `null` или `id != expectedRentalId`
   или `objectType != rental` → `invalidExistingData`, без записи.
3. Если `publishStatus == published` уже → `alreadyPublished`,
   возвращает текущую запись как есть, без записи (idempotency,
   round-1 review пункт 5; `publishedAtUtc` не трогается).
4. Если `publishStatus != pendingReview` (и не `published`) →
   `conflict`, без записи (round-1 review пункт 4 — fail-closed на
   неожиданном state).
5. Если `publishStatus == pendingReview` — строит новую модель:
   `draftStatus: published`, `publishStatus: published`,
   `moderationStatus: none` (trusted direct-publish — не эквивалент
   модерационного `approved`), **новый** `publishedAtUtc:
   DateTime.now().toUtc()` (round-1 review пункт 6). Один `saveDraft`
   вызов внутри той же очереди — единственная точка записи. Статус
   `promoted`.

`CreateRepositoryImpl.promoteRentalToPublished({userId, rentalId})`
— тонкая обёртка: вызывает `promoteRentalDraftIfCurrent`, мапит
`RentalPromotionResult` на `CreateDraftEntity`/`throw`:
`invalidExistingData`/`conflict` → типизированное исключение (без
побочных эффектов — datasource уже гарантировал ноль записи);
`promoted`/`alreadyPublished` → `persisted.toEntity()`. Вызывающий код
(`CreateController`) ловит исключение и оставляет уже полученный от
generic publish результат (`pending_review`) без изменений — round-1
review пункт 7, теперь дополнительно защищено на уровне datasource, а
не только порядком операций в repository.

### 1.3 `RentalDirectPublishPolicy` — инжектируемая, не hardcoded (round-2 review 3)

```text
class RentalDirectPublishPolicy {
  const RentalDirectPublishPolicy({this.isTrusted = false});
  final bool isTrusted;
}
```

Безопасный default — `const RentalDirectPublishPolicy()` →
`isTrusted: false` (production-safe: без явного opt-in direct-publish
никогда не авторизован). `CreateController`'s constructor получает
`RentalDirectPublishPolicy rentalDirectPublishPolicy = const
RentalDirectPublishPolicy()` — тот же паттерн default-параметра, что
уже используют `ValidateRentalDraftUseCase`/`EvaluateRentalAvailabilityUseCase`
и другие Rental-зависимости этого контроллера. Local/mock DI-композиция
(`create_providers.dart`) **явно** передаёт `const
RentalDirectPublishPolicy(isTrusted: true)` — то же место, где сегодня
собираются остальные Rental usecase-инстансы контроллера. Это делает
`PUB-AC-08` (`isTrusted == false` → `pending_review`) реально
тестируемым через конструктор `CreateController`, не только вызовом
resolver в обход wiring.

### 1.4 Controller wiring

`CreateController.publishDraft()`: после `_publishCreateDraftUseCase`
(текущий generic publish, без изменений) — если
`published.objectType == rental` (и `published.rentalData != null`,
что гарантировано этим же условием — round-2 review пункт 2),
строит `RentalDirectPublishContext` из:

- `actorUserId: _state.userId`;
- `isVerifiedCreator`: из нового поля контроллера (см. ниже) —
  **не** `_activePublisherRef`/`_capabilities`;
- `capabilities: _capabilities`;
- `draftPublisherRef: published.rentalData!.publisherRef` — **не**
  `_activePublisherRef` (round-2 review пункт 2: `_activePublisherRef`
  отражает *текущий* активный workspace, который мог измениться после
  того, как этот конкретный draft был сохранён с другим
  `PublisherRef`; сохранённый `publisherRef` — источник истины о том,
  чей это черновик);
- `isPolicyTrusted: _rentalDirectPublishPolicy.isTrusted`.

При `authorized` — вызывает `promoteRentalToPublished(userId:
_state.userId, rentalId: published.id)` (round-2 review пункт 2 —
`published.id`, итоговый де-`loc_`-фицированный id, не любой более
ранний draft id) в `try/catch`; при успехе использует
promoted-сущность для `_setState`/analytics/сообщения; при исключении
— использует исходный (`pendingReview`) `published` без изменений.
При `notAuthorized` (любой `reasonCode`) promotion не вызывается
вовсе — поведение идентично сегодняшнему.

**Новый входной сигнал `isVerifiedCreator`.** `CreateController` не
имеет сегодня доступа к `IdentityAccessSnapshot` — сигнал должен
дойти тем же путём, каким уже приходят `capabilities`/
`activePublisherRef`: новый опциональный параметр
`ensureLoaded({..., bool isVerifiedCreator = false})`, сохраняемый в
поле контроллера; вызывающий widget-код (`create_page.dart`,
единственное место, где сегодня строится вызов `ensureLoaded` с
реальными Identity-данными — `route_moderation_page.dart` его тоже
вызывает, но получит default `false`, что для его сценария поведенчески
не отличается от сегодняшнего дня, так как Route direct-publish эту
policy не использует) передаёт
`ref.watch(identityWorkspaceControllerProvider).state.accessSnapshot?.isVerifiedCreator
?? false` — тот же уровень (presentation/app-composition), где уже
читаются `authControllerProvider`/`activeCreatePublisherProvider`, не
внутрь `features/create` (boundary rule не нарушается — `features/create`
получает готовое примитивное `bool`, не импортирует
`features/identity`).

Analytics: `create_publish_succeeded` получает опциональный
`'direct_publish': true` только когда promotion реально применена
успешно (allowlist примитивных значений, не текст, не `reasonCode`).

### 1.5 Вне scope

- Real page-scoped membership authorization (см. «Что изменилось в
  v0.2») — отдельный будущий prerequisite, если/когда потребуется
  Page-publisher direct-publish.
- Explicit approval-transition/moderation UI (вариант 2, отклонён
  product owner).
- Реальный backend, любая сетевая проверка `isPolicyTrusted`.
- Rental publication-sink vertical (`RentalPublicationIndexSink`,
  `PublishedRentalDiscoveryPort`, adapter, loader) — `DTL-OBJ-01`
  §3/§4, начинается после этого slice, использует его результат
  (`published`-статус) как предпосылку для `sink.activate(...)`.
- Изменение generic `CreateRepositoryImpl.publishDraft()` сигнатуры —
  остаётся как есть для всех остальных типов.
- Route/Session/Collection/иные типы — policy только Rental.

## 2. Предлагаемый file map

| Файл | Тип | Назначение |
|---|---|---|
| `apps/mobile/lib/features/create/domain/entities/rental_direct_publish_decision.dart` | новый | `RentalDirectPublishContext`, `RentalDirectPublishDecision`, `RentalDirectPublishReasonCode` (§1.1) |
| `apps/mobile/lib/features/create/domain/usecases/resolve_rental_direct_publish_usecase.dart` | новый | Resolver — чистая функция §1.1, 6 упорядоченных проверок |
| `apps/mobile/lib/features/create/domain/entities/rental_direct_publish_policy.dart` | новый | `RentalDirectPublishPolicy` — инжектируемый `isTrusted` value object, default `false` (§1.3) |
| `apps/mobile/lib/features/create/data/datasources/create_local_datasource.dart` | правка | Новый `promoteRentalDraftIfCurrent(...)` метод через существующий `_conditionalSaveQueues`, по паттерну `saveRouteDraftIfCurrent` (§1.2) |
| `apps/mobile/lib/features/create/domain/repositories/create_repository.dart` | правка | Новый interface-метод `Future<CreateDraftEntity> promoteRentalToPublished({required String userId, required String rentalId})` |
| `apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart` | правка | Тонкая обёртка над datasource-методом — маппинг `RentalPromotionResult` → сущность/исключение (§1.2) |
| `apps/mobile/lib/app/application/active_create_publisher_provider.dart` или соседний новый provider | правка/новый | `isVerifiedCreator` bool provider из `identityWorkspaceControllerProvider` (§1.4) |
| `apps/mobile/lib/features/create/presentation/pages/create_page.dart` | правка | Передаёт `isVerifiedCreator` в `ensureLoaded(...)` |
| `apps/mobile/lib/features/create/application/controllers/create_controller.dart` | правка | `publishDraft()` wiring §1.4 |
| тесты resolver | новый | все 6 reason codes (`creator_unverified`, `capability_missing`, `policy_untrusted`, `page_membership_unsupported` безусловно, `not_owner` при mismatch), authorized happy path, порядок проверок (первая непройденная побеждает при множественных нарушениях) |
| тесты datasource promotion | новый | `promoteRentalDraftIfCurrent`: pendingReview→published; `alreadyPublished` повтор не меняет `publishedAtUtc`; id/type mismatch → `invalidExistingData`, ноль записи; неожиданный state (не pendingReview/published) → `conflict`, ноль записи; **конкурентная модификация**: вторая операция для того же `userId`, поставленная в очередь параллельно (ещё один `saveDraft`/вторая promotion попытка), сериализуется через `_conditionalSaveQueues` и получает согласованный, не потерянный результат — не race |
| тесты repository promotion | новый | маппинг каждого `RentalPromotionStatus` на entity/exception; **промежуточный сбой**: мокнутый datasource, бросающий исключение, оставляет вызывающий код с чистым исключением, без частичного состояния (review round-1 пункт 7) |
| тесты controller integration | новый | personal + verified + trusted + capability → published, используя `published.rentalData.publisherRef` (не мутированный `_activePublisherRef`, отдельный тест на переключение workspace между save и publish); page publisher → остаётся pendingReview; `isVerifiedCreator = false` → pendingReview; policy `isTrusted = false` (через constructor default, не через resolver напрямую) → pendingReview; capability отсутствует → pendingReview (текущее поведение, 0 regressions) |

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
- **PUB-AC-03.** С `isVerifiedCreator` **и** `publish.rental.direct`
  **и** `isTrusted` **и** personal `PublisherRef` из сохранённого
  `rentalData` (не текущего активного workspace), совпадающим с
  actor'ом, publish Rental завершается в `published` состоянии за один
  логический вызов `CreateController.publishDraft()` (два
  repository-вызова внутри — реализационная деталь, не наблюдаемая
  пользователем как промежуточное состояние).
- **PUB-AC-03a.** `isVerifiedCreator == false` даёт `pending_review`
  даже при наличии `publish.rental.direct` capability и `isTrusted`
  policy — verification проверяется как отдельное, самостоятельно
  тестируемое условие, не поглощена capability-проверкой.
- **PUB-AC-03b.** Переключение активного workspace
  (`_activePublisherRef`) между сохранением Rental-черновика и
  вызовом publish не влияет на authorization decision — используется
  `PublisherRef`, сохранённый вместе с этим конкретным draft'ом.
- **PUB-AC-04.** Promotion идемпотентна: повторный вызов на уже
  `published` записи не создаёт вторую запись и не изменяет
  `publishedAtUtc`.
- **PUB-AC-05.** Page `PublisherRef` **всегда** даёт
  `page_membership_unsupported`/`notAuthorized`, независимо от
  capability/policy — явный, тестируемый fail-closed, не побочный
  эффект отсутствующей проверки.
- **PUB-AC-06.** Personal `PublisherRef`, не совпадающий с
  `actorUserId` (сценарий: другой пользователь получил тот же
  capability и пытается direct-publish чужой черновик), даёт
  `not_owner`/`notAuthorized`.
- **PUB-AC-07.** Любой сбой промежуточного шага promotion (datasource
  validation failure, exception) оставляет persisted-запись в исходном
  `pending_review` — ни частичного состояния, ни повторной записи; у
  пользователя итог неотличим от «policy не авторизовала».
- **PUB-AC-07a.** Конкурентная модификация того же пользовательского
  draft-слота во время promotion (другой `saveDraft`/вторая promotion
  попытка для того же `userId`) сериализуется через
  `_conditionalSaveQueues`, а не даёт lost-update — проверено
  выделенным тестом, не только рассуждением о порядке кода.
- **PUB-AC-08.** `isTrusted == false` (policy toggle выключен через
  constructor default) даёт `pending_review` даже при наличии
  capability, verification и корректном owner — policy проверяется
  как отдельное, самостоятельно тестируемое условие, не поглощена
  capability-проверкой.
- **PUB-AC-09.** Policy resolver не содержит capability-проверок для
  других типов (`publish.route.direct` и т.п. не читается/не влияет).
- **PUB-AC-10.** `flutter analyze --no-pub`, `flutter test --no-pub`,
  boundary gate, `git diff --check` — зелёные.
- **PUB-AC-11.** `LAUNCH_STATUS.md` обновлён фактическим статусом
  реализации, не только намерением; явно фиксирует, что Page-publisher
  direct-publish остаётся fail-closed/нереализованным по дизайну, не
  забытым.

## 4. Rollback

1. Удалить `resolve_rental_direct_publish_usecase.dart`,
   `rental_direct_publish_decision.dart`, `rental_direct_publish_policy.dart`.
2. Убрать `promoteRentalToPublished` из интерфейса репозитория,
   `promoteRentalDraftIfCurrent` из datasource.
3. Убрать точечную ветку и `isVerifiedCreator`/`rentalDirectPublishPolicy`
   параметры из `CreateController`; убрать проброс `isVerifiedCreator`
   из `create_page.dart`.
4. Rental publish возвращается к сегодняшнему поведению — всегда
   `pending_review`, без regressions для уже существующих тестов.
