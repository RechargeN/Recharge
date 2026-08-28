import '../../../shared/primitives/id/id_generator.dart';
import '../domain/entities/collection_draft_data.dart';
import '../domain/entities/collection_item_draft.dart';
import '../domain/entities/collection_moderation_request.dart';
import '../domain/entities/collection_publication_data.dart';
import '../domain/entities/collection_validation_issue.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/entities/location_search_suggestion.dart';
import '../domain/repositories/collection_catalog_search_repository.dart';
import '../domain/repositories/collection_publication_repository.dart';
import '../domain/repositories/location_search_repository.dart';
import '../domain/usecases/build_collection_publication_bundle_usecase.dart';
import '../domain/usecases/remove_collection_items_only_usecase.dart';
import '../domain/usecases/validate_collection_draft_usecase.dart';
import 'collection_budget_suggestion_policy.dart';
import 'collection_create_config.dart';
import 'state/collection_create_state.dart';

/// Drives one Collection draft through search → curate → review → publish
/// (COLLECTION_GUIDE_CREATE_BLOCK_SPEC.md §7, §8). A plain synchronous state
/// holder, same shape as `RouteCreateCoordinator` — the surrounding
/// Riverpod controller owns re-render notification, this class owns the
/// domain-correct transitions.
///
/// Wired into the app runtime through
/// `CreateController.attachCollectionCoordinator`/its Collection command
/// section — this class itself performs no capability checks and calls no
/// analytics; per §6 and §15 ("Telemetry и privacy") those are the
/// controller's job alone, so the same coordinator instance stays reusable
/// against mock repositories in isolation, unmodified by that split.
///
/// Soft, non-blocking §11 warnings (self-publisher share, item count, empty
/// curator notes) are reported by `validate()` through
/// `ValidateCollectionDraftUseCase`. Budget-tier mismatch is deliberately
/// *not* one of them — it is only ever a suggestion the author can accept
/// via `suggestBudgetTier()`/`setBudgetIndicator`, never a validation issue,
/// since "the author hasn't accepted a suggestion yet" is not itself a
/// problem with the draft.
class CollectionCreateCoordinator {
  CollectionCreateCoordinator({
    required IdGenerator idGenerator,
    required CollectionCatalogSearchRepository catalogSearchRepository,
    required CollectionPublicationRepository publicationRepository,
    required LocationSearchRepository locationSearchRepository,
    this.config = const CollectionCreateRuntimeConfig(),
    ValidateCollectionDraftUseCase? validateDraft,
    BuildCollectionPublicationBundleUseCase? buildBundle,
    this.removeItemsOnly = const RemoveCollectionItemsOnlyUseCase(),
    CollectionBudgetSuggestionPolicy budgetSuggestionPolicy =
        const CollectionBudgetSuggestionPolicy(),
    MarketBudgetTierConfig marketBudgetConfig = _demoRigaMarketBudgetConfig,
    DateTime Function()? clock,
  }) : _idGenerator = idGenerator,
       _catalogSearchRepository = catalogSearchRepository,
       _publicationRepository = publicationRepository,
       _locationSearchRepository = locationSearchRepository,
       _validateDraft =
           validateDraft ??
           ValidateCollectionDraftUseCase(
             minPublishableItemCount: config.minPublishableItemCount,
             curatorNoteMaxLength: config.curatorNoteMaxLength,
             selfPublisherShareWarningThreshold:
                 config.selfPublisherShareWarningThreshold,
             itemCountSoftWarningThreshold:
                 config.itemCountSoftWarningThreshold,
           ),
       _buildBundle =
           buildBundle ??
           BuildCollectionPublicationBundleUseCase(idGenerator: idGenerator),
       _budgetSuggestionPolicy = budgetSuggestionPolicy,
       _marketBudgetConfig = marketBudgetConfig,
       _clock = clock ?? DateTime.now;

  /// Demo Riga/EUR thresholds (§15 "Конфигурационные константы" — runtime
  /// defaults, not a UI literal): median ≤ €10 → `low`, ≤ €50 → `medium`,
  /// above → `high`.
  static const MarketBudgetTierConfig _demoRigaMarketBudgetConfig =
      MarketBudgetTierConfig(
        marketCityId: 'riga',
        currency: 'EUR',
        lowMaxMinorUnits: 1000,
        mediumMaxMinorUnits: 5000,
      );

