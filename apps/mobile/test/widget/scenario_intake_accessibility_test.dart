import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/money_test_values.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/presentation/widgets/scenario_intake_selection_tray.dart';

void main() {
  testWidgets(
    'selection tray fits 360dp at 1.5 text scale and announces count',
    (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
      });
      final semantics = tester.ensureSemantics();
      final selected = List<DiscoverItemEntity>.generate(8, _item);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            );
          },
          home: Scaffold(
            bottomNavigationBar: ScenarioIntakeSelectionTray(
              selectedItems: selected,
              message: 'One selected stop needs review.',
              onRemove: (_) {},
              onCancel: () {},
              onReview: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(
          '8 stops selected for Scenario. One selected stop needs review.',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Remove Long selected stop 1'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      semantics.dispose();
    },
  );
}

DiscoverItemEntity _item(int index) => DiscoverItemEntity(
  id: 'item-$index',
  title: 'Long selected stop ${index + 1}',
  subtitle: 'Public catalog item',
  city: 'Riga',
  category: 'culture',
  startsAtUtc: DateTime.utc(2026, 8, 3),
  latitude: 56.9496,
  longitude: 24.1052,
  price: testZeroEur,
  distanceKm: 1,
  isFree: true,
  objectKind: DiscoverObjectKind.place,
);
