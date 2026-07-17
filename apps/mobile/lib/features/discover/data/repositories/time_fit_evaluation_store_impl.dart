import '../../domain/entities/time_fit_evaluation.dart';
import '../../domain/repositories/time_fit_evaluation_store.dart';

class InMemoryTimeFitEvaluationStore implements TimeFitEvaluationStore {
  final Map<String, TimeFitEvaluation> _evaluations =
      <String, TimeFitEvaluation>{};

  @override
  TimeFitEvaluation? get(String objectId) => _evaluations[objectId];

  @override
  void replaceAll(Iterable<TimeFitEvaluation> evaluations) {
    _evaluations
      ..clear()
      ..addEntries(
        evaluations.map(
          (TimeFitEvaluation value) =>
              MapEntry<String, TimeFitEvaluation>(value.objectId, value),
        ),
      );
  }

  @override
  void clear() => _evaluations.clear();
}
