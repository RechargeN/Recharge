class CollectionCreateStepConfig {
  const CollectionCreateStepConfig({
    required this.id,
    required this.titleId,
    required this.descriptionId,
  });

  final String id;

  /// ARB message ids; the UI resolves them with `createFormText` (L4).
  final String titleId;
  final String descriptionId;
}

/// Matches COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §7: Step 0 (entry guard) is
/// routing/capability logic in CreateController, not a stepper index — same
/// convention as Activity/Place, so this list holds exactly the five
/// user-facing steps.
const List<CollectionCreateStepConfig> collectionCreateSteps =
    <CollectionCreateStepConfig>[
      CollectionCreateStepConfig(
        id: 'basics',
        titleId: 'createStepCollectionBasicsTitle',
        descriptionId: 'createStepCollectionBasicsDescription',
      ),
      CollectionCreateStepConfig(
        id: 'items',
        titleId: 'createStepCollectionItemsTitle',
        descriptionId: 'createStepCollectionItemsDescription',
      ),
      CollectionCreateStepConfig(
        id: 'curatorNotes',
        titleId: 'createStepCollectionCuratorNotesTitle',
        descriptionId: 'createStepCollectionCuratorNotesDescription',
      ),
      CollectionCreateStepConfig(
        id: 'budget',
        titleId: 'createStepCollectionBudgetTitle',
        descriptionId: 'createStepCollectionBudgetDescription',
      ),
      CollectionCreateStepConfig(
        id: 'publish',
        titleId: 'createStepCollectionPublishTitle',
        descriptionId: 'createStepCollectionPublishDescription',
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
    this.collectionPublishingEnabled = true,
    this.collectionDiscoverEnabled = true,
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
  /// `collectionPublishingEnabled`/`collectionDiscoverEnabled` defaulted to
  /// `false` while CLG-CRT-01's own persistence-correctness gates (§12/§17,
  /// closed by CLG-PST-01/CLG-PST-02) were still open; both now default to
  /// `true` — publishing and Discover are live. Set either back to `false`
  /// at the one composition-root call site (`service_locator.dart`) for an
  /// emergency rollback; it stays a real, tested code path, not a removed
  /// one — see `collection_discover_default_composition_test.dart`'s
  /// rollback-direction case and
  /// `collection_create_controller_test.dart`'s
  /// `collectionPublishingEnabled:false` case.
  final bool collectionCreateEnabled;
  final bool collectionPublishingEnabled;
  final bool collectionDiscoverEnabled;
}
