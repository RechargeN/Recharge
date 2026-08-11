import 'geo_point.dart';

/// An axis-aligned WGS 84 bounding box.
///
/// A west longitude greater than the east longitude represents a box that
/// crosses the antimeridian.
class GeoBounds {
  const GeoBounds({required this.southwest, required this.northeast});

  final GeoPoint southwest;
  final GeoPoint northeast;

  double get south => southwest.latitude;
  double get west => southwest.longitude;
  double get north => northeast.latitude;
  double get east => northeast.longitude;

  bool get crossesAntimeridian => west > east;

  bool get isValid => southwest.isValid && northeast.isValid && south <= north;

  GeoBounds validated() {
    if (!isValid) {
      throw ArgumentError.value(
        this,
        'bounds',
        'Bounds require valid coordinates and south <= north.',
      );
    }
    return this;
  }

  bool contains(GeoPoint point) {
    if (!isValid || !point.isValid) {
      return false;
    }

    final withinLatitude = point.latitude >= south && point.latitude <= north;
    final withinLongitude = crossesAntimeridian
        ? point.longitude >= west || point.longitude <= east
        : point.longitude >= west && point.longitude <= east;

    return withinLatitude && withinLongitude;
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'southwest': southwest.toMap(),
    'northeast': northeast.toMap(),
  };

  factory GeoBounds.fromMap(Map<String, Object?> map) => GeoBounds(
    southwest: GeoPoint.fromMap(
      Map<String, Object?>.from(map['southwest']! as Map),
    ),
    northeast: GeoPoint.fromMap(
      Map<String, Object?>.from(map['northeast']! as Map),
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoBounds &&
          southwest == other.southwest &&
          northeast == other.northeast;

  @override
  int get hashCode => Object.hash(southwest, northeast);

  @override
  String toString() =>
      'GeoBounds(southwest: $southwest, northeast: $northeast)';
}
