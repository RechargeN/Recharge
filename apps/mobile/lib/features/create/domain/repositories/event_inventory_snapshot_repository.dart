import '../entities/event_availability_projection.dart';

abstract interface class EventInventorySnapshotRepository {
  Future<EventInventorySnapshot?> loadSnapshot({
    required String eventId,
    required String occurrenceId,
  });
}
