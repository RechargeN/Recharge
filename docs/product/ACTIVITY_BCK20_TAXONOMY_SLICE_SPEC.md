# BCK20-ACT-TX-01 — immutable taxonomy reader и сборка dataset

Дата: 2026-10-11. Статус: **Review — локальная реализация после поручения выполнить заход 8**.
Авторизация: пользователь выбрал подготовку отдельного BCK-20 slice с reader и сборкой dataset из принятой Category System v1.4.3. После подготовки пользователь повторно поручил выполнить заход 8. Это разрешает локальную реализацию prerequisite; не означает владельческую приёмку publication или production.
Вход: принятый BCK08-OD-04-A; recharge-d3-2, HEAD b1e678a23a4db584e496a9d44593fbcf86c45dc0.

## 1. Источник и цель

Канонический источник: docs/product/CATEGORY_SYSTEM.md, v1.4.3; SRCREC-CATEGORY-143-001. Проверенный SHA-256 UTF-8 bytes с CRLF→LF: 5dfe5347363eeb7d72933812424f22667e730a6edfb16aeb7c79fbeb8ef259f9. Это хеш документа, не будущего dataset.
Цель: один immutable BCK-20 dataset и reader через существующий reference-data port; Content проверяет Activity applicability/required criteria, Catalog читает историческую taxonomy revision. Нет второго справочника, новой формы, автоматической миграции drafts, cloud или production activation.

Mobile recharge_taxonomy_seed.dart и recharge_category_criteria.dart — источники сверки реализации. Canonical document побеждает при расхождениях. Getter effectiveApplicableTypes расширяет utility-типы; эти расширения не становятся authority backend. Текстовые descriptions критериев не являются автоматически машинными validators или публичной allowlist.

## 2. Предлагаемый dataset

Полный структурный snapshot канонической taxonomy, но runtime-подключение в этом slice только для Activity. Поля: schemaVersion, taxonomyId, semanticVersion, sourceRecordId, sourceDocumentSha256; categories и subcategories с каноническими IDs, explicit applicableTypes, resolved profileId; profiles с fieldIds и requiredFieldIds. Required всегда subset fieldIds; override подкатегории побеждает default категории. Служебные/hidden записи сохраняют explicit статус; не разрешаются по правилу «всё скрытое применимо ко всем».

Никаких новых labels/translations, regional policy, criterion bounds, enums или public flags из догадок. Known nonapplicable pair возвращает false; неизвестная пара на доступном полном snapshot также false; отсутствующий snapshot даёт отдельный revision failure. Известный профиль без обязательных полей возвращает [], не unavailable.

Artifact payload сериализуется UTF-8 JSON без BOM/отступов/конечного newline, object keys сортируются рекурсивно ordinal; registry lists сортируются по id, множества IDs по ordinal, порядок других массивов сохраняется. Только JSON primitives; без undefined/NaN/Infinity. artifactSha256 — SHA-256 этих bytes. Manifest отдельно хранит revisionId, artifactSha256, source provenance и acceptance evidence; hash не включает manifest и себя.

Предлагаемый revisionId: taxonomy-1.4.3-sha256:<полный artifactSha256>. Ни hash, ни acceptance evidence не заполняются вымышленными значениями. Изменение bytes требует новой revision; старые artifacts остаются доступны. Publication taxonomyRevisionId хранит точный revisionId.

## 3. Предлагаемый reader contract

Расширить существующий ReferenceDataPort дополнительным readTaxonomyRevision(input: {taxonomyRevisionId: string}) методом, а не создавать параллельный consumer port. Метод возвращает discriminated result:

- ok: true; revisionId; artifactSha256; immutable dataset (формат §2).
- ok: false; code: taxonomy_revision_unknown | taxonomy_revision_unavailable | taxonomy_integrity_failed.

unknown: revision отсутствует в registry; unavailable: известна, но artifact недоступен; integrity_failed: bytes/hash/provenance не совпали. Результаты не содержат локальных путей, внутреннего exception или storage metadata. Исключение адаптера преобразуется в unavailable. Ни latest, ни fixture fallback не допускаются.

Существующий resolve({marketId,typeId,nowUtc}) сохраняет envelope и semantics. Для Activity resolver выбирает только явно сконфигурированную принятую revision и строит существующие ReferenceLookups из reader result. Additive readTaxonomyRevision capability является optional для прежних Event-only implementations; Activity consumers при её отсутствии возвращают taxonomy_revision_unavailable. Тихого fallback нет. Emulator Activity resolver читает только закреплённый artifact, общий Catalog flag остаётся default-off.

Catalog сначала проверяет visibility, затем читает taxonomyRevisionId из immutable source.referenceRevisions и вызывает reader именно с этим ID. Current reference resolver не используется как замена historical read. Ошибка reader запрещает Activity projection/read; публичный отказ согласуется с существующим Catalog error envelope, без создания нового wire API в этом prerequisite.

## 4. Public criteria: предложенное безопасное решение

В первой версии Activity Catalog не публикует dynamic criteria: поле criteria отсутствует; категории, duration, bestTime и contribution остаются по OD-04. Reader/profile нужны для applicability и required criteria. Владелец явно подтвердил это уточнение OD-04 2026-10-11: список полей профиля сам по себе не доказывает публичность каждого значения.

Если владелец требует criteria в первой версии Catalog, до реализации требуется явная accepted allowlist по fieldId с value type/allowed values и public display semantics. Без этого списка произвольные ключи и значения не публикуются. Данный документ не принимает этот выбор самостоятельно.

## 5. Сборка и этапы

