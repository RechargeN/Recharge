import 'currency_code.dart';
import 'currency_metadata.dart';
import 'money.dart';
import 'money_parse_result.dart';

/// Exact decimal parser. It never converts user input through [double].
abstract final class MoneyParser {
  static MoneyParseResult parse(
    String input, {
    required CurrencyCode currency,
    String localeTag = 'en',
  }) {
    final CurrencyMetadata? metadata = CurrencyMetadata.tryFor(currency);
    if (metadata == null) {
      return MoneyParseFailure(
        code: MoneyParseFailureCode.unknownCurrency,
        message: 'No decimal metadata for ${currency.value}.',
      );
    }

    String value = input
        .trim()
        .replaceAll('\u00a0', '')
        .replaceAll('\u202f', '')
        .replaceAll(' ', '');
    if (value.isEmpty) {
      return const MoneyParseFailure(
        code: MoneyParseFailureCode.empty,
        message: 'Amount is empty.',
      );
    }

    final String decimalSeparator = _usesDecimalComma(localeTag) ? ',' : '.';
    final String otherSeparator = decimalSeparator == ',' ? '.' : ',';
    if (value.contains(otherSeparator)) {
      return const MoneyParseFailure(
        code: MoneyParseFailureCode.invalidFormat,
        message: 'Amount uses an unexpected decimal separator.',
      );
    }

    final bool negative = value.startsWith('-');
    if (value.startsWith('-') || value.startsWith('+')) {
      value = value.substring(1);
    }
    final List<String> parts = value.split(decimalSeparator);
    if (parts.length > 2 ||
        parts.first.isEmpty ||
        !_digitsOnly(parts.first) ||
        (parts.length == 2 &&
            (parts.last.isEmpty || !_digitsOnly(parts.last)))) {
      return const MoneyParseFailure(
        code: MoneyParseFailureCode.invalidFormat,
        message: 'Amount is not a valid decimal number.',
      );
    }

    final String fraction = parts.length == 2 ? parts.last : '';
    if (fraction.length > metadata.minorUnitExponent) {
      return MoneyParseFailure(
        code: MoneyParseFailureCode.excessFractionDigits,
        message:
            '${currency.value} supports at most '
            '${metadata.minorUnitExponent} fraction digits.',
      );
    }

    final String paddedFraction = fraction.padRight(
      metadata.minorUnitExponent,
      '0',
    );
    final BigInt scale = BigInt.from(10).pow(metadata.minorUnitExponent);
    BigInt minorUnits = BigInt.parse(parts.first) * scale;
    if (paddedFraction.isNotEmpty) {
      minorUnits += BigInt.parse(paddedFraction);
    }
    if (negative) {
      minorUnits = -minorUnits;
    }
    if (minorUnits.abs() > BigInt.from(Money.maxSafeMinorUnits)) {
      return const MoneyParseFailure(
        code: MoneyParseFailureCode.overflow,
        message: 'Amount exceeds the portable integer range.',
      );
    }

    return MoneyParseSuccess(
      Money(minorUnits: minorUnits.toInt(), currency: currency),
    );
  }

  static MoneyParseResult parseLegacyNumber(
    num value, {
    required CurrencyCode currency,
  }) => parse(value.toString(), currency: currency);

  static bool _digitsOnly(String value) => RegExp(r'^\d+$').hasMatch(value);

  static bool _usesDecimalComma(String localeTag) {
    final String language = localeTag
        .trim()
        .toLowerCase()
        .split(RegExp('[-_]'))
        .first;
    return const <String>{'lv', 'lt', 'et', 'ru'}.contains(language);
  }
}
