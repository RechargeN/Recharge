import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/currency_metadata.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:recharge/shared/primitives/money/money_parser.dart';
import 'package:recharge/shared/primitives/money/money_formatter.dart';

void main() {
  final parser = MoneyParser();
  MoneyParseResult parse(String input, [String locale = 'en']) =>
      parser.parse(input, currency: CurrencyCode.eur, locale: locale);
  test('decimal input is exact, signed, and locale-aware', () {
    expect(parse('0.01').value?.minorUnits, 1);
    expect(parse('0.1').value?.minorUnits, 10);
    expect(parse('-1.23').value?.minorUnits, -123);
    expect(parse('+1,234.56').value?.minorUnits, 123456);
    expect(parse('1 234,56', 'ru').value?.minorUnits, 123456);
    expect(parse('1\u00a0234,56', 'lv-LV').value?.minorUnits, 123456);
    expect(parse('1\u202f234,56', 'ru').value?.minorUnits, 123456);
    expect(
      parse('90071992547409.91').value?.minorUnits,
      Money.maxSafeMinorUnits,
    );
    expect(
      parse('-90071992547409.91').value?.minorUnits,
      -Money.maxSafeMinorUnits,
    );
  });
  test(
    'excess scale, malformed grouping, scientific input and locale fail explicitly',
    () {
      for (final value in ['1.005', '1.000', '0.30000000000000004']) {
        expect(parse(value).error, MoneyParseError.excessiveFractionDigits);
      }
      for (final value in [
        '1e2',
        '1,23',
        '1 234.56',
        '.',
        '1.',
        '--1',
        'NaN',
        'Infinity',
      ]) {
        expect(parse(value).error, MoneyParseError.invalidSyntax);
      }
      expect(parse('').error, MoneyParseError.empty);
      expect(parse('1.2', 'de').error, MoneyParseError.unsupportedLocale);
      expect(parse('90071992547409.92').error, MoneyParseError.outOfRange);
      expect(
        parser
            .parse('1', currency: CurrencyCode.parse('USD'), locale: 'en')
            .error,
        MoneyParseError.unknownCurrency,
      );
    },
  );
  test('formatter-parser property across signs and metadata exponents', () {
    for (var exponent = 0; exponent <= 6; exponent++) {
      final metadata = CurrencyMetadataRegistry([
        CurrencyMetadata(code: CurrencyCode.eur, exponent: exponent),
      ]);
      final p = MoneyParser(metadata: metadata);
      final f = MoneyFormatter(metadata: metadata);
      for (final locale in ['en', 'ru', 'lv']) {
        for (var minor = -12503; minor <= 12503; minor += 137) {
          final money = Money(minorUnits: minor, currency: CurrencyCode.eur);
          expect(
            p
                .parse(
                  f.decimal(money, locale: locale, groupThousands: true),
                  currency: money.currency,
                  locale: locale,
                )
                .value,
            money,
          );
        }
      }
    }
  });
}
