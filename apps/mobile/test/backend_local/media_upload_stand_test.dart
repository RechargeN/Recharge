import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/di/backend_binding_manifest.dart';
import 'package:recharge/app/di/booking_backend_selection.dart';
import 'package:recharge/app/di/booking_test_entry_guard.dart';
import 'package:recharge/app/di/media_composition.dart';
import 'package:recharge/features/booking/data/booking_transport_runtime.dart';
import 'package:recharge/features/media/data/functions_media_upload_gateway.dart';
import 'package:recharge/features/media/domain/repositories/media_upload_gateway.dart';
import 'package:uuid/uuid.dart';

import 'support/stand_backend.dart';

/// C1: the mobile Media adapter against the real local demo-recharge stand:
/// upload session, byte transfer, confirm and finalize with the existing fake
/// scanner and processor, then Content (on the backend) checks the exact Media
/// revision. The image is a repository fixture; picking from a gallery and its
/// permissions are B1-device.
///
/// The fake scanner and processor prove orchestration only: "ready" here is not
/// evidence that any real malware scan or image transformation happened.
void main() {
  final stand = StandBackend.fromEnvironment();
  const uuid = Uuid();
  late Directory temp;

  ({MediaUploadGateway gateway, BookingTestEntryGuard guard}) build(
    String label,
  ) {
    final controller = BookingBackendBindingController(
      emulatorBase: StandBackend.functionsBase,
      releaseMode: false,
      initial: BackendBindingMode.testBackend,
    );
    final guard = BookingTestEntryGuard(
      flag: true,
      releaseMode: false,
      binding: controller,
    );
    final sessions = FileSessionStore(File('${temp.path}/session-$label.json'));
    final factory = BookingTransportRuntimeFactory(
      endpoint: controller.endpoint,
      client: CountingClient(),
      tokens: AuthEmulatorTokenProvider('stand-user-$label'),
      sessions: sessions,
      installations: FixedInstallationId('c1-local-installation-$label'),
      supportDirectory: () async =>
          Directory('${temp.path}/support-$label').create(recursive: true),
    );
    return (
      gateway: _LazyGateway(() async {
        final runtime = await factory.create();
        if (await sessions.read() == null) {
          await runtime.identitySessions!.establish(requestId: uuid.v4());
        }
        return mediaUploadGatewayFor(
          port: runtime.port!,
          gate: BookingGuardMediaGate(guard),
        );
      }),
      guard: guard,
    );
  }

  late Uint8List cover;
  late Map<String, Object?> draft;

  setUpAll(() async {
    if (stand == null) return;
    temp = await Directory.systemTemp.createTemp('c1-local-');
    cover = await File('test/fixtures/media/stand_cover.png').readAsBytes();
    draft = await stand.contentDraft('creator', 'studio');
  });

  tearDownAll(() async {
    if (stand != null && await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  MediaUploadRequest request({
    Uint8List? bytes,
    String mediaType = 'image/png',
    Map<String, Object?>? forDraft,
  }) {
    final target = forDraft ?? draft;
    return MediaUploadRequest(
      intentId: uuid.v4(),
      bytes: bytes ?? cover,
      declaredMediaType: mediaType,
      publisherType: 'page',
      publisherId: target['pageId']! as String,
      contentId: target['contentId']! as String,
    );
  }

  test(
    'the creator uploads the fixture and Content accepts that exact revision',
    () async {
      final creator = build('creator');

      final result = await creator.gateway.upload(request());

      expect(
        result.outcome,
        MediaUploadOutcome.ready,
        reason: result.failureCode,
      );
      expect(result.assetId, isNotNull);
      final readiness = await stand!.mediaReadiness(
        'creator',
        draft['draftId']! as String,
        result.assetId!,
      );
      expect(readiness['ready'], isTrue, reason: '$readiness');
      expect(readiness['mediaRevision'], isA<String>());
      expect(readiness['submitted'], isTrue, reason: '$readiness');
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a user without Creator authority cannot start an upload for that draft',
    () async {
      final viewer = build('viewer');

      final result = await viewer.gateway.upload(request());

      expect(result.outcome, MediaUploadOutcome.rejected);
      expect(result.assetId, isNull);
      expect(result.failureCode, isNotNull);
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'bytes that are not the declared image type are refused at confirm',
    () async {
      final creator = build('creator');
      // The first test submitted its draft, and a submitted draft is frozen, so
      // this case needs a draft of its own.
      final fresh = await stand!.contentDraft('creator', 'studio');

      final result = await creator.gateway.upload(
        request(
          bytes: Uint8List.fromList(utf8.encode('definitely not a png')),
          forDraft: fresh,
        ),
      );

      expect(result.outcome, MediaUploadOutcome.rejected);
      expect(result.failureCode, 'signature_mismatch');
    },
    skip: stand == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('a denied gate sends nothing at all', () async {
    final port = _CountingMediaPort();
    final gateway = FunctionsMediaUploadGateway(
      port: port,
      gate: const _DeniedGate(),
    );

    await expectLater(
      gateway.upload(
        MediaUploadRequest(
          intentId: 'intent',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          declaredMediaType: 'image/png',
          publisherType: 'page',
          publisherId: 'page',
          contentId: 'content',
        ),
      ),
      throwsStateError,
    );
    expect(port.calls, 0);
  });
}

/// Builds the real gateway (and Session) on first use, outside the test body.
final class _LazyGateway implements MediaUploadGateway {
  _LazyGateway(this._create);

  final Future<MediaUploadGateway> Function() _create;
  MediaUploadGateway? _gateway;

  @override
  Future<MediaUploadResult> upload(MediaUploadRequest request) async =>
      (_gateway ??= await _create()).upload(request);
}

final class _DeniedGate implements MediaCommandGate {
  const _DeniedGate();

  @override
  void assertAllowed() => throw StateError('not allowed');
}

final class _CountingMediaPort implements MediaCallablePort {
  int calls = 0;

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    calls += 1;
    return <String, Object?>{};
  }
}
