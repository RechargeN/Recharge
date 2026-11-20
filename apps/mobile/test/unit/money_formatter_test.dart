import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:recharge/shared/primitives/money/money_formatter.dart';

void main() {
  test(
    'metadata formatting does not pass amounts through double or infer free',
    () {
      final formatter = MoneyFormatter();
      Money m(int n) => Money(minorUnits: n, currency: CurrencyCode.eur);
      expect(formatter.decimal(m(0), locale: 'en'), '0.00');
      expect(formatter.decimal(m(101), locale: 'en'), '1.01');
      expect(
        formatter.decimal(m(0), locale: 'en', omitZeroFraction: true),
        '0',
      );
      expect(
        formatter.decimal(m(100), locale: 'en', omitZeroFraction: true),
        '1',
      );
      expect(
        formatter.decimal(m(110), locale: 'en', omitZeroFraction: true),
        '1.10',
      );
      expect(
        formatter.decimal(m(101), locale: 'ru', omitZeroFraction: true),
        '1,01',
      );
      expect(formatter.decimal(m(-1), locale: 'ru'), '-0,01');
      expect(
        formatter.decimal(m(123456789), locale: 'lv', groupThousands: true),
        '1\u00a0234\u00a0567,89',
      );
      expect(
        formatter.decimal(m(Money.maxSafeMinorUnits), locale: 'en'),
        '90071992547409.91',
      );
      expect(
        () => formatter.decimal(
          Money(minorUnits: 1, currency: CurrencyCode.parse('USD')),
          locale: 'en',
        ),
        throwsA(isA<MoneyFormatException>()),
      );
    },
  );
}
