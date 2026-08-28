class CollectionCreateStepConfig {
  const CollectionCreateStepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

/// Matches COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §7: Step 0 (entry guard) is
/// routing/capability logic in CreateController, not a stepper index — same
/// convention as Activity/Place, so this list holds exactly the five
/// user-facing steps.
const List<CollectionCreateStepConfig> collectionCreateSteps =
    <CollectionCreateStepConfig>[
      CollectionCreateStepConfig(
        id: 'basics',
        title: 'Basics & media',
        description: 'Title, pitch, cover and area',
      ),
      CollectionCreateStepConfig(
        id: 'items',
        title: 'Items',
        description: 'Search and add existing places, routes and more',
      ),
      CollectionCreateStepConfig(
        id: 'curatorNotes',
        title: 'Curator notes',
        description: 'Say why each item is here and pick your highlights',
      ),
      CollectionCreateStepConfig(
        id: 'budget',
        title: 'Budget & publisher',
        description: 'Set a budget hint, publisher, market and visibility',
      ),
      CollectionCreateStepConfig(
        id: 'publish',
        title: 'Preview & publish',
        description: 'Review the composition and send',
      ),
    ];

/// Every limit, threshold and kill switch for CLG-CRT-01, in one injectable
/// place (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §3.9, §15 "Конфигурационные
/// константы"). Nothing in the coordinator, usecases or widgets hardcodes
/// these values — they are always read from an instance of this class.
class CollectionCreateRuntimeConfig {
  const CollectionCreateRuntimeConfig({
    this.minPublishableItemCount = 3,
    this.curatorNoteMaxLength = 300,
    this.selfPublisherShareWarningThreshold = 0.5,
    this.itemCountSoftWarningThreshold = 30,
    this.budgetSuggestionMinPriceCoverage = 0.5,
    this.budgetSuggestionMinPriceCount = 2,
    this.maximumHistoryEntries = 50,
    this.collectionCreateEnabled = true,
    this.collectionPublishingEnabled = false,
    this.collectionDiscoverEnabled = false,
  });

  /// Вопрос 4 — publish-time gate, not a continuously enforced invariant.
  final int minPublishableItemCount;

  /// Вопрос 7 — Unicode grapheme clusters, not UTF-16 code units.
  final int curatorNoteMaxLength;

  /// Вопрос 3 — non-blocking self-promotion warning threshold.
  final double selfPublisherShareWarningThreshold;

  /// Вопрос 5 — soft warning starts on the (threshold + 1)-th item.
  final int itemCountSoftWarningThreshold;

  /// Вопрос 18 — minimum share of ready items with a normative price
  /// required before `CollectionBudgetSuggestionPolicy` proposes a tier.
  final double budgetSuggestionMinPriceCoverage;

  /// Вопрос 18 — minimum absolute number of priced items required.
  final int budgetSuggestionMinPriceCount;

  /// Bound on the coordinator's undo/redo history (§8).
  final int maximumHistoryEntries;

  /// Rollback flags (§15 "Миграция и rollback"). Disabling a flag never
  /// deletes drafts or active local records — it only gates the surface.
  final bool collectionCreateEnabled;
  final bool collectionPublishingEnabled;
  final bool collectionDiscoverEnabled;
}
