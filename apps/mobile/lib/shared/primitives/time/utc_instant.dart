/// An explicit UTC instant. Storage keys and schemas belong to data adapters.
class UtcInstant implements Comparable<UtcInstant> {
  /// Parses explicit UTC text without normalizing invalid calendar components
  /// or discarding precision. Offsets and zone-less wall times are not UTC text.
  factory UtcInstant.parse(String source) {
    final match = _utcText.firstMatch(source);
    if (match == null || match.end != source.length) {
      throw FormatException('Expected an explicit UTC timestamp', source);
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final hour = int.parse(match[4]!);
    final minute = int.parse(match[5]!);
    final second = int.parse(match[6]!);
    final fraction = (match[7] ?? '').padRight(6, '0');
    final microseconds = int.parse(fraction);
    final DateTime value;
    try {
      value = DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
        microseconds ~/ 1000,
        microseconds % 1000,
      );
    } on ArgumentError {
      throw FormatException('UTC timestamp is out of range', source);
    }
    if (value.year != year ||
        value.month != month ||
        value.day != day ||
        value.hour != hour ||
        value.minute != minute ||
        value.second != second ||
        value.millisecond * 1000 + value.microsecond != microseconds) {
      throw FormatException('Invalid UTC calendar or time component', source);
    }
    return UtcInstant._(value);
  }

  static final RegExp _utcText = RegExp(
    r'^([0-9]{4}|-[0-9]{4}|[+-][0-9]{6})-([0-9]{2})-([0-9]{2})T'
    r'([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.([0-9]{1,6}))?Z$',
  );

  factory UtcInstant(DateTime value) {
    if (!value.isUtc) {
      throw ArgumentError.value(
        value,
        'value',
        'An explicit UTC value is required',
      );
    }
    return UtcInstant._(value);
  }

  const UtcInstant._(this.value);
  final DateTime value;

  @override
  int compareTo(UtcInstant other) => value.compareTo(other.value);
  @override
  bool operator ==(Object other) => other is UtcInstant && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value.toIso8601String();
}
