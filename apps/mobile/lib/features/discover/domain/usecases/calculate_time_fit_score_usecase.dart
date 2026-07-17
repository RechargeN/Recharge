import '../entities/time_fit_evaluation.dart';

class CalculateTimeFitScoreUseCase {
  const CalculateTimeFitScoreUseCase({required double timeFitWeight})
    : _timeFitWeight = timeFitWeight >= 0 && timeFitWeight <= 0.30
          ? timeFitWeight
          : 0;

  final double _timeFitWeight;

  double call({
    required double baseScore,
    required TimeFitEvaluation evaluation,
  }) {
    final double normalizedBase = baseScore.clamp(0, 1);
    return (1 - _timeFitWeight) * normalizedBase +
        _timeFitWeight * evaluation.normalizedTimeFitScore;
  }
}
