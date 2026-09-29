import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/parsing/input_parsers.dart';

void main() {
  test('locale decimal parser accepts comma and dot consistently', () {
    expect(parseLocaleDecimalInput('12,5'), 12.5);
    expect(parseLocaleDecimalInput(' 12.5 '), 12.5);
    expect(parseLocaleDecimalInput(''), isNull);
  });

  test('clock parser rejects negative and out-of-range components', () {
    expect(parseClockMinute('09:30'), 570);
    expect(parseClockMinute('-5:30'), isNull);
    expect(parseClockMinute('12:-1'), isNull);
    expect(parseClockMinute('24:00'), isNull);
  });
}
