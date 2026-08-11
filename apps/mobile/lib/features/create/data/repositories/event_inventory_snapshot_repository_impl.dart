import '../../domain/entities/event_availability_projection.dart';
import '../../domain/repositories/event_inventory_snapshot_repository.dart';
import '../datasources/event_mock_inventory_datasource.dart';

class EventInventorySnapshotRepositoryImpl
    implements EventInventorySnapshotRepository {
  const EventInventorySnapshotRepositoryImpl(this._dataSource);

  final EventMockInventoryDataSource _dataSource;

  @override
  Future<EventInventorySnapshot?> loadSnapshot({
    required String eventId,
    required String occurrenceId,
  }) => _dataSource.load(eventId: eventId, occurrenceId: occurrenceId);
}
