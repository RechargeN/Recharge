import '../../features/discover/domain/entities/discover_item_entity.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';
import '../../features/visited/application/controllers/visited_places_controller.dart';
import '../../features/visited/domain/entities/visited_place_entity.dart';

enum VisitHistoryLoadStatus { initial, loading, ready, error }

class VisitHistoryItem {
  const VisitHistoryItem({
    required this.id,
    required this.placeId,
    required this.title,
    required this.city,
    required this.visitedOn,
    required this.coverImageUrl,
  });

  factory VisitHistoryItem.fromEntity(VisitedPlaceEntity entity) {
    return VisitHistoryItem(
      id: entity.id,
      placeId: entity.placeId,
      title: entity.title,
      city: entity.city,
      visitedOn: entity.visitedOn,
      coverImageUrl: entity.coverImageUrl,
    );
  }

  final String id;
  final String placeId;
  final String title;
  final String city;
  final DateTime visitedOn;
  final String coverImageUrl;
}

class VisitHistorySummary {
  const VisitHistorySummary({required this.status, required this.items});

  final VisitHistoryLoadStatus status;
  final List<VisitHistoryItem> items;
}

/// App-level bridge that maps a Discover place into private Visit History.
class VisitHistoryFacade {
  const VisitHistoryFacade({
    required VisitedPlacesController controller,
    required TimezoneRepository Function() timezoneRepository,
  }) : _controller = controller,
       _timezoneRepository = timezoneRepository;

  final VisitedPlacesController _controller;
  final TimezoneRepository Function() _timezoneRepository;

  DateTime todayAtPlace(DiscoverItemEntity item, {DateTime? nowUtc}) {
    final timezoneRepository = _timezoneRepository();
    if (!timezoneRepository.isValidTimezone(item.timezoneId)) {
      throw ArgumentError('A valid place timezone is required');
    }
    final date = timezoneRepository
        .toLocal(nowUtc ?? DateTime.now().toUtc(), item.timezoneId)
        .date;
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> ensureLoaded({required String userId}) {
    return _controller.ensureLoaded(userId: userId);
  }

  Future<VisitedPlaceEntity> recordSelfReported({
    required String userId,
    required DiscoverItemEntity item,
    required DateTime visitedOn,
  }) {
    if (item.objectKind != DiscoverObjectKind.place) {
      throw ArgumentError('Only a place can be added to Visit History');
    }
    return _controller.recordPlaceVisit(
      userId: userId,
      placeId: item.id,
      title: item.title,
      subtitle: item.subtitle,
      city: item.city,
      category: item.category,
      visitedOn: visitedOn,
      today: todayAtPlace(item),
      timezoneId: item.timezoneId,
      coverImageUrl: item.coverImageUrl,
    );
  }
}
