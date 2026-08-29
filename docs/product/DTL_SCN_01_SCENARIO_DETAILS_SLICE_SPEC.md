# RECHARGE — DTL-SCN-01: Scenario Details Renderer Slice Spec

Версия: v0.3 (2026-08-24) — третий раунд review разделил Approval gates
на «написать документ» и «реализовать код» (см. ниже); v0.2 (2026-08-23)
исправила две инверсии второго раунда (gate/видимость).
Статус: **Blocked — not draftable as a full slice spec yet.**

Runtime effect (этого документа): **none**.

## Что изменилось в третьем раунде

Approval gates для FND разделены на два условия вместо одного: наличие
**Approved contract** `DTL-FND-01` (документ) достаточно, чтобы **писать**
этот документ; наличие **реализованного** `DTL-FND-01` (код) нужно,
только чтобы **реализовывать** уже написанный `DTL-SCN-01`. Раньше это
было одним пунктом — та же инверсия, что уже была исправлена для
`SCN-PUB-01` во втором раунде. См. §Approval gates ниже.

## Что изменилось относительно v0.1 (второй раунд)

1. **Gate смягчён.** Не обязательно ждать именно runtime-реализации
   `SCN-PUB-01`. Полноценный Details slice можно спроектировать уже
   после появления **Approved typed publication/read-projection
   contract** — то есть принятого владельцем продукта описания формы
   данных, до того, как код её реализует. Требование ждать runtime было
   инверсией: иначе код начинает определять спецификацию, а не наоборот.
2. **Видимость исправлена.** Accepted `SCENARIO_BUILDER_SPEC.md` (§5,
   строки 494-509) фиксирует: только `public` Scenario, прошедший
   publish/moderation flow, появляется в общей Discover-выдаче.
   `unlisted` Scenario остаётся разновидностью личного плана — не
   попадает в Discover-каталог/поиск, открывается только по прямой
   ссылке владельца через отдельный guarded link flow. Прежняя
   формулировка «public/unlisted оба проецируются в Discover» была
   неверна.

## Почему этот документ короткий и без AC/file map

В отличие от `DTL-FND-01`/`DTL-OBJ-01`/`DTL-RTE-01`/`DTL-CLG-01`, у этого
slice пока **нет Approved контракта данных**, под который можно
проектировать file map/AC без риска спекуляции. Написание полной
секционной матрицы сейчас означало бы проектировать рендерер под данные,
чья форма ещё не согласована — ровно тот speculative dead code, который
`DTL-FND-01` (FND-AC-07) прямо запрещает для кода; тот же принцип
применяется здесь к документации.

## Approval gates — разделены на «написать» и «реализовать»

Для **написания** полноценного `DTL-SCN-01` (file map/AC/test plan)
достаточно:

1. `SCN-PUB-01` имеет **Approved typed publication/read-projection
   contract** (форма read-модели согласована владельцем продукта, не
   обязательно реализована в runtime).
2. `DISCOVER_DETAILS_SYSTEM_SPEC.md` принят владельцем продукта.
3. `DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` сам имеет статус `Approved`
   как документ — его **contract** (DetailsShell/DetailsRenderer API) уже
   достаточно стабилен, чтобы проектировать под него `ScenarioDetailsRenderer`
   на бумаге, не дожидаясь, пока он физически реализован в коде.

Для **реализации** (написания кода по уже готовому `DTL-SCN-01`)
дополнительно требуется:

4. `DTL-FND-01` **реализован** в runtime (не только Approved как
   документ) — `ScenarioDetailsRenderer` не может физически
   зарегистрироваться в registry, которого ещё нет в коде.
5. Сам `DTL-SCN-01` (когда будет дописан) отдельно получает статус
   `Approved`.

Это два разных условия: документ можно и нужно написать раньше, чем
код `DTL-FND-01` появится в репозитории — держать их одним пунктом было
той же инверсией, что уже исправлена для `SCN-PUB-01` выше.

## Что уже зафиксировано и переносится в будущий полный документ без изменений

- Состав экрана — `DISCOVER_DETAILS_SYSTEM_SPEC.md` §7: overview, days,
  ordered stops, time blocks, логистика между остановками, planned/
  not-live статус транспорта, estimated budget, publisher, `Create my
  copy` (соответствует `Use this scenario` из `SCENARIO_BUILDER_SPEC.md`
  §413), save/share, multi-point карта через уже специфицированный
  `ScenarioGeoSummary` (`SCENARIO_BUILDER_SPEC.md` §673).
- Явное разделение reader-facing Scenario Details / Scenario Builder /
  личный Quick Plan / Route Details — уже зафиксировано и не
  пересматривается.
- `enum ScenarioVisibility { private, unlisted, public }` уже определён
  в `SCENARIO_BUILDER_SPEC.md` §512. По §5 (строки 494-509) только
  `public` (прошедший publish/moderation) проецируется в общую
  Discover-выдачу/каталог/поиск. `unlisted` — разновидность личного
  плана: доступен по прямой ссылке владельца, но не через
  Discover-каталог/canonical route листинга; `ScenarioDetailsRenderer`
  обслуживает и его, но не как элемент публичной выдачи. `private`
  никогда не достижим ни через canonical route, ни через прямую ссылку
  постороннему.

## Что нужно сделать перед тем, как этот документ станет полноценным

1. Дождаться, пока `SCN-PUB-01` получит **Approved** typed
   publication/read-projection contract — согласованный владельцем
   продукта список полей `PublishedScenarioDiscoveryEntity` (или её
   эквивалента), пусть даже до runtime-реализации.
2. Только после этого — написать file map, AC и test plan по тому же
   формату, что `DTL-OBJ-01`/`DTL-RTE-01`/`DTL-CLG-01`, опираясь на
   согласованную форму данных, а не на предположение о ней.

Этот документ **не подлежит** отдельному approval как implementation
slice в текущем виде — он служит только placeholder'ом в перечне Этапа 3
и фиксацией причины блокировки, чтобы она не терялась между сессиями.
