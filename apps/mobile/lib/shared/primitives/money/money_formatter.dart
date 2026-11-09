import 'currency_metadata.dart';
import 'money.dart';
import 'money_parse_result.dart';

class MoneyFormatException implements Exception {
  const MoneyFormatException(this.code);
  final MoneyParseError code;
}

class MoneyFormatter {
  MoneyFormatter({CurrencyMetadataRegistry? metadata})
    : metadata = metadata ?? CurrencyMetadataRegistry.eurOnly;
  final CurrencyMetadataRegistry metadata;
  String optionalDecimal(
    Money? value, {
    required String locale,
    String absent = '',
  }) => value == null ? absent : decimal(value, locale: locale);

  String decimal(
    Money value, {
    required String locale,
    bool groupThousands = false,
    bool omitZeroFraction = false,
  }) {
    final currencyMetadata = metadata.lookup(value.currency);
    if (currencyMetadata == null) {
      throw const MoneyFormatException(MoneyParseError.unknownCurrency);
    }
    final language = locale.replaceAll('_', '-').toLowerCase().split('-').first;
    if (!const ['en', 'ru', 'lv'].contains(language)) {
      throw const MoneyFormatException(MoneyParseError.unsupportedLocale);
    }
    final exponent = currencyMetadata.exponent;
    final digits = BigInt.from(
      value.minorUnits,
    ).abs().toString().padLeft(exponent + 1, '0');
    var whole = digits.substring(0, digits.length - exponent);
    if (groupThousands) {
      final groups = <String>[];
      while (whole.length > 3) {
        groups.insert(0, whole.substring(whole.length - 3));
        whole = whole.substring(0, whole.length - 3);
      }
      groups.insert(0, whole);
      whole = groups.join(language == 'en' ? ',' : '\u00a0');
    }
    final fractionDigits = digits.substring(digits.length - exponent);
    final fraction =
        exponent == 0 ||
            (omitZeroFraction && RegExp(r'^0+$').hasMatch(fractionDigits))
        ? ''
        : '${language == 'en' ? '.' : ','}$fractionDigits';
    return '${value.minorUnits < 0 ? '-' : ''}$whole$fraction';
  }
}
