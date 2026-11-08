import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/dev_content_media_port.dart';
import 'package:recharge/app/di/place_publication_composition.dart';
import 'package:recharge/features/booking/data/booking_callable_adapter.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/repositories/place_publication_gateway.dart';
import 'package:recharge/features/create/presentation/widgets/place_publication_section.dart';
import 'package:recharge/generated/l10n/app_localizations.dart';

final class _NoPort implements BookingCallablePort {
  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> command,
  ) => throw StateError('not called');
}

final class _NoDraft implements PlaceDraftSource {
  @override
  Future<CreateDraftEntity?> current() async => null;
}

/// A34 2026-11-08: the dev-cloud page was labelled "local Emulator".
void main() {
  for (final bool devCloud in <bool>[false, true]) {
    testWidgets('the header names the backend (devCloud=$devCloud)', (
      WidgetTester tester,
    ) async {
      final Directory dir = Directory.systemTemp.createTempSync('place-pub-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final controller = placePublicationControllerFor(
        accountId: 'user-1',
        port: _NoPort(),
        guard: PlacePublicationTestEntryGuard(
          flag: false,
          releaseMode: false,
          binding: BookingBackendBindingController(
            emulatorBase: Uri.parse(
              'http://127.0.0.1:5001/demo-recharge/europe-west1',
            ),
            releaseMode: false,
            initial: BackendBindingMode.localOnly,
          ),
          devFlag: true,
          devPort: DevContentMediaPort(_NoPort()),
        ),
        drafts: _NoDraft(),
        journalFile: File('${dir.path}/journal.json'),
        marketCurrencyCode: 'EUR',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlacePublicationSection(
              controller: controller,
              devCloud: devCloud,
            ),
          ),
        ),
      );
      expect(
        find.text(
          devCloud
              ? 'Тестовый путь публикации (dev-облако)'
              : 'Тестовый путь публикации (локальный эмулятор)',
        ),
        findsOneWidget,
      );
    });
  }
}
