import 'dart:math' as math;

import 'geo_point.dart';

/// Versioned settings for the encoded-polyline representation.
class GeometryEncodingPolicy {
  const GeometryEncodingPolicy({this.precision = 5});

  static const GeometryEncodingPolicy standard = GeometryEncodingPolicy();
  static const GeometryEncodingPolicy highPrecision = GeometryEncodingPolicy(
    precision: 6,
  );

  final int precision;

  bool get isValid => precision >= 0 && precision <= 8;

  int get scale {
    if (!isValid) {
      throw RangeError.range(precision, 0, 8, 'precision');
    }
    return math.pow(10, precision).toInt();
  }

  String get id => 'encoded-polyline-v1-p$precision';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeometryEncodingPolicy && precision == other.precision;

  @override
  int get hashCode => precision.hashCode;
}

/// Google encoded-polyline compatible encoding without a map-provider
/// dependency.
abstract final class GeometryEncoding {
  static String encode(
    Iterable<GeoPoint> points, {
    GeometryEncodingPolicy policy = GeometryEncodingPolicy.standard,
  }) {
    final scale = policy.scale;
    final output = StringBuffer();
    var previousLatitude = 0;
    var previousLongitude = 0;

    for (final point in points) {
      point.validated();
      final latitude = (point.latitude * scale).round();
      final longitude = (point.longitude * scale).round();
      _encodeSigned(latitude - previousLatitude, output);
      _encodeSigned(longitude - previousLongitude, output);
      previousLatitude = latitude;
      previousLongitude = longitude;
    }

    return output.toString();
  }

  static List<GeoPoint> decode(
    String encoded, {
    GeometryEncodingPolicy policy = GeometryEncodingPolicy.standard,
  }) {
    final scale = policy.scale;
    final points = <GeoPoint>[];
    var cursor = 0;
    var latitude = 0;
    var longitude = 0;

    while (cursor < encoded.length) {
      final latitudeValue = _decodeSigned(encoded, cursor);
      cursor = latitudeValue.nextCursor;
      final longitudeValue = _decodeSigned(encoded, cursor);
      cursor = longitudeValue.nextCursor;
      latitude += latitudeValue.value;
      longitude += longitudeValue.value;

      final point = GeoPoint(
        latitude: latitude / scale,
        longitude: longitude / scale,
      );
      if (!point.isValid) {
        throw const FormatException(
          'Encoded geometry contains an invalid coordinate.',
        );
      }
      points.add(point);
    }

    return List<GeoPoint>.unmodifiable(points);
  }

  static void _encodeSigned(int value, StringBuffer output) {
    var remaining = value < 0 ? ~(value << 1) : value << 1;
    while (remaining >= 0x20) {
      output.writeCharCode((0x20 | (remaining & 0x1f)) + 63);
      remaining >>= 5;
    }
    output.writeCharCode(remaining + 63);
  }

  static _DecodedValue _decodeSigned(String encoded, int startCursor) {
    var cursor = startCursor;
    var result = 0;
    var shift = 0;

    while (true) {
      if (cursor >= encoded.length) {
        throw const FormatException('Encoded geometry ended unexpectedly.');
      }

      final codeUnit = encoded.codeUnitAt(cursor++);
      if (codeUnit < 63 || codeUnit > 126) {
        throw const FormatException(
          'Encoded geometry contains an unsupported character.',
        );
      }

      final chunk = codeUnit - 63;
      result |= (chunk & 0x1f) << shift;
      if (chunk < 0x20) {
        break;
      }

      shift += 5;
      if (shift > 60) {
        throw const FormatException('Encoded geometry value is too large.');
      }
    }

    final value = (result & 1) == 1 ? ~(result >> 1) : result >> 1;
    return _DecodedValue(value: value, nextCursor: cursor);
  }
}

class _DecodedValue {
  const _DecodedValue({required this.value, required this.nextCursor});

  final int value;
  final int nextCursor;
}
