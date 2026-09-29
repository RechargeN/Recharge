import '../domain/entities/rental_draft_data.dart';
import '../domain/entities/rental_validation_issue.dart';
import 'rental_section_disclosure.dart';

class RentalInventorySectionDefinition {
  const RentalInventorySectionDefinition({
    required this.id,
    required this.stepId,
    required this.featureFlag,
  });

  final String id;
  final String stepId;
  final String featureFlag;
}

const RentalInventorySectionDefinition rentalInventorySectionDefinition =
    RentalInventorySectionDefinition(
      id: 'rental_inventory',
      stepId: 'inventory',
      featureFlag: 'rental_create',
    );

class RentalInventorySectionState {
  const RentalInventorySectionState({
    required this.enabled,
    required this.groups,
    required this.disclosures,
    required this.issues,
  });

  final bool enabled;
  final List<RentalInventoryGroup> groups;
  final List<RentalSectionDisclosure> disclosures;
  final List<RentalValidationIssue> issues;

  int get totalUnits => groups
      .where(
        (RentalInventoryGroup g) => g.status == RentalUnitGroupStatus.available,
      )
      .fold(0, (int sum, RentalInventoryGroup g) => sum + g.quantity);

  String? errorFor(String fieldId) {
    for (final RentalValidationIssue issue in issues) {
      if (issue.isBlocking && issue.fieldId == fieldId) {
        return issue.messageKey;
      }
    }
    return null;
  }
}
