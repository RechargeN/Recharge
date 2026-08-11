# EVENT-CREATE-CORE-SCHEDULE — Approved slice spec

- Статус: **Approved for implementation**
- Версия: 1.0
- Дата: 2026-07-19
- Parent product spec: [EVENT_CREATE_SPEC.md](EVENT_CREATE_SPEC.md)
- Canonical target: [EVENT_CLASSIFICATION_SPEC.md](EVENT_CLASSIFICATION_SPEC.md)
- Runtime: local/mock, capability scope C0 + schedule subset C1

EVT-CRT-01 является действующим реализованным C0 + schedule-C1 подмножеством
принятой Event Classification v2.2.3. Этот slice остаётся валидным baseline и
не объявляется устаревшим, но не означает реализацию полного canonical
контракта. Остальные classification/admission/inventory/provider возможности
добавляются только последующими Approved ECL slices без параллельного Event
flow или молчаливого изменения принятых инвариантов.

## 1. Цель

Заменить generic Event form специализированным пятишаговым Event block внутри
существующего config-driven Create Hub. Создать production-capable typed draft
и детерминированный schedule engine без Firebase, Booking и Payments.

## 2. Входит

1. Typed `EventDraftData` со schema migration и сохранением unknown fields.
2. Пять шагов: Basics & Media, Location & Schedule, Requirements, Price &
   Participants, Preview & Publish.
3. Offline/online/hybrid; one-time, all-day, multi-day, multi-date, recurrence.
4. Daily/weekly/monthly/yearly rules, rolling local projection, DST policy,
   exceptions и стабильные temporary occurrence ids.
5. Cover/gallery metadata, required alt text и rights confirmation на mock.
6. Free/fixed Money в minor units; payment collection none/onsite/external;
   registration none/external; public/unlisted.
7. Autosave/restore, step validation, preview, publish to `pending_review` и
   atomic replacement of temporary Event/occurrence ids.

## 3. Не входит

- Firebase, multi-device sync и production media upload/processing;
- ManagedPage/Publisher implementation и server-side capability guards;
- internal Booking, inventory, waitlist, check-in, PSP, refunds и payout;
- private/protected access и localization infrastructure.

## 4. Acceptance criteria

1. Event выбирается в общем Create Hub и использует один общий controller flow.
2. Старый Event draft загружается без потери common fields; новая schema
   round-trips unknown Event fields.
3. Каждый шаг блокирует только переход вперёд и показывает field-level issues;
   назад и autosave доступны для невалидного draft.
4. One-time/all-day/multi-day создают корректные UTC `eventSlots` из local time
   и IANA timezone.
5. Multi-date и recurrence materialize детерминированные occurrences; rolling
   projection не меняет исходное rule.
6. DST gap/overlap обрабатывается сохранённой policy и покрыт unit tests.
7. Смена schedule mode не уничтожает данные без явного подтверждения/сохранённой
   reversible state.
8. Offline требует физическую location; online — access mode; hybrid — оба.
9. Cover требует alt text и rights confirmation для Publish.
10. Money хранится в minor units; free не имеет обязательной цены; fixed имеет
    положительную цену и разрешённый collection mode.
11. External registration требует безопасный HTTPS URL и не обещает Booking.
12. Preview строится из того же typed draft, что publish validation.
13. Publish повторяем/idempotent на mock, выдаёт permanent ids и
    `pending_review`, не создавая duplicate Event.
14. Widget flow работает на ширине 360 dp и имеет labels/errors/semantics.
15. `flutter analyze` и полный `flutter test` проходят без ошибок.

## 5. Gate semantics

Этот slice разрешает только local/mock runtime. Наличие полей будущего полного
контракта не включает capability. Firebase и provider integrations остаются
запрещены до отдельных Approved slices и production gates parent spec.
