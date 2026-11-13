# L4 локализация v0.2 — проверки на `af04b1d`, 2026-10-27

Дерево: ветка `claude/l4-localization` @ `af04b1d` (поверх
`codex/recharge-integration` @ `01065f6`), worktree
`.claude/worktrees/recharge-l4-l10n`. Контракт:
[LOCALIZATION_L4_R1_AMENDMENT](../product/LOCALIZATION_L4_R1_AMENDMENT.md) v0.2.

Toolchain: Node 22.23.2, Temurin 21.0.12+8, Flutter из `C:\src\flutter`.
Ограничения: только локальный Firebase Emulator на PC-host; без устройства,
LAN, staging и облака. Зелёные проверки подтверждают полноту ресурсов,
контракты и поведение, а не качество перевода.

## Источник цифр

Исходные логи сессии L4 лежат вне репозитория:
`%TEMP%\claude\C--Users-User-Desktop-Recharge\1d0d6567-5124-448c-b11b-ebf11da3df37\scratchpad\`
(`stands\*.log`, `stands\summary.txt`, `backend\*.log`, `ftest*.log`). Ни один
лог не записывает SHA. Коммиты `2b26152…af04b1d` созданы в 19:19 (+03:00);
логи ниже помечены временем записи, чтобы было видно, какие прогоны были до
коммита, а какие после. Сохранённого лога `flutter analyze` нет, поэтому
analyze и полный `flutter test` повторены на `af04b1d` в сессии L4.1
(чистое дерево `recharge-l4-l10n`, `git status` пуст).

## Mobile

| Проверка | Результат | Источник |
|---|---|---|
| `flutter analyze` | No issues found, rc 0 | повтор на `af04b1d` (L4.1, 2026-10-27) |
| `flutter test` | 1866 пройдено, 82 пропущено, All tests passed | `ftest4.log`, 16:13 — до времени коммита; повтор на `af04b1d`: см. ниже |
| `flutter test`, повтор на `af04b1d` | 1866 пройдено, 82 пропущено, All tests passed, rc 0 | L4.1, 2026-10-27 |

Пропущенные тесты — backend_local и прочие тесты, которые запускает
Emulator-раннер стендов.

## Backend

Backend runtime в L4 не менялся (добавлен только тест
`notification_localization_l4.test.ts`).

| Проверка | Результат | Лог (время) |
|---|---|---|
| lint | rc 0, пустой вывод | `backend\lint.log` (12:01) |
| typecheck | rc 0, пустой вывод | `backend\typecheck.log` (12:02) |
| format:check | rc 0, «All matched files use Prettier code style!» | `backend\format.log` (12:02) |
| unit | 811/811 pass, 0 fail | `backend\unit.log` (12:03) |
| contract | 58/58 pass, 0 fail | `backend\contract.log` (12:03) |

Все backend-логи записаны до времени коммита. Backend-дерево ветки L4.1
совпадает с `af04b1d` (L4.1 backend не трогает), поэтому проверки повторены
на нём в сессии L4.1 (Node 22.23.2): lint, typecheck, format:check — rc 0;
unit 811/811, contract 58/58, fail 0.

## Стенд-гейты (13)

Зелёный = в логе есть «All tests passed» и строка «… gate passed»; rc из
`summary.txt`, записан сразу после команды.

| Гейт | Секунд | rc | «All tests passed» | Строка gate passed | Лог (время) |
|---|---|---|---|---|---|
| b2 | 633 | 0 | 3 | B2-local gate passed 3/3 | 19:47 |
| f1 | 196 | 0 | 1 | F1 gate passed | 19:50 |
| f2 | 237 | 0 | 2 | F2 gate passed | 19:54 |
| c3 | 287 | 0 | 2 | C3 Event publication gate passed | 19:59 |
| d3-1 | 801 | 0 | 4 | D3.1 Place publication gate passed | 20:12 |
| d3-2 | 372 | 0 | 2 | D3.2 Activity publication gate passed | 20:19 |
| d3-3 | 331 | 0 | 2 | D3.3 Rental publication gate passed | 20:24 |
| d3-4 | 379 | 0 | 2 | D3.4 Collection publication gate passed | 20:30 |
| d3-5 | 275 | 0 | 2 | D3.5 Session publication gate passed | 16:23 |
| d3-6 | 272 | 0 | 2 | D3.6 Class / Workshop publication gate passed | 16:28 |
| d3-7 | 278 | 0 | 2 | D3.7 Find People gate passed | 16:33 |
| i3 | 247 | 0 | 1 | I3 Scenario publication gate passed | 20:35 |
| j2 | 315 | 0 | 2 | J2 Route publication gate passed | 16:19 |

Девять гейтов прошли после времени коммита (19:47–20:35), четыре (j2,
d3-5, d3-6, d3-7) — до него (16:19–16:33), на рабочем дереве v0.2 после
последнего полного `flutter test` (16:13). Что это дерево побайтно равно
`af04b1d`, логи не доказывают. L4.1 перепрогоняет c3, d3-1…d3-7, i3, j2 на
своём итоговом дереве.

История `summary.txt`: в первом проходе (завершён в 13:10) b2, c3, d3-1 и j2
дали rc 1; в 13:44 они перепрогнаны с rc 0, затем все 13 — ещё раз (таблица
выше). Логи первого прохода перезаписаны, причину красного по ним
установить нельзя.
