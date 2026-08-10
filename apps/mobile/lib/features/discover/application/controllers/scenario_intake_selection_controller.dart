import 'package:flutter/foundation.dart';

import '../../domain/entities/discover_item_entity.dart';
import '../state/scenario_intake_selection_state.dart';

typedef ScenarioIntakeSupportIssue = String? Function(DiscoverItemEntity item);

enum ScenarioIntakeToggleResult {
  selected,
  deselected,
  inactive,
  unsupported,
  limitReached,
}

class ScenarioIntakeSelectionController extends ChangeNotifier {
  ScenarioIntakeSelectionController({
    required ScenarioIntakeSupportIssue supportIssue,
    this.maxSelection = 20,
  }) : assert(maxSelection > 0),
       _supportIssue = supportIssue,
       _state = ScenarioIntakeSelectionState.inactive();

  final ScenarioIntakeSupportIssue _supportIssue;
  final int maxSelection;

  ScenarioIntakeSelectionState _state;
  ScenarioIntakeSelectionState get state => _state;

  void start() {
    _state = ScenarioIntakeSelectionState(
      active: true,
      selectedItems: const <DiscoverItemEntity>[],
      message: null,
    );
    notifyListeners();
  }

  void cancel() {
    if (!_state.active && _state.selectedItems.isEmpty) return;
    _state = ScenarioIntakeSelectionState.inactive();
    notifyListeners();
  }

  ScenarioIntakeToggleResult toggle(DiscoverItemEntity item) {
    if (!_state.active) return ScenarioIntakeToggleResult.inactive;
    final selectedIndex = _state.selectedItems.indexWhere(
      (selected) => selected.id == item.id,
    );
    if (selectedIndex >= 0) {
      final next = <DiscoverItemEntity>[..._state.selectedItems]
        ..removeAt(selectedIndex);
      _state = _state.copyWith(selectedItems: next, clearMessage: true);
      notifyListeners();
      return ScenarioIntakeToggleResult.deselected;
    }
    final issue = _supportIssue(item);
    if (issue != null) {
      _state = _state.copyWith(message: issue);
      notifyListeners();
      return ScenarioIntakeToggleResult.unsupported;
    }
    if (_state.selectedItems.length >= maxSelection) {
      _state = _state.copyWith(
        message: 'A Scenario intake can contain up to $maxSelection items.',
      );
      notifyListeners();
      return ScenarioIntakeToggleResult.limitReached;
    }
    _state = _state.copyWith(
      selectedItems: <DiscoverItemEntity>[..._state.selectedItems, item],
      clearMessage: true,
    );
    notifyListeners();
    return ScenarioIntakeToggleResult.selected;
  }

  void remove(String itemId) {
    final next = _state.selectedItems
        .where((item) => item.id != itemId)
        .toList(growable: false);
    if (next.length == _state.selectedItems.length) return;
    _state = _state.copyWith(selectedItems: next, clearMessage: true);
    notifyListeners();
  }
}