  final IdGenerator _idGenerator;
  final CollectionCatalogSearchRepository _catalogSearchRepository;
  final CollectionPublicationRepository _publicationRepository;
  final LocationSearchRepository _locationSearchRepository;
  final CollectionCreateRuntimeConfig config;
  final ValidateCollectionDraftUseCase _validateDraft;
  final BuildCollectionPublicationBundleUseCase _buildBundle;
  final CollectionBudgetSuggestionPolicy _budgetSuggestionPolicy;
  final MarketBudgetTierConfig _marketBudgetConfig;
  final RemoveCollectionItemsOnlyUseCase removeItemsOnly;
  final DateTime Function() _clock;

  CollectionCreateState? _stateOrNull;
  int _searchOperationSeq = 0;
  int _locationSearchOperationSeq = 0;

  /// §12 idempotency key: stable across repeated `publish()` calls for the
  /// *same* draft revision (a retry after a transient failure, a double
  /// tap) — only regenerated once a real mutation bumps `state.revision`.
  /// Minting a fresh key on every call, as an earlier version of this
  /// coordinator did, defeated the repository/datasource idempotency
  /// contract entirely (every retry looked like a brand new publish).
  String? _publishAttemptId;
  String? _publishAttemptVersionId;
  int? _publishAttemptRevision;

  CollectionCreateState get state {
    final CollectionCreateState? value = _stateOrNull;
    if (value == null) {
      throw StateError('CollectionCreateCoordinator is not initialized.');
    }
    return value;
  }

  void initialize({required CreateDraftEntity createDraft}) {
    if (createDraft.objectType != CreateObjectType.collection ||
        createDraft.collectionData == null) {
      throw ArgumentError('A Collection draft is required.');
    }
    _stateOrNull = CollectionCreateState(
      status: CollectionCreateStatus.editing,
      createDraft: createDraft,
      revision: 0,
      persistedRevision: 0,
    );
  }

  /// Keeps this coordinator's internal `collectionData` authoritative when
  /// a shared-envelope field (title, media, market, visibility…) changes
  /// through `CreateController`'s generic `_updateDraft` path instead of a
  /// coordinator command — same fix Route applies for the same reason.
  void synchronizeEnvelope(CreateDraftEntity createDraft) {
    final CollectionCreateState current = state;
    if (createDraft.objectType != CreateObjectType.collection ||
        createDraft.id != current.createDraft.id) {
      throw ArgumentError('The Collection envelope must keep its draft identity.');
    }
    _stateOrNull = current.copyWith(
      createDraft: createDraft.copyWith(collectionData: current.collectionData),
    );
  }

  /// Location step (§7 Шаг 1) — a display/fallback field, not part of the
  /// composition; does not invalidate `CollectionCompositionReview`.
  void setAreaLabel(String value) {
    _mutate(
      CollectionEditCommandKind.setArea,
      (CollectionDraftData data) => data.copyWith(areaLabel: value),
      invalidatesReview: false,
    );
  }

  void setAreaId(String? value) {
    _mutate(
      CollectionEditCommandKind.setArea,
      (CollectionDraftData data) => value == null
          ? data.copyWith(clearAreaId: true)
          : data.copyWith(areaId: value),
      invalidatesReview: false,
    );
  }

  /// Sets the single area-anchor pin (§10 area-boost ranking, Discover mini
  /// map fallback center) — not the location of any individual item, so
  /// (like the rest of §7 Шаг 1) it does not invalidate the composition
  /// review.
  void setAreaAnchor({required double latitude, required double longitude}) {
    _mutate(
      CollectionEditCommandKind.setArea,
      (CollectionDraftData data) => data.copyWith(
        anchorLatitude: latitude,
        anchorLongitude: longitude,
      ),
      invalidatesReview: false,
    );
  }

  // ---------------------------------------------------------------------
  // Area location search (Basics step — typed name search that prefills the
  // anchor pin; a manual map tap always remains available and always wins).
  // ---------------------------------------------------------------------

  Future<void> searchAreaLocation(String query) async {
    final int myOperation = ++_locationSearchOperationSeq;
    _stateOrNull = state.copyWith(areaLocationSearchLoading: true);
    List<LocationSearchSuggestion> results;
    try {
      results = await _locationSearchRepository.search(
        query,
        marketCityId: state.createDraft.marketCityId,
      );
    } catch (_) {
      results = const <LocationSearchSuggestion>[];
    }
    if (myOperation != _locationSearchOperationSeq) return; // superseded
    _stateOrNull = state.copyWith(
      areaLocationSuggestions: results,
      areaLocationSearchLoading: false,
    );
  }

