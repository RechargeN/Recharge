import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:recharge/shared/primitives/money/money_parser.dart';

void main() {
  test('parses EUR decimal input without binary floating-point', () {
    final MoneyParseResult result = MoneyParser.parse(
      '0.29',
      currency: CurrencyCode.eur,
    );

    expect(result, isA<MoneyParseSuccess>());
    expect((result as MoneyParseSuccess).money.minorUnits, 29);
  });

  test('uses an explicit locale decimal separator', () {
    final MoneyParseResult result = MoneyParser.parse(
      '1 234,50',
      currency: CurrencyCode.eur,
      localeTag: 'lv-LV',
    );

    expect((result as MoneyParseSuccess).money.minorUnits, 123450);
  });

  test('fails closed on excess scale instead of rounding', () {
    final MoneyParseResult result = MoneyParser.parse(
      '12.345',
      currency: CurrencyCode.eur,
    );

    expect(result, isA<MoneyParseFailure>());
    expect(
      (result as MoneyParseFailure).code,
      MoneyParseFailureCode.excessFractionDigits,
    );
  });

  test('honors zero- and three-decimal currencies', () {
    expect(
      (MoneyParser.parse('12', currency: CurrencyCode.jpy) as MoneyParseSuccess)
          .money
          .minorUnits,
      12,
    );
    expect(
      (MoneyParser.parse('12.345', currency: CurrencyCode.bhd)
              as MoneyParseSuccess)
          .money
          .minorUnits,
      12345,
    );
  });

  test('fails closed on unknown metadata and portable overflow', () {
    expect(
      (MoneyParser.parse('1', currency: CurrencyCode.parse('XYZ'))
              as MoneyParseFailure)
          .code,
      MoneyParseFailureCode.unknownCurrency,
    );
    expect(
      (MoneyParser.parse('90071992547409.92', currency: CurrencyCode.eur)
              as MoneyParseFailure)
          .code,
      MoneyParseFailureCode.overflow,
    );
  });
}
