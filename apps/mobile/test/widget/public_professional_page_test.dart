import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/identity/domain/entities/public_professional_page.dart';
import 'package:recharge/features/identity/presentation/pages/public_professional_page.dart';

void main() {
  testWidgets('owner preview is explicit and gated actions stay hidden', (
    WidgetTester tester,
  ) async {
    await _pumpView(
      tester,
      projection: _projection(verified: false),
      viewerContext: const PublicPageViewerContext(
        requestedLocale: 'en',
        canOpenPageWorkspace: true,
        canEditPage: true,
        isPreview: true,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('public-page-preview-banner')),
      findsOneWidget,
    );
    expect(find.text('Verification pending'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('share-public-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('manage-public-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('edit-public-page')),
      findsOneWidget,
    );
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Contact'), findsNothing);
    expect(find.text('Report'), findsNothing);
    expect(find.text('Block'), findsNothing);
    expect(find.text('Mute'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public viewer sees verified projection without team actions', (
    WidgetTester tester,
  ) async {
    await _pumpView(
      tester,
      projection: _projection(),
      viewerContext: const PublicPageViewerContext(
        requestedLocale: 'en',
        canOpenPageWorkspace: false,
        canEditPage: false,
        isPreview: false,
      ),
    );

    expect(find.text('Verified Professional Page'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('public-page-preview-banner')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('manage-public-page')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('edit-public-page')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('public-page-empty-content')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpView(
  WidgetTester tester, {
  required PublicManagedPageProjection projection,
  required PublicPageViewerContext viewerContext,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: Scaffold(
        body: PublicProfessionalPageView(
          projection: projection,
          viewerContext: viewerContext,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PublicManagedPageProjection _projection({bool verified = true}) {
  return PublicManagedPageProjection(
    pageId: 'page-1',
    slug: 'recharge-riga',
    displayName: 'Recharge Riga Professional Community',
    countryCode: 'LV',
    verificationBadge: verified,
    contentSummary: const PublicPageContentSummary.empty(),
    publicRevision: 'opaque-token',
    schemaVersion: 1,
  );
}
