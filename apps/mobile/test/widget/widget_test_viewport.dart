import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void fullPageTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, (WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(800, 8000)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });

    await callback(tester);
  });
}

extension FullPageWidgetTester on WidgetTester {
  Future<void> scrollPageUntilVisible(
    Finder finder,
    double delta, {
    Finder? scrollable,
  }) {
    return scrollUntilVisible(
      finder,
      delta,
      scrollable: scrollable ?? find.byType(Scrollable).first,
    );
  }
}
