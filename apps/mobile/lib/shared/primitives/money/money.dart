import 'dart:math' as math;

/// Currency-safe value object used by mobile domain and persistence models.
///
/// Monetary values are stored only as integer minor units. Currency is always
/// explicit and is never inferred from a market, locale or device setting.
final class Money implements Comparable<Money> {
  const Money({required this.minorUnits, required this.currencyCode})
    : assert(minorUnits >= 0),
      assert(currencyCode.length == 3);

  final int minorUnits;
  final String currencyCode;

  static String _normalizeCurrency(String value) {
    final String normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'currencyCode',
        'must be ISO 4217 alpha-3',
      );
    }
    return normalized;
  }

  static Money zero(String currencyCode) =>
      Money(minorUnits: 0, currencyCode: _normalizeCurrency(currencyCode));

  static Money? tryParseMajor(
    String input, {
    required String currencyCode,
    int scale = 2,
  }) {
    if (scale < 0 || scale > 6) {
      throw ArgumentError.value(scale, 'scale', 'must be between 0 and 6');
    }
    final String normalized = input.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized)) {
      return null;
    }
    final List<String> parts = normalized.split('.');
    final String fraction = parts.length == 1 ? '' : parts[1];
    if (fraction.length > scale) {
      return null;
    }
    final int factor = math.pow(10, scale).toInt();
    final int whole = int.parse(parts[0]);
    final int fractionMinor = fraction.isEmpty
        ? 0
        : int.parse(fraction.padRight(scale, '0'));
    return Money(
      minorUnits: whole * factor + fractionMinor,
      currencyCode: _normalizeCurrency(currencyCode),
    );
  }

  /// Compatibility reader for versioned local data only.
  ///
  /// Never use this conversion at a backend boundary. New persistence writes
  /// must use [toJson] and integer `minorUnits`.
  static Money fromLegacyMajor(
    num value, {
    required String currencyCode,
    int scale = 2,
  }) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'must be finite and non-negative',
      );
    }
    final int factor = math.pow(10, scale).toInt();
    return Money(
      minorUnits: (value * factor).round(),
      currencyCode: _normalizeCurrency(currencyCode),
    );
  }

  static Money? fromJsonOrNull(Object? value, {String? legacyCurrencyCode}) {
    if (value == null) {
      return null;
    }
    if (value is Map<Object?, Object?>) {
      final Object? minorUnits = value['minorUnits'];
      final Object? currencyCode = value['currencyCode'];
      if (minorUnits is! int || minorUnits < 0 || currencyCode is! String) {
        return null;
      }
      try {
        return Money(
          minorUnits: minorUnits,
          currencyCode: _normalizeCurrency(currencyCode),
        );
      } on Object {
        return null;
      }
    }
    if (value is num && legacyCurrencyCode != null) {
      try {
        return Money.fromLegacyMajor(value, currencyCode: legacyCurrencyCode);
      } on ArgumentError {
        return null;
      }
    }
    return null;
  }

  Map<String, Object> toJson() => <String, Object>{
    'minorUnits': minorUnits,
    'currencyCode': currencyCode,
  };

  String formatMajor({int scale = 2, bool trimTrailingZeros = true}) {
    if (scale < 0 || scale > 6) {
      throw ArgumentError.value(scale, 'scale', 'must be between 0 and 6');
    }
    if (scale == 0) {
      return '${(minorUnits + 50) ~/ 100}';
    }
    final int requestedFactor = math.pow(10, scale).toInt();
    final int scaled = scale >= 2
        ? minorUnits * math.pow(10, scale - 2).toInt()
        : (minorUnits + 5) ~/ 10;
    final int whole = scaled ~/ requestedFactor;
    final int fraction = scaled.remainder(requestedFactor);
    String fractionText = fraction.toString().padLeft(scale, '0');
    if (trimTrailingZeros) {
      fractionText = fractionText.replaceFirst(RegExp(r'0+$'), '');
    }
    return fractionText.isEmpty ? '$whole' : '$whole.$fractionText';
  }

  /// Presentation compatibility without converting storage to floating point.
  String toStringAsFixed(int fractionDigits) =>
      formatMajor(scale: fractionDigits, trimTrailingZeros: false);

  /// Rounded major units for stable labels and telemetry dimensions only.
  int round({int scale = 2}) {
    final int factor = math.pow(10, scale).toInt();
    return (minorUnits + factor ~/ 2) ~/ factor;
  }

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(
      minorUnits: minorUnits + other.minorUnits,
      currencyCode: currencyCode,
    );
  }

  void _requireSameCurrency(Money other) {
    if (currencyCode != other.currencyCode) {
      throw StateError('Cannot combine different currencies');
    }
  }

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  @override
  String toString() => '${formatMajor()} $currencyCode';
}
