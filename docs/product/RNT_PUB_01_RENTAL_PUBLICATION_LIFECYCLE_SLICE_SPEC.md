# RECHARGE — RNT-PUB-01: Rental Trusted Direct-Publish Policy Slice Spec

- Статус: **Draft for review**
- Версия: 0.4 (2026-08-24) — 3 проверенных дефекта после третьего
  review: `saveDraft()` в реальности не проходит через
  `_conditionalSaveQueues` (v0.3's AC-07a была неверна в этой части);
  conditional contract у promotion недостаточен без `expectedRentalRevision`
  и восстановленной (потерянной при переносе на datasource-уровень)
  owner/`publisherRef` проверки; verification-сигнал должен идти через
  app-level primitive provider, не прямой Identity-импорт в
  `create_page.dart`, и обязан входить в `_loadKey`. См. «Что
  изменилось в v0.4».
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

## Что изменилось в v0.4

Третий review нашёл 3 проверенных дефекта в v0.3. Direction (conditional
write через существующий queue-механизм, отдельный verified-сигнал,
context из сохранённого publisherRef) остался верным; сама реализация
v0.3 была неполной/неточной в деталях:

1. **`_conditionalSaveQueues` не защищает от конкурентного plain
   `saveDraft()`.** v0.3's `AC-07a` утверждал, что новый
   `promoteRentalDraftIfCurrent` «сериализуется с любой другой
   conditional/unconditional записью для того же пользователя» — это
   было неверно для «unconditional» половины утверждения. Прямым
   чтением подтверждено: `saveDraft()`
   (`create_local_datasource.dart:96`) пишет напрямую в
   `_storage.write(...)`, вообще не касаясь `_conditionalSaveQueues`.
   Значит конкурентный обычный autosave **всё ещё** мог бы гонки с
   promotion — очередь защищала только promotion-vs-promotion, не
   promotion-vs-обычный-save. Исправление: `saveDraft()` сам
   переводится на тот же per-`_draftKey(userId)` queue-механизм —
   внутренняя запись выносится в `_writeDraftUnlocked(...)`, а
   `saveDraft()`/`promoteRentalDraftIfCurrent`/`saveRouteDraftIfCurrent`
   все ставятся в одну очередь по одному и тому же ключу. Это
   поведенчески прозрачно для всех остальных типов (тот же итоговый
   результат записи, просто гарантированно упорядоченный, а не
   потенциально гоняющийся) — но затрагивает shared datasource-метод,
   поэтому явно раскрыто как pre-existing-поведение-сохраняющий
   рефакторинг, не Rental-only изменение по факту (хотя мотивирован
   именно нуждами Rental promotion).
2. **Conditional contract потерял owner-проверку при переносе на
   datasource-уровень в v0.3 и не имел revision-guard ни в v0.2, ни в
   v0.3.** v0.2 (repository-уровень) проверял `publisherRef`
   соответствие `userId` как defense-in-depth; при переносе логики в
   `promoteRentalDraftIfCurrent` (v0.3) эта проверка была потеряна —
   v0.3 проверял только `id`/`objectType`/`publishStatus`. Отдельно,
   ни одна версия не предохраняла promotion от гонки с параллельной
   мутацией *содержимого* того же pending_review черновика (не
   структуры — уже сериализовано очередью после исправления п.1, но
   значение `rentalData` могло устареть между тем, как
   `CreateController` получил `published` от generic publish, и тем,
   как promotion реально записывает — новый `expectedRentalRevision`
   guard закрывает именно это, по образцу уже существующего
   `expectedRevision` в `saveRouteDraftIfCurrent`). Добавлены: явная
   `rentalData != null` проверка; `rentalData!.publisherRef.type ==
   PublisherType.user && rentalData!.publisherRef.id == userId`;
   `rentalData!.revision == expectedRentalRevision`. Любое несовпадение
   — fail-closed `conflict`/`invalidExistingData`, без записи.
3. **Verification-сигнал: app-level primitive provider, не прямой
   Identity-импорт в `create_page.dart`; обязателен в `_loadKey`.**
   v0.3's controller-wiring текст описывал
   `create_page.dart` вызывающим `ref.watch(identityWorkspaceControllerProvider)`
   напрямую — это нарушило бы boundary rule (`features/create` →
   `features/identity` прямой импорт, как и `activeCreatePublisherProvider`
   уже избегает через app-level bridge) и противоречило собственной
   file-map-строке того же v0.3, которая (верно) предполагала
   отдельный provider. Исправлено: новый app-level provider
   (`apps/app/application/`), по образцу
   `active_create_publisher_provider.dart`, отдаёт голый `bool`;
   `create_page.dart` его читает, `features/create` не импортирует
   Identity вообще. Отдельно: `_scheduleLoad`'s `_loadKey` дедупликаций-строка
   не включала `isVerifiedCreator` — при первом build (до того как
   Identity snapshot асинхронно загрузился) `ensureLoaded` вызывался бы
   с `isVerifiedCreator: false`, а последующий rebuild с реальным
   `true` не отличался бы по остальным полям ключа и **не вызвал бы
   повторный `ensureLoaded`** — контроллер навсегда застрял бы на
   `false`. `isVerifiedCreator` добавлен в состав `_loadKey`.

Дополнительно (без отдельного номера — редакционная точность):
убрана формулировка «`published.rentalData != null`, что гарантировано
[`objectType == rental`]» — это утверждение об инварианте, не проверка;
код обязан делать явный `null`-check с graceful fallback (пропустить
direct-publish попытку, оставить уже полученный `pendingReview`
результат), а не полагаться на предположение, которое будущий рефакторинг
может незаметно нарушить.

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

### 1.2 Promotion contract — conditional write (round-1 review 4–7; round-2 review 4; round-3 review 1–2)

**1.2.0 Общая очередь для всех draft-мутаций (round-3 review пункт 1).**
`saveDraft(userId, model)` перестаёт писать в `_storage` напрямую.
Внутренняя запись выносится в приватный
`_writeDraftUnlocked(userId, model)` (тело — сегодняшнее тело
`saveDraft`, без изменений семантики). Сам `saveDraft` становится
`_enqueueDraftMutation(_draftKey(userId), () =>
_writeDraftUnlocked(userId, model))`, где `_enqueueDraftMutation<T>`
— вынесенный в общий приватный helper паттерн, уже используемый
`saveRouteDraftIfCurrent`/`saveCollectionDraftIfCurrent`
(`_conditionalSaveQueues[key] = ...`, chain-on-previous). Это делает
`_conditionalSaveQueues` истинно общим per-`_draftKey(userId)` мьютексом
для **любой** мутации draft-слота — не только conditional. Поведенчески
прозрачно для Event/Place/Activity/FindPeople и т.д. (тот же результат
записи, теперь строго упорядоченный); отдельный regression-тест
подтверждает это для не-Rental типа.

**1.2.1 Новый datasource-метод:**

```text
enum RentalPromotionStatus { promoted, alreadyPublished, conflict, invalidExistingData }

class RentalPromotionResult {
  RentalPromotionStatus status
  CreateDraftModel? persisted   // non-null для promoted/alreadyPublished
}

Future<RentalPromotionResult> promoteRentalDraftIfCurrent({
  required String userId,
  required String expectedRentalId,
  required int expectedRentalRevision,
})
```

Реализация — через тот же `_enqueueDraftMutation(_draftKey(userId),
...)`, что теперь и `saveDraft`/`saveRouteDraftIfCurrent` (§1.2.0):

1. **Внутри** очереди, непосредственно перед записью: загружает
   текущий persisted draft.
2. Fail-closed валидация, **всё** до единственной записи —
   любое несовпадение → соответствующий non-`promoted` статус, ноль
   записи:
   - `null`/`id != expectedRentalId`/`objectType != rental` →
     `invalidExistingData`;
   - `rentalData == null` → `invalidExistingData` (round-3 review,
     дополнительный пункт: явная проверка, не предположение об
     инварианте — см. «Что изменилось в v0.4»);
   - `rentalData!.publisherRef.type != PublisherType.user ||
     rentalData!.publisherRef.id != userId` → `conflict` (round-3
     review пункт 2 — восстановленная owner-проверка, потерянная при
     переносе логики на datasource-уровень в v0.3; defense-in-depth
     поверх resolver'а, который тот же owner-факт уже проверил на
     уровне `CreateController`);
   - `publishStatus == published` уже → **не ошибка** — `alreadyPublished`
     (idempotency, round-1 review пункт 5; `publishedAtUtc` не
     трогается; revision здесь не проверяется — повторный вызов на
     уже-опубликованной записи легитимен вне зависимости от того, с
     каким `expectedRentalRevision` его вызвали);
   - `publishStatus != pendingReview` (и не `published`) → `conflict`
     (round-1 review пункт 4 — fail-closed на неожиданном state);
   - `rentalData!.revision != expectedRentalRevision` → `conflict`
     (round-3 review пункт 2, новый guard — та же типизированная
     проверка, что уже делает `expectedRevision` в
     `saveRouteDraftIfCurrent`: между тем, как `CreateController`
     получил `published` от generic publish, и тем, как promotion
     реально пишет, значение `rentalData` не должно было устареть).
3. Если все проверки пройдены — строит новую модель:
   `draftStatus: published`, `publishStatus: published`,
   `moderationStatus: none` (trusted direct-publish — не эквивалент
   модерационного `approved`), **новый** `publishedAtUtc:
   DateTime.now().toUtc()` (round-1 review пункт 6). Один
   `_writeDraftUnlocked` вызов внутри той же очереди — единственная
   точка записи. Статус `promoted`.

`CreateRepositoryImpl.promoteRentalToPublished({userId, rentalId,
expectedRentalRevision})` — тонкая обёртка: вызывает
`promoteRentalDraftIfCurrent`, мапит `RentalPromotionResult` на
`CreateDraftEntity`/`throw`: `invalidExistingData`/`conflict` →
типизированное исключение (без побочных эффектов — datasource уже
гарантировал ноль записи); `promoted`/`alreadyPublished` →
`persisted.toEntity()`. Вызывающий код (`CreateController`) ловит
исключение и оставляет уже полученный от generic publish результат
(`pending_review`) без изменений — round-1 review пункт 7, защищено на
уровне datasource через настоящую сериализацию (§1.2.0), не только
порядком операций в repository.

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
`published.objectType == rental`, **явно проверяет**
`published.rentalData` на `null` (round-3 review, редакционный пункт:
не заявлять `objectType == rental` гарантией непустого `rentalData` —
это предположение об инварианте, не проверка; код обязан graceful
fail-closed на `null`, пропуская direct-publish попытку и оставляя уже
полученный `pendingReview` результат как есть, тем же путём, что и
`notAuthorized`/exception). Если `rentalData != null` — строит
`RentalDirectPublishContext` из:

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
_state.userId, rentalId: published.id, expectedRentalRevision:
published.rentalData!.revision)` (round-2 review пункт 2 —
`published.id`, итоговый де-`loc_`-фицированный id, не любой более
ранний draft id; round-3 review пункт 2 — `expectedRentalRevision` из
той же `published`-сущности, не отдельным запросом) в `try/catch`; при
успехе использует promoted-сущность для
`_setState`/analytics/сообщения; при исключении — использует исходный
(`pendingReview`) `published` без изменений. При `notAuthorized`
(любой `reasonCode`) promotion не вызывается вовсе — поведение
идентично сегодняшнему.

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
policy не использует) читает **новый app-level primitive provider**
(round-3 review пункт 3 — не прямой `ref.watch(identityWorkspaceControllerProvider)`
внутри `create_page.dart`, что нарушило бы boundary rule ровно так же,
как `active_create_publisher_provider.dart` уже избегает для
`PublisherRef`): `apps/mobile/lib/app/application/` получает новый
provider вида `activeCreatorVerificationProvider`, отдающий голый
`bool` — `ref.watch(identityWorkspaceControllerProvider).state.accessSnapshot?.isVerifiedCreator
?? false` внутри app-level кода, где Identity-импорт уже легален
(тот же файл/соседний файл, что `activeCreatePublisherProvider`).
`create_page.dart` читает только этот provider, `features/create`
Identity вообще не импортирует.

**`_loadKey` обязан включать `isVerifiedCreator`** (round-3 review
пункт 3): `_scheduleLoad`'s дедупликаций-ключ сегодня строится из
`userId`/`organizerEmail`/`capabilities`/`publisherRef` — без
`isVerifiedCreator` первый build (до того, как Identity snapshot
асинхронно догрузится) закешировал бы `ensureLoaded(isVerifiedCreator:
false)`, а последующий rebuild с реальным `true` не отличался бы по
остальным полям ключа и не вызвал бы повторный `ensureLoaded` —
контроллер навсегда застрял бы на `false`. Новый ключ:
`'$userId:$organizerEmail:$isVerifiedCreator:${capabilities.join(',')}:...'`.

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
| `apps/mobile/lib/features/create/data/datasources/create_local_datasource.dart` | правка | `saveDraft`→`_writeDraftUnlocked`+`_enqueueDraftMutation` рефакторинг (§1.2.0); новый `promoteRentalDraftIfCurrent(...)` через ту же очередь, с owner/revision/null-guard'ами (§1.2.1) |
| `apps/mobile/lib/features/create/domain/repositories/create_repository.dart` | правка | Новый interface-метод `Future<CreateDraftEntity> promoteRentalToPublished({required String userId, required String rentalId, required int expectedRentalRevision})` |
| `apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart` | правка | Тонкая обёртка над datasource-методом — маппинг `RentalPromotionResult` → сущность/исключение (§1.2) |
| `apps/mobile/lib/app/application/active_creator_verification_provider.dart` | новый | `activeCreatorVerificationProvider` — голый `bool` из `identityWorkspaceControllerProvider`, по образцу `active_create_publisher_provider.dart` (§1.4) |
| `apps/mobile/lib/features/create/presentation/pages/create_page.dart` | правка | Читает `activeCreatorVerificationProvider`, передаёt `isVerifiedCreator` в `ensureLoaded(...)`, добавляет его в `_loadKey` |
| `apps/mobile/lib/features/create/application/controllers/create_controller.dart` | правка | `ensureLoaded` новый параметр; `publishDraft()` wiring §1.4, включая явный `rentalData != null` guard |
| тесты resolver | новый | все 6 reason codes (`creator_unverified`, `capability_missing`, `policy_untrusted`, `page_membership_unsupported` безусловно, `not_owner` при mismatch), authorized happy path, порядок проверок (первая непройденная побеждает при множественных нарушениях) |
| тесты datasource `saveDraft`/очередь | новый | non-Rental тип: поведение `saveDraft` не изменилось после рефакторинга §1.2.0 (regression guard) |
| тесты datasource promotion | новый | `promoteRentalDraftIfCurrent`: pendingReview→published; `alreadyPublished` повтор не меняет `publishedAtUtc` и не проверяет revision; id/type/`rentalData==null` mismatch → `invalidExistingData`, ноль записи; owner mismatch (`publisherRef.type != user` или `id != userId`) → `conflict`, ноль записи; revision mismatch → `conflict`, ноль записи; неожиданный state → `conflict`, ноль записи; **конкурентная модификация**: параллельный **обычный** `saveDraft` для того же `userId` (не только вторая promotion попытка) сериализуется через общую очередь §1.2.0 и не создаёт lost update — прямая проверка того, что `AC-07a` v0.3 неверно утверждал как уже работающее |
| тесты repository promotion | новый | маппинг каждого `RentalPromotionStatus` на entity/exception; **промежуточный сбой**: мокнутый datasource, бросающий исключение, оставляет вызывающий код с чистым исключением, без частичного состояния (review round-1 пункт 7) |
| тесты controller integration | новый | personal + verified + trusted + capability → published, используя `published.rentalData.publisherRef` (не мутированный `_activePublisherRef`, отдельный тест на переключение workspace между save и publish); page publisher → остаётся pendingReview; `isVerifiedCreator = false` → pendingReview; policy `isTrusted = false` (через constructor default, не через resolver напрямую) → pendingReview; capability отсутствует → pendingReview (текущее поведение, 0 regressions); `rentalData == null` при `objectType == rental` (искусственный edge case) → graceful pendingReview, не throw/crash |
| тесты `_loadKey`/`ensureLoaded` | новый | второй `ensureLoaded` вызов с тем же `userId`/`capabilities`/`publisherRef`, но другим `isVerifiedCreator`, реально долетает до контроллера (не съедается дедупликацией) |

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
  draft-слота во время promotion — **включая обычный, не только
  conditional, `saveDraft` для того же `userId`** (v0.3 некорректно
  ограничивал это утверждение только promotion-vs-promotion) —
  сериализуется через общую `_enqueueDraftMutation`/`_conditionalSaveQueues`
  очередь (§1.2.0), не даёт lost-update. Проверено выделенным тестом на
  реальной гонке с plain `saveDraft`, не только рассуждением о порядке
  кода.
- **PUB-AC-07b.** Promotion с устаревшим `expectedRentalRevision`
  (значение `rentalData.revision` изменилось между тем, как
  `CreateController` получил `published`, и вызовом promotion) даёт
  `conflict`, без записи.
- **PUB-AC-07c.** Promotion с `rentalData.publisherRef`, не совпадающим
  с `userId` по personal-правилу (owner mismatch на datasource-уровне,
  defense-in-depth поверх resolver'а), даёт `conflict`, без записи.
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
- **PUB-AC-12.** Второй `ensureLoaded` вызов, отличающийся только
  `isVerifiedCreator`, реально долетает до контроллера — `_loadKey`
  не съедает изменение (round-3 review пункт 3).
- **PUB-AC-13.** `rentalData == null` при `objectType == rental`
  (искусственный edge case — код не предполагает инвариант) не
  вызывает throw/crash в `publishDraft()`, а даёт тот же
  `pending_review` результат, что и `notAuthorized`.
- **PUB-AC-14.** `saveDraft()` для любого не-Rental типа ведёт себя
  наблюдаемо идентично поведению до рефакторинга §1.2.0 — 0
  regressions в существующих тестах, не завязанных на Rental.

## 4. Rollback

1. Удалить `resolve_rental_direct_publish_usecase.dart`,
   `rental_direct_publish_decision.dart`, `rental_direct_publish_policy.dart`,
   `active_creator_verification_provider.dart`.
2. Убрать `promoteRentalToPublished` из интерфейса репозитория,
   `promoteRentalDraftIfCurrent` из datasource. `_writeDraftUnlocked`/
   `_enqueueDraftMutation`-рефакторинг `saveDraft` (§1.2.0) можно
   оставить как есть — он поведенчески прозрачен и не Rental-specific,
   откатывать не обязательно, если полезен сам по себе (общая
   надёжность datasource).
3. Убрать точечную ветку и `isVerifiedCreator`/`rentalDirectPublishPolicy`
   параметры из `CreateController`; убрать `_loadKey`'s
   `isVerifiedCreator` составляющую и проброс из `create_page.dart`.
4. Rental publish возвращается к сегодняшнему поведению — всегда
   `pending_review`, без regressions для уже существующих тестов.
