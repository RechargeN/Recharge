import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/config/provider_cost_policy.dart';
import 'package:recharge/core/telemetry/provider_cost_ledger.dart';

void main() {
  test('zero-cost policy permits a local unlimited adapter', () {
    const policy = ProviderCostPolicy(
      providerId: 'local-demo-graph',
      version: 1,
      costClass: CostClass.zeroCost,
      enabled: true,
      dailyRequestLimit: 0,
    );

    expect(policy.isValid, isTrue);
    expect(policy.permitsRequests, isTrue);
  });

  test('metered provider remains disabled without explicit approval', () {
    const policy = ProviderCostPolicy(
      providerId: 'paid-routing',
      version: 1,
      costClass: CostClass.metered,
      enabled: false,
      dailyRequestLimit: 100,
    );

    expect(policy.isValid, isTrue);
    expect(policy.permitsRequests, isFalse);
  });

  test('ledger reports metered calls separately from local calls', () {
    final ledger = InMemoryProviderCostLedger()
      ..record(
        ProviderCostLedgerEntry(
          providerId: 'local-demo-graph',
          operationId: 'local-1',
          costClass: CostClass.zeroCost,
          recordedAtUtc: DateTime.utc(2026, 7, 24),
        ),
      )
      ..record(
        ProviderCostLedgerEntry(
          providerId: 'paid-routing',
          operationId: 'paid-1',
          costClass: CostClass.metered,
          recordedAtUtc: DateTime.utc(2026, 7, 24),
        ),
      );

    expect(ledger.entries, hasLength(2));
    expect(ledger.meteredCallCount, 1);
  });
}
