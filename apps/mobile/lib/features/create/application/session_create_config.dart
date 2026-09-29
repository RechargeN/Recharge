import '../domain/entities/session_schedule.dart';

class SessionCreateBlockConfig {
  const SessionCreateBlockConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

/// Matches BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md §12 v1.1: guard + three
/// required blocks on one scrollable page, not a step wizard. Kept as a
/// config list (like every other Create type's step config) so the
/// presentation layer can render a progress rail even though nothing here
/// gates navigation between blocks.
const List<SessionCreateBlockConfig> sessionCreateBlocks =
    <SessionCreateBlockConfig>[
      SessionCreateBlockConfig(
        id: 'whatWhere',
        title: 'What and where',
        description: 'Resource, category, media, location, timezone',
      ),
      SessionCreateBlockConfig(
        id: 'when',
        title: 'When',
        description: 'Weekly schedule, duration, buffer, notice',
      ),
      SessionCreateBlockConfig(
        id: 'priceAndBooking',
        title: 'Price and booking',
        description: 'Price, max party size, external booking URL',
      ),
    ];

/// One tap weekly-schedule presets (§12 Блок 2, §3.2 Calendly reference).
class SessionWeeklyPreset {
  const SessionWeeklyPreset({
    required this.id,
    required this.label,
    required this.activeWeekdays,
    required this.startMinuteLocal,
    required this.endMinuteLocalExclusive,
  });

  final String id;
  final String label;
  final Set<int> activeWeekdays;
  final int startMinuteLocal;
  final int endMinuteLocalExclusive;

  List<SessionWeeklyRule> buildRules(String Function() nextId) => [
    for (final int weekday in activeWeekdays)
      SessionWeeklyRule(
        id: nextId(),
        isoWeekday: weekday,
        startMinuteLocal: startMinuteLocal,
        endMinuteLocalExclusive: endMinuteLocalExclusive,
      ),
  ];
}

const Set<int> _everyDay = <int>{1, 2, 3, 4, 5, 6, 7};
const Set<int> _weekdaysOnly = <int>{1, 2, 3, 4, 5};

const List<SessionWeeklyPreset> sessionWeeklyPresets = <SessionWeeklyPreset>[
  SessionWeeklyPreset(
    id: 'everyday_9_21',
    label: 'Every day 9:00–21:00',
    activeWeekdays: _everyDay,
    startMinuteLocal: 9 * 60,
    endMinuteLocalExclusive: 21 * 60,
  ),
  SessionWeeklyPreset(
    id: 'weekdays_9_18',
    label: 'Weekdays 9:00–18:00',
    activeWeekdays: _weekdaysOnly,
    startMinuteLocal: 9 * 60,
    endMinuteLocalExclusive: 18 * 60,
  ),
];

/// Adaptive, non-blocking hints per category (§7). Creator sees these as a
/// pre-filled default and can change every one of them.
class SessionCategoryHint {
  const SessionCategoryHint({
    this.defaultSlotDurationMinutes = 60,
    this.defaultBufferAfterSlotMinutes = 0,
    this.defaultMaxPartySize = 4,
  });

  final int defaultSlotDurationMinutes;
  final int defaultBufferAfterSlotMinutes;
  final int defaultMaxPartySize;
}

const Map<String, SessionCategoryHint> sessionCategoryHints =
    <String, SessionCategoryHint>{
      'wellness_recharge': SessionCategoryHint(
        defaultSlotDurationMinutes: 60,
        defaultMaxPartySize: 6,
      ),
      'sport': SessionCategoryHint(
        defaultSlotDurationMinutes: 60,
        defaultBufferAfterSlotMinutes: 10,
        defaultMaxPartySize: 4,
      ),
      'pet_event': SessionCategoryHint(
        defaultSlotDurationMinutes: 60,
        defaultMaxPartySize: 1,
      ),
    };

SessionCategoryHint sessionHintForCategory(String categoryId) =>
    sessionCategoryHints[categoryId] ?? const SessionCategoryHint();
