import '../../domain/entities/collection_draft_data.dart';
import '../../domain/entities/collection_validation_issue.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/location_search_suggestion.dart';
import '../../domain/repositories/collection_catalog_search_repository.dart';

enum CollectionCreateStatus {
  restoring,
  editing,
  searchingCatalog,
  validating,
  readyToPublish,
  publishing,
  published,

  /// §6/§7 Шаг 5: a version was submitted without `publish.collection.direct`
  /// — a real write happened, but it is not yet the active Discover-facing
  /// version (distinct from [published]).
  submittedForReview,
  failure,
}

/// Labels the kind of edit an undo/redo entry replays — Collection edits are
/// simple structural list operations, so a single before/after
/// `CollectionDraftData` snapshot pair is enough; there is no need for
/// Route's typed per-command geometry union (§8).
enum CollectionEditCommandKind {
  addItem,
  removeItem,
  moveItem,
  addSection,
  renameSection,
  removeSection,
  moveSection,
  setCuratorNote,
  toggleHighlight,
  setBudgetIndicator,
  setArea,
}

class CollectionHistoryEntry {
  const CollectionHistoryEntry({
    required this.kind,
    required this.before,
    required this.after,
  });

  final CollectionEditCommandKind kind;
  final CollectionDraftData before;
  final CollectionDraftData after;
}

class CollectionCreateState {
  CollectionCreateState({
    required this.status,
    required this.createDraft,
    required this.revision,
    required this.persistedRevision,
    Iterable<CollectionCatalogSearchResult> searchResults =
        const <CollectionCatalogSearchResult>[],
    Iterable<CollectionValidationIssue> issues =
        const <CollectionValidationIssue>[],
    Iterable<CollectionHistoryEntry> undoStack =
        const <CollectionHistoryEntry>[],
    Iterable<CollectionHistoryEntry> redoStack =
        const <CollectionHistoryEntry>[],
    Iterable<LocationSearchSuggestion> areaLocationSuggestions =
        const <LocationSearchSuggestion>[],
    this.areaLocationSearchLoading = false,
    this.lastFailureCode,
  }) : searchResults = List<CollectionCatalogSearchResult>.unmodifiable(
         searchResults,
       ),
       issues = List<CollectionValidationIssue>.unmodifiable(issues),
       undoStack = List<CollectionHistoryEntry>.unmodifiable(undoStack),
       redoStack = List<CollectionHistoryEntry>.unmodifiable(redoStack),
       areaLocationSuggestions = List<LocationSearchSuggestion>.unmodifiable(
         areaLocationSuggestions,
       );

  final CollectionCreateStatus status;
  final CreateDraftEntity createDraft;

  /// Bumped by every accepted mutation; guards stale async responses and
  /// invalidates `CollectionCompositionReview` (§8).
  final int revision;
  final int persistedRevision;

  final List<CollectionCatalogSearchResult> searchResults;
  final List<CollectionValidationIssue> issues;
  final List<CollectionHistoryEntry> undoStack;
  final List<CollectionHistoryEntry> redoStack;
  final List<LocationSearchSuggestion> areaLocationSuggestions;
  final bool areaLocationSearchLoading;
  final String? lastFailureCode;

  CollectionDraftData get collectionData {
    final CollectionDraftData? data = createDraft.collectionData;
    if (data == null) {
      throw StateError('CollectionCreateState has no collectionData.');
    }
    return data;
  }

  CollectionCreateState copyWith({
    CollectionCreateStatus? status,
    CreateDraftEntity? createDraft,
    int? revision,
    int? persistedRevision,
    List<CollectionCatalogSearchResult>? searchResults,
    List<CollectionValidationIssue>? issues,
    List<CollectionHistoryEntry>? undoStack,
    List<CollectionHistoryEntry>? redoStack,
    List<LocationSearchSuggestion>? areaLocationSuggestions,
    bool? areaLocationSearchLoading,
    String? lastFailureCode,
    bool clearLastFailureCode = false,
  }) {
    return CollectionCreateState(
      status: status ?? this.status,
      createDraft: createDraft ?? this.createDraft,
      revision: revision ?? this.revision,
      persistedRevision: persistedRevision ?? this.persistedRevision,
      searchResults: searchResults ?? this.searchResults,
      issues: issues ?? this.issues,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      areaLocationSuggestions:
          areaLocationSuggestions ?? this.areaLocationSuggestions,
      areaLocationSearchLoading:
          areaLocationSearchLoading ?? this.areaLocationSearchLoading,
      lastFailureCode: clearLastFailureCode
          ? null
          : (lastFailureCode ?? this.lastFailureCode),
    );
  }
}
