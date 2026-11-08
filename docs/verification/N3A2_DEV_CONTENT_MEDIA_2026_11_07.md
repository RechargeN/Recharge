# N3a.2 — dev Content (Place) + Media runtime с проверкой на A34, 2026-11-07

Статус: **Review — облако развёрнуто (2026-11-08), сквозной прогон на A34 упёрся в 503 dev-функций (см. «A34, 2026-11-08»).** План владельца `N3A2-CONTENT-MEDIA-DEV-A34-FILE-PLAN-2026-11-07.md` утверждён 2026-11-07 (тип Place по рекомендации, вместе с частью ADR 0023). Только recharge-dev-n2a01, синтетические данные, ничего не удаляется, публикации нет. Push/merge не выполнялись.

## Сделано

- **ADR 0023 (часть).** `evaluatePublisherAccess` больше не требует роль `Creator`. Личный автор: активный аккаунт и текущая Session; факт проверки личности нужен только для рискованных типов (`identityVerificationRequired`). Бесплатные личные типы: `place`, `activity`, `collection`, `route`, `scenario`. Event, Rental, Session, Class/Workshop, Find People и любая Page — как раньше, с проверкой. Имя отказа на проводе (`creator_verification_required`) сохранено; снимки Session не менялись (только `booking.self_service`).
- **Guard цепочки Media.** `assertMediaChainPersistenceContext`: без переключателя — правила Emulator без изменений; с `RECHARGE_DEV_RUNTIME=content-media` — ровно recharge-dev-n2a01 на стандартном TLS-endpoint, без Emulator-переменных и ключей. Используют только репозитории Content, Media, Moderation (статические тесты, layout-allowlist).
- **Dev-композиции.** Media: облачный бакет N3a (`put` create-only), реальные ClamAV/sharp N3b, без fake, retention, удаления и delivery. Content: только Place; `createDraft`/`updateDraft`/`getDraft`/`getPublicationStatus`; submit, publish, withdraw, import и staff закрыты; модерации нет (закрытый порт).
- **Вход** `dev_content_media_entry.ts` (codebase `n3a2-content-media`, не в `index.ts`): протокол callable поверх onRequest, Firebase ID token, Session через `FirestoreBookingAccessAuthority` (как Emulator), allowlist uid владельца, kill-switch, лимит 1,5 МБ, max 1 экземпляр.
- **Упаковка:** `package-n3a2-content-media-runtime.mjs` + predeploy `verify-n3a2-stage.mjs` (запись владельца: без публикации и удаления).
- **Terraform** `n3a2_content_media.tf`: `runtime-media` (manifest dev `deployed: true`) — Firestore и media-объекты create/read/update **без delete**, чтение пользователя Firebase, секрет инструментов, invoker на двух сервисах N3b; `check-n3a2-plan.mjs`.
- **Mobile:** dev-allowlist пяти вызовов; порт Content/Media в dev-бандле только с `N3A2_DEV_PLACE_DRAFT=true`; guard Place пропускает dev-путь в debug-сборке. APK установлен на A34.

## Отклонения от плана

- Имена dev-функций совпадают с callable (`contentCommandV1` …), как в N2c: мобильному клиенту нужен только allowlist.
- Флаги Firestore не засеваются: достаточно kill-switch и allowlist владельца (меньше облачных записей).
- Новое имя отказа `identity_verification_required` не вводилось — без изменения контрактов в этом срезе.

## Проверки (локально)

Backend unit 873, contract 70, integration 272; lint, формат, layout-gate; Terraform 27/27; checker N3a.2 2/2; упаковщик 2/2; `flutter analyze` чисто; `flutter test` 2302 пройдено, 83 пропущено.

## Облако и A34 (один заход владельца)

`n3a2_cloud.py`: вход → квитанция бюджета (переиспользуется N3b, пока действует) → uid владельца → Terraform → индексы Firestore → deploy выключенным (503) → включённым (401 на чужой токен) → IAM → revoke. Затем A34: Create → Place → фото со скриншота → «на проверке» → «готово».

Выполнено 2026-11-08: Terraform, индексы (только три индекса Content, см. ниже), deploy выключенным (503), затем включённым в 11:01 UTC (401 на чужой токен), IAM readback. Вход владельца сохранён между запусками.

## A34, 2026-11-08

Прогон на A34 (dev debug APK, `N3A2_DEV_PLACE_DRAFT=true`) нашёл и исправил в мобильном коде:

- **User не мог создавать контент** при User=Creator (ADR 0023): Create-подсказки `create.place/route/collection` в UI, `canCreate` для роли `user` (74d0a54).
- **Шаг 2 Place не сохранялся:** контракт Content требует `place.hours` и `place.pricing.entryType`, а скрытые или неотвеченные ответы не отправлялись. Теперь это `unknown`, не выдуманные часы и не «бесплатно» (спецификация Place §8) (7d4128b).
- **Заблокированный шаг не называл причину** — только «Проверьте обязательные поля шага». Теперь шаги 1–2 показывают список ошибок этого шага.
- **Карта в форме не получала жестов** (перетаскивание листало страницу), поэтому поставленную не туда метку нельзя было вернуть. Карте отданы собственные жесты.
- **На dev-страницу публикации не было входа из приложения.** В шаге 3 есть кнопка «Публикация места (тест)», только когда её guard открыт (debug, define, dev-порт).

Не код: в worktree не было `google_maps.properties` (ключ владельца, в .gitignore), поэтому карта была пустой, а метка встала в Финляндию → «вне зоны обслуживания». Для локальной debug-сборки файл скопирован из основного репозитория.

**Блокер.** «Сохранить» на dev-странице → `contentCommandV1` отвечает 503 (журнал: App Check observation есть, токен принят, ошибка в обработчике). Тот же `createDraft` локально от имени владельца против recharge-dev-n2a01 проходит (создан один синтетический пустой черновик, не удалялся), окружение и IAM `runtime-media` совпадают с работающим `runtime-identity`. Значит, ошибка зависит от облачного окружения или прав; `catch` её глотал. Добавлен безопасный лог `dev_content_media_failure` (только класс ошибки и короткий код). Нужен один повторный deploy кодовой базы `n3a2-content-media` (скрипт владельца, бесплатно), затем повтор «Сохранить» → по коду в журнале — точечное исправление.

Проверки: `flutter analyze` чисто, `flutter test` 2304 пройдено, 83 пропущено; backend unit 874/874, lint и формат чистые.
