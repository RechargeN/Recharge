/// A provider-neutral geographic coordinate in WGS 84 decimal degrees.
///
/// Elevation is optional because many map and routing sources only provide a
/// two-dimensional coordinate.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.elevationMeters,
  });

  final double latitude;
  final double longitude;
  final double? elevationMeters;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      (elevationMeters == null || elevationMeters!.isFinite);

  GeoPoint validated() {
    if (!isValid) {
      throw ArgumentError.value(
        this,
        'point',
        'Latitude/longitude must be in range and elevation must be finite.',
      );
    }
    return this;
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'latitude': latitude,
    'longitude': longitude,
    if (elevationMeters != null) 'elevationMeters': elevationMeters,
  };

  factory GeoPoint.fromMap(Map<String, Object?> map) => GeoPoint(
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    elevationMeters: (map['elevationMeters'] as num?)?.toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          elevationMeters == other.elevationMeters;

  @override
  int get hashCode => Object.hash(latitude, longitude, elevationMeters);

  @override
  String toString() =>
      'GeoPoint(latitude: $latitude, longitude: $longitude, '
      'elevationMeters: $elevationMeters)';
}
