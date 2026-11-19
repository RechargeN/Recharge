import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/app/testing/seeded_event_fixture.dart';

void main() {
  const Map<String, String> good = <String, String>{
    'occurrence': '243fe4f5-8fc2-5b0b-9910-0969386b4371',
    'start': '2026-11-20T16:00:00.000Z',
    'end': '2026-11-20T18:00:00.000Z',
    'title': 'Synthetic',
  };

  test('a published Event opens with exactly the given occurrence', () {
    final projection = publishedTestBookingEventProjection(
      eventId: 'db873444-e9a6-471b-a6d7-d88245a4d0bb',
      query: good,
    )!;
    expect(projection.eventId, 'db873444-e9a6-471b-a6d7-d88245a4d0bb');
    expect(projection.displayOccurrenceId, good['occurrence']);
    expect(projection.occurrences.single.startAtUtc.isUtc, isTrue);
    expect(projection.title, 'Synthetic');
  });

  test('bad ids or times open nothing', () {
    for (final Map<String, String> bad in <Map<String, String>>[
      <String, String>{...good, 'occurrence': '../x'},
      <String, String>{...good, 'start': 'yesterday'},
      <String, String>{...good, 'end': '2026-11-20T15:00:00.000Z'},
      <String, String>{'start': good['start']!, 'end': good['end']!},
    ]) {
      expect(
        publishedTestBookingEventProjection(eventId: 'evt-1', query: bad),
        isNull,
      );
    }
    expect(
      publishedTestBookingEventProjection(eventId: 'a/b', query: good),
      isNull,
    );
  });
}
