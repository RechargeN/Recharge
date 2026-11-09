import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money_parse_result.dart';
import 'package:recharge/core/parsing/money_legacy_adapter.dart';

void main() {
  final adapter = MoneyLegacyAdapter();
  MoneyParseResult legacy(Object? amount) => adapter.read(
    hasCanonicalMinorUnits: false,
    legacyMajorAmount: amount,
    currency: CurrencyCode.eur,
  );
  test('legacy decimal numbers map exactly and canonical presence wins', () {
    expect(legacy(12).value?.minorUnits, 1200);
    expect(legacy(0.1).value?.minorUnits, 10);
    expect(legacy(12.34).value?.minorUnits, 1234);
    expect(legacy(-12.34).value?.minorUnits, -1234);
    expect(
      adapter
          .read(
            hasCanonicalMinorUnits: true,
            canonicalMinorUnits: 17,
            legacyMajorAmount: 42.5,
            currency: CurrencyCode.eur,
          )
          .value
          ?.minorUnits,
      17,
    );
    expect(
      adapter
          .read(
            hasCanonicalMinorUnits: true,
            canonicalMinorUnits: null,
            legacyMajorAmount: 42.5,
            currency: CurrencyCode.eur,
          )
          .error,
      MoneyParseError.invalidCanonicalValue,
    );
    expect(
      adapter
          .read(
            hasCanonicalMinorUnits: true,
            canonicalMinorUnits: 17.0,
            currency: CurrencyCode.eur,
          )
          .error,
      MoneyParseError.invalidCanonicalValue,
    );
  });
  test('no guessed rounding, currency, or binary precision recovery', () {
    expect(legacy(1.005).error, MoneyParseError.excessiveFractionDigits);
    expect(legacy(0.1 + 0.2).error, MoneyParseError.excessiveFractionDigits);
    expect(legacy(1e-7).error, MoneyParseError.excessiveFractionDigits);
    expect(legacy(1e21).error, MoneyParseError.outOfRange);
    expect(legacy(double.nan).error, MoneyParseError.nonFiniteLegacy);
    expect(legacy(double.infinity).error, MoneyParseError.nonFiniteLegacy);
    expect(legacy('1.25').error, MoneyParseError.invalidSyntax);
    expect(
      adapter
          .read(
            hasCanonicalMinorUnits: false,
            legacyMajorAmount: 1,
            currency: null,
          )
          .error,
      MoneyParseError.missingCurrency,
    );
    expect(
      adapter
          .read(
            hasCanonicalMinorUnits: false,
            legacyMajorAmount: 1,
            currency: CurrencyCode.parse('USD'),
          )
          .error,
      MoneyParseError.unknownCurrency,
    );
  });
}
