import '../domain/entities/rental_draft_data.dart';
import '../domain/entities/rental_validation_issue.dart';
import '../domain/usecases/evaluate_rental_availability_usecase.dart';
import 'rental_section_disclosure.dart';

class RentalAvailabilitySectionDefinition {
  const RentalAvailabilitySectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
}

const RentalAvailabilitySectionDefinition rentalAvailabilitySectionDefinition =
    RentalAvailabilitySectionDefinition(
      id: 'rental_availability',
      stepId: 'availability',
      featureFlag: 'rental_create',
    );

class RentalAvailabilitySectionState {
  const RentalAvailabilitySectionState({
    required this.enabled,
    required this.calendar,
    this.lastAssessment,
    required this.disclosures,
    required this.issues,
  });

  final bool enabled;
  final RentalAvailabilityCalendar calendar;

  /// Last preview computed by `EvaluateRentalAvailabilityUseCase` for the
  /// Creator's own confirmation UI — never a promise shown to renters from
  /// this section directly.
  final RentalAvailabilityAssessment? lastAssessment;
  final List<RentalSectionDisclosure> disclosures;
  final List<RentalValidationIssue> issues;

  bool get hasFreshCoverage => calendar.coverage != null;

  String? errorFor(String fieldId) {
    for (final RentalValidationIssue issue in issues) {
      if (issue.isBlocking && issue.fieldId == fieldId) {
        return issue.messageKey;
      }
    }
    return null;
  }
}