  void clearAreaLocationSuggestions() {
    _stateOrNull = state.copyWith(
      areaLocationSuggestions: const <LocationSearchSuggestion>[],
      areaLocationSearchLoading: false,
    );
  }

  /// Resolves [suggestionId] and applies it as the area anchor. Errors are
  /// swallowed on purpose — the author still has the manual map tap.
  Future<void> selectAreaLocationSuggestion(String suggestionId) async {
    final int myOperation = ++_locationSearchOperationSeq;
    LocationSearchResolution resolution;
    try {
      resolution = await _locationSearchRepository.resolve(suggestionId);
    } catch (_) {
      return;
    }
    if (myOperation != _locationSearchOperationSeq) return; // superseded
    setAreaAnchor(
      latitude: resolution.latitude,
      longitude: resolution.longitude,
    );
    clearAreaLocationSuggestions();
  }

  // ---------------------------------------------------------------------
  // Catalog search (§7 Шаг 2, §10)
  // ---------------------------------------------------------------------

  Future<void> searchCatalog(
    String text, {
    Set<CollectionCatalogObjectType>? types,
  }) async {
    final CollectionCreateState current = state;
    final int myOperation = ++_searchOperationSeq;
    final int myRevision = current.revision;
    final CollectionDraftData data = current.collectionData;
    _stateOrNull = current.copyWith(
      status: CollectionCreateStatus.searchingCatalog,
    );
    final CollectionCatalogSearchQuery query = CollectionCatalogSearchQuery(
      text: text,
      allowedTypes: types ?? CollectionCatalogObjectType.values.toSet(),
      marketCityId: current.createDraft.marketCityId,
      areaId: data.areaId,
      areaLabel: data.areaLabel.isEmpty ? null : data.areaLabel,
      excludeRefs: data.items.map((CollectionItemDraft i) => i.ref).toSet(),
    );
    List<CollectionCatalogSearchResult> results;
    try {
      results = await _catalogSearchRepository.search(query);
    } catch (_) {
      if (myOperation != _searchOperationSeq) return; // superseded
      _stateOrNull = state.copyWith(status: CollectionCreateStatus.editing);
      return;
    }
    if (myOperation != _searchOperationSeq || myRevision != state.revision) {
      return; // a newer search or a draft mutation arrived first
    }
    _stateOrNull = state.copyWith(
      status: CollectionCreateStatus.editing,
      searchResults: results,
    );
  }

  void clearCatalogSearch() {
    _stateOrNull = state.copyWith(
      searchResults: const <CollectionCatalogSearchResult>[],
    );
  }

  // ---------------------------------------------------------------------
  // Items and sections (§7 Шаг 2)
  // ---------------------------------------------------------------------

  void addItem(CollectionCatalogSearchResult result) {
    _mutate(CollectionEditCommandKind.addItem, (CollectionDraftData data) {
      final bool alreadyAdded = data.items.any(
        (CollectionItemDraft item) =>
            item.ref.stableKey == result.ref.stableKey,
      );
      if (alreadyAdded) return data;
      final CollectionItemDraft item = CollectionItemDraft(
        id: _idGenerator.generate(),
        ref: result.ref,
        snapshot: result.snapshot,
        sourceStatus: CollectionSourceStatus.ready,
        order: data.items.length,
      );
      return data.copyWith(
        items: _renumberItems(<CollectionItemDraft>[...data.items, item]),
      );
    });
  }

  void removeItem(String itemId) {
    _mutate(CollectionEditCommandKind.removeItem, (CollectionDraftData data) {
      final List<CollectionItemDraft> next = data.items
          .where((CollectionItemDraft item) => item.id != itemId)
          .toList(growable: false);
      if (next.length == data.items.length) return data;
      return data.copyWith(items: _renumberItems(next));
    });
  }

  void moveItem({
    required String itemId,
    String? toSectionId,
    required int toIndex,
  }) {
    _mutate(CollectionEditCommandKind.moveItem, (CollectionDraftData data) {
      final List<CollectionItemDraft> moved = _moveItemInList(
        data.items,
        itemId,
        toSectionId,
        toIndex,
      );
      return data.copyWith(items: moved);
    });
  }

