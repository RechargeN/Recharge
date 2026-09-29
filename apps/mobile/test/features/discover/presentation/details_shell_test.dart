import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/presentation/shell/details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

/// Contract tests for [DetailsShell] in isolation from any real renderer.
///
/// `docs/product/DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` file map: these
/// tests must prove the shell renders its loading/unavailable states
/// correctly with **no** dependency on a coordinate, a single date, a
/// price, a single publisher CTA, a single location or a single schedule —
/// i.e. purely from [DetailsScreenState], never from a concrete item shape.
void main() {
  group('DetailsShell', () {
    testWidgets('loading state shows a spinner under the RECHARGE app bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DetailsShell(state: DetailsScreenLoading()),
        ),
      );

      expect(find.text('RECHARGE'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('available state dispatches to the resolved renderer only', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DetailsShell(
            state: DetailsScreenAvailable(
              renderer: const _FakeRenderer(
                appBarActionLabel: 'fake-action',
                heroLabel: 'fake-hero',
                bodyLabel: 'fake-body',
                stickyLabel: 'fake-sticky',
              ),
            ),
          ),
        ),
      );

      expect(find.text('RECHARGE'), findsOneWidget);
      expect(find.text('fake-action'), findsOneWidget);
      expect(find.text('fake-hero'), findsOneWidget);
      expect(find.text('fake-body'), findsOneWidget);
      expect(find.text('fake-sticky'), findsOneWidget);
    });

    testWidgets(
      'a renderer with no sticky action does not get an empty sticky '
      'container',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DetailsShell(
              state: DetailsScreenAvailable(
                renderer: const _FakeRenderer(
                  appBarActionLabel: 'fake-action',
                  heroLabel: 'fake-hero',
                  bodyLabel: 'fake-body',
                  stickyLabel: null,
                ),
              ),
            ),
          ),
        );

        final Scaffold scaffold = tester.widget<Scaffold>(
          find.byType(Scaffold),
        );
        expect(scaffold.bottomNavigationBar, isNull);
      },
    );

    testWidgets(
      'temporarilyUnavailable shows a retry action that invokes onRetry',
      (tester) async {
        bool retried = false;
        await tester.pumpWidget(
          MaterialApp(
            home: DetailsShell(
              state: DetailsScreenUnavailable(
                reason: DetailsUnavailableReason.temporarilyUnavailable,
                onRetry: () => retried = true,
              ),
            ),
          ),
        );

        expect(find.text('Не удалось загрузить details'), findsOneWidget);
        expect(find.text('Повторить'), findsOneWidget);

        await tester.tap(find.text('Повторить'));
        await tester.pump();
        expect(retried, isTrue);
      },
    );

    testWidgets(
      'unavailable and notFound render identical copy with no retry action '
      '(DTL-D10: must not let a viewer distinguish the two)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DetailsShell(
              state: DetailsScreenUnavailable(
                reason: DetailsUnavailableReason.unavailable,
              ),
            ),
          ),
        );
        expect(find.text('Недоступно'), findsOneWidget);
        expect(find.text('Повторить'), findsNothing);

        await tester.pumpWidget(
          const MaterialApp(
            home: DetailsShell(
              state: DetailsScreenUnavailable(
                reason: DetailsUnavailableReason.notFound,
              ),
            ),
          ),
        );
        expect(find.text('Недоступно'), findsOneWidget);
        expect(find.text('Повторить'), findsNothing);
      },
    );

    testWidgets(
      'temporarilyUnavailable without onRetry shows no retry action',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DetailsShell(
              state: DetailsScreenUnavailable(
                reason: DetailsUnavailableReason.temporarilyUnavailable,
              ),
            ),
          ),
        );
        expect(find.text('Повторить'), findsNothing);
      },
    );
  });
}

class _FakeRenderer implements DetailsRenderer {
  const _FakeRenderer({
    required this.appBarActionLabel,
    required this.heroLabel,
    required this.bodyLabel,
    required this.stickyLabel,
  });

  final String appBarActionLabel;
  final String heroLabel;
  final String bodyLabel;
  final String? stickyLabel;

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    return <Widget>[Text(appBarActionLabel)];
  }

  @override
  Widget buildHero(BuildContext context) => Text(heroLabel);

  @override
  Widget buildBody(BuildContext context) => Text(bodyLabel);

  @override
  Widget? buildStickyAction(BuildContext context) {
    final String? label = stickyLabel;
    return label == null ? null : Text(label);
  }
}
