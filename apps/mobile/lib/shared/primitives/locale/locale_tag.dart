/// Language, optional script and optional region from the BCP 47 subset.
///
/// This identity neither enables translations nor implies a market/currency.
/// Unsupported variants and extensions fail instead of being discarded.
class LocaleTag {
  factory LocaleTag.parse(String source) {
    final match = RegExp(
      r'^([A-Za-z]{2,3})(?:-([A-Za-z]{4}))?(?:-([A-Za-z]{2}|[0-9]{3}))?$',
    ).firstMatch(source);
    if (match == null || match.end != source.length) {
      throw FormatException('Unsupported locale tag syntax', source);
    }
    final language = match.group(1)!.toLowerCase();
    final script = match.group(2);
    final region = match.group(3);
    return LocaleTag._(
      [
        language,
        if (script != null)
          '${script[0].toUpperCase()}${script.substring(1).toLowerCase()}',
        if (region != null) region.toUpperCase(),
      ].join('-'),
    );
  }

  const LocaleTag._(this.value);
  final String value;

  @override
  bool operator ==(Object other) => other is LocaleTag && value == other.value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}
