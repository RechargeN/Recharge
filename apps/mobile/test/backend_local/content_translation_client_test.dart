import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/content_translation_composition.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/discover/data/datasources/content_translation_client.dart';
import 'package:recharge/features/discover/domain/repositories/content_translation_port.dart';
import 'package:uuid/uuid.dart';

import 'support/stand_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['RECHARGE_CT_LOCAL'] == '1';
  if (enabled) HttpOverrides.global = null;
  test(
    'the real Flutter client translates through the Session transport',
    () async {
      final temp = await Directory.systemTemp.createTemp('ct-client-');
      addTearDown(() async {
        if (await temp.exists()) await temp.delete(recursive: true);
      });
      final contentId = Platform.environment['RECHARGE_CT_CONTENT_ID']!;
      final revisionId = Platform.environment['RECHARGE_CT_REVISION_ID']!;
      final binding = BookingBackendBindingController(
        emulatorBase: StandBackend.functionsBase,
        releaseMode: false,
        initial: BackendBindingMode.testBackend,
      );
      final http = CountingClient();
      addTearDown(http.close);
      final runtime = await BookingTransportRuntimeFactory(
        endpoint: binding.endpoint,
        client: http,
        tokens: AuthEmulatorTokenProvider('stand-user-translation'),
        sessions: FileSessionStore(File('${temp.path}/session.json')),
        installations: FixedInstallationId('ct-mobile-client'),
        supportDirectory: () =>
            Directory('${temp.path}/support').create(recursive: true),
      ).create();
      await runtime.identitySessions!.establish(requestId: const Uuid().v4());
      final client = ContentTranslationClient(
        invoke: contentTranslationInvoke(
          binding: binding,
          runtime: () async => runtime,
        ),
      );

      expect(
        await client.offer(
          contentId: contentId,
          publishedRevisionId: revisionId,
          targetLocale: 'ru',
        ),
        isTrue,
      );
      expect(
        await client.offer(
          contentId: contentId,
          publishedRevisionId: revisionId,
          targetLocale: 'lv',
        ),
        isFalse,
        reason: 'the source language needs no translation',
      );
      final translation = await client.translate(
        contentId: contentId,
        publishedRevisionId: revisionId,
        targetLocale: 'ru',
      );
      expect(translation.sourceLocale, 'lv');
      expect(translation.title, '[lv→ru] Atvērto durvju diena');

      binding.activate(BackendBindingMode.localOnly);
      expect(
        await client.offer(
          contentId: contentId,
          publishedRevisionId: revisionId,
          targetLocale: 'ru',
        ),
        isFalse,
        reason: 'without the test entry nothing goes on the wire',
      );
      await expectLater(
        client.translate(
          contentId: contentId,
          publishedRevisionId: revisionId,
          targetLocale: 'ru',
        ),
        throwsA(isA<ContentTranslationFailure>()),
      );
    },
    skip: enabled
        ? false
        : 'Run the content-translation Emulator group with RECHARGE_G_MOBILE=1.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
