import '../entities/rental_draft_data.dart';

class RentalRateEstimate {
  const RentalRateEstimate({
    required this.billableUnits,
    required this.unitPriceMinor,
    required this.totalMinor,
    required this.currencyCode,
  });

  final int billableUnits;
  final int unitPriceMinor;
  final int totalMinor;
  final String currencyCode;
}

/// Pure implementation of spec §10.2: billable units round up to the
/// billing unit, the step with the largest `minUnits <= billableUnits`
/// applies, and the estimate is informational only (final amount is shown
/// only on the provider site). Uses checked integer arithmetic — no
/// `double`, per repository convention for money.
class EstimateRentalRateUseCase {
  const EstimateRentalRateUseCase();

  /// A conservative bound well under the 64-bit signed int range and under
  /// JS's safe-integer limit (2^53), so a result stays representable even
  /// if this value round-trips through a web/JSON boundary.
  static const int _maxSafeMinorUnits = 1 << 53;

  RentalRateEstimate? call({
    required RentalPricingPolicy pricing,
    required int requestedMinutes,
  }) {
    if (requestedMinutes <= 0 || pricing.rateSteps.isEmpty) return null;
    final int unitMinutes = pricing.billingUnit.minutes;
    if (unitMinutes <= 0) return null;

    final int billableUnits =
        (requestedMinutes + unitMinutes - 1) ~/ unitMinutes;
    if (billableUnits <= 0) return null;

    RentalRateStep? selected;
    for (final RentalRateStep step in pricing.rateSteps) {
      if (step.minUnits <= billableUnits) {
        if (selected == null || step.minUnits > selected.minUnits) {
          selected = step;
        }
      }
    }
    selected ??= pricing.rateSteps.first;

    final int? totalMinor = _checkedMultiply(
      billableUnits,
      selected.unitPrice.amountMinor,
    );
    if (totalMinor == null) return null;

    return RentalRateEstimate(
      billableUnits: billableUnits,
      unitPriceMinor: selected.unitPrice.amountMinor,
      totalMinor: totalMinor,
      currencyCode: pricing.currencyCode,
    );
  }

  int? _checkedMultiply(int a, int b) {
    if (a == 0 || b == 0) return 0;
    final int product = a * b;
    if (product ~/ a != b) return null; // overflow
    if (product.abs() > _maxSafeMinorUnits) return null;
    return product;
  }
}
