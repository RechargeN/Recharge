import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/visited/application/visited_places_providers.dart';
import '../../features/visited/application/state/visited_places_state.dart';
import 'visit_history_facade.dart';
import '../di/service_locator.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';

final visitHistoryFacadeProvider = Provider<VisitHistoryFacade>((ref) {
  return VisitHistoryFacade(
    controller: ref.watch(visitedPlacesControllerProvider),
    timezoneRepository: () => sl<TimezoneRepository>(),
  );
});

final visitHistorySummaryProvider = Provider<VisitHistorySummary>((ref) {
  final VisitedPlacesState state = ref
      .watch(visitedPlacesControllerProvider)
      .state;
  return VisitHistorySummary(
    status: switch (state.status) {
      VisitedPlacesStatus.initial => VisitHistoryLoadStatus.initial,
      VisitedPlacesStatus.loading => VisitHistoryLoadStatus.loading,
      VisitedPlacesStatus.ready => VisitHistoryLoadStatus.ready,
      VisitedPlacesStatus.error => VisitHistoryLoadStatus.error,
    },
    items: state.items.map(VisitHistoryItem.fromEntity).toList(growable: false),
  );
});
