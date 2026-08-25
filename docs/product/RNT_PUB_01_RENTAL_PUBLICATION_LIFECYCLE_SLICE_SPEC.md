# RECHARGE — RNT-PUB-01: Rental Trusted Direct-Publish Policy Slice Spec

- Статус: **Draft for review**
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

## 1. Scope

### 1.1 Authorization contract (пункты review 1–4, 6–7)

```text
RentalDirectPublishContext {
  actorUserId: StableId
  capabilities: Set<String>
  draftPublisherRef: PublisherRef
  isPolicyTrusted: bool
}

RentalDirectPublishDecision {
  authorized: bool
  reasonCode: authorized
             | capability_missing
             | policy_untrusted
             | page_membership_unsupported
             | not_owner
}
```

`resolveRentalDirectPublish(context) → RentalDirectPublishDecision`
эволюционирует один explicit `switch`/цепочку early-return проверок,
**в этом порядке** (первая непройденная — reasonCode):

1. `capabilities.contains('publish.rental.direct')` — отсутствие
   capability уже подразумевает «не verified Creator для этой
   операции», ровно тем же mock-proxy, каким сегодня работают
   `create.rental`/`submit.rental` (отдельного verified-флага в модели
   нет — см. «Что изменилось»). Иначе `capability_missing`.
2. `isPolicyTrusted` — **отдельный** от capability сигнал (canonical
   §4.2: «explicit `publish.rental.direct` **и** trusted policy» — два
   условия, не одно). Не capability-строка, а bounded local/mock policy
   toggle — см. §2 `RentalDirectPublishPolicy` ниже. Иначе
   `policy_untrusted`.
3. `draftPublisherRef.type == PublisherType.page` → всегда
   `page_membership_unsupported` (см. «Что изменилось» — сознательный,
   раскрытый fail-closed, не проверка membership, которой не из чего
   быть).
4. `draftPublisherRef.type == PublisherType.user &&
   draftPublisherRef.id != actorUserId` → `not_owner` (review пункт 2:
   personal `PublisherRef` обязан совпадать с actor'ом — черновик,
   созданный от имени одного user, не может быть direct-published
   действием другого).
5. Иначе `authorized`.

Resolver — чистая функция, без I/O, без доступа к репозиторию/сети.

### 1.2 Promotion contract (пункты review 4–7)

`CreateRepository.promoteRentalToPublished({userId, rentalId})`:

1. Загружает текущий сохранённый draft по `rentalId` (не по
   in-memory состоянию контроллера — защита от stale data).
2. **Fail-closed валидация, без единой записи, пока не пройдены все
   проверки** (review пункт 7 — сбой оставляет честный
   `pending_review`, потому что до этого момента ничего не
   писалось): draft существует; `id == rentalId`; `objectType ==
   rental`; `publisherRef` соответствует `userId` по тем же
   правилам, что resolver уже проверил (defense-in-depth — promotion
   не доверяет вызывающему коду слепо); `publishStatus` —
   `pendingReview` **или** уже `published`.
3. Если уже `published` — возвращает текущую запись без изменений
   (review пункт 5, idempotency; НЕ обновляет `publishedAtUtc`
   повторно).
4. Если `pendingReview` — строит новую сущность:
   `draftStatus: published`, `publishStatus: published`,
   `moderationStatus: none` (trusted direct-publish — не эквивалент
   модерационного `approved`; модерации не было), **новый**
   `publishedAtUtc: DateTime.now().toUtc()` (review пункт 6 — момент
   реальной публикации, не момент исходного pending_review submit).
   Один атомарный `saveDraft(...)` вызов — единственная точка записи
   во всём методе.
5. Любое несовпадение в шаге 2 — `throw` (типизированное исключение,
   не silent false), без вызова `saveDraft`. Вызывающий код
   (`CreateController`) ловит его и оставляет состояние как есть —
   пользователь видит уже полученный от generic publish результат
   (`pending_review`), не полу-опубликованное состояние.

### 1.3 `RentalDirectPublishPolicy` (bounded local/mock policy source)

