import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/shared/primitives/money/money_formatter.dart';

void main() {
  test('formats English and Latvian values from integer minor units', () {
    const Money value = Money(minorUnits: 123450, currency: CurrencyCode.eur);

    expect(MoneyFormatter.format(value), '€1,234.50');
    expect(
      MoneyFormatter.format(value, localeTag: 'lv-LV'),
      '1\u00a0234,50\u00a0€',
    );
  });

  test('formats negative, zero-decimal and code-labelled values', () {
    expect(
      MoneyFormatter.format(
        const Money(minorUnits: -120, currency: CurrencyCode.eur),
        useSymbol: false,
      ),
      '-EUR1.20',
    );
    expect(
      MoneyFormatter.format(
        const Money(minorUnits: 1200, currency: CurrencyCode.jpy),
      ),
      '¥1,200',
    );
  });

  test('serializes canonical URL decimals with integer arithmetic', () {
    expect(
      MoneyFormatter.decimal(
        const Money(minorUnits: 1200, currency: CurrencyCode.eur),
      ),
      '12',
    );
    expect(
      MoneyFormatter.decimal(
        const Money(minorUnits: 1234, currency: CurrencyCode.eur),
      ),
      '12.34',
    );
    expect(
      MoneyFormatter.decimal(
        const Money(minorUnits: 1234, currency: CurrencyCode.bhd),
      ),
      '1.234',
    );
  });
}
