/// One declarative section of the Class / Workshop Create block (D3.6, CW-V1).
class ClassWorkshopCreateSectionConfig {
  const ClassWorkshopCreateSectionConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

/// CW-V1 sections on one scrollable page, rendered by the shared Create page
/// like the other typed blocks (AGENTS rule 4): no separate flow per type.
const List<ClassWorkshopCreateSectionConfig> classWorkshopCreateSections =
    <ClassWorkshopCreateSectionConfig>[
      ClassWorkshopCreateSectionConfig(
        id: 'basics',
        title: 'Offering',
        description: 'Kind, title, descriptions, category, criteria and media',
      ),
      ClassWorkshopCreateSectionConfig(
        id: 'learning',
        title: 'Programme and instructor',
        description: 'Outcomes, programme, prerequisites and instructor',
      ),
      ClassWorkshopCreateSectionConfig(
        id: 'schedule',
        title: 'Dates and place',
        description: 'Single class or fixed series, timezone, delivery, place',
      ),
      ClassWorkshopCreateSectionConfig(
        id: 'participation',
        title: 'Participation',
        description: 'Materials, requirements, group size, price, enrollment',
      ),
    ];
