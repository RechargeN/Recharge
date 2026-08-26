import '../../domain/entities/activity_validation_issue.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/event_validation_issue.dart';
import '../../domain/entities/find_people_validation_issue.dart';
import '../../domain/entities/location_search_suggestion.dart';
import '../../domain/entities/place_validation_issue.dart';
import '../../domain/entities/rental_validation_issue.dart';
import '../../domain/entities/session_validation_issue.dart';
import '../../domain/entities/place_duplicate_candidate.dart';
import '../../domain/entities/place_enrichment_proposal.dart';
import '../../domain/entities/route_publication_data.dart';
import '../../domain/entities/scenario_draft_data.dart';
import '../../domain/repositories/catalog_object_picker_port.dart';
import '../scenario_generation_coordinator.dart';

enum CreateSaveStatus { saved, saving, unsaved, failed }

enum CreateStatus {
  initial,
  loading,
  ready,
  saving,
  publishing,
  publishSuccess,
  error,
}

class CreateState {
  const CreateState({
    required this.status,
    required this.userId,
    required this.draft,
    required this.message,
    required this.validationErrors,
    required this.publishedDraft,
    required this.saveStatus,
    required this.eventStep,
    required this.eventValidationIssues,
    required this.placeStep,
    required this.activityStep,
    required this.findPeopleStep,
    required this.findPeopleValidationIssues,
    required this.placeValidationIssues,
    required this.activityValidationIssues,
    required this.sessionValidationIssues,
    required this.rentalStep,
    required this.rentalValidationIssues,
    required this.placeDuplicateMatches,
    required this.duplicateOverrideConfirmed,
    required this.placeEnrichmentLoading,
    required this.placeEnrichmentProposal,
    required this.placeEnrichmentError,
    required this.placeLocationSuggestions,
    required this.placeLocationSearchLoading,
    required this.scenarioStep,
    required this.scenarioUndoStack,
    required this.scenarioRedoStack,
    required this.scenarioCatalogCandidates,
    required this.scenarioCatalogLoading,
    required this.scenarioGenerationPrompt,
    required this.scenarioGenerationLoading,
    required this.scenarioGenerationPreview,
    required this.scenarioGenerationError,
    required this.routeStep,
    required this.routePublishReceipt,
    required this.routeModerationRequests,
    required this.collectionStep,
  });

  factory CreateState.initial() {
    return CreateState(
      status: CreateStatus.initial,
      userId: '',
      draft: CreateDraftEntity.defaults(
        organizerId: '',
        organizerEmail: '',
        organizerName: '',
      ),
      message: null,
      validationErrors: const <String, String>{},
      publishedDraft: null,
      saveStatus: CreateSaveStatus.saved,
      eventStep: 0,
      eventValidationIssues: const <EventValidationIssue>[],
      placeStep: 0,
      activityStep: 0,
      findPeopleStep: 0,
      findPeopleValidationIssues: const <FindPeopleValidationIssue>[],
      placeValidationIssues: const <PlaceValidationIssue>[],
      activityValidationIssues: const <ActivityValidationIssue>[],
      sessionValidationIssues: const <SessionValidationIssue>[],
      rentalStep: 0,
      rentalValidationIssues: const <RentalValidationIssue>[],
      placeDuplicateMatches: const <PlaceDuplicateMatch>[],
      duplicateOverrideConfirmed: false,
      placeEnrichmentLoading: false,
      placeEnrichmentProposal: null,
      placeEnrichmentError: null,
      placeLocationSuggestions: const <LocationSearchSuggestion>[],
      placeLocationSearchLoading: false,
      scenarioStep: 0,
      scenarioUndoStack: const <ScenarioDraftData>[],
      scenarioRedoStack: const <ScenarioDraftData>[],
      scenarioCatalogCandidates: const <ScenarioCatalogObjectCandidate>[],
      scenarioCatalogLoading: false,
      scenarioGenerationPrompt: '',
      scenarioGenerationLoading: false,
      scenarioGenerationPreview: null,
      scenarioGenerationError: null,
      routeStep: 0,
      routePublishReceipt: null,
      routeModerationRequests: const <RouteModerationRequest>[],
      collectionStep: 0,
    );
  }

