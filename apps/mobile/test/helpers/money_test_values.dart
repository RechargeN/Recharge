import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

const Money testZeroEur = Money.zero(CurrencyCode.eur);
const Money testFiveEur = Money(minorUnits: 500, currency: CurrencyCode.eur);
const Money testEightEur = Money(minorUnits: 800, currency: CurrencyCode.eur);
const Money testTenEur = Money(minorUnits: 1000, currency: CurrencyCode.eur);
const Money testTwelveEur = Money(minorUnits: 1200, currency: CurrencyCode.eur);
