import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/discover_item_entity.dart';
import 'package:recharge/features/discover/presentation/shell/compatibility_object_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_renderer.dart';
import 'package:recharge/features/discover/presentation/shell/details_shell.dart';

/// `docs/product/DTL_FND_01_DETAILS_SHELL_SLICE_SPEC.md` file map: "360dp/
/// 150% text scale, sticky action container overflow" — the shell owns the
/// sticky action container, so it must not let an oversized label overflow
/// it regardless of which renderer supplies the content.
void main() {
  Future<void> pumpAtNarrowWidthAndLargeTextScale(
    WidgetTester tester,
    Widget home,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..resetPhysicalSize()
        ..resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          );
        },
        home: home,
      ),
    );
  }

  group('DetailsShell at 360dp / 150% text scale', () {
    testWidgets(
      'a sticky action with an oversized label does not overflow the '
      'bottom bar',
      (tester) async {
        await pumpAtNarrowWidthAndLargeTextScale(
          tester,
          DetailsShell(
            state: DetailsScreenAvailable(renderer: const _LongLabelRenderer()),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CompatibilityObjectRenderer (the real DTL-FND-01 consumer) renders '
      'without overflow for a long-title item',
      (tester) async {
        await pumpAtNarrowWidthAndLargeTextScale(
          tester,
          DetailsShell(
            state: DetailsScreenAvailable(
              renderer: CompatibilityObjectRenderer(
                item: _longTitleItem,
                isFavorite: false,
                ctaSubmitted: false,
                onFavoriteTap: () {},
                onShareTap: () {},
                onMap: () {},
                onRouteMap: () {},
                onAddToScenario: null,
                onSearch: () {},
                onCreateSimilar: () {},
                onCreateRoute: () {},
                onMarkVisited: () {},
                onCtaTap: () {},
                onReportRoute: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('RECHARGE'), findsOneWidget);
      },
    );

    testWidgets(
      'loading and unavailable states also render without overflow',
      (tester) async {
        await pumpAtNarrowWidthAndLargeTextScale(
          tester,
          const DetailsShell(state: DetailsScreenLoading()),
        );
        // A single pump only: the loading state's CircularProgressIndicator
        // is an indeterminate spinner with a never-ending animation, so
        // pumpAndSettle would time out waiting for it to stop.
        await tester.pump();
        expect(tester.takeException(), isNull);

        await pumpAtNarrowWidthAndLargeTextScale(
          tester,
          const DetailsShell(
            state: DetailsScreenUnavailable(
              reason: DetailsUnavailableReason.temporarilyUnavailable,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _LongLabelRenderer implements DetailsRenderer {
  const _LongLabelRenderer();

  @override
  List<Widget> buildAppBarActions(BuildContext context) => const <Widget>[];

  @override
  Widget buildHero(BuildContext context) => const SizedBox(height: 120);

  @override
  Widget buildBody(BuildContext context) => const SizedBox.shrink();

  @override
  Widget? buildStickyAction(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: () {},
                child: const Text(
                  'A very long call to action label that must not overflow '
                  'the sticky bottom bar container',
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.favorite_border),
            ),
          ],
        ),
      ),
    );
  }
}

final DiscoverItemEntity _longTitleItem = DiscoverItemEntity(
  id: 'evt_1',
  title:
      'Morning yoga with an unusually long title meant to stress-test text '
      'wrapping at a 150% scale factor',
  subtitle: 'Gentle recharge session with an equally long subtitle line',
  city: 'Rezekne',
  category: 'wellness',
  startsAtUtc: DateTime.parse('2026-04-18T07:00:00Z'),
  latitude: 56.5099,
  longitude: 27.3332,
  priceAmount: 0,
  distanceKm: 1.2,
  isFree: true,
  objectKind: DiscoverObjectKind.activity,
  organizerName: 'Recharge Studio',
  organizerHandle: '@recharge',
  venueName: 'Green studio',
  addressLine: 'Atbrivosanas aleja 1',
  participantsCount: 8,
  capacity: 12,
  durationMinutes: 60,
  ctaLabel: 'Join activity',
  highlights: const <String>['Beginner friendly', 'Calm group pace'],
);