`isPolicyTrusted` не хардкодится инлайн в resolver — отдельный
маленький versioned policy-объект по образцу уже существующих
`RentalCreatePolicy`/`RentalAdaptiveHint` (не новая архитектура, тот
же паттерн). V1: `RentalDirectPublishPolicy.current.isTrusted = true`
константа — единственный источник; hook для будущей market/category-
зависимой policy оставлен через параметр, не через ветвление в
resolver.

### 1.4 Controller wiring

`CreateController.publishDraft()`: после `_publishCreateDraftUseCase`
(текущий generic publish, без изменений) — если
`published.objectType == rental`, строит
`RentalDirectPublishContext` из `_activePublisherRef`/`_capabilities`/
`_state.userId`/`RentalDirectPublishPolicy.current.isTrusted`, вызывает
resolver; при `authorized` — вызывает `promoteRentalToPublished(...)`
в `try/catch`; при успехе использует promoted-сущность для
`_setState`/analytics/сообщения; при исключении — использует
исходный (`pendingReview`) `published` без изменений, как сегодня.
При `notAuthorized` (любой `reasonCode`) promotion не вызывается
вовсе — поведение идентично сегодняшнему.

Analytics: `create_publish_succeeded` получает опциональный
`'direct_publish': true` только когда promotion реально применена
успешно (allowlist примитивных значений, не текст, не `reasonCode`).

### 1.5 Вне scope

- Real page-scoped membership authorization (см. «Что изменилось») —
  отдельный будущий prerequisite, если/когда потребуется Page-publisher
  direct-publish.
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
| `apps/mobile/lib/features/create/domain/usecases/resolve_rental_direct_publish_usecase.dart` | новый | Resolver — чистая функция §1.1, 5 упорядоченных проверок |
| `apps/mobile/lib/features/create/domain/entities/rental_direct_publish_policy.dart` | новый | `RentalDirectPublishPolicy` — versioned local/mock `isTrusted` источник (§1.3) |
| `apps/mobile/lib/features/create/domain/repositories/create_repository.dart` | правка | Новый interface-метод `Future<CreateDraftEntity> promoteRentalToPublished({required String userId, required String rentalId})` |
| `apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart` | правка | Реализация §1.2 — fail-closed валидация перед единственной записью, идемпотентность, новый `publishedAtUtc` |
| `apps/mobile/lib/features/create/application/controllers/create_controller.dart` | правка | `publishDraft()` wiring §1.4 |
| тесты resolver | новый | все 5 reason codes (включая `page_membership_unsupported` безусловно, `not_owner` при mismatch), authorized happy path |
| тесты repository promotion | новый | pendingReview→published; idempotent повтор на published не меняет `publishedAtUtc`; id/type/owner mismatch → throw, ноль записи; **промежуточный сбой**: мокнутый datasource, бросающий на `saveDraft`, оставляет persisted-запись в исходном pendingReview (review пункт 7 — прямая проверка, не косвенная) |
| тесты controller integration | новый | personal + trusted + capability → published; page publisher → остаётся pendingReview (fail-closed, не throw наружу пользователю); policy `isTrusted = false` → pendingReview; capability отсутствует → pendingReview (текущее поведение, 0 regressions) |

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
- **PUB-AC-03.** С `publish.rental.direct` **и** `isTrusted` **и**
  personal `PublisherRef`, совпадающим с actor'ом, publish Rental
  завершается в `published` состоянии за один логический вызов
  `CreateController.publishDraft()` (два repository-вызова внутри —
  реализационная деталь, не наблюдаемая пользователем как
  промежуточное состояние).
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
- **PUB-AC-07.** Любой сбой промежуточного шага promotion (repository
  throw, datasource failure) оставляет persisted-запись в исходном
  `pending_review` — ни частичного состояния, ни повторной записи; у
  пользователя итог неотличим от «policy не авторизовала».
- **PUB-AC-08.** `isTrusted == false` (policy toggle выключен) даёт
  `pending_review` даже при наличии capability и корректном owner —
  policy проверяется как отдельное, самостоятельно тестируемое
  условие, не поглощена capability-проверкой.
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
2. Убрать `promoteRentalToPublished` из интерфейса и реализации
   репозитория.
3. Убрать точечную ветку в `CreateController.publishDraft()`.
4. Rental publish возвращается к сегодняшнему поведению — всегда
   `pending_review`, без regressions для уже существующих тестов.
