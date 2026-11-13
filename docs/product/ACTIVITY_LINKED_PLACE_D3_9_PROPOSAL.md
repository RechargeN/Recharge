# D3.9 — Activity linked Place: политика и bounded implementation plan

Дата: 2026-10-11. Статус: **Approved plan — OD-01 вариант A принят владельцем, реализация в Review; завершённые gates в evidence**.
Основание: поручение захода 9, принятый D3.8, RECHARGE_ACTIVITY_CREATE_BLOCK_SPEC.md §13 шаг 5, DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md. Это план, не evidence implementation.

## Проверенный вход

Worktree C:/Users/User/.claude/worktrees/recharge-d3-2, detached HEAD b1e678a23a4db584e496a9d44593fbcf86c45dc0. Принятая D3.8 база: source fingerprint 51a55dd34b12027e15f1ec22de76d85bf94da05d629d7eb750e09e18e8e2e0ce. Перед подготовкой этого документа все 100 файлов принятого source manifest проверены: изменений нет. Значительный ранее авторизованный WIP сохраняется.

Catalog имеет Event и default-off Activity, но не Place projection/Details family. Поэтому готовность Activity Catalog не означает готовность Place lookup. Content имеет Place immutable published revisions/pointers и read-only ContentPublicationFeed; Catalog уже получает их через ContentFeedCatalogSource. Не хватает Catalog-owned exact-ID Place eligibility API, bounded candidate query и authoring picker. Существующий Collection PublishedObjectLookup синхронный и для этой async зависимости не становится новым authority fixture.

Текущий emulator_activity_dependencies.ts отказывает всем linkedPlaceId. Content вызывает composition validation на submit, publish и теле целевой immutable revision при activate; исправление activate уже присутствует. ActivityCreateBlock содержит raw ID поле. Координаты Activity собственные и обязательные; связь с Place необязательна.

## Решение D3.9-OD-01 — требуется до реализации

**Предлагаемый вариант A: Activity самостоятельна, ограничивается только связь.**

1. Для submit, publish ранее одобренной submission и activate целевой revision linked Place должен сейчас быть известным, существующим, опубликованным и публично допустимым Place того же market. Draft, submission, Event с таким ID, owner-hidden, restricted, withdrawn, archived/deleted или неизвестный Place — отказ. Наличие старой projection, старого snapshot или прежнего успешного выбора не разрешает связь. Недоступный Catalog/owner-source тоже даёт отказ; отсутствие linkedPlaceId оставляет standalone путь.
2. После скрытия/ограничения/удаления Place уже опубликованная Activity остаётся видимой по своим собственным правилам. Публичная ссылка и сведения о связанном Place перестают выдаваться во всех Catalog/Discover ответах, включая старые snapshots; причина moderation/внутренние поля не выдаются. В authoring показывается общее «Связанное место недоступно»: можно очистить/заменить связь. Draft и immutable Activity revision автоматически не переписываются.
3. Пока Place недопустим или dependency недоступна, новый submit/publish/activate тела с этим linkedPlaceId запрещён. После разрешённого восстановления Place ссылка снова доступна после свежего Catalog-owned read; Activity pointer и moderation state от этого не меняются, автоматического Content publish/activate нет. Это явно предлагаемый выбор по восстановлению optional relation, не перенос правила D2 Media restoration на другую зависимость.
4. Если lookup недоступен во время публичного Activity read, связь не выдаётся; сама Activity в варианте A остаётся доступной только по её собственным gates. Если lookup недоступен при authoring command, команда отказывается без изменения pointer/revisions/effects. Unknown/unavailable/forbidden имеют стабильные публичные коды и один field path /body/location/linkedPlaceId; внутренняя информация не выдаётся.

**Альтернатива B: linked Place является обязательной зависимостью публичной видимости.** При недопустимом или недоступном Place вся linked Activity отсутствует в Catalog/Discover, включая старые snapshots. Content pointer и immutable revisions не меняются. Восстановление Place вновь разрешает read только после свежего Catalog-owned проверки; это не автоматический Content publish. Эта альтернатива меняет семантику optional relation и требует отдельного явного выбора владельца. Обязательное ручное восстановление после Place restore, если оно требуется владельцу, нужно определить отдельно до реализации; оно не подразумевается ни A, ни B.

Оба варианта запрещают новый submit/publish/activate при плохой зависимости. Рекомендация A следует из принятого контракта: Activity имеет собственную location/accessNotes, Place необязателен и не определяет её географию. Выбор применяется и к скрытию владельцем, и к moderation restriction.

## Catalog-owned контракт и bounded scope после принятия

Catalog владеет `PlaceLinkEligibility` (eligible / unknown / forbidden / unavailable) и bounded picker query. Eligible результат содержит exact Place contentId, текущие publishedRevisionId/pointerRevision, market и allowlisted public title; никаких draft/private/moderation details. Эти snapshots нужны для display/freshness, не являются capability или доказательством eligibility, принимаемым от клиента. Client сохраняет только linkedPlaceId в существующем Activity draft.

