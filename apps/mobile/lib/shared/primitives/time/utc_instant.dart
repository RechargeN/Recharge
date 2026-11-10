/// An explicit UTC instant. Parsing storage formats belongs to data adapters.
class UtcInstant implements Comparable<UtcInstant> {
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
