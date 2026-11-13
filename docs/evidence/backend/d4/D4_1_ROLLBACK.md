# D4.1 — откат импорта и fenced cleanup (только Emulator): evidence

Дата 2026-10-13. Ветка `claude/m1-3-import-rollback` от `1749d1d` (заход 3a,
amendment). Нормативный текст:
[LOCAL_IMPORT_D4_1_ROLLBACK_AMENDMENT.md](../../../product/LOCAL_IMPORT_D4_1_ROLLBACK_AMENDMENT.md).
Checklist M1: [M1_LOCAL_CONTOUR_CHECKLIST.md](../../../verification/M1_LOCAL_CONTOUR_CHECKLIST.md),
заход 3.

## Проверенный код

Проверки 3b шли на рабочем дереве поверх `1749d1d`; коммит этого захода
содержит ровно проверенный код (SHA — в истории ветки). Итоговая приёмка на
чистом worktree этого SHA — заход 3c,
[M1_ACCEPTANCE.md](../m1/M1_ACCEPTANCE.md).

Среда: Windows 11 Home 10.0.26100, Flutter 3.44.9, Node 22.23.2, npm 10.9.8,
Temurin 21.0.12+8; стенд и Emulator `demo-recharge` на 127.0.0.1. Клиент —
`flutter test` на ПК против стенда; устройств, LAN и cloud нет. Журналы вне
checkout, в scratchpad сессии Claude
(`…/fb5bbe95-84a3-45b7-aa07-ad5cdfdf0985/scratchpad/logs/s3/`).

## Результаты

Код и тесты последний раз изменены в 21:53:46 (+03:00); гейт D4 шёл
21:54:06–21:56:24, остальные проверки — 21:56:58–22:13:33. После этого менялись
только документы.

| Проверка | Результат |
|---|---|
| Backend `format:check`, `lint`, `typecheck`, `build` | pass |
| `test:unit` / `test:contract` / `test:r1:integration` | 729/729 / 55/55 / 254/254 (из них 9 новых integration: 7 в `content_local_import_rollback`, 1 в `content_local_import`, 1 новый сценарий репозиториев) |
| `verify:r1:layout`, `verify:content-persistence:layout` | pass |
| `test:emulator:runner` / `test:stand` | 6/6 / 43/43 |
| Emulator `content-media` | 69/69, 195 с (лимит 330 с); общий сценарий репозиториев D4.1 — на Firestore |
| Emulator `collection` | 13/13, 192 с (лимит 390 с) |
| Emulator `import` (новая группа) | 8/8: замер 54,2 с → лимит 150 с; повтор 49,7 с |
| Гейт D4 | pass: стенд-тест 4/4 (2 новых сценария D4.1), инварианты base и Place, verified stop |
| Гейт C1 | pass 4/4, verified stop |
| `flutter analyze` | 0 issues |
| `flutter test` | 1616 passed, 67 skipped (стенд-тесты, идут в гейтах; +2 новых в `local_import_stand_test.dart`), 0 failed |
| Unit и widget импорта | 45/45: контроллер 27 (13 новых), политика и журнал 2 новых, шлюз 1 новый, widget 5 новых |
| Boundary | self-test pass; 614 файлов, 0 нарушений, 71/71 |
| Inventory `--check-output` | pass |
| `git diff --check` рабочего дерева | чисто |

## Сценарии amendment §4

