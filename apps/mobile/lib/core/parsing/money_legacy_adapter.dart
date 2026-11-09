import '../../shared/primitives/money/currency_code.dart';
import '../../shared/primitives/money/currency_metadata.dart';
import '../../shared/primitives/money/money.dart';
import '../../shared/primitives/money/money_parse_result.dart';
import '../../shared/primitives/money/money_parser.dart';

/// Used by data mappers only. Reads never mutate storage or infer currency.
class MoneyLegacyAdapter {
  MoneyLegacyAdapter({CurrencyMetadataRegistry? metadata})
    : _parser = MoneyParser(metadata: metadata);
  final MoneyParser _parser;

  Money? readOptional({
    required bool hasCanonicalMinorUnits,
    Object? canonicalMinorUnits,
    Object? legacyMajorAmount,
    required String? currencyCode,
  }) {
    // Explicit canonical null means absent, never a legacy fallback.
    if (hasCanonicalMinorUnits
        ? canonicalMinorUnits == null
        : legacyMajorAmount == null) {
      return null;
    }
    CurrencyCode? currency;
    if (currencyCode != null) {
      try {
        currency = CurrencyCode.parse(currencyCode);
      } on FormatException {
        throw const MoneyReadException(MoneyParseError.missingCurrency);
      }
    }
    final result = read(
      hasCanonicalMinorUnits: hasCanonicalMinorUnits,
      canonicalMinorUnits: canonicalMinorUnits,
      legacyMajorAmount: legacyMajorAmount,
      currency: currency,
    );
    if (!result.isSuccess) throw MoneyReadException(result.error!);
    return result.value;
  }

  MoneyParseResult read({
    required bool hasCanonicalMinorUnits,
    Object? canonicalMinorUnits,
    Object? legacyMajorAmount,
    required CurrencyCode? currency,
  }) {
    if (currency == null) {
      return const MoneyParseResult.failure(MoneyParseError.missingCurrency);
    }
    if (_parser.metadata.lookup(currency) == null) {
      return const MoneyParseResult.failure(MoneyParseError.unknownCurrency);
    }
    if (hasCanonicalMinorUnits) {
      if (canonicalMinorUnits is! int) {
        return const MoneyParseResult.failure(
          MoneyParseError.invalidCanonicalValue,
        );
      }
      try {
        return MoneyParseResult.success(
          Money(minorUnits: canonicalMinorUnits, currency: currency),
        );
      } on MoneyArithmeticException {
        return const MoneyParseResult.failure(MoneyParseError.outOfRange);
      }
    }
    if (legacyMajorAmount is! num) {
      return const MoneyParseResult.failure(MoneyParseError.invalidSyntax);
    }
    if (!legacyMajorAmount.isFinite) {
      return const MoneyParseResult.failure(MoneyParseError.nonFiniteLegacy);
    }
    return _parser.parse(
      _expandExponent(legacyMajorAmount.toString()),
      currency: currency,
      locale: 'en',
    );
  }

  static String _expandExponent(String value) {
    final match = RegExp(
      r'^(-?)([0-9]+)(?:\.([0-9]+))?[eE]([+-]?[0-9]+)$',
    ).firstMatch(value);
    if (match == null) return value;
    final sign = match.group(1)!;
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    final digits = whole + fraction;
    final point = whole.length + int.parse(match.group(4)!);
    if (point <= 0) return '${sign}0.${'0' * -point}$digits';
    if (point >= digits.length) {
      return '$sign$digits${'0' * (point - digits.length)}';
    }
    return '$sign${digits.substring(0, point)}.${digits.substring(point)}';
  }
}
