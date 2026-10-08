import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/repositories/media_upload_gateway.dart';

/// Transport used by Media: the same authenticated Functions path as Booking,
/// injected so this feature does not import the Booking feature.
abstract interface class MediaCallablePort {
  Future<Map<String, Object?>> invoke(
    String callableName,
    Map<String, Object?> data,
  );
}

/// Failure of the transport itself (no answer, no Session).
final class MediaTransportFailure implements Exception {
  const MediaTransportFailure(this.code);

  final String code;
}

/// Same shape as the Booking gate: every call asks it first.
abstract interface class MediaCommandGate {
  void assertAllowed();
}

/// Mobile Media adapter: createUploadSession, byte transfer, confirmUpload and
/// finalizeAsset. It holds no authority and no state: Session repair stays in
/// the transport, every decision stays on the server, and retries reuse the
/// idempotency keys derived from the intent id.
final class FunctionsMediaUploadGateway implements MediaUploadGateway {
  FunctionsMediaUploadGateway({
    required MediaCallablePort port,
    required MediaCommandGate gate,
  }) : _port = port,
       _gate = gate;

  final MediaCallablePort _port;
  final MediaCommandGate _gate;

  @override
  Future<MediaUploadResult> upload(MediaUploadRequest request) async {
    _gate.assertAllowed();
    try {
      final sha256Hex = sha256.convert(request.bytes).toString();
      final session = await _command(<String, Object?>{
        'schemaVersion': 1,
        'commandType': 'createUploadSession',
        'idempotencyKey': '${request.intentId}:session',
        'payload': <String, Object?>{
          'family': 'image',
          'marketId': request.marketId,
          'visibilityClass': 'publicDerived',
          'declaredMediaType': request.declaredMediaType,
          'declaredByteLength': request.bytes.length,
          'publisherRef': <String, Object?>{
            'type': request.publisherType,
            'id': request.publisherId,
          },
          'entityIntent': <String, Object?>{
            'domain': 'content',
            'entityId': request.contentId,
            'purpose': 'contentMedia',
          },
        },
      });
      if (session.failure != null) return _rejected(session.failure!);
      final uploadSessionId = session.data!['uploadSessionId']! as String;
      final assetId = session.data!['assetId']! as String;

      final transfer = await _port
          .invoke('uploadMediaBytesV1', <String, Object?>{
            'schemaVersion': 1,
            'uploadSessionId': uploadSessionId,
            'bytesBase64': base64Encode(request.bytes),
          });
      if (transfer['kind'] != 'succeeded') {
        return _rejected(transfer['code'] as String? ?? 'invalid_contract');
      }

      final confirmed = await _command(<String, Object?>{
        'schemaVersion': 1,
        'commandType': 'confirmUpload',
        'idempotencyKey': '${request.intentId}:confirm',
        'payload': <String, Object?>{
          'uploadSessionId': uploadSessionId,
          'expectedSha256': sha256Hex,
          'expectedByteLength': request.bytes.length,
        },
      });
      if (confirmed.failure != null) return _rejected(confirmed.failure!);
      final source = confirmed.data!['sourceGenerationRef']! as Map;

      final finalized = await _command(<String, Object?>{
        'schemaVersion': 1,
        'commandType': 'finalizeAsset',
        'idempotencyKey': '${request.intentId}:finalize',
        'payload': <String, Object?>{
          'assetId': assetId,
          'expectedAssetRevision': confirmed.data!['revision']! as int,
          'sourceProviderGeneration': source['providerGeneration']! as String,
          'expectedSha256': sha256Hex,
          'expectedByteLength': request.bytes.length,
        },
      });
      if (finalized.failure != null) return _rejected(finalized.failure!);
      if (finalized.data!['lifecycle'] != 'ready') {
        return _rejected('invalid_state');
      }
      return MediaUploadResult(
        MediaUploadOutcome.ready,
        assetId: assetId,
        assetRevision: finalized.data!['revision']! as int,
      );
    } on MediaTransportFailure {
      return const MediaUploadResult(MediaUploadOutcome.unavailable);
    }
  }

  Future<({Map<String, Object?>? data, String? failure})> _command(
    Map<String, Object?> command,
  ) async {
    final result = await _port.invoke('mediaCommandV1', command);
    if (result['kind'] == 'succeeded') {
      return (
        data: Map<String, Object?>.from(result['data']! as Map),
        failure: null,
      );
    }
    return (
      data: null,
      failure: result['code'] as String? ?? 'invalid_contract',
    );
  }

  MediaUploadResult _rejected(String code) =>
      MediaUploadResult(MediaUploadOutcome.rejected, failureCode: code);
}
