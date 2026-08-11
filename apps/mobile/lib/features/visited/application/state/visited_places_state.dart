import '../../domain/entities/visited_place_entity.dart';

enum VisitedPlacesStatus { initial, loading, ready, error }

class VisitedPlacesState {
  const VisitedPlacesState({
    required this.status,
    required this.items,
    required this.visibleItems,
    required this.selectedMonth,
    required this.selectedDay,
    required this.message,
  });

  factory VisitedPlacesState.initial() {
    return const VisitedPlacesState(
      status: VisitedPlacesStatus.initial,
      items: <VisitedPlaceEntity>[],
      visibleItems: <VisitedPlaceEntity>[],
      selectedMonth: null,
      selectedDay: null,
      message: null,
    );
  }

  final VisitedPlacesStatus status;
  final List<VisitedPlaceEntity> items;
  final List<VisitedPlaceEntity> visibleItems;
  final DateTime? selectedMonth;
  final DateTime? selectedDay;
  final String? message;

  bool get hasTimeFilter => selectedMonth != null || selectedDay != null;

  VisitedPlacesState copyWith({
    VisitedPlacesStatus? status,
    List<VisitedPlaceEntity>? items,
    List<VisitedPlaceEntity>? visibleItems,
    DateTime? selectedMonth,
    bool clearSelectedMonth = false,
    DateTime? selectedDay,
    bool clearSelectedDay = false,
    String? message,
    bool clearMessage = false,
  }) {
    return VisitedPlacesState(
      status: status ?? this.status,
      items: items ?? this.items,
      visibleItems: visibleItems ?? this.visibleItems,
      selectedMonth: clearSelectedMonth
          ? null
          : (selectedMonth ?? this.selectedMonth),
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