  final CreateStatus status;
  final String userId;
  final CreateDraftEntity draft;
  final String? message;
  final Map<String, String> validationErrors;
  final CreateDraftEntity? publishedDraft;
  final CreateSaveStatus saveStatus;
  final int eventStep;
  final List<EventValidationIssue> eventValidationIssues;
  final int placeStep;
  final int activityStep;
  final int findPeopleStep;
  final List<FindPeopleValidationIssue> findPeopleValidationIssues;
  final List<PlaceValidationIssue> placeValidationIssues;
  final List<ActivityValidationIssue> activityValidationIssues;
  final List<SessionValidationIssue> sessionValidationIssues;
  final int rentalStep;
  final List<RentalValidationIssue> rentalValidationIssues;
  final List<PlaceDuplicateMatch> placeDuplicateMatches;
  final bool duplicateOverrideConfirmed;
  final bool placeEnrichmentLoading;
  final PlaceEnrichmentProposal? placeEnrichmentProposal;
  final String? placeEnrichmentError;
  final List<LocationSearchSuggestion> placeLocationSuggestions;
  final bool placeLocationSearchLoading;
  final int scenarioStep;
  final List<ScenarioDraftData> scenarioUndoStack;
  final List<ScenarioDraftData> scenarioRedoStack;
  final List<ScenarioCatalogObjectCandidate> scenarioCatalogCandidates;
  final bool scenarioCatalogLoading;
  final String scenarioGenerationPrompt;
  final bool scenarioGenerationLoading;
  final ScenarioGenerationPreview? scenarioGenerationPreview;
  final String? scenarioGenerationError;
  final int routeStep;
  final RoutePublishReceipt? routePublishReceipt;
  final List<RouteModerationRequest> routeModerationRequests;
  final int collectionStep;

  bool get isLoaded =>
      status == CreateStatus.ready ||
      status == CreateStatus.saving ||
      status == CreateStatus.publishing ||
      status == CreateStatus.publishSuccess;

