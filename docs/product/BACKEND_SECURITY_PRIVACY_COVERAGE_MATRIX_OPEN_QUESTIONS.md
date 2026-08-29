# BCK-04 coverage matrix — open questions (ответ владельца)

- Источник: [`BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md`](BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md) §7
- Статус: **Отвечено владельцем 2026-08-16; учтено в coverage matrix v0.2**
- Назначение: три решения ниже определяют объём и форму `BCK-04 v0.1`.

Примечание к ответам: исходные ссылки владельца указывали на пути в другом
git worktree (`C:/Users/User/.codex/worktrees/5bb6/Recharge/...`). Файлы
`RECHARGE_BACKEND_MASTER_SPEC.md` и `RECHARGE_BACKEND_DELIVERY_MAP.md`
проверены и подтянуты в эту рабочую копию через `git checkout origin/main --
docs/product/...` — содержание совпадает с тем, что процитировал владелец
(включая OD-11 на строке 612 `RECHARGE_BACKEND_DELIVERY_MAP.md`). Ссылки
ниже исправлены на локальные пути этого репозитория.

---

## Вопрос 1 — Отсутствующий `BCK-01`

Формальная последовательность требует "перевести `BCK-01` в `Review`" первым
шагом, но файла `BCK-01` физически нет в репозитории ни под одним найденным
именем.

**Варианты:**

- **A. Создать заглушку `BCK-01` сейчас** — минимальный файл с тем, что уже
  фактически используется как parent architecture (ссылки на ADR 0011–0019,
  `RECHARGE_ARCHITECTURE.md`, `PLATFORM_FOUNDATION_SPEC.md`), чтобы шаг 1
  формальной последовательности стал технически выполним.
- **B. `BCK-04 v0.1` стартует без `BCK-01`** — явный blocking gap фиксируется
  в Definition of Ready BCK-04 и снимается позже, когда `BCK-01` появится.
- **C. `BCK-01` уже существует, но не в этом репозитории/не под этим именем**
  — назовите фактическое расположение/имя файла, и я привяжу к нему ссылки
  вместо заглушки.

**Ответ:** C.

`BCK-01` физически существует: [`RECHARGE_BACKEND_MASTER_SPEC.md`](RECHARGE_BACKEND_MASTER_SPEC.md).
Параметры подтверждены сверкой с файлом: ID `BCK-01`, версия `v0.3`, статус
`Draft — architecture review required`, runtime `Absent`.

Проблема не в отсутствии файла, а в том, что `BCK-01 v0.3` ещё не переведён
в `Review`. `BCK-04 v0.1` можно готовить как Draft, но его переход в
`Review` остаётся заблокированным до Review и reconciliation `BCK-01`.
Учтено в coverage matrix v0.2 §2.

---

## Вопрос 2 — §18 OD-11 (minors/age eligibility)

В репозитории нет ни одного источника про возрастные ограничения, guardian
consent или age gate для Find People/Booking.

**Варианты:**

- **A. Recommendation-style** — как в BCK-03: предложить конкретный
  черновой вариант политики (например, минимальный возраст аккаунта,
  fail-closed для age-restricted функций до Accepted решения) с пометкой
  "Draft rule, не Accepted", чтобы Legal/Privacy было от чего отталкиваться.
- **B. Оставить буквально пустым** — только заголовок раздела и список
  вопросов без предлагаемого решения, до назначения Legal/Privacy owner.

**Ответ:** A — Recommendation-style, без числового возраста.

Источник уже существует: [`RECHARGE_BACKEND_DELIVERY_MAP.md` §16, строка
OD-11 (line 612)](RECHARGE_BACKEND_DELIVERY_MAP.md). В BCK-04 следует
предложить Draft policy:

- политика версионируется отдельно для LV, EE и LT;
- конкретный минимальный возраст и legal basis не назначаются BCK-04
  самостоятельно;
- возраст, guardian consent и verification принимаются только после
  Legal/Privacy review для конкретного рынка;
- client-declared age не является authority;
- production account creation, Find People и age-restricted функции
  остаются server-disabled до Accepted OD-11;
- применимые Booking paths работают fail-closed;
- базовый disabled Booking Emulator core не блокируется глобально, пока
  age-sensitive paths не активируются;
- каждое решение содержит market, product scope, owner, дату Legal/Privacy
  review и effective date.

Статус предложения: `Proposed — not Accepted`. Учтено в coverage matrix
v0.2 §4 (строка 18) и §7.

---

## Вопрос 3 — Статус `FIREBASE_ARCHITECTURE.md` внутри BCK-04

Этот документ (v2.2) сейчас имеет статус `Proposed`, но фактически содержит
большую часть предлагаемого содержания для authentication/authorization/
Rules/Storage/App Check разделов BCK-04.

**Варианты:**

- **A. Везде цитировать как "proposed baseline"** — BCK-04 явно помечает
  каждую заимствованную часть как непринятую, ничего не наследует тихо.
- **B. Заранее согласовать повышение статуса конкретных частей** (например,
  §8 aggregate model, §11 Rules strategy) до почти-нормативного уровня —
  назовите, какие именно разделы можно считать settled для целей BCK-04.

**Ответ:** A.

[`FIREBASE_ARCHITECTURE.md` v2.2](../architecture/FIREBASE_ARCHITECTURE.md)
использовать только как `Proposed architecture input`. Правила:

- ничего не наследовать тихо;
- каждое заимствованное положение помечать `Proposed input`;
- проверять его против Accepted ADR, BCK-01, BCK-02 и BCK-03;
- §8 и §11 пока не считать settled;
- BCK-04 может принять отдельные положения как собственные Draft rules, но
  это не повышает статус исходного Firebase-документа;
- никакого Firebase/runtime authorization.

Учтено в coverage matrix v0.2 §3 и §6, п.2.

---

## Дополнительные правки — учтено

Правки владельца ("coverage matrix необходимо пересобрать по актуальному
состоянию main", "утверждение об отсутствии источников OD-11 удалить",
"`FIREBASE_ARCHITECTURE.md` — только Proposed input", "coverage matrix пока
физически отсутствует в main") перенесены в
[`BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md`](BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md)
v0.2 целиком: §0 (что изменилось), §2 (формальная последовательность
исправлена по факту существования `BCK-01`/`BCK-02`/`BCK-03`/`BCK-09` в
рабочей копии после `git checkout origin/main --`), §3 (реестр `BCK-02 §5`
и `OD-11` из `BCK-02 §16` заменили пометки `RA`/`NS` на `EA`), §6 (снята
ранее заявленная "fabrication"-находка про `BCK-02 §14`, см. §0.1
матрицы). Единственное, что остаётся верным и не изменено: сама эта
coverage matrix и этот файл с вопросами физически существуют только в
локальной рабочей копии — на `origin/main` их нет, они появятся там только
через отдельный docs-only PR.