  void addSection(String title) {
    _mutate(CollectionEditCommandKind.addSection, (CollectionDraftData data) {
      final CollectionSectionDraft section = CollectionSectionDraft(
        id: _idGenerator.generate(),
        title: title,
        order: data.sections.length,
      );
      return data.copyWith(
        sections: _renumberSections(<CollectionSectionDraft>[
          ...data.sections,
          section,
        ]),
      );
    });
  }

  void renameSection(String sectionId, String title) {
    _mutate(CollectionEditCommandKind.renameSection, (
      CollectionDraftData data,
    ) {
      bool found = false;
      final List<CollectionSectionDraft> sections = data.sections
          .map((CollectionSectionDraft section) {
            if (section.id != sectionId) return section;
            found = true;
            return section.copyWith(title: title);
          })
          .toList(growable: false);
      return found ? data.copyWith(sections: sections) : data;
    });
  }

  /// Removing a section unsections its items rather than deleting them —
  /// recoverable state, not destructive auto-cleanup (§3.6 principle
  /// applied consistently to authoring, not only to publish-time decay).
  void removeSection(String sectionId) {
    _mutate(CollectionEditCommandKind.removeSection, (
      CollectionDraftData data,
    ) {
      final bool exists = data.sections.any(
        (CollectionSectionDraft section) => section.id == sectionId,
      );
      if (!exists) return data;
      final List<CollectionSectionDraft> sections = _renumberSections(
        data.sections
            .where((CollectionSectionDraft section) => section.id != sectionId)
            .toList(growable: false),
      );
      final List<CollectionItemDraft> items = _renumberItems(
        data.items
            .map(
              (CollectionItemDraft item) => item.sectionId == sectionId
                  ? item.copyWith(clearSectionId: true)
                  : item,
            )
            .toList(growable: false),
      );
      return data.copyWith(sections: sections, items: items);
    });
  }

  void moveSection(String sectionId, int toIndex) {
    _mutate(CollectionEditCommandKind.moveSection, (CollectionDraftData data) {
      final List<CollectionSectionDraft> working =
          List<CollectionSectionDraft>.of(data.sections);
      final int fromIndex = working.indexWhere(
        (CollectionSectionDraft section) => section.id == sectionId,
      );
      if (fromIndex == -1) return data;
      final CollectionSectionDraft moved = working.removeAt(fromIndex);
      final int clamped = toIndex.clamp(0, working.length);
      working.insert(clamped, moved);
      return data.copyWith(sections: _renumberSections(working));
    });
  }

  void setCuratorNote(String itemId, String note) {
    _mutate(
      CollectionEditCommandKind.setCuratorNote,
      (CollectionDraftData data) => _updateItem(
        data,
        itemId,
        (CollectionItemDraft item) => item.copyWith(curatorNote: note),
      ),
    );
  }

  void toggleHighlight(String itemId) {
    _mutate(
      CollectionEditCommandKind.toggleHighlight,
      (CollectionDraftData data) => _updateItem(
        data,
        itemId,
        (CollectionItemDraft item) => item.copyWith(highlight: !item.highlight),
      ),
    );
  }

  /// Budget is a draft-level display field, not part of the composition —
  /// unlike item/section edits it does not invalidate
  /// `CollectionCompositionReview` (§9).
  void setBudgetIndicator(CollectionBudgetTier? tier) {
    _mutate(
      CollectionEditCommandKind.setBudgetIndicator,
      (CollectionDraftData data) => tier == null
          ? data.copyWith(clearBudgetTier: true)
          : data.copyWith(budgetTier: tier),
      invalidatesReview: false,
    );
  }

  /// A read-only suggestion (§7 Шаг 4, Вопрос 18) — never writes on its
  /// own. `null` means the policy has no confident suggestion (too few
  /// priced items, insufficient coverage, or mixed/unknown currency); the
  /// caller decides what to do with that, including leaving the field
  /// unset.
  CollectionBudgetTier? suggestBudgetTier() {
    return _budgetSuggestionPolicy.suggest(
      items: state.collectionData.items,
      marketConfig: _marketBudgetConfig,
    );
  }

  // ---------------------------------------------------------------------
  // Undo / redo (§8)
  // ---------------------------------------------------------------------

