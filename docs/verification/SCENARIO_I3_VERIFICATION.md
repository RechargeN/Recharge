# I3 Scenario publication — проверка, 2026-10-20

Контракт: [SCN-PUB-01](../product/SCENARIO_PUBLICATION_BCK10_AMENDMENT.md)
(SP-01…SP-14 утверждены владельцем 2026-10-20), BCK-10 v0.4 §33.
Checkout: `.claude/worktrees/recharge-i2-integration`, detached `eb5fb0f`
(`codex/recharge-integration`, I2 Done); I3 — коммиты поверх него на той же ветке.
Owner принял I3 в local/Emulator объёме 2026-10-20 и разрешил commit в
`codex/recharge-integration` без push и deploy. Это локальное Emulator/PC-host evidence,
не устройство, staging или production.

## Prerequisites на входе

| Условие | Основание |
|---|---|
| I2 | Owner accepted 2026-10-19; `51d3f29` + `eb5fb0f` на `codex/recharge-integration`; полный Emulator 16/16, 323 pass на точном toolchain ([evidence](SCENARIO_I2_VERIFICATION.md)) |
| Контракт и owner-решение | SCN-PUB-01 v0.2 Accepted, SP-01…SP-14 по рекомендациям, 2026-10-20 |
| C3 / E1 для Scenario | Scenario-части §7 amendment реализованы в I3 (resolver/validator/moderation/Media и Catalog family) |
| D1 | Done 2026-10-14 (Linux CI `83e05cd`) |

## Матрица visibility × actor (реализована)

| Visibility | Owner | Editor | Viewer | Посторонний | Отозванный | Staff |
|---|---|---|---|---|---|---|
| personal | R E | R E | R | — | — | — |
| unlisted | R E S A W | R E | R | R по token | R по token | restrict/restore share |
| public pending | R E W | R E | R | — | — | approve/reject |
| public published | R E S A W | R E | R | R exact/Catalog | R exact/Catalog | restrict/restore |
| hidden/restricted | статус | live draft | live draft | `not_found` | `not_found` | restore |

R — чтение, E — правка live draft, S — submit/share, A — activate, W — withdraw/unshare.
Editor и посторонний получают `not_found_or_forbidden` на distribute/share/unshare;
не-Creator owner может distribute, но не создать Content draft.

## Обязательная проверка → где доказано

| # | Требование | Доказательство |
|---|---|---|
| 1 | Матрица visibility × actor | `scenario_i3.test.ts` тест 1 |
| 2 | Нет утечки private/участников/invites/stop-данных, Media | тест 2: маркеры `PRIVATE-`, snapshot и location каталожного stop, id участников отсутствуют в share, exact read, Catalog card/details; deliverable pin Media есть только пока публикация видима, после withdraw delivery `not_found` |
| 3 | Полный C3 lifecycle | тест 3: Planning → Content draft → Media cover → submit → C2 approve → publish → Catalog listed; restrict/restore |
| 4 | Один запрещённый body на submit, publish approved, activate | тест 4: stop снят с публикации → `validation_failed` во всех трёх точках; Planning `distribution_invalid` |
| 5 | Concurrent edit во время review | тест 5: публикуется ровно approved hash; правка draft под review → `revision_conflict`; новый distribute по старой ревизии → `revision_conflict` |
| 6 | Visibility, hide/restore/withdraw, revisions, share | тест 6: withdraw/activate, rotate, revoke, `restrict_share`/`restore_share`, `token_expired`, TTL > 90 → `request_invalid` |
| 7 | Старый snapshot/cursor | тест 7: feed/map/details со старым snapshot не возвращают отозванный Scenario |
| 8 | Недоступная/изменённая зависимость | тест 8: свежий title stop; снятый stop → `{type:"unavailable"}` без id и title; < 2 доступных → Catalog excluded, публикация остаётся |
| 9 | Lost response / повтор / resume | тест 9: один revision и один share на повтор; повтор share не раскрывает token; второй createDraft → `revision_conflict`; delete при активной публикации/ссылке → `publication_active`; стенд interrupted/resumed |
| 10 | Mobile Create flow против Emulator | `scenario_publication_ui_stand_test.dart` в `stand-i3-gate.mjs`: I2 sync → Prepare → cover → Submit → staff approve → Publish → Share → resolve → Revoke → Hide |
| 11 | Quick Plan и Route не меняются; Expand один путь | тест 11; I2-группа (Expand) зелёная в том же полном прогоне |

