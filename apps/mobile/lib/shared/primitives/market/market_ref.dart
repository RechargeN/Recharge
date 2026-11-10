/// A stable market ID, not a city display name or an enabled-market grant.
///
/// Registry lookup and legacy city-name resolution remain outside this value.
class MarketRef {
  factory MarketRef.parse(String source) {
    if (RegExp(r'^[a-z][a-z0-9]*(?:[-_][a-z0-9]+)*$').stringMatch(source) !=
        source) {
      throw FormatException('Expected a stable lowercase market ID', source);
    }
    return MarketRef._(source);
  }

  const MarketRef._(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is MarketRef && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}
