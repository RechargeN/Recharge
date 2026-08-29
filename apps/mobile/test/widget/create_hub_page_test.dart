import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/presentation/pages/create_hub_page.dart';

void main() {
  testWidgets(
    'Collection / guide card is hidden without create.collection',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateHubPage(
            isAuthenticated: true,
            capabilities: <String>['create.route'],
          ),
        ),
      );

      expect(find.text('Collection / guide'), findsNothing);
      expect(find.text('Route'), findsOneWidget);
    },
  );

  testWidgets(
    'Collection / guide card appears with create.collection',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateHubPage(
            isAuthenticated: true,
            capabilities: <String>['create.collection'],
          ),
        ),
      );

      expect(find.text('Collection / guide'), findsOneWidget);
    },
  );

  testWidgets(
    'unauthenticated users never see any create block, Collection included',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CreateHubPage(
            isAuthenticated: false,
            capabilities: <String>['create.collection'],
          ),
        ),
      );

      expect(find.text('Collection / guide'), findsNothing);
      expect(find.text('Требуется авторизация'), findsOneWidget);
    },
  );
}
