import '../domain/entities/rental_draft_data.dart';
import '../domain/entities/rental_validation_issue.dart';
import 'rental_create_config.dart';
import 'rental_section_disclosure.dart';

class RentalTermsSectionDefinition {
  const RentalTermsSectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
}

const RentalTermsSectionDefinition rentalTermsSectionDefinition =
    RentalTermsSectionDefinition(
      id: 'rental_terms',
      stepId: 'terms',
      featureFlag: 'rental_create',
    );

class RentalTermsSectionState {
  const RentalTermsSectionState({
    required this.enabled,
    required this.terms,
    this.adaptiveHint,
    required this.disclosures,
    required this.issues,
  });

  final bool enabled;
  final RentalTerms terms;

  /// Category-driven suggestion (spec §7 adaptive table) — editable,
  /// never auto-applied without Creator action.
  final RentalAdaptiveHint? adaptiveHint;
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