1. Собрать таблицу всех 28 categories, 530 subcategories и 21+fallback profiles по §6–7 canonical document. Resolve group defaults и subcategory overrides. Сверить IDs, applicability, profiles, required fields с mobile seeds; сформировать parity report каждого расхождения. Не считать только совпадение count доказательством.
2. Детерминированный generator производит payload, hash и кандидат manifest; повторная сборка даёт bytes-identical result. Source hash mismatch, duplicate ID, dangling profile/field или неоднозначность парсинга останавливают сборку. Никакого regex best-effort acceptance.
3. Принять контракт и решение §4, затем принять конкретный artifact/manifest после parity review. Не объявлять технический build принятой revision автоматически.
4. Реализовать локальный reader/registry в BCK-20 и подключить Activity через существующий port. Минимальная пятизаписная fixture остаётся только в тестах. Старые draft IDs и immutable revisions не переписываются; неизвестные legacy revision явно отказываются.
5. После prerequisite gates продолжить заход 8: Catalog union/projection, existing Discover/Details mapping, kill switches и D2/replay/rebuild stand gates.

## 6. Точный план файлов

Новые файлы после принятия:
- packages/api_contracts/schema/reference_data/v1/taxonomy_dataset.schema.json
- apps/backend/scripts/build-taxonomy-dataset.mjs
- apps/backend/functions/src/modules/reference_data/domain/taxonomy_dataset.ts
- apps/backend/functions/src/modules/reference_data/infrastructure/local_taxonomy_reader.ts
- apps/backend/functions/test/reference_data/unit/taxonomy_dataset.test.ts
- apps/backend/functions/test/reference_data/contract/taxonomy_dataset_contract.test.ts
- apps/backend/functions/test/reference_data/integration/taxonomy_reader.test.ts
- packages/api_contracts/schema/reference_data/v1/artifacts/category-system-1.4.3.json и taxonomy_manifest.json — только проверенный generator output, не ручной справочник.

Изменяемые:
- modules/reference_data/domain/repositories.ts — owning artifact repository boundary;
- modules/content/application/ports/reference_data_port.ts — exact revision read contract;
- modules/content/infrastructure/emulator_reference_data.ts и emulator_activity_taxonomy.ts — reader composition вместо runtime fixture;
- modules/catalog/infrastructure/content_catalog_source.ts — historical revision access для последующего Catalog slice;
- test/unit/content/emulator_activity_taxonomy.test.ts и существующие Content Activity contract/unit tests — fixture separation и parity;
- functions/package.json — build/check script; runner groups только если добавленные Emulator tests требуют регистрации;
- docs/product/REFERENCE_DATA_LOCALIZATION_SPEC.md — additive contract annex после принятия; исходные Accepted owner decisions и ADR не редактируются;
- docs/architecture/LAUNCH_STATUS.md — фактические результаты, без автоматического Done.

Пути modules/test относятся к apps/backend/functions/src и apps/backend/functions/test соответственно. Mobile runtime в prerequisite не меняется; seeds/criteria только читаются для parity.

## 7. Acceptance criteria и gates

AC1 source hash совпадает с SRCREC binding; полная parity таблица проверена, неоднозначностей нет.
AC2 dataset unique IDs, valid profile references, required subset, full counts и конкретные Activity positive/nonapplicable pairs.
AC3 две сборки bytes-identical; modified artifact без новой integrity binding отказывается.
AC4 reader exact historical revision, unknown/unavailable/corrupt explicit refusal; no latest/fixture fallback.
AC5 существующий resolve совместим; Activity submit/publish/activate используют applicability/required criteria; false/0 не ошибочно missing, whitespace missing по существующим правилам.
AC6 old drafts/revisions unchanged; legacy test-only revision не переименована в accepted.
AC7 минимальная fixture только test; default-off flags и source/provenance manifest проверены.
AC8 backend build до live run; affected reference_data/content/schema gates green; существующие Event/Place compatibility tests сохранены. diff check и source fingerprint приложены. Flutter gates обязательны только при фактических Flutter edits, которых здесь не планируется.

Catalog stand/replay/D2/full Flutter acceptance относится к последующему заходу 8, не заменяется этим prerequisite.

## 8. Откат и граница завершения

Возврат прежней Emulator composition и выключение Activity Catalog/Discover. Не удалять immutable artifacts или существующие journals/drafts; test fixture не становится accepted fallback. Старый runtime остаётся явно synthetic.

Результат подготовки: контракт-предложение и reviewable slice. Результат реализации после принятия: проверенный artifact manifest, reader и точная общая revision/fingerprint. Production и market activation остаются выключены.

## Реализованный контракт и provenance

Artifact: packages/api_contracts/schema/reference_data/v1/artifacts/category-system-1.4.3.json; JSON schema: taxonomy_dataset.schema.json. Revision: taxonomy-1.4.3-sha256:d5d4472629d52b8f3db883d9a449bcbfd5fa18e5f87a6d6aa26ae5b98168c822. Сборщик build-taxonomy-dataset.mjs проверяет закреплённый source hash и registry counts; --check проверяет artifact, runtime mirror и manifest. Bundled generated mirror переносит те же immutable bytes, не является вторым authoring registry. Reader возвращает deep-frozen dataset и explicit unknown/unavailable/integrity failure; existing ReferenceDataPort расширен additive capability, без нового справочника.

28 категорий, 530 подкатегорий, 22 profiles. Activity parity с mobile: applicability, profile и required fields совпадают. Единственное отличие общего registry вне Activity — other_event: canonical all-ten против ограниченной mobile declared applicability; оно зафиксировано отдельно и не исправляется в данном slice. Старые drafts/revisions не переписываются. Minimal Activity fixture остаётся только в tests. Canonical semantic source принят; это не новая владельческая приёмка immutable publication revisions или production MarketConfig.

Rollback prerequisite: вернуть прежнюю Emulator Activity reference-data композицию; не переименовывать сохранённые revisions и не заменять unknown историческую revision fixture.
