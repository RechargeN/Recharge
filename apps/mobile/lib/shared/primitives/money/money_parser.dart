import 'currency_code.dart';
import 'currency_metadata.dart';
import 'money.dart';
import 'money_parse_result.dart';

/// Exact decimal text input. No implicit locale or currency inference.
class MoneyParser {
  MoneyParser({CurrencyMetadataRegistry? metadata})
    : metadata = metadata ?? CurrencyMetadataRegistry.eurOnly;
  final CurrencyMetadataRegistry metadata;
  MoneyParseResult parse(
    String text, {
    required CurrencyCode currency,
    required String locale,
  }) {
    final currencyMetadata = metadata.lookup(currency);
    if (currencyMetadata == null) {
      return const MoneyParseResult.failure(MoneyParseError.unknownCurrency);
    }
    final language = locale.replaceAll('_', '-').toLowerCase().split('-').first;
    if (!const ['en', 'ru', 'lv'].contains(language)) {
      return const MoneyParseResult.failure(MoneyParseError.unsupportedLocale);
    }
    var source = text.trim();
    if (source.isEmpty) {
      return const MoneyParseResult.failure(MoneyParseError.empty);
    }
    final negative = source.startsWith('-');
    if (negative || source.startsWith('+')) source = source.substring(1);
    final decimal = language == 'en' ? '.' : ',';
    final grouping = language == 'en' ? ',' : ' ';
    if (language != 'en') {
      source = source.replaceAll('\u00a0', ' ').replaceAll('\u202f', ' ');
    }
    final parts = source.split(decimal);
    if (parts.length > 2 || parts.first.isEmpty) {
      return const MoneyParseResult.failure(MoneyParseError.invalidSyntax);
    }
    var whole = parts.first;
    if (whole.contains(grouping)) {
      final groups = whole.split(grouping);
      if (!RegExp(r'^[0-9]{1,3}$').hasMatch(groups.first) ||
          groups
              .skip(1)
              .any((value) => !RegExp(r'^[0-9]{3}$').hasMatch(value))) {
        return const MoneyParseResult.failure(MoneyParseError.invalidSyntax);
      }
      whole = groups.join();
    }
    final fraction = parts.length == 2 ? parts.last : '';
    if (!RegExp(r'^[0-9]+$').hasMatch(whole) ||
        (parts.length == 2 && !RegExp(r'^[0-9]+$').hasMatch(fraction))) {
      return const MoneyParseResult.failure(MoneyParseError.invalidSyntax);
    }
    if (fraction.length > currencyMetadata.exponent) {
      return const MoneyParseResult.failure(
        MoneyParseError.excessiveFractionDigits,
      );
    }
    final digits = whole + fraction.padRight(currencyMetadata.exponent, '0');
    final minor = BigInt.parse(digits) * (negative ? -BigInt.one : BigInt.one);
    final max = BigInt.from(Money.maxSafeMinorUnits);
    if (minor < -max || minor > max) {
      return const MoneyParseResult.failure(MoneyParseError.outOfRange);
    }
    return MoneyParseResult.success(
      Money(minorUnits: minor.toInt(), currency: currency),
    );
  }
}
