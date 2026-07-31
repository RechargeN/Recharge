import '../../domain/entities/quick_plan_conversion.dart';
import '../../domain/repositories/quick_plan_conversion_source_port.dart';

class InMemoryQuickPlanConversionSource
    implements QuickPlanConversionSourcePort {
  final Map<String, QuickPlanConversionSnapshot> _snapshots =
      <String, QuickPlanConversionSnapshot>{};

  void put(QuickPlanConversionSnapshot snapshot) {
    _snapshots[snapshot.id] = snapshot;
  }

  @override
  Future<QuickPlanConversionSnapshot?> loadForCopy({
    required String quickPlanId,
    required String requesterId,
  }) async {
    final QuickPlanConversionSnapshot? snapshot = _snapshots[quickPlanId];
    if (snapshot == null) return null;
    final bool canRead =
        snapshot.ownerId == requesterId ||
        snapshot.readableByUserIds.contains(requesterId);
    return canRead ? snapshot : null;
  }
}
