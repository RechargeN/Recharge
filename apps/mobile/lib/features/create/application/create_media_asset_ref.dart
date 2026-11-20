import 'dart:convert';

import 'package:crypto/crypto.dart';

/// MEDIA-PICK-02: a draft photo field that no longer points at a local copy
/// but at the server Media asset it became (`asset:<assetId>`). The value is
/// written only after the server reported the asset `ready` and the content
/// draft was saved with it; the server still checks ownership on every use.
const String promotedMediaPrefix = 'asset:';

final RegExp _assetIdShape = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// The asset id of a promoted field value, null for anything else (a local
/// copy, a URL, an empty field).
String? promotedMediaAssetId(String ref) {
  if (!ref.startsWith(promotedMediaPrefix)) return null;
  final String id = ref.substring(promotedMediaPrefix.length);
  return _assetIdShape.hasMatch(id) ? id : null;
}

/// The field value for [assetId]. Throws on an id the server never issues.
String promotedMediaRef(String assetId) {
  if (!_assetIdShape.hasMatch(assetId)) {
    throw ArgumentError.value(assetId, 'assetId', 'invalid asset id');
  }
  return '$promotedMediaPrefix$assetId';
}

/// A stable stand-in for the photo digest of a promoted field: there are no
/// local bytes any more, and the same value always maps to the same digest.
String promotedMediaDigest(String ref) =>
    sha256.convert(utf8.encode(ref)).toString();
