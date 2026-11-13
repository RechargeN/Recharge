class ActivityCreateStepConfig {
  const ActivityCreateStepConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
}

/// Matches spec §11: Step 1 (basics + media), Step 2 (location & access),
/// Step 3 (when & for whom), Step 4 (preview & publish). The spec's entry
/// "Step 0 guard" is routing/auth logic in CreateController, not a stepper
/// index — same convention as Place, whose 3-step `placeCreateSteps` also
/// excludes its entry guard.
const List<ActivityCreateStepConfig> activityCreateSteps =
    <ActivityCreateStepConfig>[
      ActivityCreateStepConfig(
        id: 'basics',
        titleId: 'createStepActivityBasicsTitle',
        descriptionId: 'createStepActivityBasicsDescription',
      ),
      ActivityCreateStepConfig(
        id: 'location',
        titleId: 'createStepActivityLocationTitle',
        descriptionId: 'createStepActivityLocationDescription',
      ),
      ActivityCreateStepConfig(
        id: 'whenFor',
        titleId: 'createStepActivityWhenForTitle',
        descriptionId: 'createStepActivityWhenForDescription',
      ),
      ActivityCreateStepConfig(
        id: 'publish',
        titleId: 'createStepActivityPublishTitle',
        descriptionId: 'createStepActivityPublishDescription',
      ),
    ];
