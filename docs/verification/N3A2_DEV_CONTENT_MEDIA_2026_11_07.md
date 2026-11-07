# N3a.2 — dev Content (Place) + Media runtime с проверкой на A34, 2026-11-07

Статус: **Review — код, IaC и APK готовы, облачные шаги не выполнены.** План владельца `N3A2-CONTENT-MEDIA-DEV-A34-FILE-PLAN-2026-11-07.md` утверждён 2026-11-07 (тип Place по рекомендации, вместе с частью ADR 0023). Только recharge-dev-n2a01, синтетические данные, ничего не удаляется, публикации нет. Push/merge не выполнялись.

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
