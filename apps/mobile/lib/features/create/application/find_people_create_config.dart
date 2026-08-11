class FindPeopleCreateStepConfig {
  const FindPeopleCreateStepConfig({
    required this.id,
    required this.title,
    required this.description,
    required this.iconKey,
  });

  final String id;
  final String title;
  final String description;
  final String iconKey;
}

const List<FindPeopleCreateStepConfig>
findPeopleCreateSteps = <FindPeopleCreateStepConfig>[
  FindPeopleCreateStepConfig(
    id: 'activity',
    title: 'Activity',
    description: 'Describe what you want to do and who it suits.',
    iconKey: 'activity',
  ),
  FindPeopleCreateStepConfig(
    id: 'schedule',
    title: 'When',
    description: 'Choose one time, a poll, or a finite recurring series.',
    iconKey: 'schedule',
  ),
  FindPeopleCreateStepConfig(
    id: 'meeting',
    title: 'Where',
    description: 'Keep the public area separate from private meeting details.',
    iconKey: 'meeting',
  ),
  FindPeopleCreateStepConfig(
    id: 'group',
    title: 'Group',
    description:
        'Set capacity, applications, verification, waitlist, and costs.',
    iconKey: 'group',
  ),
  FindPeopleCreateStepConfig(
    id: 'hosts',
    title: 'Hosts & access',
    description: 'Configure publisher, visibility, communication, and sharing.',
    iconKey: 'hosts',
  ),
  FindPeopleCreateStepConfig(
    id: 'publish',
    title: 'Preview & publish',
    description:
        'Review public/private data and complete safety confirmations.',
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
