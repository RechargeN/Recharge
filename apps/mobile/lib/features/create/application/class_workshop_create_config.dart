/// One declarative section of the Class / Workshop Create block (D3.6, CW-V1).
class ClassWorkshopCreateSectionConfig {
  const ClassWorkshopCreateSectionConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
}

/// CW-V1 sections on one scrollable page, rendered by the shared Create page
/// like the other typed blocks (AGENTS rule 4): no separate flow per type.
const List<ClassWorkshopCreateSectionConfig> classWorkshopCreateSections =
    <ClassWorkshopCreateSectionConfig>[
      ClassWorkshopCreateSectionConfig(
        id: 'basics',
        titleId: 'createStepClassWorkshopBasicsTitle',
        descriptionId: 'createStepClassWorkshopBasicsDescription',
      ),
      ClassWorkshopCreateSectionConfig(
        id: 'learning',
        titleId: 'createStepClassWorkshopLearningTitle',
        descriptionId: 'createStepClassWorkshopLearningDescription',
      ),
      ClassWorkshopCreateSectionConfig(
        id: 'schedule',
        titleId: 'createStepClassWorkshopScheduleTitle',
        descriptionId: 'createStepClassWorkshopScheduleDescription',
      ),
      ClassWorkshopCreateSectionConfig(
        id: 'participation',
        titleId: 'createStepClassWorkshopParticipationTitle',
        descriptionId: 'createStepClassWorkshopParticipationDescription',
      ),
    ];
