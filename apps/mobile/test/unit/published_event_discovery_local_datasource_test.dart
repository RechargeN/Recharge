import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/discover/data/datasources/published_event_discovery_local_datasource.dart';
import 'package:recharge/features/discover/data/repositories/event_details_lookup.dart';
import 'package:recharge/features/discover/domain/entities/published_event_discovery_entity.dart';
import 'package:recharge/features/discover/domain/repositories/published_event_discovery_port.dart';
import 'package:recharge/shared/models/catalog_object_ref.dart';

void main() {
  late PublishedEventDiscoveryLocalDataSource dataSource;

  setUp(() {
    dataSource = PublishedEventDiscoveryLocalDataSource();
  });

  group('PublishedEventDiscoveryLocalDataSource', () {
    test('serves the Sunset Tennis Meetup fixture by its known id', () async {
      final PublishedEventDiscoveryEntity? event = await dataSource
          .getActiveEvent(
            PublishedEventDiscoveryLocalDataSource.sunsetTennisMeetupId,
          );

      expect(event, isNotNull);
      expect(event!.title, 'Sunset Tennis Meetup');
      expect(event.venueName, 'Marine Tennis Club');
      expect(event.timezoneId, 'Asia/Dubai');
      expect(event.programItems, hasLength(3));
      expect(event.displayOccurrence, isNotNull);
      // §7.5: 18:00–20:30 Dubai local time (UTC+4, no DST).
      expect(event.displayOccurrence!.startAtUtc, DateTime.utc(2026, 6, 21, 14));
      expect(event.displayOccurrence!.endAtUtc, DateTime.utc(2026, 6, 21, 16, 30));
    });

    test('returns null (never throws) for an unknown id', () async {
      final PublishedEventDiscoveryEntity? event = await dataSource
          .getActiveEvent('does_not_exist');
      expect(event, isNull);
    });
  });

  group('EventDetailsLookup', () {
    test('delegates lookup to the port', () async {
      final EventDetailsLookup lookup = EventDetailsLookup(dataSource);
      final Object? result = await lookup.lookup(
        PublishedEventDiscoveryLocalDataSource.sunsetTennisMeetupId,
      );
      expect(result, isA<PublishedEventDiscoveryEntity>());
    });

    test('classify always returns CatalogObjectType.event', () {
      final EventDetailsLookup lookup = EventDetailsLookup(dataSource);
      expect(
        lookup.classify(Object()),
        CatalogObjectType.event,
      );
    });

    test('PublishedEventDiscoveryPort is satisfied by the data source', () {
      // Compile-time contract check: EventDetailsLookup only depends on
      // the port interface, not the concrete data source.
      final PublishedEventDiscoveryPort port = dataSource;
      expect(port, isNotNull);
    });
  });
}
