import '../../../../shared/primitives/money/money.dart';
import '../../../../shared/primitives/money/currency_code.dart';
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

    final Money total;
    try {
      selected.unitPrice.minorUnitsIn(CurrencyCode.parse(pricing.currencyCode));
      total = selected.unitPrice.scaledBy(billableUnits);
    } on MoneyArithmeticException {
      return null;
    } on FormatException {
      return null;
    }

    return RentalRateEstimate(
      billableUnits: billableUnits,
      unitPriceMinor: selected.unitPrice.minorUnits,
      totalMinor: total.minorUnits,
      currencyCode: pricing.currencyCode,
    );
  }
}
