enum CostClass { zeroCost, freeTier, metered, forbiddenByDefault }

class ProviderCostPolicy {
  const ProviderCostPolicy({
    required this.providerId,
    required this.version,
    required this.costClass,
    required this.enabled,
    required this.dailyRequestLimit,
  });

  final String providerId;
  final int version;
  final CostClass costClass;
  final bool enabled;
  final int dailyRequestLimit;

  bool get isValid =>
      providerId.trim().isNotEmpty &&
      version > 0 &&
      dailyRequestLimit >= 0 &&
      (costClass == CostClass.zeroCost || dailyRequestLimit > 0);

  bool get permitsRequests =>
      isValid && enabled && costClass != CostClass.forbiddenByDefault;
}
