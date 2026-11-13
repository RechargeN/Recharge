import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/domain/entities/event_occurrence.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:recharge/features/discover/domain/entities/published_event_program_item.dart';

PublishedEventDiscoveryEntity _entity({
  List<EventOccurrence>? occurrences,
  String? displayOccurrenceId,
}) {
  final List<EventOccurrence> resolvedOccurrences =
      occurrences ??
      <EventOccurrence>[
        EventOccurrence(
          id: 'occ_1',
          startAtUtc: DateTime.utc(2026, 6, 21, 18),
          endAtUtc: DateTime.utc(2026, 6, 21, 20, 30),
          status: EventOccurrenceStatus.scheduled,
        ),
      ];
  return PublishedEventDiscoveryEntity(
    eventId: 'evt_1',
    publisherId: 'pub_1',
    publisherType: 'page',
    publisherName: 'Marine Tennis Club',
    title: 'Sunset Tennis Meetup',
    subtitle: 'Friendly tennis at sunset',
    fullDescription: 'Дружеская встреча для любителей тенниса.',
    category: 'outdoor',
    city: 'Dubai',
    latitude: 25.2048,
    longitude: 55.2708,
    distanceKm: 1.4,
    priceAmount: 12,
    isFree: false,
    currencyCode: 'EUR',
    scheduleMode: EventScheduleMode.oneTime,
    occurrences: resolvedOccurrences,
    displayOccurrenceId:
        displayOccurrenceId ??
        (resolvedOccurrences.isEmpty ? 'unused' : resolvedOccurrences.first.id),
    timezoneId: 'Asia/Dubai',
    publishedAtUtc: DateTime.utc(2026, 6, 1),
  );
}

void main() {
  group('EventProgramItemKind wire vocabulary', () {
    test('round-trips every Accepted EVENT_CLASSIFICATION_SPEC.md kind', () {
      for (final EventProgramItemKind kind in EventProgramItemKind.values) {
        expect(EventProgramItemKind.fromWireName(kind.wireName), kind);
      }
    });

    test('break maps to the reserved-word-safe wire string "break"', () {
      expect(EventProgramItemKind.breakTime.wireName, 'break');
    });

    test('unknown wire value resolves to null, not a thrown error', () {
      expect(EventProgramItemKind.fromWireName('intermission'), isNull);
    });
  });

  group('PublishedEventDiscoveryEntity occurrence invariants', () {
    test('throws when occurrences is empty — Event without a confirmed '
        'occurrence is not published', () {
      expect(
        () => _entity(occurrences: <EventOccurrence>[]),
        throwsArgumentError,
      );
    });

    test('throws when displayOccurrenceId does not resolve to any '
        'occurrence', () {
      expect(
        () => _entity(displayOccurrenceId: 'occ_missing'),
        throwsArgumentError,
      );
    });

    test('displayOccurrence resolves the matching entry', () {
      final PublishedEventDiscoveryEntity event = _entity();
      expect(event.displayOccurrence?.id, 'occ_1');
      expect(event.hasActionableDisplayOccurrence, isTrue);
    });

    test(
      'cancelled display occurrence remains readable but is not actionable',
      () {
        final PublishedEventDiscoveryEntity event = _entity(
          occurrences: <EventOccurrence>[
            EventOccurrence(
              id: 'occ_cancelled',
              startAtUtc: DateTime.utc(2026, 6, 21, 18),
              endAtUtc: DateTime.utc(2026, 6, 21, 20, 30),
              status: EventOccurrenceStatus.cancelled,
            ),
          ],
        );
        expect(
          event.displayOccurrence?.status,
          EventOccurrenceStatus.cancelled,
        );
        expect(event.hasActionableDisplayOccurrence, isFalse);
      },
    );

    test('occurrence rejects an inverted time interval', () {
      expect(
        () => EventOccurrence(
          id: 'occ_invalid',
          startAtUtc: DateTime.utc(2026, 6, 21, 20),
          endAtUtc: DateTime.utc(2026, 6, 21, 18),
          status: EventOccurrenceStatus.scheduled,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PublishedEventProgramItem', () {
    test('carries no independent booking/pricing/visibility field — the '
        'invariant is enforced by the type shape, not a runtime check', () {
      final PublishedEventProgramItem item = PublishedEventProgramItem(
        id: 'prog_1',
        title: 'Сбор участников и разминка',
        kind: EventProgramItemKind.activity,
        startAtUtc: DateTime.utc(2026, 6, 21, 18),
        endAtUtc: DateTime.utc(2026, 6, 21, 18, 20),
      );
      // The absence of price/capacity/visibility fields is a compile-time
      // guarantee (EVENT_CLASSIFICATION_SPEC.md:958-960,1071) — this test
      // documents the intent so a future field addition here is a
      // conscious decision, not an accidental widening.
      expect(item.id, 'prog_1');
      expect(item.description, isNull);
    });
  });
}
