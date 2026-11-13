class FindPeopleCreateStepConfig {
  const FindPeopleCreateStepConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
    required this.iconKey,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
  final String iconKey;
}

const List<FindPeopleCreateStepConfig> findPeopleCreateSteps =
    <FindPeopleCreateStepConfig>[
      FindPeopleCreateStepConfig(
        id: 'activity',
        titleId: 'createStepFindPeopleActivityTitle',
        descriptionId: 'createStepFindPeopleActivityDescription',
        iconKey: 'activity',
      ),
      FindPeopleCreateStepConfig(
        id: 'schedule',
        titleId: 'createStepFindPeopleScheduleTitle',
        descriptionId: 'createStepFindPeopleScheduleDescription',
        iconKey: 'schedule',
      ),
      FindPeopleCreateStepConfig(
        id: 'meeting',
        titleId: 'createStepFindPeopleMeetingTitle',
        descriptionId: 'createStepFindPeopleMeetingDescription',
        iconKey: 'meeting',
      ),
      FindPeopleCreateStepConfig(
        id: 'group',
        titleId: 'createStepFindPeopleGroupTitle',
        descriptionId: 'createStepFindPeopleGroupDescription',
        iconKey: 'group',
      ),
      FindPeopleCreateStepConfig(
        id: 'hosts',
        titleId: 'createStepFindPeopleHostsTitle',
        descriptionId: 'createStepFindPeopleHostsDescription',
        iconKey: 'hosts',
      ),
      FindPeopleCreateStepConfig(
        id: 'publish',
        titleId: 'createStepFindPeoplePublishTitle',
        descriptionId: 'createStepFindPeoplePublishDescription',
        iconKey: 'publish',
      ),
    ];

const Set<String> findPeopleHouseRuleOptions = <String>{
  'be_on_time',
  'respect_boundaries',
  'no_harassment',
  'no_sales',
  'no_substances',
  'bring_required_gear',
  'follow_venue_rules',
  'leave_no_trace',
};
