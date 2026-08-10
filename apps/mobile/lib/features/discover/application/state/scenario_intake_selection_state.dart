import '../../domain/entities/discover_item_entity.dart';

class ScenarioIntakeSelectionState {
  ScenarioIntakeSelectionState({
    required this.active,
    required List<DiscoverItemEntity> selectedItems,
    required this.message,
  }) : selectedItems = List<DiscoverItemEntity>.unmodifiable(selectedItems);

  factory ScenarioIntakeSelectionState.inactive() =>
      ScenarioIntakeSelectionState(
        active: false,
        selectedItems: const <DiscoverItemEntity>[],
        message: null,
      );

  final bool active;
  final List<DiscoverItemEntity> selectedItems;
  final String? message;

  int get count => selectedItems.length;
  bool get canReview => active && selectedItems.isNotEmpty;

  int? orderOf(String itemId) {
    final index = selectedItems.indexWhere((item) => item.id == itemId);
    return index < 0 ? null : index + 1;
  }

  ScenarioIntakeSelectionState copyWith({
    bool? active,
    List<DiscoverItemEntity>? selectedItems,
    String? message,
    bool clearMessage = false,
  }) => ScenarioIntakeSelectionState(
    active: active ?? this.active,
    selectedItems: selectedItems ?? this.selectedItems,
    message: clearMessage ? null : (message ?? this.message),
  );
}
