import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/time/utc_instant.dart';

void main() {
  test('strict UTC text roundtrips precision and supported year range', () {
    for (final value in [
      DateTime.utc(0),
      DateTime.utc(-1),
      DateTime.utc(-10000),
      DateTime.utc(10000),
      DateTime.utc(275760, 9, 13),
      DateTime.utc(-271821, 4, 20),
      DateTime.utc(2024, 2, 29, 23, 59, 59, 999, 999),
    ]) {
      expect(UtcInstant.parse(value.toIso8601String()), UtcInstant(value));
    }
    expect(UtcInstant.parse('2026-01-01T00:00:00Z').value, DateTime.utc(2026));
    expect(UtcInstant.parse('2026-01-01T00:00:00.1Z').value.millisecond, 100);
  });

  test('UTC text rejects normalization, offsets and lossy precision', () {
    for (final text in [
      '2026-02-29T00:00:00Z',
      '2026-00-01T00:00:00Z',
      '2026-13-01T00:00:00Z',
      '2026-01-00T00:00:00Z',
      '2026-04-31T00:00:00Z',
      '2026-01-01T24:00:00Z',
      '2026-01-01T00:60:00Z',
      '2026-01-01T00:00:60Z',
      '2026-01-01T00:00:00.0000001Z',
      '2026-01-01T00:00:00',
      '2026-01-01T00:00:00+00:00',
      '2026-01-01T03:00:00+03:00',
      '2026-01-01',
      '2026-01-01T00:00:00z',
      '2026-01-01T00:00:00Z\n',
      ' 2026-01-01T00:00:00Z',
      '+999999-01-01T00:00:00Z',
    ]) {
      expect(() => UtcInstant.parse(text), throwsFormatException, reason: text);
    }
  });

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
