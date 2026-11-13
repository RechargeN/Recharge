import '../entities/content_validation_violation.dart';

/// Server publication readiness (M1 stage 3, owner decisions Р-09 and 3-Б).
///
/// The server keeps its rules; these are exact ports of the static rules the
/// local Create checks did not cover, run on the very body the mapper sends.
/// They return the same public code and field path the server would
/// (`validation_details.ts`), so the Create form and the publication test
/// path can explain a refusal before anything is sent. Rules that depend on
/// the server's time, policy revision or Catalog stay with the server and
/// reach the client through its public validation details.
///
/// Lengths count Unicode code points after trimming and collapsing
/// whitespace, as the server does (`normalizedLength`).

const String _body = '/body';

List<ContentValidationViolation> placeServerReadiness(
  Map<String, Object?> body, {
  required String marketCurrencyCode,
}) {
  final _Collector issues = _Collector();
  issues.require(
    _isText(body['shortDescription'], 20, 180),
    'place.shortDescription',
    '$_body/shortDescription',
  );

  final Object? hours = body['hours'];
  if (issues.require(hours is Map, 'place.hours', '$_body/hours')) {
    final Object? mode = (hours! as Map)['mode'];
    if (mode == 'seasonal') {
      issues.add('place.hours.mode_unsupported:seasonal', '$_body/hours/mode');
    } else {
      issues.require(
        const <String>{'regular', 'alwaysOpen', 'unknown'}.contains(mode),
        'place.hours.mode',
        '$_body/hours/mode',
      );
    }
  }

  final Object? pricing = body['pricing'];
  if (pricing is Map) {
    final bool entryOk = issues.require(
      const <String>{
        'free',
        'paid',
        'mixed',
        'notApplicable',
        'unknown',
      }.contains(pricing['entryType']),
      'place.pricing.entryType',
      '$_body/pricing/entryType',
    );
    if (entryOk) {
      issues.require(
        pricing['currencyCode'] == marketCurrencyCode,
        'place.pricing.currencyCode',
        '$_body/pricing/currencyCode',
      );
    }
  }

  final Object? contacts = body['contacts'];
  if (contacts is Map && contacts['phone'] != null) {
    issues.require(
      _isPhone(contacts['phone']),
      'place.contacts.phone',
      '$_body/contacts/phone',
    );
  }

  final Object? media = body['media'];
  issues.require(
    media is Map && _isMediaRef(media['coverImage']),
    'place.media.cover_missing',
    '$_body/media/coverImage',
  );

  final Object? provenance = body['provenance'];
  final String? expectedSource = const <String, String>{
    'owner': 'ownerSubmission',
    'staff': 'staffSubmission',
    'visitor': 'creatorSubmission',
    'curator': 'creatorSubmission',
  }[body['relationshipToPlace']];
  if (provenance is Map && expectedSource != null) {
    issues.require(
      provenance['sourceType'] == expectedSource,
      'place.provenance.sourceType',
      '$_body/provenance/sourceType',
    );
  }
  return issues.result;
}

/// The TEST-ONLY Emulator Rental policy the server applies
/// (`rental_reference_policy.json`, base values). A test keeps it equal to the
/// shared fixture; it is not an accepted market policy.
final class RentalServerPolicy {
  const RentalServerPolicy({
    required this.policyVersion,
    required this.coverageFreshnessDays,
    required this.minApproximatePrecisionMeters,
    required this.maxDeliveryRadiusKm,
  });

  final String policyVersion;
  final int coverageFreshnessDays;
  final int minApproximatePrecisionMeters;
  final num maxDeliveryRadiusKm;

  static const RentalServerPolicy emulatorTestOnly = RentalServerPolicy(
    policyVersion: '1.0',
    coverageFreshnessDays: 7,
    minApproximatePrecisionMeters: 500,
    maxDeliveryRadiusKm: 50,
  );
}

