# M1 заход 2 — доступ Page и надёжность публикации: evidence

Дата 2026-10-13. Ветка `claude/m1-2-page-reliability` от `1ad1c96` (заход 1).
Checklist: [M1_LOCAL_CONTOUR_CHECKLIST.md](../../../verification/M1_LOCAL_CONTOUR_CHECKLIST.md),
сценарии S1–S7.

## Проверенный код

Проверки шли на рабочем дереве поверх `1ad1c96` с 20:02:10 до 20:40:35
(+03:00). Все файлы кода и тестов изменены не позднее 17:43:19; после старта
менялись только `apps/backend/README.md` и checklist. Коммит этого захода
содержит ровно проверенный код; его SHA — в сообщении коммита и в истории ветки.

Среда: Windows 11 Home 10.0.26100, Flutter 3.44.9, Node 22.23.2, npm 10.9.8,
Temurin 21.0.12+8; стенд `demo-recharge` на 127.0.0.1,
`FUNCTIONS_DISCOVERY_TIMEOUT=60`. Клиент — `flutter test` на ПК против стенда;
устройств, LAN и cloud нет.

## Результаты

| Проверка | Результат |
|---|---|
| Backend `format:check`, `lint`, `typecheck`, `build` | pass |
| `test:stand` | pass (43/43) |
| Гейт C3 | pass: Event controller 6/6 (S1–S4), UI 1/1 |
| Гейт D3.1 | pass: Place controller 6/6, UI 1/1; свежий стенд: отзыв доступа 8/8 (S5, S6, UI); инварианты; свежий стенд: две установки 1/1 (S7); инварианты |
| Гейт D3.2 | pass: Activity, включая S1–S3 |
| Гейт D3.3 | pass: Rental, включая S1–S3 |
| Гейт D3.4 | pass: Collection, включая S1–S4 |
| `flutter analyze` | 0 issues |
| `flutter test` | 1595 passed, 65 skipped (стенд-тесты, идут в гейтах), 0 failed |
| Unit-тесты контроллеров публикации | 60/60, из них 9 новых (D1 ×5, D2 ×4) |
| Boundary | 0 нарушений, 71/71 |
| Inventory `--check-output` | pass |
| `git diff --check` рабочего дерева | чисто |

Журналы вне checkout, в scratchpad сессии Claude
(`…/fb5bbe95-84a3-45b7-aa07-ad5cdfdf0985/scratchpad/logs/`): итоговый прогон —
`final/*.log` и `summary_stage2_final.txt`; прогон до исправлений —
`s2_*.log`; диагностика — `s2d_*.log`. Два ранних диагностических шага с
ложным rc=0 (`cmd.exe /c` в Git Bash не запускал тест) переименованы в
`*_invalid.log` и в evidence не используются.

## Сценарии

| № | Что | Где | Итог |
|---|---|---|---|
| S1 | обрыв до отправки на `submit` и `publish` | `expectSubmitSurvivesFaults` / `expectPublishSurvivesFaults` в `support/content_fault_client.dart`, пять стенд-тестов типов | ничего не дошло до сервера, offline, поздний повтор успешен |
| S2 | потерянный ответ на `submit` и `publish` | то же | сервер обработал; повтор тем же ключом — одна submission, одна публикация |
| S3 | restart после неизвестного исхода | то же, новый контроллер над тем же журналом | без дублей |
| S4 | повторный save после restart | Event, Collection | тот же серверный черновик |
| S5 | права Content сняты `setCapabilities`, Event и Place, save/submit/publish отдельно, плюс UI | `page_access_revocation_stand_test.dart` | `capability_denied`; черновик, журнал и ключи без изменений; на сервере нет продвижения; после возврата — ровно один раз |
| S6 | Page `suspended` через `decidePage`, Place | то же | `publisher_not_eligible`; после `reverify` — ровно один раз |
| S7 | один пользователь, две установки | `publication_two_installs_stand_test.dart` | `revision_conflict`; правка A на сервере, правка B локально; refresh даёт актуальную ревизию; запись поверх — только нажатием «Save my version», одна запись |

Фикстура `page-access` возвращает сохранённый исходный набор capabilities и
`verified` для Page; `stand verify` после фаз S5/S6 и S7 подтвердил, что все
членства владельца как после seed.

## Найденные и исправленные дефекты

- **D1.** До исправления все пять гейтов были красными на S2 для `publish`:
  повтор отправлял свежий `expectedPointerRevision` под прежним ключом и
  получал `idempotency_conflict`, хотя публикация на сервере была одна
  (`s2_gate_*.log`). Исправление: `PublishIntent` журналируется до вызова и
  повторяется без изменений.
- **D2.** До исправления S7 был красным: Place сам перечитал ревизию и записал
  правку B поверх правки A (`s2d_two_installs.log`). Тот же приём был в
  Activity, Rental и Collection. Исправление: `PendingDraftUpdate` журналируется
  с payload; сначала повторяется только собственная незавершённая запись; чужая
  ревизия даёт `DraftConflict`; запись поверх — только `saveOverServerVersion()`
  по кнопке в секции. Своя потерянная запись по-прежнему восстанавливается
  (существующие unit-тесты D3.x зелёные).

## Файлы и отклонения от утверждённой карты

Утверждены владельцем 2026-10-13 вместе с исправлением D1/D2:

- `apps/backend/functions/test/stand/stand_seed.test.ts` — фикстура unit-теста
  инвариантов в форме owner-пути и негативный тест;
- `apps/backend/scripts/stand-seed.mjs` — `page-access` в allowlist CLI стенда.

Уточнения при реализации:

- кнопка конфликта — в секциях
  `apps/mobile/lib/features/create/presentation/widgets/{place,activity,rental,collection_content}_publication_section.dart`;
  панели `lib/app/presentation/*_panel.dart` только встраивают секции и не
  менялись;
- общие типы `PublishIntent`, `PendingDraftUpdate`, `DraftConflict` — в
  `apps/mobile/lib/features/create/domain/entities/event_publication.dart`,
  где уже лежат общие для пяти типов `EventPublicationStatus` и gateway;
- S7 написан как `testWidgets`, чтобы явное разрешение проверялось нажатием в
  настоящей секции Place.

Новых файлов в `apps/mobile/lib/features` нет; inventory не изменился.

## Откат

Revert коммита захода. Новые поля журнала необязательные и игнорируются
прежним кодом; фикстура только тестовая; authority boundaries не менялись.
Стенд сбрасывается штатно (`stand:reset`).
