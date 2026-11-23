import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/push_announcer.dart';

// A34 2026-11-22 13:23: a push arrived ~1.7 s after launch, while the router
// had no page yet, and showSnackBar failed: "no descendant Scaffolds".
void main() {
  final GlobalKey<ScaffoldMessengerState> messenger =
      GlobalKey<ScaffoldMessengerState>();
  final ValueNotifier<bool> page = ValueNotifier<bool>(false);

  SnackBar banner(BuildContext context) =>
      const SnackBar(content: Text('push arrived'));

  Widget app() => MaterialApp(
    scaffoldMessengerKey: messenger,
    home: ValueListenableBuilder<bool>(
      valueListenable: page,
      builder: (_, bool shown, _) =>
          shown ? const Scaffold(body: Text('page')) : const SizedBox(),
    ),
  );

  setUp(() => page.value = false);

  testWidgets('a push before any page waits for one', (tester) async {
    await tester.pumpWidget(app());
    PushAnnouncer(messenger).announce(banner);
    await tester.pump();
    expect(tester.takeException(), isNull);

    page.value = true;
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('push arrived'), findsOneWidget);
  });

  testWidgets('a push on a page shows at once', (tester) async {
    page.value = true;
    await tester.pumpWidget(app());
    PushAnnouncer(messenger).announce(banner);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('push arrived'), findsOneWidget);
  });

  testWidgets('without a page the banner is dropped, nothing fails', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    PushAnnouncer(messenger).announce(banner);
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);

    page.value = true;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('push arrived'), findsNothing);
  });
}