List<ContentValidationViolation> rentalServerReadiness(
  Map<String, Object?> body, {
  required DateTime nowUtc,
  RentalServerPolicy policy = RentalServerPolicy.emulatorTestOnly,
}) {
  final _Collector issues = _Collector();
  final Object? media = body['mediaRefs'];
  issues.require(
    media is List &&
        media.isNotEmpty &&
        media.every((Object? id) => id is String),
    'rental.cover_required',
    '$_body/mediaRefs',
  );
  issues.require(
    _isText(body['subcategoryId'], 1, 64),
    'rental.subcategory_required',
    '$_body/subcategoryId',
  );

  final Object? availability = body['availability'];
  if (availability is Map && availability['coverage'] is Map) {
    final Object? confirmed =
        (availability['coverage'] as Map)['confirmedAtUtc'];
    final DateTime? confirmedAt = confirmed is String
        ? DateTime.tryParse(confirmed)
        : null;
    if (confirmedAt != null && !confirmedAt.isAfter(nowUtc)) {
      issues.require(
        nowUtc.difference(confirmedAt) <=
            Duration(days: policy.coverageFreshnessDays),
        'rental.coverage_stale',
        '$_body/availability/coverage/confirmedAtUtc',
      );
    }
  }

  final Object? handover = body['handover'];
  if (handover is Map) {
    final Object? precision = handover['publicGeoPrecisionMeters'];
    if (handover['disclosure'] == 'approximate_area' &&
        precision is int &&
        precision >= 1 &&
        precision <= 100000) {
      issues.require(
        precision >= policy.minApproximatePrecisionMeters,
        'rental.handover_precision_too_fine',
        '$_body/handover/publicGeoPrecisionMeters',
      );
    }
    if (handover['deliveryAvailable'] == true) {
      final Object? radius = handover['deliveryRadiusKm'];
      issues.require(
        radius is num &&
            radius.isFinite &&
            radius > 0 &&
            radius <= policy.maxDeliveryRadiusKm,
        'rental.delivery_radius',
        '$_body/handover/deliveryRadiusKm',
      );
    }
  }

  final Object? fulfillment = body['fulfillment'];
  if (fulfillment is Map) {
    final Uri? url = _safeHttpsUrl(fulfillment['externalBookingUrl']);
    if (url != null) {
      issues.require(
        url.fragment.isEmpty,
        'rental.external_url_fragment',
        '$_body/fulfillment/externalBookingUrl',
      );
    }
  }

  final Object? attestation = body['attestation'];
  if (attestation is Map && attestation['policyVersion'] is String) {
    issues.require(
      attestation['policyVersion'] == policy.policyVersion,
      'rental.attestation_stale_policy',
      '$_body/attestation/policyVersion',
    );
  }
  return issues.result;
}

/// [subcategoryApplies] answers from the app's canonical taxonomy whether the
/// subcategory belongs to the category and applies to Collection.
List<ContentValidationViolation> collectionServerReadiness(
  Map<String, Object?> body, {
  required bool Function(String categoryId, String subcategoryId)
  subcategoryApplies,
}) {
  final _Collector issues = _Collector();
  issues.require(
    _isText(body['shortDescription'], 1, 300),
    'collection.short_description_required',
    '$_body/shortDescription',
  );
  final Object? media = body['media'];
  issues.require(
    media is Map && _isMediaRef(media['coverImage']),
    'collection.cover_image_required',
    '$_body/media/coverImage',
  );
  final Object? category = body['categoryId'];
  final Object? subcategory = body['subcategoryId'];
  if (category is String && subcategory is String && subcategory.isNotEmpty) {
    issues.require(
      subcategoryApplies(category, subcategory),
      'collection.subcategory_not_applicable',
      '$_body/subcategoryId',
    );
  }
  final Object? items = body['items'];
  if (items is List) {
    bool localRef = false;
    for (final Object? item in items) {
      final Object? ref = item is Map ? item['ref'] : null;
      final Object? objectId = ref is Map ? ref['objectId'] : null;
      if (objectId is String && objectId.startsWith('loc_')) localRef = true;
    }
    if (localRef) {
      issues.add('collection.item_ref_invalid', '$_body/items');
      issues.add('collection.local_id_unreplaced', _body);
    }
  }
  return issues.result;
}

final class _Collector {
  final Map<String, ContentValidationViolation> _items =
      <String, ContentValidationViolation>{};

  bool require(bool ok, String code, String fieldPath) {
    if (!ok) add(code, fieldPath);
    return ok;
  }

  void add(String code, String fieldPath) {
    // The schema's public code: no suffix, snake_case (as `publicCode` on the
    // server, e.g. `place.pricing.entryType` → `place.pricing.entry_type`).
    final String base = code.contains(':')
        ? code.substring(0, code.indexOf(':'))
        : code;
    final String publicCode = base.replaceAllMapped(
      RegExp('[A-Z]'),
      (Match m) => '_${m[0]!.toLowerCase()}',
    );
    _items.putIfAbsent(
      '$publicCode:$fieldPath',
      () => ContentValidationViolation(code: publicCode, fieldPath: fieldPath),
    );
  }

  List<ContentValidationViolation> get result =>
      List<ContentValidationViolation>.unmodifiable(_items.values);
}

int _normalizedLength(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').runes.length;

bool _isText(Object? value, int min, int max) {
  if (value is! String) return false;
  final int length = _normalizedLength(value);
  return length >= min && length <= max;
}

bool _isMediaRef(Object? value) =>
    value is Map && _isText(value['mediaId'], 1, 128);

bool _isPhone(Object? value) {
  if (value is! String || value.length > 32) return false;
  if (!RegExp(r'^\+?[\d\s().-]+$').hasMatch(value)) return false;
  final int digits = value.replaceAll(RegExp(r'\D'), '').length;
  return digits >= 7 && digits <= 15;
}

Uri? _safeHttpsUrl(Object? value) {
  if (value is! String || value.length < 12 || value.length > 2048) {
    return null;
  }
  final Uri? uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}