  void undo() {
    final CollectionCreateState current = state;
    if (current.undoStack.isEmpty) return;
    final CollectionHistoryEntry entry = current.undoStack.last;
    final List<CollectionHistoryEntry> undo = current.undoStack.sublist(
      0,
      current.undoStack.length - 1,
    );
    final List<CollectionHistoryEntry> redo = <CollectionHistoryEntry>[
      ...current.redoStack,
      entry,
    ];
    _stateOrNull = current.copyWith(
      createDraft: current.createDraft.copyWith(
        collectionData: entry.before.copyWith(clearCompositionReview: true),
      ),
      revision: current.revision + 1,
      undoStack: undo,
      redoStack: redo,
    );
  }

  void redo() {
    final CollectionCreateState current = state;
    if (current.redoStack.isEmpty) return;
    final CollectionHistoryEntry entry = current.redoStack.last;
    final List<CollectionHistoryEntry> redo = current.redoStack.sublist(
      0,
      current.redoStack.length - 1,
    );
    final List<CollectionHistoryEntry> undo = <CollectionHistoryEntry>[
      ...current.undoStack,
      entry,
    ];
    _stateOrNull = current.copyWith(
      createDraft: current.createDraft.copyWith(collectionData: entry.after),
      revision: current.revision + 1,
      undoStack: undo,
      redoStack: redo,
    );
  }

  // ---------------------------------------------------------------------
  // Preview, review and publish (§7 Шаг 5, §12)
  // ---------------------------------------------------------------------

  /// Re-resolves every item against the catalog and records the result on
  /// each item's `sourceStatus`/`snapshot`. A stale response (superseded by
  /// a later mutation) is discarded instead of overwriting newer state.
  Future<void> buildPreview() async {
    final CollectionCreateState current = state;
    final CollectionDraftData data = current.collectionData;
    if (data.items.isEmpty) return;
    final int myRevision = current.revision;
    final List<CollectionObjectRef> refs = data.items
        .map((CollectionItemDraft item) => item.ref)
        .toList(growable: false);
    Map<String, CollectionCatalogSearchResult> resolved;
    try {
      resolved = await _catalogSearchRepository.resolve(refs);
    } catch (_) {
      return;
    }
    if (myRevision != state.revision) return; // superseded
    final List<CollectionItemDraft> updated = data.items
        .map((CollectionItemDraft item) {
          final CollectionCatalogSearchResult? match =
              resolved[item.ref.stableKey];
          if (match == null) {
            return item.copyWith(
              sourceStatus: CollectionSourceStatus.unavailable,
            );
          }
          return item.copyWith(
            snapshot: match.snapshot,
            sourceStatus: CollectionSourceStatus.ready,
          );
        })
        .toList(growable: false);
    _stateOrNull = state.copyWith(
      createDraft: state.createDraft.copyWith(
        collectionData: data.copyWith(
          items: updated,
          clearCompositionReview: true,
        ),
      ),
    );
  }

  /// Records that the author reviewed the *current* live-resolved
  /// composition and knowingly accepts its unavailable items (§2, §9).
  /// Call only right after a successful `buildPreview()`.
  void acknowledgeCompositionReview() {
    final CollectionCreateState current = state;
    final CollectionDraftData data = current.collectionData;
    final Set<String> unavailable = data.items
        .where(
          (CollectionItemDraft item) =>
              item.sourceStatus == CollectionSourceStatus.unavailable,
        )
        .map((CollectionItemDraft item) => item.ref.stableKey)
        .toSet();
    final CollectionCompositionReview review = CollectionCompositionReview(
      draftRevision: current.revision,
      reviewedAtUtc: _clock(),
      acknowledgedUnavailableStableKeys: unavailable,
    );
    _stateOrNull = current.copyWith(
      createDraft: current.createDraft.copyWith(
        collectionData: data.copyWith(compositionReview: review),
      ),
    );
  }

  List<CollectionValidationIssue> validate() {
    final List<CollectionValidationIssue> issues = _validateDraft(
      state.createDraft,
    );
    final bool blocked = issues.any(
      (CollectionValidationIssue issue) =>
          issue.severity == CollectionValidationSeverity.error,
    );
    _stateOrNull = state.copyWith(
      issues: issues,
      status: blocked
          ? CollectionCreateStatus.editing
          : CollectionCreateStatus.readyToPublish,
    );
    return issues;
  }

