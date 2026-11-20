import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/rental_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/estimate_rental_rate_usecase.dart';

void main() {
  const EstimateRentalRateUseCase useCase = EstimateRentalRateUseCase();

  RentalPricingPolicy pricingWithLadder() => RentalPricingPolicy(
    currencyCode: 'EUR',
    billingUnit: RentalBillingUnit.day,
    rateSteps: <RentalRateStep>[
      RentalRateStep(
        minUnits: 1,
        unitPrice: Money(minorUnits: 2800, currency: CurrencyCode.parse('EUR')),
      ),
      RentalRateStep(
        minUnits: 3,
        unitPrice: Money(minorUnits: 2500, currency: CurrencyCode.parse('EUR')),
      ),
      RentalRateStep(
        minUnits: 7,
        unitPrice: Money(minorUnits: 2200, currency: CurrencyCode.parse('EUR')),
      ),
    ],
    deposit: RentalDepositPolicy(
      amount: Money(minorUnits: 15000, currency: CurrencyCode.parse('EUR')),
      collectionMethod: RentalDepositCollectionMethod.externalProvider,
      terms: 'Held by provider.',
    ),
    damagePolicy: 'Repair cost up to deposit.',
    cancellationPolicyId: 'standard',
  );

  test('rounds up to whole billing units', () {
    final RentalRateEstimate? estimate = useCase(
      pricing: pricingWithLadder(),
      requestedMinutes: 1500, // just over 1 day (1440 min)
    );

    expect(estimate, isNotNull);
    expect(estimate!.billableUnits, 2);
  });

  test('selects the highest applicable step, price never increases', () {
    final RentalRateEstimate? threeDay = useCase(
      pricing: pricingWithLadder(),
      requestedMinutes: 3 * 1440,
    );
    final RentalRateEstimate? sevenDay = useCase(
      pricing: pricingWithLadder(),
      requestedMinutes: 7 * 1440,
    );

    expect(threeDay!.unitPriceMinor, 2500);
    expect(threeDay.totalMinor, 3 * 2500);
    expect(sevenDay!.unitPriceMinor, 2200);
    expect(sevenDay.totalMinor, 7 * 2200);
  });

  test('returns null for non-positive duration or empty rate ladder', () {
    expect(useCase(pricing: pricingWithLadder(), requestedMinutes: 0), isNull);
    expect(
      useCase(
        pricing: pricingWithLadder().copyWith(
          rateSteps: const <RentalRateStep>[],
        ),
        requestedMinutes: 1440,
      ),
      isNull,
    );
  });

  test('deposit zero/nonzero is an explicit, distinguishable state', () {
    final RentalDepositPolicy zero = RentalDepositPolicy(
      amount: Money(minorUnits: 0, currency: CurrencyCode.parse('EUR')),
      collectionMethod: RentalDepositCollectionMethod.none,
    );
    final RentalDepositPolicy nonzero = pricingWithLadder().deposit;

    expect(zero.isZero, isTrue);
    expect(nonzero.isZero, isFalse);
  });
}