Это relation-only Catalog capability, не включение Place в обычные Discover Feed/Map/Details и не принятие остальных BCK08-OD-04 families. Для picker используются существующий guarded Catalog gateway и discoverQueryV1 envelope с явно версионированными additive query types для кандидатов и exact selected ID. Неизвестная версия/unsupported capability отказывается; нет fallback на mock Place authority. Candidate query bounded/paginated; отсутствие результата в странице не означает unknown exact ID.

Catalog читает существующий Content-owned publication feed: добавить exact current pointer read и проверить current immutable Place revision/type/market/public policy/body hash. Content не читает Place коллекции, не хранит Place published/hidden state и не получает moderation reasons. Content consumer port только запрашивает Catalog-owned решение. Единственный policy evaluator живёт в Catalog и используется picker, command checks и public relation filtering. Public reads повторно проверяют current eligibility перед сериализацией, чтобы lag/rebuild/rollback/старый snapshot не разрешали скрытую связь.

Async dependency check выполняется на exact body внутри каждого submit/publish/activate validation path; существующие capability, moderation, Media, revision conflict, command journal и recovery остаются. На activate используется target.body, не текущий draft/current revision. Ошибка adapter превращается в unavailable и field-level validation failure. Свежесть/гонка определены явно: eligibility относится к текущему owner-source read, это не lease и не распределённая атомарность двух aggregates; последующие изменения Place всегда применяются при public read согласно OD-01. Реализация не должна объявлять stronger atomicity без transaction-bound owner-read контракта и его доказательства.

## Точный план файлов — после подтверждения OD-01 и этого плана

Все пути ниже относительно worktree; existing files сохраняют предыдущий WIP.

### Backend

- Новый apps/backend/functions/src/modules/catalog/domain/place_link.ts — owner contract, safe statuses/DTOs.
- Новый apps/backend/functions/src/modules/catalog/application/place_link_service.ts — один exact-ID evaluator и bounded candidates.
- apps/backend/functions/src/modules/catalog/application/ports.ts — exact publication pointer read у существующего owner-source.
- apps/backend/functions/src/modules/content/infrastructure/content_publication_feed.ts — Content-owned read-only exact pointer API; без новой eligibility policy.
- apps/backend/functions/src/modules/catalog/infrastructure/content_catalog_source.ts — adapter, integrity check для Place.
- apps/backend/functions/src/modules/catalog/infrastructure/emulator_catalog_composition.ts — default-off linked Place capability и shared evaluator composition.
- apps/backend/functions/src/modules/catalog/application/discover_query_handler.ts и catalog_query_service.ts — additive picker/exact-resolution envelopes и current relation filter на Feed/Search/Map/Details.
- apps/backend/functions/src/modules/catalog/domain/activity_projection.ts и catalog_item.ts — optional relation facts без наследования location и private Place fields.
- Новый apps/backend/functions/src/modules/content/application/ports/linked_place_eligibility_port.ts — consumer boundary; policy остаётся в Catalog.
- apps/backend/functions/src/modules/content/application/content_publication_service.ts — async checks на submit/publish/activate exact body; без повторной реализации activation lifecycle.
- apps/backend/functions/src/modules/content/infrastructure/emulator_activity_dependencies.ts — прежний deny при disabled/missing capability; Catalog-backed check при explicit enablement.
- apps/backend/functions/src/content_entry.ts и catalog_entry.ts — guarded Emulator wiring, без production entry expansion.
- apps/backend/functions/src/modules/content/domain/validation_details.ts — allowlisted стабильные ошибки связи и field path.
- Новый packages/api_contracts/schema/discover/v1/place_link_result.schema.json и fixtures/place_link.json — bounded public contract; Activity schema/fixture расширяется только optional relation shape.

### Mobile — существующая форма и gateway

- Новый apps/mobile/lib/features/create/domain/repositories/activity_place_link_repository.dart — provider-neutral Catalog read boundary для picker.
- Новый apps/mobile/lib/features/create/data/repositories/catalog_activity_place_link_repository.dart — existing CatalogQueryPort, typed statuses, без direct Firestore.
- Новый apps/mobile/lib/features/create/application/activity_place_link_controller.dart — загрузка кандидатов/selected ID, loading/error/stale и clear; не отдельная форма.
- apps/mobile/lib/app/di/discover_catalog_composition.dart — existing non-release/testBackend/loopback guard + default-off capability.
- apps/mobile/lib/features/create/presentation/pages/create_page.dart и presentation/widgets/activity_create_block.dart — заменить raw-ID entry на bounded search/select/clear в существующем location step; existing draft ID сохраняется честно, без автоматического rewrite.
- apps/mobile/lib/features/create/application/controllers/create_controller.dart — переиспользовать existing updateActivityLinkedPlaceId, не добавлять второй draft store.
- apps/mobile/lib/features/create/application/activity_validation_feedback.dart — stable error mapping возле поля, unknown code generic fallback.
- apps/mobile/lib/features/discover/data/models/catalog_wire_models.dart, data/repositories/catalog_discover_repository.dart, domain/entities/activity_catalog_facts.dart и presentation/shell/compatibility_object_renderer.dart — allowlisted optional public relation, current unavailable state без старого label leakage. Не создавать Place Details route до принятия Place family.

