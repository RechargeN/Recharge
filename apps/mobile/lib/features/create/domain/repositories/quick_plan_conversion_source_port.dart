import '../entities/quick_plan_conversion.dart';

abstract class QuickPlanConversionSourcePort {
  Future<QuickPlanConversionSnapshot?> loadForCopy({
    required String quickPlanId,
    required String requesterId,
  });
}
