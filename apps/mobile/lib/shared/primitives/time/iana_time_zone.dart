/// A structural, case-preserving IANA zone identifier.
///
/// Existence and alias resolution require the existing TZDB data adapter;
/// parsing this value alone does not establish a known or enabled zone.
class IanaTimeZone {
  factory IanaTimeZone.parse(String source) {
    if (RegExp(
          r'^[A-Za-z][A-Za-z0-9_+-]*(?:/[A-Za-z0-9_+-]+)*$',
        ).stringMatch(source) !=
        source) {
      throw FormatException('Invalid IANA zone identifier syntax', source);
    }
    return IanaTimeZone._(source);
  }

  const IanaTimeZone._(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      other is IanaTimeZone && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}
