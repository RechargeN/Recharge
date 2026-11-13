import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/media/data/functions_media_upload_gateway.dart';
import 'package:recharge/features/media/domain/repositories/media_upload_gateway.dart';

/// D4 §4.2: a retry of an upload intent whose answer was lost replays the
/// same, already completed, upload session. The bytes are never sent twice:
/// the server's record of the asset decides whether the earlier attempt is
/// reused.
void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
  final String digest = sha256.convert(bytes).toString();

  MediaUploadRequest request() => MediaUploadRequest(
    intentId: 'intent-1',
    bytes: bytes,
    declaredMediaType: 'image/png',
    publisherType: 'page',
    publisherId: 'page-1',
    contentId: 'content-1',
  );

  Map<String, Object?> asset({
    String lifecycle = 'ready',
    String? sha = 'same',
    int? length,
    String entityId = 'content-1',
  }) => <String, Object?>{
    'assetId': 'asset-1',
    'lifecycle': lifecycle,
    'revision': 4,
    'entityBinding': <String, Object?>{
      'domain': 'content',
      'entityId': entityId,
      'purpose': 'contentMedia',
    },
    'sourceGenerationRef': <String, Object?>{
      'providerGeneration': 'g-1',
      'byteLength': length ?? bytes.length,
      'verifiedMediaType': 'image/png',
      'sha256': sha == 'same' ? digest : sha,
      'validationProfileRevision': 'v1',
    },
  };

  test('a fresh upload goes through every step once and never asks for the '
      'asset status', () async {
    final _ScriptedPort port = _ScriptedPort();
    final MediaUploadResult result = await _gateway(port).upload(request());
    expect(result.outcome, MediaUploadOutcome.ready);
    expect(result.assetId, 'asset-1');
    expect(result.assetRevision, 3);
    expect(port.steps, <String>[
      'createUploadSession',
      'bytes',
      'confirmUpload',
      'finalizeAsset',
    ]);
  });

  test('a replayed intent whose asset is ready returns it without a second '
      'transfer', () async {
    final _ScriptedPort port = _ScriptedPort(
      transferCode: 'session_expired',
      status: asset(),
    );
    final MediaUploadResult result = await _gateway(port).upload(request());
    expect(result.outcome, MediaUploadOutcome.ready);
    expect(result.assetId, 'asset-1');
    expect(result.assetRevision, 4);
    expect(port.steps, <String>[
      'createUploadSession',
      'bytes',
      'getAssetStatus',
    ]);
  });

  test('a replayed intent confirmed but not finalized finishes through the '
      'same idempotency keys', () async {
    final _ScriptedPort port = _ScriptedPort(
      transferCode: 'session_expired',
      status: asset(lifecycle: 'uploaded'),
    );
    final MediaUploadResult result = await _gateway(port).upload(request());
    expect(result.outcome, MediaUploadOutcome.ready);
    expect(port.steps, <String>[
      'createUploadSession',
      'bytes',
      'getAssetStatus',
      'confirmUpload',
      'finalizeAsset',
    ]);
    expect(port.keys, <String>[
      'intent-1:session',
      'intent-1:confirm',
      'intent-1:finalize',
    ]);
  });

  test('other bytes, another entity, an unusable state or another refusal keep '
      'the refusal', () async {
    for (final Map<String, Object?>? status in <Map<String, Object?>?>[
      asset(sha: 'other'),
      asset(length: 99),
      asset(entityId: 'content-2'),
      asset(lifecycle: 'reserved'),
      asset(lifecycle: 'blocked'),
      asset(lifecycle: 'deleted'),
      null,
    ]) {
      final _ScriptedPort port = _ScriptedPort(
        transferCode: 'session_expired',
        status: status,
      );
      final MediaUploadResult result = await _gateway(port).upload(request());
      expect(result.outcome, MediaUploadOutcome.rejected, reason: '$status');
      expect(result.failureCode, 'session_expired');
      expect(port.steps.last, 'getAssetStatus');
    }
    final _ScriptedPort limited = _ScriptedPort(
      transferCode: 'limit_exceeded',
      status: asset(),
    );
    final MediaUploadResult refused = await _gateway(limited).upload(request());
    expect(refused.failureCode, 'limit_exceeded');
    expect(limited.steps, <String>['createUploadSession', 'bytes']);
  });
}

FunctionsMediaUploadGateway _gateway(_ScriptedPort port) =>
    FunctionsMediaUploadGateway(port: port, gate: const _Open());

final class _Open implements MediaCommandGate {
  const _Open();

  @override
  void assertAllowed() {}
}

/// Answers the Media callables like the server would for one intent.
final class _ScriptedPort implements MediaCallablePort {
  _ScriptedPort({this.transferCode, this.status});

  /// Refusal of the byte transfer; null accepts it.
  final String? transferCode;

  /// The asset view `getAssetStatus` returns; null refuses with `not_found`.
  final Map<String, Object?>? status;

  final List<String> steps = <String>[];
  final List<String> keys = <String>[];

  @override
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  ) async {
    Map<String, Object?> ok(Map<String, Object?> body) => <String, Object?>{
      'kind': 'succeeded',
      'data': body,
    };
    Map<String, Object?> no(String code) => <String, Object?>{
      'kind': 'rejected',
      'code': code,
    };
    switch (callableName) {
      case 'uploadMediaBytesV1':
        steps.add('bytes');
        return transferCode == null
            ? ok(<String, Object?>{'received': 5})
            : no(transferCode!);
      case 'mediaQueryV1':
        steps.add(data['queryType']! as String);
        return status == null ? no('not_found') : ok(status!);
      case 'mediaCommandV1':
        final String type = data['commandType']! as String;
        steps.add(type);
        keys.add(data['idempotencyKey']! as String);
        return switch (type) {
          'createUploadSession' => ok(<String, Object?>{
            'uploadSessionId': 'session-1',
            'assetId': 'asset-1',
          }),
          'confirmUpload' => ok(<String, Object?>{
            'revision': 2,
            'sourceGenerationRef': <String, Object?>{'providerGeneration': 'g'},
          }),
          'finalizeAsset' => ok(<String, Object?>{
            'lifecycle': 'ready',
            'revision': 3,
          }),
          _ => no('invalid_contract'),
        };
    }
    return no('invalid_contract');
  }
}
