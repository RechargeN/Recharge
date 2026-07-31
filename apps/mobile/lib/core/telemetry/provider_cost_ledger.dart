import '../config/provider_cost_policy.dart';

class ProviderCostLedgerEntry {
  const ProviderCostLedgerEntry({
    required this.providerId,
    required this.operationId,
    required this.costClass,
    required this.recordedAtUtc,
  });

  final String providerId;
  final String operationId;
  final CostClass costClass;
  final DateTime recordedAtUtc;
}

abstract interface class ProviderCostLedger {
  void record(ProviderCostLedgerEntry entry);
}

class InMemoryProviderCostLedger implements ProviderCostLedger {
  final List<ProviderCostLedgerEntry> _entries = <ProviderCostLedgerEntry>[];

  List<ProviderCostLedgerEntry> get entries =>
      List<ProviderCostLedgerEntry>.unmodifiable(_entries);

  int get meteredCallCount => _entries
      .where(
        (ProviderCostLedgerEntry entry) => entry.costClass == CostClass.metered,
      )
      .length;

  @override
  void record(ProviderCostLedgerEntry entry) {
    if (!entry.recordedAtUtc.isUtc) {
      throw ArgumentError.value(
        entry.recordedAtUtc,
        'entry.recordedAtUtc',
        'Ledger timestamps must be UTC.',
      );
    }
    _entries.add(entry);
  }
}