| № | Сценарий | Где проверен | Итог |
|---|---|---|---|
| 1 | Успешный rollback: оригинал побайтово сохранён, cleanup запрещён | integration и Emulator (общий сценарий «rollback tombstones…»), unit контроллера, стенд | черновик `rolledBack` с телом, binding `rolledBack`; локальный черновик и байты обложки те же; `deleteLocal` → `cleanup_rolledBack`, reserve сервером → `import_rolled_back` |
| 2 | Повтор, потерянный ответ, restart в `rollbackPending` | unit, стенд | после restart тот же ключ и та же ревизия; применено один раз; cleanup и импорт элемента заблокированы до исхода |
| 3 | Чужой автор, конфликт ревизий, submitted/published | integration, Emulator | `not_found`; `revision_conflict` без изменений; `import_rollback_not_allowed` после submit и после publish; делегированный модуль — `capability_denied`; отзыв capability — `capability_denied` |
| 4 | Rollback против submit — один победитель | Emulator, 4 раунда | ровно один успех; проигравший submit — `import_rolled_back`, проигравший rollback — `import_rollback_not_allowed` |
| 5 | Cleanup против rollback на одной и двух установках | unit, Emulator (4 раунда), стенд | при любом исходе гонки — один победитель; удержанный резерв (в т. ч. с потерянным ответом) запрещает rollback локально и на другой установке |
| 6 | Restart и потерянные ответы до и после удаления оригинала | unit, стенд | потерянный reserve повторяется тем же token и ключом; потерянный complete завершается после restart через `finishCleanups` |
| 7 | Истёкший резерв, устаревшие tokens | integration, Emulator | после истечения lease другой token — `cleanup_reserved`, rollback — `cleanup_reserved`; чужой token — `cleanup_token_mismatch`; после `done` release — `original_removed` |
| 8 | Старый retry после rollback; параллельные новые импорты | integration, Emulator | старая команда возвращает свой результат поколения 1 и ничего не создаёт; три параллельных импорта — один черновик поколения 3 |
| 9 | Media orphan reconcile после grace; asset с другой ссылкой | integration (настоящие `OrphanSweep`/`MediaDeletionService` над `ContentMediaScope`) | asset только откатанного тела помечен и удалён после grace; asset, на который ссылается другой черновик, остаётся; tombstone не принимает новую привязку Media |
| 10 | UI импорта и rollback | widget `local_import_section_test.dart` | подтверждение (отмена ничего не шлёт), ожидание и повтор, успех, типизированный отказ, отмена cleanup |

Инвариант «не утрачены одновременно локальный оригинал и пригодная серверная
копия» обеспечивают: локальный rollback только при наличии оригинала и без
cleanup-намерения; серверный rollback запрещён при резерве любой давности и
после `done`; удаление оригинала только под подтверждённым резервом;
`releaseImportCleanup` после удаления запрещён.

## Найденные и исправленные дефекты

- **Класс D2 в импорте** (известен из захода 2, исправлен по amendment §3.3):
  `_saveBody` при `revision_conflict` больше не перечитывает ревизию и не
  пишет поверх; элемент получает `revision_conflict`, правка на сервере
  сохраняется (unit «D4.1 §3.3»).

## Файлы и отклонения от карты §5

Отклонения (вне закрытой карты; утверждение — общим указанием владельца
продолжать без остановки на формальные подтверждения, 2026-10-13):

- `apps/backend/functions/src/modules/content/domain/failures.ts` — тип
  результата `importBinding` и причина конфликта `binding_revision`;
- `apps/backend/functions/src/modules/content/application/content_media_scope.ts` —
  tombstone не принимает новую привязку Media (как уже не принимает
  `submitted`), иначе откатанному черновику можно было бы снова назначить asset.

Уточнения при реализации:

- ключи: поколение 1 сохраняет ключи D4 (`li1-<hash>:…`), поколение ≥ 2
  добавляет `:g<N>`, Media intents поколения ≥ 2 — отдельный UUID v5 с `g<N>`;
  ключи rollback и cleanup всегда содержат `:g<N>` (amendment §3.2 записывал
  префикс как `local-import:g<N>:…`; смысл — ключ включает поколение — тот же);
- installation id: контроллер получает его из конструктора или создаёт
  случайный; receipt хранит использованный; разделяет установки fencing token,
  composition не менялась;
- секция: действия элемента доступны и в фазе `offline`, чтобы повторить
  неизвестный исход; `finishCleanups` и `pendingCleanups` завершают cleanup,
  когда оригинал уже исчез из inventory;
- `LocalImportBindingView` — в `local_import_gateway.dart` рядом с
  `LocalImportServerDraft`;
- запись binding перенесена из `putDraft` в `putImportBinding` (CAS по
  `bindingRevision`); в in-memory уникальность импорта обеспечивает тот же CAS,
  паритет проверяет общий сценарий репозиториев на обоих адаптерах.

Новых файлов в `apps/mobile/lib/features` нет; inventory не изменился.

## Откат

Revert коммита захода (amendment §7) при выключенном define входа импорта.
Tombstones, binding с поколениями, аудит и receipts сохраняются; локальные
оригиналы не трогаются. Прежний код не знает статуса `rolledBack` и читает
binding только по `draftId`, поэтому вход импорта остаётся закрытым, пока на
стенде есть tombstones D4.1, либо стенд сбрасывается штатно (`stand:reset`).
