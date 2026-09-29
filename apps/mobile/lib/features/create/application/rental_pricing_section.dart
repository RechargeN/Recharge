import '../domain/entities/rental_draft_data.dart';
import '../domain/entities/rental_validation_issue.dart';
import '../domain/usecases/estimate_rental_rate_usecase.dart';
import 'rental_section_disclosure.dart';

class RentalPricingSectionDefinition {
  const RentalPricingSectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
}

const RentalPricingSectionDefinition rentalPricingSectionDefinition =
    RentalPricingSectionDefinition(
      id: 'rental_pricing',
      stepId: 'pricing',
      featureFlag: 'rental_create',
    );

class RentalPricingSectionState {
  const RentalPricingSectionState({
    required this.enabled,
    required this.pricing,
    this.exampleEstimate,
    required this.disclosures,
    required this.issues,
  });

  final bool enabled;
  final RentalPricingPolicy pricing;

  /// Informational example computed by `EstimateRentalRateUseCase` for a
  /// representative duration, shown so Creator can sanity-check the rate
  /// ladder before publishing (spec §11 "immediate deterministic examples").
  final RentalRateEstimate? exampleEstimate;
  final List<RentalSectionDisclosure> disclosures;
  final List<RentalValidationIssue> issues;

  String? errorFor(String fieldId) {
    for (final RentalValidationIssue issue in issues) {
      if (issue.isBlocking && issue.fieldId == fieldId) {
        return issue.messageKey;
      }
    }
    return null;
  }
}
