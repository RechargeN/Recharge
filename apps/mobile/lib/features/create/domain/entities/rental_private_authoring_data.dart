import '../../../../shared/primitives/geo/geo_point.dart';

/// Local-only authoring data that must never enter the public draft
/// envelope, `RentalListing`, Discover, share, logs or analytics (spec
/// §7.3, AC 12). Stored and read through `RentalPrivateAuthoringRepository`
/// only — never through `CreateRepository`/`create_repository_impl.dart`.
class RentalPrivateAuthoringData {
  const RentalPrivateAuthoringData({
    this.exactPickupAddress,
    this.exactPickupGeo,
    this.handoverInstructions,
    this.inventoryNotesByGroupId = const <String, String>{},
    this.availabilityNotesByBlockId = const <String, String>{},
  });

  final String? exactPickupAddress;
  final GeoPoint? exactPickupGeo;
  final String? handoverInstructions;
  final Map<String, String> inventoryNotesByGroupId;
  final Map<String, String> availabilityNotesByBlockId;

  bool get isEmpty =>
      (exactPickupAddress == null || exactPickupAddress!.trim().isEmpty) &&
      exactPickupGeo == null &&
      (handoverInstructions == null || handoverInstructions!.trim().isEmpty) &&
      inventoryNotesByGroupId.isEmpty &&
      availabilityNotesByBlockId.isEmpty;

  RentalPrivateAuthoringData copyWith({
    String? exactPickupAddress,
    bool clearExactPickupAddress = false,
    GeoPoint? exactPickupGeo,
    bool clearExactPickupGeo = false,
    String? handoverInstructions,
    bool clearHandoverInstructions = false,
    Map<String, String>? inventoryNotesByGroupId,
    Map<String, String>? availabilityNotesByBlockId,
  }) {
    return RentalPrivateAuthoringData(
      exactPickupAddress: clearExactPickupAddress
          ? null
          : (exactPickupAddress ?? this.exactPickupAddress),
      exactPickupGeo: clearExactPickupGeo
          ? null
          : (exactPickupGeo ?? this.exactPickupGeo),
      handoverInstructions: clearHandoverInstructions
          ? null
          : (handoverInstructions ?? this.handoverInstructions),
      inventoryNotesByGroupId:
          inventoryNotesByGroupId ?? this.inventoryNotesByGroupId,
      availabilityNotesByBlockId:
          availabilityNotesByBlockId ?? this.availabilityNotesByBlockId,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (exactPickupAddress != null) 'exactPickupAddress': exactPickupAddress,
    if (exactPickupGeo != null) 'exactPickupGeo': exactPickupGeo!.toMap(),
    if (handoverInstructions != null)
      'handoverInstructions': handoverInstructions,
    'inventoryNotesByGroupId': inventoryNotesByGroupId,
    'availabilityNotesByBlockId': availabilityNotesByBlockId,
  };

  factory RentalPrivateAuthoringData.fromMap(Map<String, Object?> map) {
    final Object? geo = map['exactPickupGeo'];
    return RentalPrivateAuthoringData(
      exactPickupAddress: map['exactPickupAddress'] as String?,
      exactPickupGeo: geo is Map<String, Object?>
          ? GeoPoint.fromMap(geo)
          : geo is Map
          ? GeoPoint.fromMap(Map<String, Object?>.from(geo))
          : null,
      handoverInstructions: map['handoverInstructions'] as String?,
      inventoryNotesByGroupId: _stringMap(map['inventoryNotesByGroupId']),
      availabilityNotesByBlockId: _stringMap(map['availabilityNotesByBlockId']),
    );
  }

  static Map<String, String> _stringMap(Object? raw) {
    if (raw is Map) {
      return raw.map(
        (Object? key, Object? value) =>
            MapEntry<String, String>(key.toString(), value.toString()),
      );
    }
    return const <String, String>{};
  }
}
