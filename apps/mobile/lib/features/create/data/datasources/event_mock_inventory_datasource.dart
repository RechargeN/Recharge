import '../../domain/entities/event_availability_projection.dart';

class EventMockInventoryDataSource {
  EventMockInventoryDataSource({
    Iterable<EventInventorySnapshot> fixtures =
        const <EventInventorySnapshot>[],
  }) : _fixtures = Map<String, EventInventorySnapshot>.unmodifiable(
         <String, EventInventorySnapshot>{
           for (final EventInventorySnapshot fixture in fixtures)
             _key(fixture.eventId, fixture.occurrenceId): fixture,
         },
       );

  final Map<String, EventInventorySnapshot> _fixtures;

  Future<EventInventorySnapshot?> load({
    required String eventId,
    required String occurrenceId,
  }) async => _fixtures[_key(eventId, occurrenceId)];

  static String _key(String eventId, String occurrenceId) =>
      '$eventId::$occurrenceId';
}
