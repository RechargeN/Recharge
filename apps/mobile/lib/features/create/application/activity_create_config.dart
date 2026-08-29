class ActivityCreateStepConfig {
  const ActivityCreateStepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
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
        title: 'About',
        description: 'Title, category and media',
      ),
      ActivityCreateStepConfig(
        id: 'location',
        title: 'Location',
        description: 'Where to go and how to get there',
      ),
      ActivityCreateStepConfig(
        id: 'whenFor',
        title: 'When & for whom',
        description: 'Best time, duration and group size',
      ),
      ActivityCreateStepConfig(
        id: 'publish',
        title: 'Publish',
        description: 'Preview and send',
      ),
    ];