  /// §6/§7 Шаг 5, §12: [direct] selects the write path only — capability
  /// gating happens one layer up, in `CreateController`, never here.
  /// [actorId] is the trusted-context actor for the idempotency key (§12)
  /// — never client-suppliable free text, always `CreateController`'s own
  /// loaded `userId`.
  Future<CollectionPublishReceipt> publish({
    required bool direct,
    required String actorId,
  }) async {
    final List<CollectionValidationIssue> issues = validate();
    if (issues.any(
      (CollectionValidationIssue issue) =>
          issue.severity == CollectionValidationSeverity.error,
    )) {
      throw StateError(
        'Cannot publish: draft still has blocking validation issues.',
      );
    }
    final CollectionCreateState beforePublish = state;
    _stateOrNull = beforePublish.copyWith(
      status: CollectionCreateStatus.publishing,
    );
    final bool isRetryOfSameAttempt =
        _publishAttemptId != null &&
        _publishAttemptRevision == beforePublish.revision;
    final String publishAttemptId = isRetryOfSameAttempt
        ? _publishAttemptId!
        : _idGenerator.generate();
    // Reuse the *exact* version id from the first attempt too — the
    // datasource's idempotency check compares a hash of the whole payload,
    // so a fresh `collectionVersionId` here would make a legitimate retry
    // look like a different payload under the same key (see the doc
    // comment on `BuildCollectionPublicationBundleUseCase.call`).
    final CollectionPublishBundle bundle = _buildBundle(
      draft: beforePublish.createDraft,
      publishAttemptId: publishAttemptId,
      collectionVersionId: isRetryOfSameAttempt
          ? _publishAttemptVersionId
          : null,
    );
    try {
      final CollectionPublishReceipt receipt = direct
          ? await _publicationRepository.publish(bundle, actorId: actorId)
          : await _publicationRepository.submitForReview(
              bundle,
              actorId: actorId,
            );
      _publishAttemptId = publishAttemptId;
      _publishAttemptVersionId = bundle.collectionVersionId;
      _publishAttemptRevision = beforePublish.revision;
      // ADR id-only-links invariant: a `loc_*` draft gets a permanent id at
      // its first publish/submit. Fix the draft itself so a later attempt —
      // same revision (a retry) or a later one (a new version) — reuses it
      // instead of `BuildCollectionPublicationBundleUseCase` minting a new
      // one on every call.
      final CreateDraftEntity draftWithPermanentId =
          beforePublish.createDraft.id == bundle.collectionId
          ? beforePublish.createDraft
          : beforePublish.createDraft.copyWith(id: bundle.collectionId);
      _stateOrNull = state.copyWith(
        createDraft: draftWithPermanentId,
        status: receipt.outcome == CollectionPublishOutcome.pendingReview
            ? CollectionCreateStatus.submittedForReview
            : CollectionCreateStatus.published,
        persistedRevision: beforePublish.revision,
        clearLastFailureCode: true,
      );
      return receipt;
    } on CollectionPublicationException catch (e) {
      _stateOrNull = state.copyWith(
        status: CollectionCreateStatus.failure,
        lastFailureCode: e.failure.name,
      );
      rethrow;
    }
  }

  /// §3.11 lifecycle command — distinct from removal-only; deactivates the
  /// Discover-facing version without publishing anything new. A no-op
  /// (returns `true`, trivially in sync) if this Collection was never
  /// published (including a `loc_*` draft that has no permanent id yet).
  /// Returns whether Discover ended up in sync — see the repository's own
  /// `archive` doc.
  Future<bool> archive() async {
    final String collectionId = state.createDraft.id;
    if (collectionId.startsWith('loc_')) return true;
    return _publicationRepository.archive(collectionId);
  }

  /// §6 moderation surface — process-wide, not scoped to this draft; a
  /// `moderate.collection` actor reviews every Collection awaiting a
  /// decision, not only the one this coordinator happens to be editing. No
  /// dedicated moderation page ships in this slice, but the command is real.
  Future<List<CollectionModerationRequest>> pendingModerationRequests() {
    return _publicationRepository.pendingRequests();
  }

  Future<CollectionModerationDecisionResult> decideModerationRequest({
    required String requestId,
    required bool accept,
    CollectionModerationRejectionReason? rejectionReason,
  }) {
    return _publicationRepository.decide(
      requestId: requestId,
      accept: accept,
      rejectionReason: rejectionReason,
    );
  }

