# Create Templates Local-First Slice Spec

Версия: 1.0
Статус: Approved
Slice: CRT-TPL-01
Дата: 2026-07-31

## 1. Цель

Дать Creator быстрый и безопасный повторный Create без смешения шаблона,
активного черновика и опубликованного объекта. Первая вертикаль — Event;
контракты остаются типизированными и расширяемыми для остальных принятых
Create-типов.

## 2. Scope

1. Несколько именованных пользовательских шаблонов одного Create-типа.
2. Сохранение текущего Event draft как нового шаблона.
3. Обновление имени и содержимого существующего шаблона.
4. Удаление шаблона.
5. Выбор шаблона перед началом нового Event.
6. Последний применённый Event template автоматически используется при явном
   действии `Create another Event`.
7. Новый draft получает независимые временные ids и актуальные market defaults.
8. Local/mock persistence без Firebase, сети и платных сервисов.

## 3. Не входит

- Firebase, multi-device sync и shared/team templates;
- marketplace, публичные шаблоны и monetization;
- AI generation;
- автоматическая публикация;
- копирование Booking, Payment, Attendance, inventory usage или access secrets;
- новый Create-тип;
- автоматическая замена восстановленного активного draft.

## 4. Модель

`CreateTemplate` имеет:

- постоянный client-generated ULID `id`;
- `ownerUserId`;
- `objectType`;
- пользовательское `name`;
- versioned reusable draft snapshot;
- `createdAtUtc`, `updatedAtUtc`, `lastUsedAtUtc`;
- `schemaVersion`.

Шаблон не является `CreateDraft`, Event, Series или Publisher. Ссылки на
шаблон допустимы только по `templateId`.

## 5. Правила materialization

При применении шаблона создаётся новый независимый draft:

- новый `loc_*` draft id и новые `loc_*` child ids;
- lifecycle/moderation/publish status сброшены в `draft`;
- `createdAtUtc`/`updatedAtUtc` заданы заново, `publishedAtUtc=null`;
- Publisher/organizer берётся из текущего авторизованного контекста;
- market, timezone и currency берутся из активных runtime defaults;
- exact dates, materialized occurrences и occurrence overrides сбрасываются;
- Event schedule shape, duration и recurrence policy могут быть сохранены, но
  первая дата пересчитывается от текущего дня в активной timezone;
- public online URL, external booking URL и private/access данные не копируются;
- media не копируется в CRT-TPL-01, чтобы не утверждать повторное право на asset;
- taxonomy, descriptions, format, reusable location, amenities, requirements,
  audience, pricing/capacity mode и visibility могут быть скопированы и всегда
  повторно валидируются.

## 6. Restore и default semantics

1. Незавершённый active draft всегда восстанавливается без применения шаблона.
2. Автоматическое применение последнего шаблона происходит только после явного
   `Create another Event`.
3. Ручной выбор шаблона создаёт новый draft только после подтверждённого
   действия пользователя.
4. Последним считается шаблон с максимальным `lastUsedAtUtc`.
5. Удаление последнего шаблона безопасно возвращает новый Event к defaults.
6. Шаблоны разных пользователей и Create-типов не смешиваются.

## 7. Persistence

Local datasource хранит versioned collection отдельно от active draft.
Повреждённая запись не уничтожает active draft. Записи сериализуются
детерминированно; неизвестная будущая schema не применяется и возвращает
типизированную ошибку/пустой безопасный результат.

## 8. UI

- Event Create показывает компактное действие `Templates`.
- Picker отображает все Event templates, сортируя last used/updated.
- Доступны `Use`, `Rename`, `Replace with current`, `Delete`.
- Доступно `Save current as template`.
- Success screen для Event предлагает `Create another from last template`;
  при отсутствии шаблона — обычный `Create another Event`.
- Любое применение явно сообщает, какой шаблон использован.

## 9. Acceptance criteria

1. Можно сохранить минимум три Event templates одного пользователя.
2. После перезапуска список и содержимое восстанавливаются.
3. Применение каждого template создаёт новый draft id и новые occurrence ids.
4. Даты, occurrences, overrides, media, URLs и publish metadata не протекают.
5. Активный draft не перезаписывается template restore автоматически.
6. `Create another Event` применяет последний использованный template.
7. После удаления последнего template используется безопасный empty Event.
8. Шаблоны другого user/type не видны и не применяются.
9. Rename/replace/delete не повреждают соседние templates.
10. Mapper поддерживает round-trip и fail-closed unknown schema.
11. Widget flow работает на 360 dp и имеет semantics/labels.
12. Firebase/сеть не используются.
13. Boundary check, `flutter analyze` и полный `flutter test` зелёные.

## 10. Rollback

UI entry и coordinator можно отключить без изменения active draft schema.
Удаление local template collection не влияет на drafts и опубликованный
контент. Нет удалённых side effects или платной инфраструктуры.
