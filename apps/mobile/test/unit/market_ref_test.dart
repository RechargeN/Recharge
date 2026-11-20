import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/market/market_ref.dart';

void main() {
  test('retains stable identity without display-name or market resolution', () {
    final riga = MarketRef.parse('riga');
    expect(riga.value, 'riga');
    expect(riga.toString(), 'riga');
    expect(riga.hashCode, MarketRef.parse('riga').hashCode);
    expect(riga, isNot(MarketRef.parse('rezekne')));
    expect(MarketRef.parse('lv-riga').value, 'lv-riga');
    expect(MarketRef.parse('unknown_market').value, 'unknown_market');
  });

  test('rejects labels, whitespace and malformed IDs', () {
    for (final value in [
      '',
      'Riga',
      'Rīga',
      'new york',
      ' riga',
      'riga ',
      'lv/riga',
      '-riga',
      'riga-',
      'lv--riga',
      'riga\n',
    ]) {
      expect(() => MarketRef.parse(value), throwsFormatException);
    }
  });
}