  CreateState copyWith({
    CreateStatus? status,
    String? userId,
    CreateDraftEntity? draft,
    String? message,
    bool clearMessage = false,
    Map<String, String>? validationErrors,
    bool clearValidationErrors = false,
    CreateDraftEntity? publishedDraft,
    bool clearPublishedDraft = false,
    CreateSaveStatus? saveStatus,
    int? eventStep,
    List<EventValidationIssue>? eventValidationIssues,
    bool clearEventValidationIssues = false,
    int? placeStep,
    int? activityStep,
    int? findPeopleStep,
    List<FindPeopleValidationIssue>? findPeopleValidationIssues,
    bool clearFindPeopleValidationIssues = false,
    List<PlaceValidationIssue>? placeValidationIssues,
    bool clearPlaceValidationIssues = false,
    List<ActivityValidationIssue>? activityValidationIssues,
    bool clearActivityValidationIssues = false,
    List<SessionValidationIssue>? sessionValidationIssues,
    bool clearSessionValidationIssues = false,
    int? rentalStep,
    List<RentalValidationIssue>? rentalValidationIssues,
    bool clearRentalValidationIssues = false,
    List<PlaceDuplicateMatch>? placeDuplicateMatches,
    bool clearPlaceDuplicateMatches = false,
    bool? duplicateOverrideConfirmed,
    bool? placeEnrichmentLoading,
    PlaceEnrichmentProposal? placeEnrichmentProposal,
    bool clearPlaceEnrichmentProposal = false,
    String? placeEnrichmentError,
    bool clearPlaceEnrichmentError = false,
    List<LocationSearchSuggestion>? placeLocationSuggestions,
    bool? placeLocationSearchLoading,
    int? scenarioStep,
    List<ScenarioDraftData>? scenarioUndoStack,
    bool clearScenarioUndoStack = false,
    List<ScenarioDraftData>? scenarioRedoStack,
    bool clearScenarioRedoStack = false,
    List<ScenarioCatalogObjectCandidate>? scenarioCatalogCandidates,
    bool clearScenarioCatalogCandidates = false,
    bool? scenarioCatalogLoading,
    String? scenarioGenerationPrompt,
    bool? scenarioGenerationLoading,
    ScenarioGenerationPreview? scenarioGenerationPreview,
    bool clearScenarioGenerationPreview = false,
    String? scenarioGenerationError,
    bool clearScenarioGenerationError = false,
    int? routeStep,
    RoutePublishReceipt? routePublishReceipt,
    bool clearRoutePublishReceipt = false,
    List<RouteModerationRequest>? routeModerationRequests,
    bool clearRouteModerationRequests = false,
    int? collectionStep,
  }) {
    return CreateState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      draft: draft ?? this.draft,
      message: clearMessage ? null : (message ?? this.message),
      validationErrors: clearValidationErrors
          ? const <String, String>{}
          : (validationErrors ?? this.validationErrors),
      publishedDraft: clearPublishedDraft
          ? null
          : (publishedDraft ?? this.publishedDraft),
      saveStatus: saveStatus ?? this.saveStatus,
      eventStep: eventStep ?? this.eventStep,
      eventValidationIssues: clearEventValidationIssues
          ? const <EventValidationIssue>[]
          : (eventValidationIssues ?? this.eventValidationIssues),
      placeStep: placeStep ?? this.placeStep,
      activityStep: activityStep ?? this.activityStep,
      findPeopleStep: findPeopleStep ?? this.findPeopleStep,
      findPeopleValidationIssues: clearFindPeopleValidationIssues
          ? const <FindPeopleValidationIssue>[]
          : (findPeopleValidationIssues ?? this.findPeopleValidationIssues),
      placeValidationIssues: clearPlaceValidationIssues
          ? const <PlaceValidationIssue>[]
          : (placeValidationIssues ?? this.placeValidationIssues),
      activityValidationIssues: clearActivityValidationIssues
          ? const <ActivityValidationIssue>[]
          : (activityValidationIssues ?? this.activityValidationIssues),
      sessionValidationIssues: clearSessionValidationIssues
          ? const <SessionValidationIssue>[]
          : (sessionValidationIssues ?? this.sessionValidationIssues),
      rentalStep: rentalStep ?? this.rentalStep,
      rentalValidationIssues: clearRentalValidationIssues
          ? const <RentalValidationIssue>[]
          : (rentalValidationIssues ?? this.rentalValidationIssues),
      placeDuplicateMatches: clearPlaceDuplicateMatches
          ? const <PlaceDuplicateMatch>[]
          : (placeDuplicateMatches ?? this.placeDuplicateMatches),
      duplicateOverrideConfirmed:
          duplicateOverrideConfirmed ?? this.duplicateOverrideConfirmed,
      placeEnrichmentLoading:
          placeEnrichmentLoading ?? this.placeEnrichmentLoading,
      placeEnrichmentProposal: clearPlaceEnrichmentProposal
          ? null
          : (placeEnrichmentProposal ?? this.placeEnrichmentProposal),
      placeEnrichmentError: clearPlaceEnrichmentError
          ? null
          : (placeEnrichmentError ?? this.placeEnrichmentError),
      placeLocationSuggestions:
          placeLocationSuggestions ?? this.placeLocationSuggestions,
      placeLocationSearchLoading:
          placeLocationSearchLoading ?? this.placeLocationSearchLoading,
      scenarioStep: scenarioStep ?? this.scenarioStep,
      scenarioUndoStack: clearScenarioUndoStack
          ? const <ScenarioDraftData>[]
          : (scenarioUndoStack ?? this.scenarioUndoStack),
      scenarioRedoStack: clearScenarioRedoStack
          ? const <ScenarioDraftData>[]
          : (scenarioRedoStack ?? this.scenarioRedoStack),
      scenarioCatalogCandidates: clearScenarioCatalogCandidates
          ? const <ScenarioCatalogObjectCandidate>[]
          : (scenarioCatalogCandidates ?? this.scenarioCatalogCandidates),
      scenarioCatalogLoading:
          scenarioCatalogLoading ?? this.scenarioCatalogLoading,
      scenarioGenerationPrompt:
          scenarioGenerationPrompt ?? this.scenarioGenerationPrompt,
      scenarioGenerationLoading:
          scenarioGenerationLoading ?? this.scenarioGenerationLoading,
      scenarioGenerationPreview: clearScenarioGenerationPreview
          ? null
          : (scenarioGenerationPreview ?? this.scenarioGenerationPreview),
      scenarioGenerationError: clearScenarioGenerationError
          ? null
          : (scenarioGenerationError ?? this.scenarioGenerationError),
      routeStep: routeStep ?? this.routeStep,
      routePublishReceipt: clearRoutePublishReceipt
          ? null
          : (routePublishReceipt ?? this.routePublishReceipt),
      routeModerationRequests: clearRouteModerationRequests
          ? const <RouteModerationRequest>[]
          : (routeModerationRequests ?? this.routeModerationRequests),
      collectionStep: collectionStep ?? this.collectionStep,
    );
  }
}
