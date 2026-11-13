# D2 — поправка: реакция на ограниченное или удалённое Media опубликованного Content

Статус: **D2 в реализации** (2026-10-09). План, карта файлов и решения владельца
приняты 2026-10-09.

Область: локальный стенд `demo-recharge` (Emulator, loopback). D2 закрывает
требование BCK-07 §38.11.6: механизм, который замечает опубликованные ревизии,
ссылающиеся на позднее ограниченное или удалённое Media, и реагирует на них.
Не облако, не deploy, не подписанные URL, не CDN, не клиентский кеш (это F2a),
не мобильный клиент. Ни одно правило `MEDIA_STORAGE_BACKEND_SPEC.md` и
`CONTENT_PUBLICATION_BACKEND_SPEC.md` не ослабляется.

## 0. Отделение от D1-L

D1-L (Linux gate, 13 файлов) не закоммичен. Перед первой правкой D2 снят снимок
`%LOCALAPPDATA%\Recharge\slice-baselines\d1l-2026-10-09\` (база
`8c69715bba03eb1cef7309d4496ebfddd6d11a1e`): `d1l_tracked.patch`
(`ce3d7cb07528c1b8696d776ede6835d773cfcefdd9a9efbf2ebb5d8643c32c60`),
`d1l_untracked.tar` (`d8f0297d3b487b7c6a9813d6427381d3999deebb0a68a40261bfdb4e8cc8d0b3`).
Коммиты D1-L и D2 собираются раздельно.

## 1. Решения владельца (2026-10-09)

| Вопрос | Решение |
|---|---|
| Что такое «выдача Media» в D2 | шлюз + минимальная Emulator-only выдача реальных байтов публичного варианта; авторизация, актуальное состояние публикации и закреплённое поколение проверяются на каждом запросе. Подписанные URL, CDN и клиентский кеш остаются F2a; D2 их рисков не закрывает |
| Реакция Content | подавить только затронутое Media; публикация остаётся в Catalog без него; видимость Event и Booking не меняются |
| Возврат | только явным действием уполномоченного издателя (повторная активация текущей ревизии). `MediaDeliveryRestored` подавление не снимает; удалённое Media не возвращается |
| Источник ограничения | staff-модерация: действия `restrict_media` / `restore_media` над `assetId` |
| Сироты | удаление байтов — только в экземпляре гейта D2 с явно тестовой политикой хранения; без политики — `policy_unavailable`, ничего не удаляется |
| Сценарий «ограничили → сняли при выключенном потребителе Content» | выдача остаётся запрещённой до явной активации; закрывается устойчивым маркером (§3) |

Позднее скрытие Content не заменяет доказательство прекращения выдачи.

## 2. Что входит

1. Шлюз выдачи `mediaDeliveryV1` (§4).
2. Устойчивый маркер отзыва в Media и подтверждение в Content (§3, §5).
3. Подавление Media в указателе публикации, факты для Catalog, Booking без
   изменений (§5, §6).
4. Возврат повторной активацией текущей ревизии (§5.4).
5. Потребитель `mediaEffects`, проверка после публикации/активации, сверки R1/R2
   (§5.3, §8).
6. Ограничение и снятие ограничения Media через staff-модерацию (§7).

## 3. Устойчивый маркер: эпоха отзыва

- Запись ассета Media получает `revocationEpoch` (отсутствие = 0) и
  `restrictionDecisionRef`. Оба поля внутренние: в `MediaAssetV1`-представление
  для владельца не попадают.
- `revocationEpoch` монотонна: +1 в той же транзакции, что применяет решение об
  ограничении (каждое новое решение) или начинает удаление (`beginDeletion`,
  `abortUpload`). Снятие ограничения её не уменьшает. Удержание удаления её не
  меняет: оно и так выключает выдачу (`deliveryDisabled`), а опубликованный
  ассет удалить нельзя — удаление отказывает при ссылке.
- Ограничение хранит решение. Снять его может только инструкция, которая
  восстанавливает именно действующее решение (`restoresDecisionRef` ==
  `restrictionDecisionRef`); иначе `stale_revision`, ничего не меняется. Новое
  ограничение заменяет старое.
- Свидетельство готовности (`MediaReadinessPort`) при `ready` возвращает
  `confirmations: [{assetId, revocationEpoch}]`. Хэш `mediaRevision` и
  неизменяемая ревизия эпоху не содержат: иначе откат после цикла ограничения
  стал бы невозможен навсегда.

## 4. Шлюз выдачи `mediaDeliveryV1` (Emulator-only)

Запрос `{schemaVersion: 1, contentId, assetId, profile}`; ответ — байты варианта
(base64), тип и SHA-256. Ни URL, ни дескриптора, ни заголовков кеша.

| Шаг | Проверка | Отказ |
|---|---|---|
| 1 | Session действительна (та же проверка, что у `discoverQueryV1`); флаг `media.delivery` | `unauthenticated` / `capability_denied` |
| 2 | Content из своих записей: публикация видима, текущая ревизия закрепляет `assetId`, подавления нет, подтверждение есть → поколение, манифест, эпоха, `pointerRevision` | `not_found` |
| 3 | Media: `ready`, `!deliveryDisabled`, `publicDerived`, поколение и манифест = закреплённым, **эпоха = подтверждённой**, вариант профиля есть | `not_found` |
| 4 | байты варианта с условием на поколение и лимитом; SHA-256 = манифест | `not_found` |
| 5 | повторно Content: `pointerRevision` не изменилась | `not_found` |
| 6 | повторно Media, последней: ревизия ассета не изменилась | `not_found` |

Все отказы после шага 1 — `not_found`: существование не раскрывается. Модули
читаются короткими отдельными транзакциями; межмодульного вызова под
блокировкой нет (AC-107).

## 5. Content: подтверждение, подавление, возврат

### 5.1 Указатель публикации

Необязательные поля (отсутствие = пустой список; хранятся только непустые):

- `mediaConfirmations: [{assetId, revocationEpoch}]` — из свидетельства при
  публикации и активации;
- `mediaSuppression: [{assetId, reason: 'revoked' | 'deleted', observedEpoch}]`
  — растёт только; уменьшается только активацией издателем.

### 5.2 Ядро `reconcileContent(contentId)` — по состоянию, не по событию

1. Короткой транзакцией: указатель и текущая ревизия.
2. Вне транзакции: состояние и эпоха закреплённых ассетов у Media.
3. Нужное подавление: нет записи, `deleting`, `deleted` → `deleted`;
   ограничено, нет подтверждения, эпоха ≠ подтверждённой или поколение/манифест
   ≠ закреплённым → `revoked`; только удержание удаления → без изменений;
   Media недоступно → без изменений, итог `unavailable`.
4. Транзакция Content сверяет ревизию указателя (CAS). Если нужное подавление
   шире текущего — новая ревизия указателя и эффект
   `ContentMediaAvailabilityChanged`; иначе ничего не пишется.

### 5.3 Три запуска одного ядра

- (a) потребитель `mediaEffects` (`consumeMediaEffectV1`): свой checkpoint и
  квитанции в коллекциях Content; по `assetId` находит Content через индекс
  `mediaAssetIds`;
- (b) потребитель эффектов Content `mediaVerification` (в
  `consumeContentEffectV1`): после каждой публикации/активации/возврата —
  закрывает гонки §38.11.2 и возврата;
- (c) сверка R1 (§8).

### 5.4 Возврат издателем

`activatePublishedRevision` на текущей ревизии разрешена, если есть подавление
или свидетельство показывает эпоху ≠ подтверждённой. Перепроверяются: право
`publish`, тип и справочники, что ревизия — текущая, все закреплённые ассеты
`ready`, без ограничения, удержания и удаления, с тем же поколением и
манифестом, `mediaRevision` совпадает. Удержание модерации →
`publication_restricted`; удалённое Media → `media_not_ready`. Итог:
подтверждения = эпохи из свидетельства, подавление пусто. Если видимость не
меняется — эффект `ContentMediaAvailabilityChanged` (Booking не затрагивается);
если заодно снимается удержание издателя — `ContentRevisionActivated`, как
раньше. Повтор с тем же ключом возвращает сохранённый результат без эффектов;
новый ключ при полностью подтверждённой ревизии — `revision_conflict` без
эффекта.

## 6. Catalog и Booking

- Каждый эффект Content несёт `suppressedMediaIds` текущего указателя (поле
  опускается, когда пусто: хэши старых фактов не меняются).
- Catalog: подавленная обложка → `coverMediaId = null`. Rebuild переигрывает
  факты и не возвращает запрещённое Media; сверка Catalog видит разрыв по
  `pointerRevision` и переигрывает его. Форма проекции та же.
- Передача Event → Booking: эффект `ContentMediaAvailabilityChanged` не даёт
  фактов, продвигает `lastPointerRevision` (непрерывность сохраняется), пишет
  квитанцию с 0 фактов. Состояние Event и Booking не меняется.

## 7. Модерация Media

- Действия `restrict_media` и `restore_media` (с `restoresDecisionId`), цель
  `{assetId}`; решение записывается с аттестацией, как для Content.
- `MediaRestrictionVerifier` (модуль модерации) реализует порт Media и
  возвращает `{verified, restoresDecisionRef}`; исполнение — через
  `applyRestriction` Media.
- Поддельное, чужое или не совпадающее решение и восстановление не действующего
  решения ничего не меняют.
- Стенд: `stand-moderate.mjs restrict-media <assetId> --reason …`,
  `restore-media <assetId> --decision <id> --reason …`.

## 8. Сверки

- **R1 (Content ↔ Media):** страницы указателей с вложениями → `reconcileContent`.
  Ловит потерянные и пропущенные эффекты; подавление не снимает.
- **R2 (сироты Media):** существующий `OrphanReconciler` по страницам ассетов.
  Ссылки — `ContentMediaScope.isReferenced` (черновики и все опубликованные
  ревизии; сомнение = ссылка; до транзакции; под удержанием удаления). Без
  политики хранения — `policy_unavailable`. В экземпляре гейта D2 — политика
  с пометкой «test-only» и управляемыми часами. Ограничение R2 не трогает.

## 9. Поверхность запуска

Только Emulator, флаги по умолчанию выключены:

| Экспорт | Вид | Флаг |
|---|---|---|
| `mediaDeliveryV1` | onCall | `media.delivery` |
| `consumeMediaEffectV1` | onDocumentCreated `mediaEffects/{effectId}` | `content.mediaAvailability` |
| `reconcileMediaReferencesV1` | onSchedule: R1, затем R2 | R1 — `content.mediaAvailability`, R2 — `media.reconcile` |

Потребитель `mediaVerification` идёт под флагом `content.mediaAvailability`.

## 10. Остаточные окна (не нулевые, без гарантии по времени)

| Окно | Что происходит | Чем закрывается | Что остаётся |
|---|---|---|---|
| W1 выдача в процессе | ответ, прошедший шаг 6 до коммита ограничения | Media проверяется последней | один ответ; полученные байты у клиента (F2a) |
| W2 смена публикации | изменение указателя после шага 5 (снятие, скрытие модерацией, новая ревизия, подавление) | повторная проверка `pointerRevision` | один ответ с не отозванным Media; отозванное ловит шаг 6 |
| W3 отставание Content/Catalog | Catalog ещё отдаёт `coverMediaId` | шлюз отказывает сразу (эпоха/состояние); (a), (b), R1 | идентификатор виден до сходимости, байтов нет |
| W4 гонка публикации/возврата (§38.11.2) | ревизия подтвердила старую эпоху | шлюз отказывает по эпохе; (b) подавляет | — |
| W5 пропуск ленты | эффект с ранней отметкой времени после checkpoint | R1 | задержка до следующего R1 |
| W6 удержание удаления | выдача закрыта, подавления нет | удержание снимается или удаление → `deleted` | — |

Межмодульной атомарности нет (AC-107).

## 11. Проверки

| № | Что | Где |
|---|---|---|
| T1 | реальные байты публичного варианта (SHA-256 = манифест, WebP от sharp, без EXIF/GPS); чужое/неопубликованное/снятое/неизвестное → `not_found`; некорректный запрос → `invalid_contract`. Session и флаг обёртки — T15 | integration + Emulator |
| T2 | отказ сразу после ограничения при выключенных потребителях; Content без подавления, Catalog отдаёт `coverMediaId` | Emulator |
| T3 | ограничили → сняли при выключенном потребителе → отказ по эпохе; включили → подавление, `coverMediaId = null`; активация → выдача; фактов Booking нет | integration + Emulator |
| T4 | дубли и перестановки Disabled/Restored до и после активации → без лишних ревизий и эффектов | integration |
| T5 | потеря worker: сбой до и после коммита → повтор сходится, одна ревизия подавления | integration + Emulator |
| T6 | поздний запуск после нескольких изменений = то же состояние | integration |
| T7 | гонки публикации и возврата: шлюз отказывает сразу, (b) подавляет | integration |
| T8 | rebuild/активация/откат набора Catalog не возвращают подавленную обложку; после возврата обложка есть | integration + Emulator |
| T9 | ветка `deleted` (подготовленное состояние) → подавление; возврат отклонён | integration |
| T10 | R2: сирота удалена из Storage Emulator; ссылка из черновика/старой ревизии/недоступный Content → сохранён; R1 находит пропущенный эффект | integration + Emulator |
| T11 | модерация: подделка, чужое решение, восстановление не действующего решения, замена новым | integration |
| T12 | W1/W2: смена Media между шагами 3 и 6, смена указателя между шагами 2 и 5 → отказ | integration |
| T13 | Booking пропускает эффект только Media: 0 фактов, непрерывность (Emulator: число фактов outbox не меняется) | unit + Emulator |
| T14 | стражи: точный список экспортов и триггеров; шлюз и реакция Content не вызывают другой модуль под транзакцией (проба блокировки во время вызова); нет URL, кеша и логов байтов; все отказы шлюза — `not_found` | integration |
| T15 | `mediaDeliveryV1` по HTTP через Functions Emulator: без токена и с токеном без Session → `unauthenticated`; Session при отсутствующем и при выключенном `media.delivery` → `capability_denied`; при включённом запрос доходит до шлюза (`not_found`, `invalid_contract`). Проверяется конкретный код; флаг, Session и пользователи Auth восстанавливаются после файла | Emulator (Functions) |

Гейт `stand-d2-gate.mjs` (Windows-local): сборка, D2-тесты без Emulator, затем
инструменты D1 (L1) ради настоящего варианта от sharp и Emulator-сценарий
T1 → T2 → T3 (с T5) → T8 → T10 под `firebase emulators:exec` (auth, firestore,
storage) в процессе теста — без долгоживущего стенда и без Functions Emulator.
T15 (`media_delivery_callable.test.ts`) идёт в общем `test:emulator`, где
работает Functions Emulator.

## 12. Карта файлов (фактическая)

Пересечений с D1-L нет. Пути от `apps/backend/` (кроме `packages/` и `docs/`).

**Новые (22):**

```text
functions/src/media_effects_entry.ts
functions/src/modules/content/application/content_media_availability.ts
functions/src/modules/content/application/ports/media_availability_port.ts
functions/src/modules/media/application/media_delivery_gate.ts
functions/src/modules/media/application/orphan_sweep.ts
functions/src/modules/media/application/ports/published_media_port.ts
functions/src/modules/media/infrastructure/media_effect_feed.ts
functions/src/modules/moderation/infrastructure/media_moderation_adapter.ts
functions/src/modules/moderation/infrastructure/media_restriction_verifier.ts
functions/test/emulator/media_delivery_callable.test.ts
functions/test/emulator/media_late_restriction_flow.test.ts
functions/test/integration/content_media_availability.test.ts
functions/test/integration/media_delivery_gate.test.ts
functions/test/integration/media_orphan_sweep.test.ts
functions/test/integration/moderation_media_restriction.test.ts
functions/test/stand/stand_media_reconcile.ts
functions/test/unit/catalog/catalog_media_suppression.test.ts
functions/test/unit/content/publication_pointer_media.test.ts
functions/test/unit/media/media_revocation_epoch.test.ts
scripts/stand-d2-gate.mjs
packages/api_contracts/schema/media/v1/media_delivery.schema.json
docs/product/MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md
```

**Изменённые:** контракты (`content_v1.ts`, `media_schema_registry.ts`, схема
указателя и фикстуры Content и Media), Media (`media_asset.ts`,
`media_attachment.ts`, `repositories.ts`, `media_deletion_service.ts`,
`content_media_readiness.ts`, порты `actor_authority_port.ts` и
`object_store_port.ts`, оба репозитория, `fake_object_store.ts`,
`storage_emulator_object_store.ts`, `emulator_media_composition.ts`), Content
(`publication_pointer.ts`, `repositories.ts`, `event_internal_registration.ts`,
`content_publication_service.ts`, `content_media_scope.ts`,
`event_booking_handoff.ts`, `media_readiness_port.ts`, оба репозитория), Catalog
(`catalog_item.ts`, `catalog_projector.ts`, `content_catalog_source.ts`),
модерация (`moderation.ts`, `moderation_service.ts`, `ports.ts`,
`emulator_moderation_composition.ts`), точки входа (`index.ts`,
`media_entry.ts`, `content_entry.ts`, `content_effects_entry.ts`,
`feature_flags.ts`), `firestore.rules`, `config/manifests/execution-manifest.json`,
стражи (`verify-r1-exports.mjs`, `verify-r1-layout.mjs`,
`verify-content-persistence-layout.mjs`, `run-emulator-tests.mjs`,
`functions/package.json` — список `test:emulator`), стенд
(`stand-moderate.mjs`, `stand-seed.mjs`, `stand_flags.ts`, `stand_main.ts`,
`stand_media.ts`, `stand_moderation.ts`), тесты и помощники
(`content_event_world.ts`, `content_repository_scenarios.ts`, стражи
`media_security`, `content_publication_security`, `content_rules_default_deny`,
подделки портов в четырёх тестах Media и двух тестах Content), спецификации
(`MEDIA_STORAGE_BACKEND_SPEC.md` §34.15, `CONTENT_PUBLICATION_BACKEND_SPEC.md`
§38.11.6, `DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md` §35,
`BACKEND_MEDIA_STORAGE_COVERAGE_MATRIX.md`, `LAUNCH_STATUS.md`).

**Добавлено при реализации, вне принятой карты:**

- `content_catalog_source.ts` — переносит `suppressedMediaIds` в факт Catalog.
  Без этого Catalog терял подавление: ошибку поймал Emulator-тест гейта (T3),
  а не unit-тесты; добавлен unit-тест на перенос.
- `config/manifests/execution-manifest.json` и `verify-r1-layout.mjs` — реестры
  коллекций и файлов, которые требуют явной записи новых путей.
- Восстановление ограничения требует ссылки на действующее решение: подделки
  портов в существующих тестах Media получили карту `restores`; поведение
  снятия «чужим» решением теперь `stale_revision`.
- Обход R2 удаляет и ограниченную сироту (существующая логика BCK-14):
  ограничение не снимается, надгробие держит выдачу закрытой. Удержаний по
  закону и безопасности нет (BCK-04 / OD-07) — открытый пункт.
- Формат вариантов D1 — WebP; T1 проверяет WebP.
- `media_delivery_callable.test.ts` и строка в `functions/package.json` — T15:
  статической проверки границ доступа обёртки было недостаточно.
- Не D2: исправление остановки стенда (`scripts/emulator-stand.mjs` и его
  тест) — отдельное изменение. Принадлежность процесса — PID вместе со
  временем создания; переиспользованный PID не блокирует успех; сомнительный
  процесс не завершается, а остановка с ним или с занятым портом не
  подтверждается.

## 13. Статус

**Review (2026-10-10).** Windows-local Emulator evidence; не Done.

**Проверенная ревизия: `8c69715+wt:3c31bd0c7065`.** Это изолированная копия
R3: HEAD `8c69715` (`codex/recharge-integration`) плюс изменения D1-L, D2 и
исправление стенда — 103 файла. Копия понадобилась потому, что другая сессия
во время прогона меняла `apps/mobile`, `AGENTS.md` и `docs/` в общем рабочем
дереве. Прогон R2 (`8c69715+wt:417e1e26f3ec`) поэтому недействителен; цепочка
R1 (`8c69715+wt:16dec5c2f893`) — промежуточная.

Отпечаток: пути, отличающиеся от HEAD (`git diff --name-only HEAD`), и
неотслеживаемые (`git ls-files --others --exclude-standard`) — по строке
«путь TAB SHA-256 содержимого», отсортировано; первые 12 hex SHA-256 этого
списка. Исключены только два статусных документа (эта поправка и
`LAUNCH_STATUS.md`): гейты их не читают. Отпечаток до и после прогона совпал;
собственные файлы рабочего дерева побайтно совпадают с R3.

| Проверка | Результат |
|---|---|
| сборка, lint, формат | без ошибок |
| тесты без Emulator | 934/934 |
| тесты скриптов | 43/43 |
| стражи `verify:*` | пройдены |
| `test:emulator` | 185/185, в том числе T15 4/4 |
| гейт D2 | 72 без Emulator + 5/5 в Emulator |
| гейт D1 | пройден (L1, Windows-local) |
| 11 гейтов стенда | пройдены, каждая остановка подтверждена |
| start → stop → start → stop без `reset` | пройден, порты стенда свободны |
| `api_contracts` | 25/25 |
| `flutter analyze` / `flutter test` | 0 замечаний / 1303 пройдено, 20 пропущено |

Открыто (D2 эти пункты не закрывает):

- OD-07 (BCK-04): удержания по закону и безопасности. R2 удаляет и
  ограниченную сироту.
- F2a: подписанные URL, CDN, клиентский кеш.
- Окна W1–W6 (§10) описаны, но не закрыты; межмодульной атомарности нет.
- Гейты Linux, физического устройства, облака и production: Windows/Emulator
  evidence их не закрывает.
- Мобильный клиент выдачи Media.