### Проверки и документы

- apps/backend/functions/test/integration/content_activity_enablement.test.ts — расширить имеющиеся submit/publish/old-target activate negative tests и positive Catalog-backed path; verify no pointer/revisions/effects changes on refusal.
- Новый apps/backend/functions/test/unit/catalog/place_link.test.ts — exact owner eligibility, statuses, wrong type/market, bounded candidates, outage и выбранная OD-01 семантика.
- apps/backend/functions/test/emulator/activity_catalog_emulator_flow.test.ts — Place hide/restrict/restore, old snapshot/replay/rebuild/rollback и выбранная relation policy; без дублирования всех D2 Media комбинаций.
- Новый apps/backend/functions/test/contract/place_link_fixture.test.ts; Activity schema fixture существующего contract теста.
- apps/mobile/test/widget/activity_create_block_test.dart — picker selected/clear/unavailable и сохранение draft, без отдельного form flow.
- Новый apps/mobile/test/unit/activity_place_link_controller_test.dart; existing catalog_discover_repository_test.dart и activity_validation_feedback_test.dart — selected policy mapping и failures.
- apps/mobile/test/backend_local/activity_catalog_stand_test.dart — один real Catalog picker → Activity submit/review/publish/activate scenario и выбранное последующее hide policy.
- apps/backend/scripts/stand-d3-8-gate.mjs — bounded extension существующего stand; build до live run, verified stop. При необходимости dedicated D3.9 invocation в существующем runner, без параллельных Emulator групп.
- docs/product/ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md, текущий proposal, docs/architecture/LAUNCH_STATUS.md и новый docs/evidence/backend/d3/D3_ACTIVITY_LINKED_PLACE_2026-10-11.md — принятое решение, статус, одна проверенная revision и точный долг.

Никаких runtime edits до подтверждения. Контракт/DTO имена выше предложены, а не выдаются за уже существующий BCK-08 контракт. Изменять другие Create types, Category System, Payments, production, full Place Catalog/Discover или Accepted ADR не требуется.

## Acceptance criteria

1. Разрешённый опубликованный Place выбирается по exact ID из Catalog-owned кандидатов; Activity retains own pin/accessNotes.
2. submit, publish ранее approved submission и activate exact old/hidden target получают свежий Catalog-owned outcome. Unknown, wrong type/market, private/hidden/restricted/deleted/unpublished и dependency outage отказываются без побочных lifecycle effects.
3. Смена Place после выбора/submit, старый draft, immutable revision, stale picker response и snapshot не обходят проверки. Старые drafts автоматически не мигрируют.
4. После hide/restrict/restore выполняется явно выбранная OD-01 политика на всех публичных surfaces, replay/rebuild/rollback её не отменяют. Нет Place authority или shadow hidden state в Content.
5. Existing form, controller/gateway/journal/capabilities/revision conflicts/recovery сохранены; unknown violation code использует общее сообщение.
6. Default-off capability и explicit fallback deny; отсутствие backend/picker capability никогда не включает mock authority.
7. Зелёные affected backend unit/contract/integration и targeted Emulator gates; full Flutter analyzer/test, boundary, diff/source fingerprint; live stand отдельно от device/production. Неповторяемые gates обоснованы по изменённым механизмам.

Rollback: выключить linked Place capability на backend/mobile и вернуть прежний deny; сохранённые drafts/revisions не переписывать. Public read остаётся fail closed для связанных Place, не выдаёт старый label или обход guards. Exact public Activity visibility после отключения следует выбранной OD-01 политике. Production/merge/commit не разрешены.

Owner decision 2026-10-11: «A — Activity видима, связь скрыта; подтверждаю bounded lookup/picker и план (рекомендуется)». This authorizes the bounded implementation; slice acceptance follows verified evidence.

## Implementation scope clarification (2026-10-11)

OD-01 A and the file plan are owner approved. Runtime implementation is in Review pending the recorded gates; this is not owner acceptance of the finished slice. Existing `updateActivityLinkedPlaceId` and Catalog entry delegation were reused without unnecessary edits. The existing `activity_publication_composition.dart`, `service_locator.dart`, `create_providers.dart` and `build_activity_content_body.dart` require additive wiring/mapper capability because the old mapper intentionally rejected links before transport. Missing DI composition returns explicit unavailable. `activity_content_body_mapper_test.dart` and a dedicated `activity_linked_place_stand_test.dart` exercise this same existing publication path; `stand-d3-8-gate.mjs --yes --linked-place` selects the bounded gate, preserving the original invocation. No separate form, journal, lifecycle or Place Details route is introduced.
