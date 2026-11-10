import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/time/utc_instant.dart';

void main() {
  test('preserves explicit UTC precision, equality and ordering', () {
    final value = DateTime.utc(2026, 3, 29, 1, 2, 3, 456, 789);
    final instant = UtcInstant(value);
    expect(instant.value, same(value));
    expect(instant.toString(), '2026-03-29T01:02:03.456789Z');
    expect(UtcInstant(DateTime.parse(instant.toString())), instant);
    expect(
      UtcInstant(DateTime.parse(instant.toString())).hashCode,
      instant.hashCode,
    );
    expect(
      instant.compareTo(UtcInstant(value.add(const Duration(microseconds: 1)))),
      lessThan(0),
    );
  });

  test('rejects local DateTime even when the host offset is zero', () {
    expect(() => UtcInstant(DateTime(2026, 3, 29)), throwsArgumentError);
    expect(
      () => UtcInstant(DateTime.fromMillisecondsSinceEpoch(0)),
      throwsArgumentError,
    );
    expect(
      UtcInstant(
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ).value.isUtc,
      isTrue,
    );
  });
}
