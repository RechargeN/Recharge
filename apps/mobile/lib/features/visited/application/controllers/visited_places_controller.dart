import 'package:flutter/foundation.dart';

import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/visited_place_entity.dart';
import '../../domain/usecases/get_visited_places_usecase.dart';
import '../../domain/usecases/record_place_visit_usecase.dart';
import '../../domain/usecases/remove_visit_usecase.dart';
import '../state/visited_places_state.dart';

class VisitedPlacesController extends ChangeNotifier {
  VisitedPlacesController({
    required GetVisitedPlacesUseCase getVisitedPlacesUseCase,
    RecordPlaceVisitUseCase? recordPlaceVisitUseCase,
    RemoveVisitUseCase? removeVisitUseCase,
    required AnalyticsService analyticsService,
  }) : _getVisitedPlacesUseCase = getVisitedPlacesUseCase,
       _recordPlaceVisitUseCase = recordPlaceVisitUseCase,
       _removeVisitUseCase = removeVisitUseCase,
       _analyticsService = analyticsService;

  final GetVisitedPlacesUseCase _getVisitedPlacesUseCase;
  final RecordPlaceVisitUseCase? _recordPlaceVisitUseCase;
  final RemoveVisitUseCase? _removeVisitUseCase;
  final AnalyticsService _analyticsService;

  VisitedPlacesState _state = VisitedPlacesState.initial();
  VisitedPlacesState get state => _state;

  String? _loadedUserId;

  Future<void> ensureLoaded({required String userId}) async {
    if (_loadedUserId == userId && _state.status == VisitedPlacesStatus.ready) {
      return;
    }
    await loadVisitedPlaces(userId: userId);
  }

  Future<void> loadVisitedPlaces({required String userId}) async {
    _setState(
      _state.copyWith(status: VisitedPlacesStatus.loading, clearMessage: true),
    );
    try {
      final List<VisitedPlaceEntity> items = await _getVisitedPlacesUseCase(
        userId: userId,
      );
      _loadedUserId = userId;
      _setState(
        _state.copyWith(
          status: VisitedPlacesStatus.ready,
          items: items,
          visibleItems: items,
          clearSelectedMonth: true,
          clearSelectedDay: true,
          clearMessage: true,
        ),
      );
      _analyticsService.track(
        'visited_places_loaded',
        params: <String, Object?>{'item_count': items.length},
      );
    } on Exception {
      _setState(
        _state.copyWith(
          status: VisitedPlacesStatus.error,
          message: 'Не удалось загрузить историю посещений',
        ),
      );
      _analyticsService.track(
        'visited_places_load_failed',
        params: const <String, Object?>{'error_group': 'storage'},
      );
    }
  }

  Future<VisitedPlaceEntity> recordPlaceVisit({
    required String userId,
    required String placeId,
    required String title,
    required String subtitle,
    required String city,
    required String category,
    required DateTime visitedOn,
    required DateTime today,
    required String timezoneId,
    String coverImageUrl = '',
  }) async {
    final RecordPlaceVisitUseCase? useCase = _recordPlaceVisitUseCase;
    if (useCase == null) {
      throw StateError('RecordPlaceVisitUseCase is not configured');
    }
    final VisitedPlaceEntity visit = await useCase(
      userId: userId,
      placeId: placeId,
      title: title,
      subtitle: subtitle,
      city: city,
      category: category,
      visitedOn: visitedOn,
      today: today,
      timezoneId: timezoneId,
      coverImageUrl: coverImageUrl,
    );
    await loadVisitedPlaces(userId: userId);
    _analyticsService.track(
      'visit_history_self_reported',
      params: <String, Object?>{
        'place_id': placeId,
        'visited_on': visit.localDayKey,
      },
    );
    return visit;
  }

  Future<void> removeVisit({
    required String userId,
    required String visitId,
  }) async {
    final RemoveVisitUseCase? useCase = _removeVisitUseCase;
    if (useCase == null) {
      throw StateError('RemoveVisitUseCase is not configured');
    }
    await useCase(userId: userId, visitId: visitId);
    await loadVisitedPlaces(userId: userId);
    _analyticsService.track(
      'visit_history_removed',
      params: <String, Object?>{'visit_id': visitId},
    );
  }

  void selectMonth(DateTime month) {
    final DateTime normalizedMonth = DateTime(month.year, month.month);
    _setState(
      _state.copyWith(
        visibleItems: _filterByMonth(_state.items, normalizedMonth),
        selectedMonth: normalizedMonth,
        clearSelectedDay: true,
      ),
    );
    _trackPeriodChanged('month');
  }

  void selectDay(DateTime day) {
    final DateTime normalizedDay = DateTime(day.year, day.month, day.day);
    _setState(
      _state.copyWith(
        visibleItems: _filterByDay(_state.items, normalizedDay),
        selectedMonth: DateTime(day.year, day.month),
        selectedDay: normalizedDay,
      ),
    );
    _trackPeriodChanged('day');
  }

  void clearTimeFilter() {
    _setState(
      _state.copyWith(
        visibleItems: _state.items,
        clearSelectedMonth: true,
        clearSelectedDay: true,
      ),
    );
    _trackPeriodChanged('all');
  }

  List<VisitedPlaceEntity> _filterByMonth(
    List<VisitedPlaceEntity> items,
    DateTime month,
  ) {
    return items
        .where((VisitedPlaceEntity item) {
          final DateTime localDate = item.visitedOn;
          return localDate.year == month.year && localDate.month == month.month;
        })
        .toList(growable: false);
  }

  List<VisitedPlaceEntity> _filterByDay(
    List<VisitedPlaceEntity> items,
    DateTime day,
  ) {
    return items
        .where((VisitedPlaceEntity item) {
          final DateTime localDate = item.visitedOn;
          return localDate.year == day.year &&
              localDate.month == day.month &&
              localDate.day == day.day;
        })
        .toList(growable: false);
  }

  void _trackPeriodChanged(String period) {
    _analyticsService.track(
      'visited_places_period_changed',
      params: <String, Object?>{
        'period': period,
        'visible_count': _state.visibleItems.length,
      },
    );
  }

  void _setState(VisitedPlacesState nextState) {
    _state = nextState;
    notifyListeners();
  }
}
