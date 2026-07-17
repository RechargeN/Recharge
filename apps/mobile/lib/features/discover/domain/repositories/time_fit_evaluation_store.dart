import '../entities/time_fit_evaluation.dart';

abstract class TimeFitEvaluationStore {
  TimeFitEvaluation? get(String objectId);
  void replaceAll(Iterable<TimeFitEvaluation> evaluations);
  void clear();
}
