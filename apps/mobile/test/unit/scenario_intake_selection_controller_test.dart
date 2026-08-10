import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/adapters/discover_scenario_intake_adapter.dart';
import 'package:recharge/features/discover/application/controllers/scenario_intake_selection_controller.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';

void main() {
  const adapter = DiscoverScenarioIntakeAdapter();
  late ScenarioIntakeSelectionController controller;

  setUp(() {
    controller = ScenarioIntakeSelectionController(
      supportIssue: adapter.supportIssue,
    );
  });

  tearDown(() => controller.dispose());

  test('tap order is stable and toggling removes only the exact item', () {
    controller.start();
    controller.toggle(_item(2));
    controller.toggle(_item(1));
    controller.toggle(_item(3));

    expect(controller.state.selectedItems.map((item) => item.id), <String>[
      'item-2',
      'item-1',
      'item-3',
    ]);
    expect(controller.state.orderOf('item-1'), 2);

    controller.toggle(_item(1));
    expect(controller.state.selectedItems.map((item) => item.id), <String>[
      'item-2',
      'item-3',
    ]);
    expect(controller.state.orderOf('item-3'), 2);
  });

  test('selection is independent from the current result collection', () {
    controller.start();
    final hiddenAfterFilter = _item(7);
    controller.toggle(hiddenAfterFilter);

    final visibleAfterFilter = <DiscoverItemEntity>[_item(8), _item(9)];

    expect(visibleAfterFilter, isNot(contains(hiddenAfterFilter)));
    expect(controller.state.selectedItems.single, same(hiddenAfterFilter));
    controller.remove(hiddenAfterFilter.id);
    expect(controller.state.selectedItems, isEmpty);
  });

  test('twenty-first item is rejected without changing the first twenty', () {
    controller.start();
    for (var index = 1; index <= 20; index++) {
      expect(
        controller.toggle(_item(index)),
        ScenarioIntakeToggleResult.selected,
      );
    }

    final result = controller.toggle(_item(21));

    expect(result, ScenarioIntakeToggleResult.limitReached);
    expect(controller.state.count, 20);
    expect(controller.state.selectedItems.last.id, 'item-20');
    expect(controller.state.message, contains('up to 20'));
  });

  test('unsupported result explains the issue and cancel clears all state', () {
    controller.start();
    final invalid = _item(1).copyWith();
    final invalidLocation = DiscoverItemEntity(
      id: invalid.id,
      title: invalid.title,
      subtitle: invalid.subtitle,
      city: invalid.city,
      category: invalid.category,
      startsAtUtc: invalid.startsAtUtc,
      latitude: 91,
      longitude: invalid.longitude,
      priceAmount: invalid.priceAmount,
      distanceKm: invalid.distanceKm,
      isFree: invalid.isFree,
    );

    expect(
      controller.toggle(invalidLocation),
      ScenarioIntakeToggleResult.unsupported,
    );
    expect(controller.state.message, contains('no usable catalog location'));
    expect(controller.state.selectedItems, isEmpty);

    controller.toggle(_item(2));
    controller.cancel();
    expect(controller.state.active, isFalse);
    expect(controller.state.selectedItems, isEmpty);
    expect(controller.state.message, isNull);
  });
}

DiscoverItemEntity _item(int index) => DiscoverItemEntity(
  id: 'item-$index',
  title: 'Item $index',
  subtitle: 'Catalog result',
  city: 'Riga',
  category: 'activity',
  startsAtUtc: DateTime.utc(2026, 8, 3, 12),
  latitude: 56.94 + index / 10000,
  longitude: 24.10 + index / 10000,
  priceAmount: 0,
  distanceKm: 1,
  isFree: true,
);