  /// Self-service removal from the *published* active version (§3.11,
  /// Вопрос 19, final decision) — distinct from `removeItem`, which only
  /// edits the local draft on the way to the next full, moderated publish.
  /// Never touches `submit`/`moderate`; the reducer on the repository side
  /// narrows the active version, it does not accept a new one from here.
  /// Returns `null` if this Collection has never been published yet — there
  /// is no active version to remove from.
  Future<CollectionPublishReceipt?> removeItemsFromActiveVersion(
    Set<String> stableKeys,
  ) async {
    final String collectionId = state.createDraft.id;
    final PublishedCollectionVersion? active = await _publicationRepository
        .getActiveVersion(collectionId);
    if (active == null) return null;
    final CollectionRemovalOnlyCommand command = removeItemsOnly(
      activeVersion: active,
      removedItemStableKeys: stableKeys,
      requestId: _idGenerator.generate(),
    );
    return _publicationRepository.removeItemsOnly(command);
  }

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  CollectionDraftData _updateItem(
    CollectionDraftData data,
    String itemId,
    CollectionItemDraft Function(CollectionItemDraft item) update,
  ) {
    bool found = false;
    final List<CollectionItemDraft> items = data.items
        .map((CollectionItemDraft item) {
          if (item.id != itemId) return item;
          found = true;
          return update(item);
        })
        .toList(growable: false);
    return found ? data.copyWith(items: items) : data;
  }

  List<CollectionItemDraft> _moveItemInList(
    List<CollectionItemDraft> items,
    String itemId,
    String? toSectionId,
    int toIndex,
  ) {
    final List<CollectionItemDraft> working = List<CollectionItemDraft>.of(
      items,
    );
    final int fromIndex = working.indexWhere(
      (CollectionItemDraft item) => item.id == itemId,
    );
    if (fromIndex == -1) return items;
    final CollectionItemDraft moved = working
        .removeAt(fromIndex)
        .copyWith(sectionId: toSectionId, clearSectionId: toSectionId == null);
    int scopeSeen = 0;
    int insertAt = working.length;
    for (int i = 0; i < working.length; i++) {
      if (working[i].sectionId == toSectionId) {
        if (scopeSeen == toIndex) {
          insertAt = i;
          break;
        }
        scopeSeen++;
      }
    }
    working.insert(insertAt, moved);
    return _renumberItems(working);
  }

  /// Dense, per-scope `order` (§9 invariant) — recomputed from list
  /// position after every structural change instead of storing sparse gaps.
  List<CollectionItemDraft> _renumberItems(List<CollectionItemDraft> items) {
    final Map<String?, int> counters = <String?, int>{};
    return items
        .map((CollectionItemDraft item) {
          final int next = counters.update(
            item.sectionId,
            (int value) => value + 1,
            ifAbsent: () => 0,
          );
          return item.copyWith(order: next);
        })
        .toList(growable: false);
  }

  List<CollectionSectionDraft> _renumberSections(
    List<CollectionSectionDraft> sections,
  ) {
    return <CollectionSectionDraft>[
      for (int i = 0; i < sections.length; i++) sections[i].copyWith(order: i),
    ];
  }

  void _mutate(
    CollectionEditCommandKind kind,
    CollectionDraftData Function(CollectionDraftData data) mutator, {
    bool invalidatesReview = true,
  }) {
    final CollectionCreateState current = state;
    final CollectionDraftData before = current.collectionData;
    final CollectionDraftData rawAfter = mutator(before);
    if (identical(rawAfter, before)) return; // no-op guard
    final CollectionDraftData after = invalidatesReview
        ? rawAfter.copyWith(clearCompositionReview: true)
        : rawAfter;
    final CollectionHistoryEntry entry = CollectionHistoryEntry(
      kind: kind,
      before: before,
      after: after,
    );
    final List<CollectionHistoryEntry> undo = <CollectionHistoryEntry>[
      ...current.undoStack,
      entry,
    ];
    while (undo.length > config.maximumHistoryEntries) {
      undo.removeAt(0);
    }
    _stateOrNull = current.copyWith(
      createDraft: current.createDraft.copyWith(collectionData: after),
      revision: current.revision + 1,
      undoStack: undo,
      redoStack: const <CollectionHistoryEntry>[],
    );
  }
}
