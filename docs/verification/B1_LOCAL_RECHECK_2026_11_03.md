# B1-local — перепроверка на A34, 2026-11-03

Candidate: `5da203f` (`44fd676` + правило A34 в AGENTS.md). A2 проверен на
`b1bf615`: backend и стенд-скрипты в нём совпадают с candidate, отличие
`b1bf615..44fd676` — только l10n mobile и docs. Checkout: отдельный чистый
worktree `.claude/worktrees/recharge-fold`; до и после прогонов `git status`
пустой. Push, merge и deploy нет.

Toolchain: Node 22.23.2, Temurin 21.0.12+8, Flutter 3.44.9 из `C:\src\flutter`.
Устройство: Samsung A34 (SM-A346B, `RFCW91QHWWJ`), Android 16, USB, статус
`device`; AVD не поднимался. Связь со стендом — `adb reverse` портов 9099
(Auth), 5001 (Functions) и 8765 (fixture bridge) на loopback, после прогона
сняты. A34 здесь — среда исполнения, а не приёмка B1-device.

## Известный красный gate

В документах и в предыдущих заходах записи о красном gate A2 не найдено.
A2 перепроверен заново, обходов и ослабленных проверок нет.

## Прогоны

| Gate | SHA | Результат |
|---|---|---|
| A2 `stand-acceptance.mjs --yes` | `b1bf615` | pass: чистый seed, export/import и повторный seed с одинаковым digest `9a441977…1e3885`, verified stop |
| A2 `test:stand` | `b1bf615` | 43/43 |
| `flutter analyze` | `5da203f` | no issues |
| `flutter test` | `5da203f` | 2214 pass, 83 skip, 0 fail |
| Boundary gate | `5da203f` | passed, исключений 69/71 |
| `git diff --check 44fd676 5da203f` | `5da203f` | чисто |
| `stand-mobile-gate.mjs --yes` (PC host) | `5da203f` | 4/4: Session после restart, revoke через owner path, замена истёкшей Session с одним retry, `testBackend` ↔ `localOnly` без вызова и потери данных |
| `stand-mobile-gate.mjs --yes --android RFCW91QHWWJ` | `5da203f` | 1/1: настоящие `firebase_auth` и FlutterSecureStorage, жизненный цикл Session, затем `localOnly` |

Digest A2 по README не пинится: он намеренно меняется вместе с составом
seed, сравнивается только внутри одного прогона.

## Не покрыто (B1-device)

Фон и возврат, завершение процесса ОС, закрытие приложения пользователем,
реальные permissions и выбор изображения, Booking и unknown-outcome на
устройстве, Create → publication → Discover на телефоне, двухпользовательские
проверки, iOS. Чек-лист — [C1–E2 closure review](../product/C1_E2_CLOSURE_REVIEW.md).

## Follow-up

- Native gate печатает итог «Android Emulator» и на физическом устройстве;
  текст нужно брать из фактического target.
- Сборка предупреждает: проект на Android NDK 27.0.12077973, плагины
  `integration_test` и `jni` требуют 28.2.13676358.

## Evidence

Логи и скрипты запуска: `C:\Users\User\Documents\Recharge-evidence\B1-local-2026-11-03`
(`a2/`, `b1/`), SHA-256 файлов — в `SHA256SUMS.txt`; хэш самого
`SHA256SUMS.txt` — `51258af74665929e6177e171926242a3fc8bf6890b9589f33abe76fcafc7ca67`.
