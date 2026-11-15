import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/layout/page_list_padding.dart';

/// N4b A34 2026-11-15: page lists with an explicit padding ran under the
/// system navigation bar on edge-to-edge Android.
void main() {
  Future<EdgeInsets> paddingWith(
    WidgetTester tester, {
    required double systemBottom,
    bool shellNavigationBar = false,
  }) async {
    late EdgeInsets result;
    Widget page = Builder(
      builder: (BuildContext context) {
        result = pageListPadding(context, const EdgeInsets.all(16));
        return const SizedBox.shrink();
      },
    );
    if (shellNavigationBar) {
      page = Scaffold(
        body: page,
        bottomNavigationBar: const SizedBox(height: 56),
      );
    }
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: systemBottom)),
        child: MaterialApp(home: page),
      ),
    );
    return result;
  }

  testWidgets('a page list ends above the system navigation bar', (
    WidgetTester tester,
  ) async {
    expect(
      await paddingWith(tester, systemBottom: 48),
      const EdgeInsets.fromLTRB(16, 16, 16, 64),
    );
  });

  testWidgets('no system inset: the padding is unchanged', (
    WidgetTester tester,
  ) async {
    expect(
      await paddingWith(tester, systemBottom: 0),
      const EdgeInsets.all(16),
    );
  });

  testWidgets('inside a shell with a bottom bar the inset is already taken', (
    WidgetTester tester,
  ) async {
    expect(
      await paddingWith(tester, systemBottom: 48, shellNavigationBar: true),
      const EdgeInsets.all(16),
    );
  });
}
