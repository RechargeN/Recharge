# N3a — dev Cloud Storage adapter для Media, 2026-11-07

Статус: **Done** — решение владельца 2026-11-07 (adapter реализован и проверен в облаке на синтетических объектах). Только recharge-dev-n2a01 / `recharge-dev-n2a01-media`. Scanner, processor, push, signed URL, публичный доступ, cleanup и удаление в облаке не выполнялись. Push/merge не выполнялись.

## Что сделано (`b906d93`)

`DevCloudObjectStore` реализует существующие `ObjectStorePort`/`ObjectBytesPort` с контрактом `StorageEmulatorObjectStore` (общий набор сценариев для обоих adapters).

- Привязка fail-closed: `RECHARGE_MEDIA_STORAGE=dev-cloud`, `GCLOUD_PROJECT=recharge-dev-n2a01`, нет одновременно настроенного Emulator, бакет ровно `recharge-dev-n2a01-media`; factory не подставляет default bucket.
- Handles проверяются до пути; только `media-source/` и `media-variant/`.
- Каждое чтение ограничено и закреплено на одной generation; `stat` слишком большого объекта сообщает размер без скачивания (сервис первым отказывает `limit_exceeded`).
- `writeVariant` create-only (`ifGenerationMatch: 0`): идентичный повтор возвращает сохранённую generation, другие байты — отказ.
- Удаление только увиденной generation; 404 → `absent`, 412/403/таймаут → `failed`.
- Media ports, owner/scope, quarantine, retention, deletion не менялись; Local/Emulator — по умолчанию, возврат — снять флаг. Guard `media_security.test.ts` перечисляет adapter явно; signed URL и delivery для него запрещены.

## Проверки

Backend unit + contract + integration 1192/1192, полный lint, adapter 7/7, `verify:cloud-context` PASS.

Облако (run `20261106T210912Z`, вход владельца, ADC отозван): бакет EUROPE-WEST1, `publicAccessPrevention=enforced`, uniform access, публичных участников нет; через adapter — `absent` до записи, `complete` 43 байта с совпавшим SHA-256 и `image/png`, ограниченное чтение `too_large`, идемпотентный повтор варианта, `variant_content_conflict` на другие байты, чтение по закреплённой generation и `absent` по чужой. IAM: стоп-условий нет. Оставлены синтетические объекты `media-source/n3a-smoke-20261106T210930-ed3aa2ee` и `media-variant/20bcb805-97b9-4996-af7d-1c47292c9cf6` (удаление запрещено владельцем; стоимость пренебрежимо мала).

## Не входит / открыто

- Удаление в облаке проверено только unit-тестами (облачное удаление — отдельное разрешение).
- Полный Media runtime в облаке: `FirestoreMediaRepository` разрешён только в Emulator; включение — отдельное решение.
- Upload transport для клиента (signed upload / Rules) и runtime-media IAM — до развёртывания Media функций.
- N3b (scanner/processor) разблокирован по зависимости N3a; нужны разрешение на проект и решения из пакета готовности `N3B-READINESS-2026-11-06.md`, решения D-01…D-12.
