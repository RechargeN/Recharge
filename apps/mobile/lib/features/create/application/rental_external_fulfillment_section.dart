import '../domain/entities/rental_draft_data.dart';
import '../domain/entities/rental_validation_issue.dart';
import 'rental_section_disclosure.dart';

class RentalExternalFulfillmentSectionDefinition {
  const RentalExternalFulfillmentSectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
}

const RentalExternalFulfillmentSectionDefinition
rentalExternalFulfillmentSectionDefinition =
    RentalExternalFulfillmentSectionDefinition(
      id: 'rental_fulfillment',
      stepId: 'fulfillment',
      featureFlag: 'rental_create',
    );

class RentalExternalFulfillmentSectionState {
  const RentalExternalFulfillmentSectionState({
    required this.enabled,
    required this.fulfillment,
    this.destinationHost,
    required this.disclosures,
    required this.issues,
  });

  final bool enabled;
  final RentalExternalFulfillment fulfillment;

  /// Host derived from the normalized URL only, for the "leaving Recharge"
  /// warning copy (spec §12) — never a Creator-supplied trusted label.
  final String? destinationHost;
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
