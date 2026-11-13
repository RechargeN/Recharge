import '../domain/entities/rental_draft_data.dart';
import '../domain/entities/rental_validation_issue.dart';
import 'rental_section_disclosure.dart';

class RentalHandoverSectionDefinition {
  const RentalHandoverSectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
}

const RentalHandoverSectionDefinition rentalHandoverSectionDefinition =
    RentalHandoverSectionDefinition(
      id: 'rental_handover',
      stepId: 'handover',
      featureFlag: 'rental_create',
    );

class RentalHandoverSectionState {
  const RentalHandoverSectionState({
    required this.enabled,
    required this.handover,
    required this.disclosures,
    required this.issues,
  });

  final bool enabled;
  final RentalHandoverDraft handover;
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
