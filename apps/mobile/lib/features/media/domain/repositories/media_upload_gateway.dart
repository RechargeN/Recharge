import 'dart:typed_data';

/// What the user wants to upload for one Content draft. The bytes are chosen by
/// the caller (a repository fixture today; a picker in B1-device) and the
/// server alone decides whether they are acceptable.
final class MediaUploadRequest {
  const MediaUploadRequest({
    required this.intentId,
    required this.bytes,
    required this.declaredMediaType,
    required this.publisherType,
    required this.publisherId,
    required this.contentId,
    this.marketId = 'LV',
  });

  /// Stable id of this upload intent; every idempotency key derives from it, so
  /// a retry of the same intent can never create a second asset.
  final String intentId;
  final Uint8List bytes;
  final String declaredMediaType;
  final String publisherType;
  final String publisherId;
  final String contentId;
  final String marketId;
}

enum MediaUploadOutcome {
  /// Scanned, processed and ready (orchestration with the fake adapters).
  ready,

  /// The server refused the upload; [MediaUploadResult.failureCode] says why.
  rejected,

  /// No answer: the intent may be retried with the same [MediaUploadRequest].
  unavailable,
}

final class MediaUploadResult {
  const MediaUploadResult(
    this.outcome, {
    this.assetId,
    this.assetRevision,
    this.failureCode,
  });

  final MediaUploadOutcome outcome;
  final String? assetId;
  final int? assetRevision;
  final String? failureCode;
}

abstract interface class MediaUploadGateway {
  /// Creates an upload session, sends the bytes, confirms and finalizes.
  Future<MediaUploadResult> upload(MediaUploadRequest request);
}
