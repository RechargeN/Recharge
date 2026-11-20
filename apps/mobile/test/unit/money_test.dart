import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/shared/primitives/money/money_parser.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:recharge/core/parsing/money_legacy_adapter.dart';

void main() {
  test('Money parses exact decimals and refuses implicit rounding', () {
    final parser = MoneyParser();
    expect(
      parser.parse('12.34', currency: CurrencyCode.eur, locale: 'en').value,
      Money(minorUnits: 1234, currency: CurrencyCode.eur),
    );
    expect(
      parser.parse('12.345', currency: CurrencyCode.eur, locale: 'en').error,
      MoneyParseError.excessiveFractionDigits,
    );
  });
  test('main integer map and pre-Money major units remain readable', () {
    final reader = MoneyLegacyAdapter();
    final expected = Money(minorUnits: 1234, currency: CurrencyCode.eur);
    expect(
      reader.readOptional(
        hasCanonicalMinorUnits: false,
        legacyMajorAmount: {'minorUnits': 1234, 'currencyCode': 'EUR'},
        currencyCode: null,
      ),
      expected,
    );
    expect(
      reader.readOptional(
        hasCanonicalMinorUnits: false,
        legacyMajorAmount: 12.34,
        currencyCode: 'EUR',
      ),
      expected,
    );
    expect(
      () => reader.readOptional(
        hasCanonicalMinorUnits: false,
        legacyMajorAmount: double.nan,
        currencyCode: 'EUR',
      ),
      throwsA(isA<MoneyReadException>()),
    );
  });
  test('canonical null wins and inconsistent map currencies fail closed', () {
    final reader = MoneyLegacyAdapter();
    expect(
      reader.readOptional(
        hasCanonicalMinorUnits: true,
        canonicalMinorUnits: null,
        legacyMajorAmount: 99,
        currencyCode: 'EUR',
      ),
      isNull,
    );
    expect(
      () => reader.readOptional(
        hasCanonicalMinorUnits: false,
        legacyMajorAmount: {'minorUnits': 1234, 'currencyCode': 'USD'},
        currencyCode: 'EUR',
      ),
      throwsA(isA<MoneyReadException>()),
    );
    expect(
      () => reader.readOptional(
        hasCanonicalMinorUnits: false,
        legacyMajorAmount: {'minorUnits': 1.5, 'currencyCode': 'EUR'},
        currencyCode: 'EUR',
      ),
      throwsA(isA<MoneyReadException>()),
    );
  });
  test('signed arithmetic is exact and rejects currency mismatch', () {
    final negative = Money(minorUnits: -1, currency: CurrencyCode.eur);
    expect(
      (negative + Money(minorUnits: 2, currency: CurrencyCode.eur)).minorUnits,
      1,
    );
    final usd = Money(minorUnits: 1, currency: CurrencyCode.parse('USD'));
    expect(() => negative + usd, throwsA(isA<MoneyArithmeticException>()));
    expect(
      () => negative.compareTo(usd),
      throwsA(isA<MoneyArithmeticException>()),
    );
  });
}