## Прогоны

Точный toolchain: Node 22.23.2 / npm 10.9.8 / Temurin 21.0.12+8 / Terraform 1.15.9 /
Flutter 3.44.9; `node_modules` идентичен lockfile (firebase-tools 15.34.0).
Финальный набор — одна сессия, все rc записаны сразу после команды:

| Гейт | Результат |
|---|---|
| verify:toolchain, format, lint, typecheck | exit 0 |
| Backend unit / contract / integration / stand | 750 / 58 / 257 / 43 pass, 0 fail/skip |
| Runner self-tests / audit policy / stand-gate self-tests (I3 + D3.5) | 7/7 / 13/13 / 6/6 |
| Manifest, Content layout, R1 layout/config/exports, generated, reproducibility | exit 0; digest `b9bda28882645d7552671db3dd31fd744b219713490c3a51e413a7ffec002afe` |
| Production audit strict | exit 0; 6 moderate, 0 high/critical |
| Boundary self-test / repo / inventory | exit 0; 636 files, 71/71, 0 violations |
| Diff check (tracked и untracked) | exit 0 |
| Flutter analyze / full test | 0 issues / 1683 pass, 73 skip, 0 fail |
| Raw-body probe | exit 0 |
| Full Emulator — одна сессия `recharge-emulator-tests-cSXThX` | **17/17 groups, 334 pass, 0 fail, 0 skip, complete:true, code:0**; I3 11/11 и I2 15/15 с подтверждённым cleanup |

Summary SHA-256: `c9e79409e8746cc2b699881fa61f4e2ddfeed7e1196cdc252b67eede9599c057`.

Стендовый gate `node scripts/stand-i3-gate.mjs --yes`: clean seed → verify →
digest; новый стенд → seed прерван после `bind` → resume из идемпотентных
команд → verify → digest равен clean; повтор → `reused`, digest равен clean;
реальный Flutter UI-тест (define on) прошёл; инварианты сохраняются; verified stop
и cleanup изолированного стенда; exit 0. Собственная Planning Session стендового
seed исключена из digest как per-run by design (handle нигде не хранится).

Неуспешные прогоны (сохранены честно):

1. Первый stand gate: `scenario verify` читал ревизию напрямую из Firestore, а не
   через Content-репозиторий, и не находил ref. Исправлена только проверка стенда.
2. Первый финальный набор: gate `diff` упал на CRLF-предупреждении git, которое
   PowerShell 5.1 превращает в ошибку; сам diff был чистым. Исправлен только запускатель.
3. Второй финальный набор: полный Emulator 16/17 — статическая проверка I2
   запрещала любой импорт `publication` в Planning-сервисе. Проверка уточнена:
   разрешён только собственный модуль `./scenario_publication.js`, Route и Catalog
   по-прежнему запрещены. Третий набор выше — полный зелёный прогон после исправления.


## Оставшиеся ограничения

- Hosted CI, физические устройства, staging и production не выполнялись.
- Mobile Discover/Details для Scenario — отдельный slice `DTL-SCN-01`.
- Unlisted-ссылка без Media и без отдельного report flow; mobile-читатель ссылки — только gateway.
- Media bytes delivery с fake processor не проверяема (variant bytes не пишутся);
  проверен Content-шаг D2 gate (deliverable pin). Байтовый шаг покрыт D1/D10 real tools.
- Числовые лимиты (TTL, размеры) — TEST-ONLY; rate limit чтения ссылок не реализован.
- Page publisher, dated public, Copy, Route stops — вне v1 по SP-02/SP-07/SP-13/SP-08.
