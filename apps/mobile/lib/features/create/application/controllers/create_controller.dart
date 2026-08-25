import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/config/recharge_taxonomy.dart';
import '../../../../core/parsing/input_parsers.dart';
import '../../../../core/telemetry/analytics_service.dart';
import '../../domain/entities/activity_draft_data.dart';
import '../../domain/entities/activity_validation_issue.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/create_template_entity.dart';
import '../../domain/entities/create_availability.dart';
import '../../domain/entities/event_draft_data.dart';
import '../../domain/entities/event_admission.dart';
import '../../domain/entities/event_availability_projection.dart';
import '../../domain/entities/event_classification.dart';
import '../../domain/entities/event_inventory.dart';
import '../../domain/entities/event_validation_issue.dart';
import '../../domain/entities/find_people_draft_data.dart';
import '../../domain/entities/find_people_validation_issue.dart';
import '../../domain/entities/place_draft_data.dart';
import '../../domain/entities/place_creation_policy.dart';
import '../../domain/entities/place_duplicate_candidate.dart';
import '../../domain/entities/place_enrichment_proposal.dart';
import '../../domain/entities/place_validation_issue.dart';
import '../../domain/entities/rental_direct_publish_decision.dart';
import '../../domain/entities/rental_direct_publish_policy.dart';
import '../../domain/entities/rental_draft_data.dart';
import '../../domain/entities/rental_listing.dart';
import '../../domain/entities/rental_private_authoring_data.dart';
import '../../domain/entities/rental_validation_issue.dart';
import '../../domain/entities/route_draft_save_result.dart';
import '../../domain/entities/route_edit_command.dart';
import '../../domain/entities/route_publication_data.dart';
import '../../domain/entities/scenario_draft_data.dart';
import '../../domain/entities/scenario_generation_proposal.dart';
import '../../domain/entities/scenario_item_draft.dart';
import '../../domain/entities/scenario_logistics_draft.dart';
import '../../domain/entities/scenario_transit_mutation.dart';
import '../../domain/entities/scenario_transit_schedule.dart';
import '../../domain/entities/scenario_validation_issue.dart';
import '../../domain/repositories/catalog_object_picker_port.dart';
import '../../domain/repositories/create_template_repository.dart';
import '../../domain/repositories/rental_private_authoring_repository.dart';
import '../../domain/repositories/rental_publication_index_sink.dart';
import '../../domain/repositories/route_gpx_repository.dart';
import '../../domain/usecases/build_rental_public_projection_usecase.dart';
import '../../domain/usecases/check_place_duplicates_usecase.dart';
import '../../domain/usecases/estimate_rental_rate_usecase.dart';
import '../../domain/usecases/evaluate_rental_availability_usecase.dart';
import '../../domain/usecases/evaluate_scenario_readiness_usecase.dart';
import '../../domain/usecases/generate_scenario_proposal_usecase.dart';
import '../../domain/usecases/load_create_draft_usecase.dart';
import '../../domain/usecases/load_create_draft_by_id_usecase.dart';
import '../../domain/usecases/manage_create_template_usecase.dart';
import '../../domain/usecases/promote_rental_to_published_usecase.dart';
import '../../domain/usecases/publish_create_draft_usecase.dart';
import '../../domain/usecases/resolve_rental_direct_publish_usecase.dart';
import '../../domain/usecases/save_create_draft_usecase.dart';
import '../../domain/usecases/validate_create_availability_usecase.dart';
import '../../domain/usecases/validate_find_people_draft_usecase.dart';
import '../../domain/usecases/validate_place_draft_usecase.dart';
import '../../domain/usecases/validate_rental_draft_usecase.dart';
import '../../domain/usecases/apply_route_edit_command_usecase.dart';
import '../../domain/usecases/build_route_publication_bundle_usecase.dart';
import '../../domain/usecases/count_activity_informal_access_usecase.dart';
import '../../domain/usecases/validate_activity_draft_usecase.dart';
import '../activity_create_config.dart';
import '../create_runtime_defaults.dart';
import '../create_taxonomy.dart';
import '../event_create_coordinator.dart';
import '../event_admission_section.dart';
import '../event_classification_section.dart';
import '../event_inventory_section.dart';
import '../place_create_config.dart';
import '../place_enrichment_coordinator.dart';
import '../rental_availability_section.dart';
import '../rental_create_config.dart';
import '../rental_external_fulfillment_section.dart';
import '../rental_handover_section.dart';
import '../rental_inventory_section.dart';
import '../rental_pricing_section.dart';
import '../rental_section_disclosure.dart';
import '../rental_terms_section.dart';
import '../route_create_config.dart';
import '../route_create_coordinator.dart';
import '../route_publication_coordinator.dart';
import '../scenario_create_coordinator.dart';
import '../scenario_generation_coordinator.dart';
import '../scenario_transit_telemetry.dart';
import '../get_category_criteria_usecase.dart';
import '../state/create_state.dart';
import '../state/route_create_state.dart';

class CreateController extends ChangeNotifier {
  CreateController({
    required LoadCreateDraftUseCase loadCreateDraftUseCase,
    LoadCreateDraftByIdUseCase? loadCreateDraftByIdUseCase,
    required SaveCreateDraftUseCase saveCreateDraftUseCase,
    required PublishCreateDraftUseCase publishCreateDraftUseCase,
    required AnalyticsService analyticsService,
    required EventCreateCoordinator eventCreateCoordinator,
    bool eventClassificationEnabled = true,
    bool eventAdmissionConfigurationEnabled = false,
    bool eventMockAvailabilityEnabled = false,
    CreateTemplateRepository? createTemplateRepository,
    ManageCreateTemplateUseCase? manageCreateTemplate,
    RoutePublicationCoordinator? routePublicationCoordinator,
    ScenarioCreateCoordinator? scenarioCreateCoordinator,
    ScenarioGenerationCoordinator? scenarioGenerationCoordinator,
    PlaceEnrichmentCoordinator? placeEnrichmentCoordinator,
    CatalogObjectPickerPort? catalogObjectPicker,
    CreateRuntimeDefaults runtimeDefaults = const CreateRuntimeDefaults(
      marketCityId: '',
      timezone: 'UTC',
      country: '',
      city: '',
      currency: '',
    ),
    ValidateCreateAvailabilityUseCase validateCreateAvailability =
        const ValidateCreateAvailabilityUseCase(),
    ValidatePlaceDraftUseCase validatePlaceDraft =
        const ValidatePlaceDraftUseCase(),
    ValidateFindPeopleDraftUseCase validateFindPeopleDraft =
        const ValidateFindPeopleDraftUseCase(),
    CheckPlaceDuplicatesUseCase checkPlaceDuplicates =
        const CheckPlaceDuplicatesUseCase(),
    ValidateActivityDraftUseCase validateActivityDraft =
        const ValidateActivityDraftUseCase(),
    CountActivityInformalAccessUseCase countActivityInformalAccess =
        const CountActivityInformalAccessUseCase(),
    ValidateRentalDraftUseCase validateRentalDraft =
        const ValidateRentalDraftUseCase(),
    EvaluateRentalAvailabilityUseCase evaluateRentalAvailability =
        const EvaluateRentalAvailabilityUseCase(),
    EstimateRentalRateUseCase estimateRentalRate =
        const EstimateRentalRateUseCase(),
    BuildRentalPublicProjectionUseCase buildRentalPublicProjection =
        const BuildRentalPublicProjectionUseCase(),
    RentalPrivateAuthoringRepository? rentalPrivateAuthoringRepository,
    ResolveRentalDirectPublishUseCase resolveRentalDirectPublish =
        const ResolveRentalDirectPublishUseCase(),
    RentalDirectPublishPolicy rentalDirectPublishPolicy =
        const RentalDirectPublishPolicy(),
    PromoteRentalToPublishedUseCase? promoteRentalToPublished,
    RentalPublicationIndexSink? rentalPublicationIndexSink,
  }) : _loadCreateDraftUseCase = loadCreateDraftUseCase,
       _loadCreateDraftByIdUseCase = loadCreateDraftByIdUseCase,
       _saveCreateDraftUseCase = saveCreateDraftUseCase,
       _publishCreateDraftUseCase = publishCreateDraftUseCase,
       _analyticsService = analyticsService,
       _scenarioTransitTelemetry = ScenarioTransitTelemetry(analyticsService),
       _eventCreateCoordinator = eventCreateCoordinator,
       _eventClassificationEnabled = eventClassificationEnabled,
       _eventAdmissionConfigurationEnabled = eventAdmissionConfigurationEnabled,
       _eventMockAvailabilityEnabled = eventMockAvailabilityEnabled,
       _createTemplateRepository = createTemplateRepository,
       _manageCreateTemplate = manageCreateTemplate,
       _routePublicationCoordinator = routePublicationCoordinator,
       _scenarioCreateCoordinator = scenarioCreateCoordinator,
       _scenarioGenerationCoordinator = scenarioGenerationCoordinator,
       _placeEnrichmentCoordinator = placeEnrichmentCoordinator,
       _catalogObjectPicker = catalogObjectPicker,
       _runtimeDefaults = runtimeDefaults,
       _validateCreateAvailability = validateCreateAvailability,
       _validatePlaceDraft = validatePlaceDraft,
       _validateFindPeopleDraft = validateFindPeopleDraft,
       _checkPlaceDuplicates = checkPlaceDuplicates,
       _validateActivityDraft = validateActivityDraft,
       _countActivityInformalAccess = countActivityInformalAccess,
       _validateRentalDraft = validateRentalDraft,
       _evaluateRentalAvailability = evaluateRentalAvailability,
       _estimateRentalRate = estimateRentalRate,
       _buildRentalPublicProjection = buildRentalPublicProjection,
       _rentalPrivateAuthoringRepository = rentalPrivateAuthoringRepository,
       _resolveRentalDirectPublish = resolveRentalDirectPublish,
       _rentalDirectPublishPolicy = rentalDirectPublishPolicy,
       _promoteRentalToPublished = promoteRentalToPublished,
       _rentalPublicationIndexSink = rentalPublicationIndexSink;

  final LoadCreateDraftUseCase _loadCreateDraftUseCase;
  final LoadCreateDraftByIdUseCase? _loadCreateDraftByIdUseCase;
  final SaveCreateDraftUseCase _saveCreateDraftUseCase;
  final PublishCreateDraftUseCase _publishCreateDraftUseCase;
  final AnalyticsService _analyticsService;
  final ScenarioTransitTelemetry _scenarioTransitTelemetry;
  final EventCreateCoordinator _eventCreateCoordinator;
  final bool _eventClassificationEnabled;
  final bool _eventAdmissionConfigurationEnabled;
  final bool _eventMockAvailabilityEnabled;
  final CreateTemplateRepository? _createTemplateRepository;
  final ManageCreateTemplateUseCase? _manageCreateTemplate;
  final RoutePublicationCoordinator? _routePublicationCoordinator;
  final ScenarioCreateCoordinator? _scenarioCreateCoordinator;
  final ScenarioGenerationCoordinator? _scenarioGenerationCoordinator;
  final PlaceEnrichmentCoordinator? _placeEnrichmentCoordinator;
  final CatalogObjectPickerPort? _catalogObjectPicker;
  final CreateRuntimeDefaults _runtimeDefaults;
  final ValidateCreateAvailabilityUseCase _validateCreateAvailability;
  final ValidatePlaceDraftUseCase _validatePlaceDraft;
  final ValidateFindPeopleDraftUseCase _validateFindPeopleDraft;
  final CheckPlaceDuplicatesUseCase _checkPlaceDuplicates;
  final ValidateActivityDraftUseCase _validateActivityDraft;
  final CountActivityInformalAccessUseCase _countActivityInformalAccess;
  final ValidateRentalDraftUseCase _validateRentalDraft;
  final EvaluateRentalAvailabilityUseCase _evaluateRentalAvailability;
  final EstimateRentalRateUseCase _estimateRentalRate;
  final BuildRentalPublicProjectionUseCase _buildRentalPublicProjection;
  final RentalPrivateAuthoringRepository? _rentalPrivateAuthoringRepository;
  final ResolveRentalDirectPublishUseCase _resolveRentalDirectPublish;
  final RentalDirectPublishPolicy _rentalDirectPublishPolicy;
  final PromoteRentalToPublishedUseCase? _promoteRentalToPublished;
  final RentalPublicationIndexSink? _rentalPublicationIndexSink;
  bool _isVerifiedCreator = false;
  List<CreateTemplateEntity> _rentalTemplates = const <CreateTemplateEntity>[];
  int _scenarioGenerationRequestSerial = 0;
  int _placeEnrichmentRequestSerial = 0;

  CreateState _state = CreateState.initial();
  CreateState get state => _state;
  Set<String> get supportedContentLocales =>
      _runtimeDefaults.supportedContentLocales;
  Set<String> get supportedServiceLanguages =>
      _runtimeDefaults.supportedServiceLanguages;
  double get marketCenterLat => _runtimeDefaults.marketCenterLat;
  double get marketCenterLng => _runtimeDefaults.marketCenterLng;
  bool get canManagePlace =>
      _capabilities.contains('create.place') ||
      _capabilities.contains('publish.place');
  bool get canCreateRoute => _capabilities.contains('create.route');
  bool get canSubmitRoute => _capabilities.contains('submit.route');
  bool get canPublishRouteDirect =>
      _capabilities.contains('publish.route.direct');
  bool get canModerateRoute => _capabilities.contains('moderate.route');
  bool get canManageRoute => _capabilities.contains('manage.route');
  bool get canArchiveRoute => _capabilities.contains('archive.route');
  bool get canCreateRental => _capabilities.contains('create.rental');
  bool get canSubmitRental => _capabilities.contains('submit.rental');
  bool get canPublishRentalDirect =>
      _capabilities.contains('publish.rental.direct');
  bool get canManageRental => _capabilities.contains('manage.rental');
  bool get canArchiveRental => _capabilities.contains('archive.rental');
  RouteCreateState? get routeCreateState => _routeCoordinator?.state;
  bool get eventClassificationEnabled => _eventClassificationEnabled;
  EventClassificationSectionState get eventClassificationState =>
      _eventCreateCoordinator.classificationState(
        _state.draft,
        enabled: _eventClassificationEnabled,
      );
  bool get eventAdmissionConfigurationEnabled =>
      _eventAdmissionConfigurationEnabled;
  bool get eventMockAvailabilityEnabled => _eventMockAvailabilityEnabled;
  EventAdmissionSectionState get eventAdmissionState =>
      _eventCreateCoordinator.admissionState(
        _state.draft,
        enabled: _eventAdmissionConfigurationEnabled,
        selectedPreset: _selectedAdmissionPreset,
        presetPreview: _admissionPresetPreview,
        presetIssues: _admissionPresetIssues,
      );
  EventInventorySectionState get eventInventoryState =>
      _eventCreateCoordinator.inventoryState(
        _state.draft,
        enabled: _eventAdmissionConfigurationEnabled,
        mockPreviewEnabled: _eventMockAvailabilityEnabled,
        availabilityPreview: _eventAvailabilityPreview,
        refreshingPreview: _refreshingEventAvailability,
      );

  RentalInventorySectionState get rentalInventoryState {
    final RentalDraftData? rental = _state.draft.rentalData;
    return RentalInventorySectionState(
      enabled: rental != null,
      groups: rental?.inventoryGroups ?? const <RentalInventoryGroup>[],
      disclosures: const <RentalSectionDisclosure>[],
      issues: _state.rentalValidationIssues,
    );
  }

  RentalAvailabilitySectionState get rentalAvailabilityState {
    final RentalDraftData? rental = _state.draft.rentalData;
    final RentalAvailabilityCalendar calendar =
        rental?.availability ??
        const RentalAvailabilityCalendar(timeZoneId: '');
    final DateTime now = DateTime.now().toUtc();
    return RentalAvailabilitySectionState(
      enabled: rental != null,
      calendar: calendar,
      lastAssessment: rental == null
          ? null
          : _evaluateRentalAvailability(
              calendar: calendar,
              groups: rental.inventoryGroups,
              queryStartUtc: now,
              queryEndUtc: now.add(const Duration(hours: 1)),
              nowUtc: now,
            ),
      disclosures: const <RentalSectionDisclosure>[],
      issues: _state.rentalValidationIssues,
    );
  }

  RentalHandoverSectionState get rentalHandoverState {
    final RentalDraftData? rental = _state.draft.rentalData;
    return RentalHandoverSectionState(
      enabled: rental != null,
      handover:
          rental?.handover ??
          const RentalHandoverDraft(pickupPlaceName: '', publicAreaLabel: ''),
      disclosures: const <RentalSectionDisclosure>[],
      issues: _state.rentalValidationIssues,
    );
  }

  RentalTermsSectionState get rentalTermsState {
    final RentalDraftData? rental = _state.draft.rentalData;
    return RentalTermsSectionState(
      enabled: rental != null,
      terms:
          rental?.terms ??
          const RentalTerms(offeredMinMinutes: 60, offeredMaxMinutes: 4320),
      adaptiveHint: rental == null
          ? null
          : rentalAdaptiveHintFor(rental.categoryId),
      disclosures: const <RentalSectionDisclosure>[],
      issues: _state.rentalValidationIssues,
    );
  }

  RentalPricingSectionState get rentalPricingState {
    final RentalDraftData? rental = _state.draft.rentalData;
    final RentalPricingPolicy pricing =
        rental?.pricing ??
        RentalPricingPolicy(
          currencyCode: _runtimeDefaults.currency,
          billingUnit: RentalBillingUnit.day,
          deposit: RentalDepositPolicy(
            amount: RentalMoneyDraft(
              amountMinor: 0,
              currencyCode: _runtimeDefaults.currency,
            ),
            collectionMethod: RentalDepositCollectionMethod.none,
          ),
          damagePolicy: '',
          cancellationPolicyId: 'standard',
        );
    final RentalTerms? terms = rental?.terms;
    return RentalPricingSectionState(
      enabled: rental != null,
      pricing: pricing,
      exampleEstimate: terms == null
          ? null
          : _estimateRentalRate(
              pricing: pricing,
              requestedMinutes: terms.offeredMinMinutes,
            ),
      disclosures: const <RentalSectionDisclosure>[],
      issues: _state.rentalValidationIssues,
    );
  }

  RentalExternalFulfillmentSectionState get rentalFulfillmentState {
    final RentalDraftData? rental = _state.draft.rentalData;
    final RentalExternalFulfillment fulfillment =
        rental?.fulfillment ?? const RentalExternalFulfillment();
    return RentalExternalFulfillmentSectionState(
      enabled: rental != null,
      fulfillment: fulfillment,
      destinationHost: _rentalDestinationHost(fulfillment.externalBookingUrl),
      disclosures: const <RentalSectionDisclosure>[],
      issues: _state.rentalValidationIssues,
    );
  }

  RentalListing? get rentalPublicPreview {
    final RentalDraftData? rental = _state.draft.rentalData;
    if (rental == null) return null;
    return _buildRentalPublicProjection(id: _state.draft.id, draft: rental);
  }

  List<CreateTemplateEntity> get rentalTemplates =>
      List<CreateTemplateEntity>.unmodifiable(_rentalTemplates);

  CreateTemplateEntity? get lastRentalTemplate =>
      _rentalTemplates.isEmpty ? null : _rentalTemplates.first;

  String? _rentalDestinationHost(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    return Uri.tryParse(url.trim())?.host;
  }

  String? _loadedUserId;
  Set<String> _capabilities = const <String>{};
  PublisherRef? _activePublisherRef;
  Timer? _autosaveTimer;
  int _localIdCounter = 0;
  RouteCreateCoordinator? _routeCoordinator;
  List<CreateTemplateEntity> _eventTemplates = const <CreateTemplateEntity>[];
  EventAdmissionPreset? _selectedAdmissionPreset;
  EventAdmissionDraft? _admissionPresetPreview;
  int? _admissionPresetRevision;
  List<EventValidationIssue> _admissionPresetIssues =
      const <EventValidationIssue>[];
  EventAvailabilityProjection _eventAvailabilityPreview =
      EventAvailabilityProjection.unknown;
  bool _refreshingEventAvailability = false;
  int _eventAvailabilityRequestSerial = 0;

  List<CreateTemplateEntity> get eventTemplates =>
      List<CreateTemplateEntity>.unmodifiable(_eventTemplates);

  CreateTemplateEntity? get lastEventTemplate =>
      _eventTemplates.isEmpty ? null : _eventTemplates.first;

  Future<void> ensureLoaded({
    required String userId,
    required String organizerEmail,
    required String organizerName,
    List<String> capabilities = const <String>[],
    PublisherRef? activePublisherRef,
    bool isVerifiedCreator = false,
  }) async {
    final PublisherRef resolvedPublisher = activePublisherRef?.isValid == true
        ? activePublisherRef!
        : PublisherRef(type: PublisherType.user, id: userId);
    if (_loadedUserId == userId && _state.isLoaded) {
      _capabilities = capabilities.toSet();
      _activePublisherRef = resolvedPublisher;
      _isVerifiedCreator = isVerifiedCreator;
      return;
    }
    _loadedUserId = userId;
    _capabilities = capabilities.toSet();
    _activePublisherRef = resolvedPublisher;
    _isVerifiedCreator = isVerifiedCreator;

    _setState(
      _state.copyWith(
        status: CreateStatus.loading,
        clearMessage: true,
        clearValidationErrors: true,
      ),
    );

    final CreateDraftEntity? saved = await _loadCreateDraftUseCase(userId);
    final bool createsFreshDraft = saved == null;
    CreateDraftEntity draft =
        saved ??
        CreateDraftEntity.defaults(
          organizerId: userId,
          organizerEmail: organizerEmail,
          organizerName: organizerName,
          marketCityId: _runtimeDefaults.marketCityId,
          timezone: _runtimeDefaults.timezone,
          country: _runtimeDefaults.country,
          city: _runtimeDefaults.city,
          currency: _runtimeDefaults.currency,
        );
    if (createsFreshDraft && draft.eventData != null) {
      draft = draft.copyWith(
        eventData: draft.eventData!.copyWith(publisherRef: resolvedPublisher),
      );
    }
    if (draft.objectType == CreateObjectType.place && draft.placeData == null) {
      draft = draft.copyWith(placeData: _placeDefaults(userId));
    }
    if (draft.objectType == CreateObjectType.event) {
      draft = _eventCreateCoordinator.apply(
        draft,
        draft.eventData ?? _eventDefaults(),
        incrementRevision: false,
      );
    }
    if (draft.objectType == CreateObjectType.findPeople &&
        draft.findPeopleData == null) {
      draft = draft.copyWith(findPeopleData: _findPeopleDefaults(userId));
    }
    if (draft.objectType == CreateObjectType.scenario &&
        draft.scenarioData == null) {
      draft = draft.copyWith(scenarioData: _scenarioDefaults());
    }
    if (draft.objectType == CreateObjectType.route && draft.routeData == null) {
      draft = draft.copyWith(routeData: createEmptyRouteDraft());
    }

    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        userId: userId,
        draft: draft,
        clearMessage: true,
        clearValidationErrors: true,
      ),
    );
    await _loadEventTemplates(userId);
    _analyticsService.track(
      'create_draft_loaded',
      params: <String, Object?>{
        'object_type': draft.objectType.taxonomyId,
        'user_id': userId,
      },
    );
  }

  Future<bool> saveCurrentEventAsTemplate(String name) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    final ManageCreateTemplateUseCase? useCase = _manageCreateTemplate;
    if (repository == null || useCase == null || _state.userId.isEmpty) {
      _setState(_state.copyWith(message: 'Хранилище шаблонов недоступно.'));
      return false;
    }
    try {
      final CreateTemplateEntity template = useCase.create(
        userId: _state.userId,
        name: name,
        draft: _state.draft,
      );
      await repository.upsertTemplate(
        userId: _state.userId,
        template: template,
      );
      await _loadEventTemplates(_state.userId);
      _setState(
        _state.copyWith(message: 'Шаблон «${template.name}» сохранён.'),
      );
      return true;
    } on Object catch (error) {
      _setState(_state.copyWith(message: _templateErrorMessage(error)));
      return false;
    }
  }

  Future<bool> renameEventTemplate(String templateId, String name) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    final ManageCreateTemplateUseCase? useCase = _manageCreateTemplate;
    final CreateTemplateEntity? current = _templateById(templateId);
    if (repository == null || useCase == null || current == null) return false;
    try {
      final CreateTemplateEntity renamed = useCase.rename(
        template: current,
        userId: _state.userId,
        name: name,
      );
      await repository.upsertTemplate(userId: _state.userId, template: renamed);
      await _loadEventTemplates(_state.userId);
      _setState(_state.copyWith(message: 'Шаблон переименован.'));
      return true;
    } on Object catch (error) {
      _setState(_state.copyWith(message: _templateErrorMessage(error)));
      return false;
    }
  }

  Future<bool> replaceEventTemplate(String templateId) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    final ManageCreateTemplateUseCase? useCase = _manageCreateTemplate;
    final CreateTemplateEntity? current = _templateById(templateId);
    if (repository == null || useCase == null || current == null) return false;
    try {
      final CreateTemplateEntity replaced = useCase.replace(
        template: current,
        userId: _state.userId,
        draft: _state.draft,
      );
      await repository.upsertTemplate(
        userId: _state.userId,
        template: replaced,
      );
      await _loadEventTemplates(_state.userId);
      _setState(
        _state.copyWith(message: 'Шаблон «${replaced.name}» обновлён.'),
      );
      return true;
    } on Object catch (error) {
      _setState(_state.copyWith(message: _templateErrorMessage(error)));
      return false;
    }
  }

  Future<bool> deleteEventTemplate(String templateId) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    if (repository == null || _templateById(templateId) == null) return false;
    await repository.deleteTemplate(
      userId: _state.userId,
      templateId: templateId,
    );
    await _loadEventTemplates(_state.userId);
    _setState(_state.copyWith(message: 'Шаблон удалён.'));
    return true;
  }

  Future<bool> applyEventTemplate(String templateId) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    final ManageCreateTemplateUseCase? useCase = _manageCreateTemplate;
    final CreateTemplateEntity? current = _templateById(templateId);
    if (repository == null || useCase == null || current == null) return false;
    try {
      CreateDraftEntity draft = useCase.materializeEvent(
        template: current,
        userId: _state.userId,
        organizerEmail: _state.draft.organizerEmail,
        organizerName: _state.draft.organizerName,
        marketCityId: _runtimeDefaults.marketCityId,
        timezone: _runtimeDefaults.timezone,
        country: _runtimeDefaults.country,
        city: _runtimeDefaults.city,
        currency: _runtimeDefaults.currency,
        publisherRef: _activePublisherRef,
      );
      draft = _eventCreateCoordinator.apply(
        draft,
        draft.eventData!,
        incrementRevision: false,
      );
      final CreateTemplateEntity used = useCase.markUsed(
        template: current,
        userId: _state.userId,
      );
      await repository.upsertTemplate(userId: _state.userId, template: used);
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          draft: draft,
          eventStep: 0,
          clearEventValidationIssues: true,
          clearValidationErrors: true,
          clearPublishedDraft: true,
          message: 'Применён шаблон «${used.name}».',
        ),
      );
      await _loadEventTemplates(_state.userId);
      await saveDraft();
      return true;
    } on Object catch (error) {
      _setState(_state.copyWith(message: _templateErrorMessage(error)));
      return false;
    }
  }

  Future<void> startAnotherEvent({
    required String organizerId,
    required String organizerEmail,
    required String organizerName,
  }) async {
    await _loadEventTemplates(organizerId);
    final CreateTemplateEntity? template = lastEventTemplate;
    if (template != null) {
      resetToFreshDraft(
        organizerId: organizerId,
        organizerEmail: organizerEmail,
        organizerName: organizerName,
      );
      final bool applied = await applyEventTemplate(template.id);
      if (applied) return;
    }
    resetToFreshDraft(
      organizerId: organizerId,
      organizerEmail: organizerEmail,
      organizerName: organizerName,
    );
  }

  Future<void> _loadEventTemplates(String userId) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    if (repository == null) {
      _eventTemplates = const <CreateTemplateEntity>[];
      return;
    }
    _eventTemplates = await repository.listTemplates(
      userId: userId,
      objectType: CreateObjectType.event,
    );
    notifyListeners();
  }

  CreateTemplateEntity? _templateById(String templateId) {
    for (final CreateTemplateEntity template in _eventTemplates) {
      if (template.id == templateId &&
          template.ownerUserId == _state.userId &&
          template.objectType == CreateObjectType.event) {
        return template;
      }
    }
    return null;
  }

  String _templateErrorMessage(Object error) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Некорректный шаблон.';
    }
    return 'Не удалось выполнить действие с шаблоном.';
  }

  void setObjectType(CreateObjectType type) {
    if (type == CreateObjectType.route && !canCreateRoute) {
      _setState(
        _state.copyWith(
          message: 'Для создания Route требуется capability create.route.',
        ),
      );
      return;
    }
    final CreateBlockConfig config = createBlockConfigFor(type);
    final bool sameType = _state.draft.objectType == type;
    final bool keepTaxonomy =
        sameType && _state.draft.mainCategory.trim().isNotEmpty;
    _updateDraft(
      _state.draft.copyWith(
        objectType: type,
        availabilityKind: _availabilityKindFor(type),
        scheduleSlots: const <CreateTimeSlotDraft>[],
        openingHours: const <CreateOpeningHoursDraftRule>[],
        mainCategory: keepTaxonomy
            ? _state.draft.mainCategory
            : config.defaultCategoryId,
        subcategory: keepTaxonomy
            ? _state.draft.subcategory
            : config.defaultSubcategoryId,
        clearStartDateTimeUtc: !sameType || !config.requiresStartDateTime,
        clearEndDateTimeUtc: !sameType,
        clearDurationMinutes: !sameType,
        clearRegistrationDeadlineUtc: !sameType,
        eventData: type == CreateObjectType.event
            ? (_state.draft.eventData ?? _eventDefaults())
            : null,
        clearEventData: type != CreateObjectType.event,
        placeData: type == CreateObjectType.place
            ? (_state.draft.placeData ?? _placeDefaults(_state.userId))
            : null,
        clearPlaceData: type != CreateObjectType.place,
        activityData: type == CreateObjectType.activity
            ? (_state.draft.activityData ?? _activityDefaults(_state.userId))
            : null,
        clearActivityData: type != CreateObjectType.activity,
        findPeopleData: type == CreateObjectType.findPeople
            ? (_state.draft.findPeopleData ??
                  _findPeopleDefaults(_state.userId))
            : null,
        clearFindPeopleData: type != CreateObjectType.findPeople,
        scenarioData: type == CreateObjectType.scenario
            ? (_state.draft.scenarioData ?? _scenarioDefaults())
            : null,
        clearScenarioData: type != CreateObjectType.scenario,
        routeData: type == CreateObjectType.route
            ? (_state.draft.routeData ?? createEmptyRouteDraft())
            : null,
        clearRouteData: type != CreateObjectType.route,
        rentalData: type == CreateObjectType.rental
            ? (_state.draft.rentalData ?? _rentalDefaults(_state.userId))
            : null,
        clearRentalData: type != CreateObjectType.rental,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
    if (type == CreateObjectType.event) {
      _updateEvent((EventDraftData value) => value, incrementRevision: false);
    }
    _setState(
      _state.copyWith(
        eventStep: 0,
        clearEventValidationIssues: true,
        placeStep: 0,
        findPeopleStep: 0,
        clearFindPeopleValidationIssues: true,
        clearPlaceDuplicateMatches: true,
        duplicateOverrideConfirmed: false,
        scenarioStep: 0,
        clearScenarioUndoStack: true,
        clearScenarioRedoStack: true,
        clearScenarioCatalogCandidates: true,
        scenarioGenerationPrompt: '',
        scenarioGenerationLoading: false,
        clearScenarioGenerationPreview: true,
        clearScenarioGenerationError: true,
        routeStep: 0,
        rentalStep: 0,
        clearRentalValidationIssues: true,
      ),
    );
  }

  void attachRouteCoordinator(RouteCreateCoordinator coordinator) {
    if (identical(_routeCoordinator, coordinator)) return;
    final draft = _state.draft.objectType == CreateObjectType.route
        ? _state.draft.copyWith(
            routeData: _state.draft.routeData ?? createEmptyRouteDraft(),
          )
        : _state.draft;
    if (draft.objectType != CreateObjectType.route || _state.userId.isEmpty) {
      return;
    }
    _routeCoordinator = coordinator;
    coordinator.initialize(userId: _state.userId, createDraft: draft);
    _setState(_state.copyWith(draft: coordinator.state.createDraft));
  }

  void detachRouteCoordinator(RouteCreateCoordinator coordinator) {
    if (identical(_routeCoordinator, coordinator)) {
      _routeCoordinator = null;
    }
  }

  Future<RouteCommandOutcome> applyRouteCommand(
    RouteEditCommand command,
  ) async {
    final coordinator = _routeCoordinator;
    if (coordinator == null) {
      return const RouteCommandOutcome(
        accepted: false,
        failureCode: RouteEditFailureCode.invalidCommand,
      );
    }
    final outcome = await coordinator.execute(command);
    _adoptRouteCoordinatorState(outcome: outcome);
    return outcome;
  }

  Future<RouteCommandOutcome> importRouteGpx(
    RouteGpxImportSelection selection, {
    required bool confirmGeometryReplacement,
  }) async {
    final coordinator = _routeCoordinator;
    if (coordinator == null) {
      return const RouteCommandOutcome(
        accepted: false,
        failureCode: RouteEditFailureCode.invalidGpxImport,
      );
    }
    final outcome = await coordinator.importGpx(
      selection,
      confirmGeometryReplacement: confirmGeometryReplacement,
    );
    _adoptRouteCoordinatorState(outcome: outcome);
    return outcome;
  }

  bool undoRoute() {
    final coordinator = _routeCoordinator;
    if (coordinator == null || !coordinator.undo()) return false;
    _adoptRouteCoordinatorState();
    return true;
  }

  bool redoRoute() {
    final coordinator = _routeCoordinator;
    if (coordinator == null || !coordinator.redo()) return false;
    _adoptRouteCoordinatorState();
    return true;
  }

  RouteCommandOutcome restorePersistedRoute() {
    final coordinator = _routeCoordinator;
    if (coordinator == null) {
      return const RouteCommandOutcome(
        accepted: false,
        failureCode: RouteEditFailureCode.invalidCommand,
      );
    }
    final outcome = coordinator.restorePersistedRevision();
    _adoptRouteCoordinatorState(outcome: outcome);
    return outcome;
  }

  void goToRouteStep(int step) {
    if (step < 0 || step >= routeCreateSteps.length) return;
    _setState(_state.copyWith(routeStep: step, clearMessage: true));
  }

  ScenarioReadinessResult? get scenarioReadiness {
    final ScenarioDraftData? scenario = _state.draft.scenarioData;
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    if (scenario == null || coordinator == null) return null;
    return coordinator.evaluate(scenario);
  }

  bool get canUndoScenario => _state.scenarioUndoStack.isNotEmpty;
  bool get canRedoScenario => _state.scenarioRedoStack.isNotEmpty;
  bool get canGenerateScenario => _scenarioGenerationCoordinator != null;

  void updateScenarioGenerationPrompt(String value) {
    _scenarioGenerationRequestSerial++;
    _setState(
      _state.copyWith(
        scenarioGenerationPrompt: value,
        scenarioGenerationLoading: false,
        clearScenarioGenerationPreview: true,
        clearScenarioGenerationError: true,
        clearMessage: true,
      ),
    );
  }

  Future<void> generateScenarioPreview() async {
    final ScenarioGenerationCoordinator? coordinator =
        _scenarioGenerationCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;

    final int requestSerial = ++_scenarioGenerationRequestSerial;
    final int sourceRevision = current.revision;
    _setState(
      _state.copyWith(
        scenarioGenerationLoading: true,
        clearScenarioGenerationPreview: true,
        clearScenarioGenerationError: true,
        clearMessage: true,
      ),
    );

    try {
      final ScenarioGenerationPreview preview = await coordinator.generate(
        prompt: _state.scenarioGenerationPrompt,
        marketCityId: _runtimeDefaults.marketCityId,
        draft: current,
      );
      final ScenarioDraftData? latest = _state.draft.scenarioData;
      if (requestSerial != _scenarioGenerationRequestSerial ||
          latest == null ||
          latest.revision != sourceRevision) {
        if (requestSerial == _scenarioGenerationRequestSerial) {
          _setState(
            _state.copyWith(
              scenarioGenerationLoading: false,
              scenarioGenerationError:
                  'Scenario changed. Generate a fresh preview.',
              clearScenarioGenerationPreview: true,
            ),
          );
        }
        return;
      }
      _setState(
        _state.copyWith(
          scenarioGenerationLoading: false,
          scenarioGenerationPreview: preview,
          clearScenarioGenerationError: true,
        ),
      );
    } on ScenarioGenerationFailure catch (error) {
      if (requestSerial != _scenarioGenerationRequestSerial) return;
      _setState(
        _state.copyWith(
          scenarioGenerationLoading: false,
          scenarioGenerationError: error.message,
          clearScenarioGenerationPreview: true,
        ),
      );
    } catch (_) {
      if (requestSerial != _scenarioGenerationRequestSerial) return;
      _setState(
        _state.copyWith(
          scenarioGenerationLoading: false,
          scenarioGenerationError:
              'Could not build this local demo preview. Try again.',
          clearScenarioGenerationPreview: true,
        ),
      );
    }
  }

  void discardScenarioGenerationPreview() {
    _scenarioGenerationRequestSerial++;
    _setState(
      _state.copyWith(
        scenarioGenerationLoading: false,
        clearScenarioGenerationPreview: true,
        clearScenarioGenerationError: true,
      ),
    );
  }

  void applyScenarioGenerationPreview() {
    final ScenarioGenerationCoordinator? coordinator =
        _scenarioGenerationCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    final ScenarioGenerationProposal? proposal =
        _state.scenarioGenerationPreview?.proposal;
    if (coordinator == null ||
        current == null ||
        proposal == null ||
        !proposal.canApply) {
      return;
    }

    try {
      final ScenarioDraftData next = coordinator.apply(current, proposal);
      _scenarioGenerationRequestSerial++;
      _applyScenario(next);
      _setState(
        _state.copyWith(
          scenarioGenerationLoading: false,
          clearScenarioGenerationPreview: true,
          clearScenarioGenerationError: true,
          message: 'AI proposal added to your Scenario.',
        ),
      );
    } on ScenarioGenerationStaleFailure {
      _scenarioGenerationRequestSerial++;
      _setState(
        _state.copyWith(
          scenarioGenerationLoading: false,
          clearScenarioGenerationPreview: true,
          scenarioGenerationError:
              'Scenario changed. Generate a fresh preview.',
        ),
      );
    }
  }

  void updateScenarioContext({
    ScenarioFormat? format,
    ScenarioDateMode? dateMode,
    int? peopleCount,
    ScenarioPartyKind? partyKind,
    ScenarioPace? pace,
    ScenarioBudgetBasis? budgetBasis,
  }) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(
      coordinator.updateContext(
        current,
        format: format,
        dateMode: dateMode,
        peopleCount: peopleCount,
        partyKind: partyKind,
        pace: pace,
        budgetBasis: budgetBasis,
      ),
    );
  }

  Future<void> searchScenarioCatalog(String query) async {
    final CatalogObjectPickerPort? picker = _catalogObjectPicker;
    if (picker == null) return;
    _setState(_state.copyWith(scenarioCatalogLoading: true));
    final List<ScenarioCatalogObjectCandidate> results = await picker.search(
      query,
    );
    _setState(
      _state.copyWith(
        scenarioCatalogLoading: false,
        scenarioCatalogCandidates: results,
      ),
    );
  }

  void addScenarioCatalogItem(ScenarioCatalogObjectCandidate candidate) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(coordinator.addCatalogItem(current, candidate));
  }

  void addScenarioTimeBlock({
    required String title,
    required int durationMinutes,
  }) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(
      coordinator.addTimeBlock(
        current,
        title: title,
        durationMinutes: durationMinutes,
      ),
    );
  }

  void updateScenarioTransport({
    required ScenarioTravelMode primaryTravelMode,
    required Set<ScenarioTravelMode> allowedTravelModes,
  }) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(
      coordinator.updateTransportPreferences(
        current,
        primaryTravelMode: primaryTravelMode,
        allowedTravelModes: allowedTravelModes,
      ),
    );
  }

  void addScenarioPlannedTransport({
    required ScenarioPlannedTransportKind kind,
    required String carrierName,
    required String serviceLabel,
    required int durationMinutes,
    ScenarioLocalTimeDraft? plannedDeparture,
    ScenarioLocalTimeDraft? plannedArrival,
  }) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(
      coordinator.addPlannedTransport(
        current,
        kind: kind,
        carrierName: carrierName,
        serviceLabel: serviceLabel,
        durationMinutes: durationMinutes,
        plannedDeparture: plannedDeparture,
        plannedArrival: plannedArrival,
      ),
    );
  }

  ScenarioTransitMutationResult? applyScenarioTransitSelection({
    required int expectedRevision,
    required ScenarioTransitServiceOption option,
    String? replaceItemId,
  }) {
    final coordinator = _scenarioCreateCoordinator;
    final current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return null;
    final result = coordinator.applyTransitSelection(
      current,
      expectedRevision: expectedRevision,
      option: option,
      replaceItemId: replaceItemId,
    );
    _scenarioTransitTelemetry.trackMutation(
      replacing: replaceItemId != null,
      mutation: result,
      freshness: option.manifest.freshness,
    );
    if (result.accepted) {
      _applyScenario(result.draft);
    } else {
      _setState(
        _state.copyWith(
          message: _transitMutationFailureMessage(result.failure),
        ),
      );
    }
    return result;
  }

  void upsertScenarioManualLeg({
    required String fromItemId,
    required String toItemId,
    required ScenarioTravelMode mode,
    required int durationMinutes,
    required double distanceKm,
    int? otherCostMinorUnits,
  }) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(
      coordinator.upsertManualLeg(
        current,
        fromItemId: fromItemId,
        toItemId: toItemId,
        mode: mode,
        durationMinutes: durationMinutes,
        distanceKm: distanceKm,
        otherCostMinorUnits: otherCostMinorUnits,
      ),
    );
  }

  void addScenarioCustomStop({
    required String title,
    required int durationMinutes,
    required double latitude,
    required double longitude,
  }) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(
      coordinator.addCustomStop(
        current,
        title: title,
        durationMinutes: durationMinutes,
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  void moveScenarioItem(String itemId, int delta) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(coordinator.moveItem(current, itemId: itemId, delta: delta));
  }

  void updateScenarioItem(
    String itemId, {
    ScenarioItemRole? role,
    bool? orderLocked,
    bool? timeLocked,
    bool? selected,
  }) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(
      coordinator.updateItem(
        current,
        itemId,
        role: role,
        orderLocked: orderLocked,
        timeLocked: timeLocked,
        selected: selected,
      ),
    );
  }

  void removeScenarioItem(String itemId) {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (coordinator == null || current == null) return;
    _applyScenario(coordinator.removeItem(current, itemId));
  }

  void undoScenario() {
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (current == null || _state.scenarioUndoStack.isEmpty) return;
    final List<ScenarioDraftData> undo = <ScenarioDraftData>[
      ..._state.scenarioUndoStack,
    ];
    final ScenarioDraftData previous = undo.removeLast();
    _setState(
      _state.copyWith(
        draft: _state.draft.copyWith(scenarioData: previous),
        scenarioUndoStack: undo,
        scenarioRedoStack: <ScenarioDraftData>[
          ..._state.scenarioRedoStack,
          current,
        ],
        saveStatus: CreateSaveStatus.unsaved,
      ),
    );
    _scheduleScenarioAutosave();
  }

  void redoScenario() {
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (current == null || _state.scenarioRedoStack.isEmpty) return;
    final List<ScenarioDraftData> redo = <ScenarioDraftData>[
      ..._state.scenarioRedoStack,
    ];
    final ScenarioDraftData next = redo.removeLast();
    _setState(
      _state.copyWith(
        draft: _state.draft.copyWith(scenarioData: next),
        scenarioUndoStack: <ScenarioDraftData>[
          ..._state.scenarioUndoStack,
          current,
        ],
        scenarioRedoStack: redo,
        saveStatus: CreateSaveStatus.unsaved,
      ),
    );
    _scheduleScenarioAutosave();
  }

  Future<bool> goToScenarioStep(int step) async {
    _setState(
      _state.copyWith(scenarioStep: step.clamp(0, 2), clearMessage: true),
    );
    await saveDraft();
    return true;
  }

  Future<bool> saveScenarioToMyScenarios() async {
    final ScenarioReadinessResult? readiness = scenarioReadiness;
    if (_state.draft.title.trim().isEmpty || readiness == null) {
      _setState(
        _state.copyWith(
          validationErrors: const <String, String>{
            'title': 'Give the Scenario a title',
          },
          message: 'Add a title before saving',
        ),
      );
      return false;
    }
    if (!readiness.canSaveToMyScenarios) {
      _setState(
        _state.copyWith(
          validationErrors: <String, String>{
            for (final ScenarioValidationIssue issue
                in readiness.validation.issues)
              if (issue.severity == ScenarioValidationSeverity.error)
                issue.path: issue.message,
          },
          message: 'Resolve the blocking Scenario issues',
        ),
      );
      return false;
    }
    await saveDraft();
    return _state.saveStatus != CreateSaveStatus.failed;
  }

  bool applyConvertedScenario(CreateDraftEntity converted) {
    if (converted.objectType != CreateObjectType.scenario ||
        converted.scenarioData == null ||
        converted.organizerId != _state.userId) {
      return false;
    }
    _autosaveTimer?.cancel();
    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        draft: converted,
        saveStatus: CreateSaveStatus.unsaved,
        scenarioStep: 0,
        clearScenarioUndoStack: true,
        clearScenarioRedoStack: true,
        clearScenarioCatalogCandidates: true,
        scenarioGenerationPrompt: '',
        scenarioGenerationLoading: false,
        clearScenarioGenerationPreview: true,
        clearScenarioGenerationError: true,
        clearValidationErrors: true,
        clearMessage: true,
        clearPublishedDraft: true,
      ),
    );
    _scheduleScenarioAutosave();
    _analyticsService.track(
      'quick_plan_expanded_to_scenario',
      params: <String, Object?>{
        'scenario_id': converted.id,
        'source_id': converted.scenarioData?.origin?.sourceId,
        'source_revision': converted.scenarioData?.origin?.sourceRevision,
      },
    );
    return true;
  }

  Future<bool> openScenarioDraftById({
    required String userId,
    required String draftId,
  }) async {
    final loadById = _loadCreateDraftByIdUseCase;
    if (loadById == null || userId != _state.userId || draftId.trim().isEmpty) {
      return false;
    }
    _autosaveTimer?.cancel();
    _setState(
      _state.copyWith(
        status: CreateStatus.loading,
        clearMessage: true,
        clearValidationErrors: true,
      ),
    );
    try {
      final draft = await loadById(ownerId: userId, draftId: draftId);
      if (draft == null ||
          draft.id != draftId ||
          draft.organizerId != userId ||
          draft.objectType != CreateObjectType.scenario ||
          draft.scenarioData == null) {
        _setState(
          _state.copyWith(
            status: CreateStatus.ready,
            message: 'Scenario is no longer available.',
          ),
        );
        return false;
      }
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          draft: draft,
          saveStatus: CreateSaveStatus.saved,
          scenarioStep: 1,
          clearScenarioUndoStack: true,
          clearScenarioRedoStack: true,
          clearScenarioCatalogCandidates: true,
          scenarioGenerationPrompt: '',
          scenarioGenerationLoading: false,
          clearScenarioGenerationPreview: true,
          clearScenarioGenerationError: true,
          clearValidationErrors: true,
          clearMessage: true,
          clearPublishedDraft: true,
        ),
      );
      return true;
    } on Object {
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          message: 'Could not open this Scenario.',
        ),
      );
      return false;
    }
  }

  void updateTitle(String value) {
    _updateDraft(
      _state.draft.copyWith(
        title: value.trim(),
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
    _invalidatePlaceDuplicateCheck();
  }

  void updateMainCategory(String value) => _updateDraft(
    _state.draft.copyWith(
      mainCategory: normalizeRechargeContentGroupId(value),
      updatedAtUtc: DateTime.now().toUtc(),
    ),
  );

  void updateSubcategory(String value) => _updateDraft(
    _state.draft.copyWith(
      subcategory: normalizeRechargeLegacySubcategoryId(value),
      updatedAtUtc: DateTime.now().toUtc(),
    ),
  );

  void updateTags(Iterable<String> values) {
    final List<String> tags = values
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .take(8)
        .toList(growable: false);
    _updateDraft(
      _state.draft.copyWith(tags: tags, updatedAtUtc: DateTime.now().toUtc()),
    );
  }

  void applyTaxonomySelection({
    required String mainCategory,
    required String subcategory,
  }) {
    final String normalizedGroup = normalizeRechargeContentGroupId(
      mainCategory,
    );
    final String normalizedSubcategory = normalizeRechargeLegacySubcategoryId(
      subcategory,
    );
    final Map<String, Object?> existingCriteria = <String, Object?>{
      ...?_state.draft.sectionData['criteria'] as Map<String, Object?>?,
    };
    final Map<String, Object?> inactiveCriteria = <String, Object?>{
      ...?_state.draft.sectionData['inactive_place_criteria']
          as Map<String, Object?>?,
    };
    final CategoryCriteriaResult? nextProfile =
        const GetCategoryCriteriaUseCase()(normalizedSubcategory);
    final Set<String> nextFieldIds =
        nextProfile?.fields.map((field) => field.id).toSet() ??
        const <String>{};
    final Map<String, Object?> retainedCriteria = <String, Object?>{
      for (final MapEntry<String, Object?> entry in <String, Object?>{
        ...inactiveCriteria,
        ...existingCriteria,
      }.entries)
        if (nextFieldIds.contains(entry.key)) entry.key: entry.value,
    };
    final Map<String, Object?> nextInactiveCriteria = <String, Object?>{
      for (final MapEntry<String, Object?> entry in <String, Object?>{
        ...inactiveCriteria,
        ...existingCriteria,
      }.entries)
        if (!nextFieldIds.contains(entry.key)) entry.key: entry.value,
    };
    final PlaceCreationPolicy placePolicy = placeCreationPolicyFor(
      normalizedSubcategory,
    );
    final PlaceKind suggestedKind = placePolicy.suggestedKind;
    final Map<String, Object?> sectionData = <String, Object?>{
      ..._state.draft.sectionData,
      'criteria': retainedCriteria,
      'inactive_place_criteria': nextInactiveCriteria,
    };
    final PlaceDraftData? placeData = _state.draft.placeData;
    _updateDraft(
      _state.draft.copyWith(
        mainCategory: normalizedGroup,
        subcategory: normalizedSubcategory,
        sectionData: sectionData,
        placeData: placeData
            ?.copyWith(
              categoryConfirmed: true,
              placeKind: suggestedKind,
              relationshipToPlace:
                  placeData.relationshipToPlace ?? PlaceRelationship.visitor,
            )
            .nextRevision(),
        availabilityKind: placePolicy.hours == PlaceFieldRequirement.hidden
            ? CreateAvailabilityKind.none
            : _state.draft.availabilityKind,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
    _invalidatePlaceDuplicateCheck();
  }

  void updateCategoryCriterion(String fieldId, Object? value) {
    final Map<String, Object?> criteria = <String, Object?>{
      ...?_state.draft.sectionData['criteria'] as Map<String, Object?>?,
    };
    if (value == null || (value is String && value.trim().isEmpty)) {
      criteria.remove(fieldId);
    } else {
      criteria[fieldId] = value;
    }
    _updateDraft(
      _state.draft.copyWith(
        sectionData: <String, Object?>{
          ..._state.draft.sectionData,
          'criteria': criteria,
        },
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  EventArchetypeChangeImpact eventArchetypeImpact(EventArchetype value) {
    return _eventCreateCoordinator.archetypeImpact(
      _state.draft.eventData?.classification,
      value,
    );
  }

  void selectEventArchetype(EventArchetype value) {
    _selectEventArchetype(value, source: 'manual');
  }

  void _selectEventArchetype(
    EventArchetype value, {
    required String source,
    String? suggestionReason,
    String? suggestionConfidence,
  }) {
    if (!_eventClassificationEnabled) return;
    final EventArchetypeChangeImpact impact = eventArchetypeImpact(value);
    _updateEvent((EventDraftData event) {
      final EventClassificationDraft current =
          event.classification ?? EventClassificationDraft();
      return event.copyWith(
        schemaVersion:
            event.schemaVersion < EventDraftData.classificationSchemaVersion
            ? EventDraftData.classificationSchemaVersion
            : event.schemaVersion,
        classification: current.copyWith(
          archetype: value,
          clearOtherReason: impact.clearsOtherReason,
        ),
      );
    });
    _analyticsService.track(
      'event_classification_archetype_selected',
      params: <String, Object?>{
        'archetype': value.wireName,
        'source': source,
        if (suggestionReason != null) 'suggestion_reason': suggestionReason,
        if (suggestionConfidence != null)
          'suggestion_confidence': suggestionConfidence,
      },
    );
  }

  void selectEventPrimaryParticipation(ParticipationMode value) {
    if (!_eventClassificationEnabled) return;
    _updateEvent((EventDraftData event) {
      final EventClassificationDraft current =
          event.classification ?? EventClassificationDraft();
      final Set<ParticipationMode> additional = <ParticipationMode>{
        ...current.additionalParticipationModes,
      }..remove(value);
      return event.copyWith(
        schemaVersion:
            event.schemaVersion < EventDraftData.classificationSchemaVersion
            ? EventDraftData.classificationSchemaVersion
            : event.schemaVersion,
        classification: current.copyWith(
          primaryParticipationMode: value,
          additionalParticipationModes: additional,
        ),
      );
    });
    _analyticsService.track(
      'event_classification_primary_participation_selected',
      params: <String, Object?>{'mode': value.wireName},
    );
  }

  void setEventAdditionalParticipation(ParticipationMode value, bool enabled) {
    if (!_eventClassificationEnabled) return;
    final EventClassificationDraft current =
        _state.draft.eventData?.classification ?? EventClassificationDraft();
    if (enabled && value == current.primaryParticipationMode) return;
    final Set<ParticipationMode> additional = <ParticipationMode>{
      ...current.additionalParticipationModes,
    };
    if (enabled && additional.length >= 3 && !additional.contains(value)) {
      _setState(
        _state.copyWith(
          message: 'Можно выбрать не более трёх дополнительных ролей',
        ),
      );
      return;
    }
    enabled ? additional.add(value) : additional.remove(value);
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        schemaVersion:
            event.schemaVersion < EventDraftData.classificationSchemaVersion
            ? EventDraftData.classificationSchemaVersion
            : event.schemaVersion,
        classification: current.copyWith(
          additionalParticipationModes: additional,
        ),
      ),
    );
    _analyticsService.track(
      'event_classification_additional_participation_changed',
      params: <String, Object?>{
        'mode': value.wireName,
        'selected': enabled,
        'count': additional.length,
      },
    );
  }

  void updateEventArchetypeOtherReason(String value) {
    if (!_eventClassificationEnabled) return;
    final EventClassificationDraft? current =
        _state.draft.eventData?.classification;
    if (current?.archetype != EventArchetype.other) return;
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        schemaVersion:
            event.schemaVersion < EventDraftData.classificationSchemaVersion
            ? EventDraftData.classificationSchemaVersion
            : event.schemaVersion,
        classification: current!.copyWith(
          otherReason: value.trim(),
          clearOtherReason: value.trim().isEmpty,
        ),
      ),
    );
  }

  bool confirmEventClassificationSuggestion({int? expectedRevision}) {
    final int currentRevision = _state.draft.eventData?.revision ?? -1;
    if (expectedRevision != null && expectedRevision != currentRevision) {
      _setState(
        _state.copyWith(
          message: 'Classification changed. Review the current draft.',
        ),
      );
      return false;
    }
    final suggestion = eventClassificationState.suggestion;
    if (suggestion == null) return false;
    _selectEventArchetype(
      suggestion.archetype,
      source: 'suggestion',
      suggestionReason: suggestion.reasonCode,
      suggestionConfidence: suggestion.confidence.name,
    );
    return true;
  }

  void clearEventClassification() {
    if (!_eventClassificationEnabled) return;
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        schemaVersion:
            event.schemaVersion < EventDraftData.classificationSchemaVersion
            ? EventDraftData.classificationSchemaVersion
            : event.schemaVersion,
        clearClassification: true,
      ),
    );
    _analyticsService.track(
      'event_classification_cleared',
      params: const <String, Object?>{'status': 'cleared'},
    );
  }

  void previewEventAdmissionPreset(
    EventAdmissionPreset preset, {
    AdmissionMode? admissionMode,
    EventRegistrationMode? registrationMode,
    ConfirmationMode? confirmationMode,
  }) {
    if (!_eventAdmissionConfigurationEnabled) return;
    final result = _eventCreateCoordinator.normalizeAdmissionPreset(
      preset,
      admissionMode: admissionMode,
      registrationMode: registrationMode,
      confirmationMode: confirmationMode,
    );
    _selectedAdmissionPreset = preset;
    _admissionPresetPreview = result.admission;
    _admissionPresetIssues = result.issues;
    _admissionPresetRevision = _state.draft.eventData?.revision;
    notifyListeners();
  }

  bool applyEventAdmissionPreset({int? expectedRevision}) {
    if (!_eventAdmissionConfigurationEnabled) return false;
    final EventDraftData? event = _state.draft.eventData;
    final EventAdmissionDraft? preview = _admissionPresetPreview;
    final int? expected = expectedRevision ?? _admissionPresetRevision;
    if (event == null ||
        preview == null ||
        (expected != null && expected != event.revision)) {
      _setState(
        _state.copyWith(
          message: 'Admission configuration changed. Preview the preset again.',
        ),
      );
      return false;
    }
    if (!_applyEventAdmission(preview)) return false;
    _admissionPresetPreview = null;
    _admissionPresetIssues = const <EventValidationIssue>[];
    _admissionPresetRevision = null;
    return true;
  }

  bool confirmEventAdmissionLegacySuggestion({int? expectedRevision}) {
    if (!_eventAdmissionConfigurationEnabled) return false;
    final EventDraftData? event = _state.draft.eventData;
    final suggestion = eventAdmissionState.legacySuggestion;
    if (event == null ||
        suggestion == null ||
        !suggestion.canConfirm ||
        (expectedRevision != null && expectedRevision != event.revision)) {
      _setState(
        _state.copyWith(
          message: 'Legacy admission suggestion must be reviewed again.',
        ),
      );
      return false;
    }
    return _applyEventAdmission(suggestion.admission);
  }

  void updateEventAdmissionAxes({
    AdmissionMode? admissionMode,
    EventRegistrationMode? registrationMode,
    ConfirmationMode? confirmationMode,
  }) {
    if (!_eventAdmissionConfigurationEnabled) return;
    final EventAdmissionDraft current =
        _state.draft.eventData?.admission ??
        const EventAdmissionDraft(
          admissionMode: null,
          registrationMode: null,
          confirmationMode: null,
        );
    _clearAdmissionPresetSelection();
    _applyEventAdmission(
      current.copyWith(
        admissionMode: admissionMode,
        registrationMode: registrationMode,
        confirmationMode: confirmationMode,
      ),
    );
  }

  void updateEventEligibilityRules(List<EligibilityRule> rules) {
    _updateEventAdmissionPolicy(
      (current) => current.copyWith(
        eligibilityRules: List<EligibilityRule>.unmodifiable(rules),
      ),
    );
  }

  String? addEventEligibilityRule(EligibilityRuleKind kind) {
    if (!_eventAdmissionConfigurationEnabled) return null;
    if (!_eventAccessWritable('admission')) return null;
    final EventAdmissionDraft current =
        _state.draft.eventData?.admission ??
        const EventAdmissionDraft(
          admissionMode: null,
          registrationMode: null,
          confirmationMode: null,
        );
    final String id = _localId();
    updateEventEligibilityRules(<EligibilityRule>[
      ...current.eligibilityRules,
      EligibilityRule(id: id, kind: kind),
    ]);
    return id;
  }

  void updateEventEligibilityRule(EligibilityRule rule) {
    final EventAdmissionDraft? current = _state.draft.eventData?.admission;
    if (current == null ||
        !current.eligibilityRules.any((item) => item.id == rule.id)) {
      return;
    }
    updateEventEligibilityRules(
      current.eligibilityRules
          .map((item) => item.id == rule.id ? rule : item)
          .toList(growable: false),
    );
  }

  void removeEventEligibilityRule(String ruleId) {
    final EventAdmissionDraft? current = _state.draft.eventData?.admission;
    if (current == null ||
        !current.eligibilityRules.any((item) => item.id == ruleId)) {
      return;
    }
    updateEventEligibilityRules(
      current.eligibilityRules
          .where((item) => item.id != ruleId)
          .toList(growable: false),
    );
  }

  void updateEventGuestPolicy(GuestPolicy? policy) {
    _updateEventAdmissionPolicy(
      (current) => current.copyWith(
        guestPolicy: policy,
        clearGuestPolicy: policy == null,
      ),
    );
  }

  void updateEventOnsiteAdmissionPolicy(OnsiteAdmissionPolicy? policy) {
    _updateEventAdmissionPolicy(
      (current) => current.copyWith(
        onsiteAdmissionPolicy: policy,
        clearOnsiteAdmissionPolicy: policy == null,
      ),
    );
  }

  void updateEventInterestPolicy(InterestPolicy? policy) {
    _updateEventAdmissionPolicy(
      (current) => current.copyWith(
        interestPolicy: policy,
        clearInterestPolicy: policy == null,
      ),
    );
  }

  void updateEventAccessWindows({
    EventAccessWindow? registrationWindow,
    bool clearRegistrationWindow = false,
    EventAccessWindow? applicationWindow,
    bool clearApplicationWindow = false,
  }) {
    _updateEventAdmissionPolicy(
      (current) => current.copyWith(
        registrationWindow: registrationWindow,
        clearRegistrationWindow: clearRegistrationWindow,
        applicationWindow: applicationWindow,
        clearApplicationWindow: clearApplicationWindow,
      ),
    );
  }

  void updateEventWaitlistConfiguration(WaitlistConfiguration? policy) {
    _updateEventAdmissionPolicy(
      (current) => current.copyWith(
        waitlistPolicy: policy,
        clearWaitlistPolicy: policy == null,
      ),
    );
  }

  void selectEventInventoryAuthority(InventoryAuthority authority) {
    if (!_eventAdmissionConfigurationEnabled) return;
    final EventInventoryConfiguration current =
        _state.draft.eventData?.inventory ??
        const EventInventoryConfiguration(authority: InventoryAuthority.none);
    _applyEventInventory(
      authority == InventoryAuthority.none
          ? const EventInventoryConfiguration(
              authority: InventoryAuthority.none,
            )
          : current.copyWith(authority: authority),
    );
  }

  void selectEventInventoryShapes({
    required InventoryShape primaryShape,
    Set<InventoryShape> additionalShapes = const <InventoryShape>{},
  }) {
    if (!_eventAdmissionConfigurationEnabled) return;
    final EventInventoryConfiguration current =
        _state.draft.eventData?.inventory ??
        const EventInventoryConfiguration(authority: InventoryAuthority.none);
    final Set<InventoryShape> normalized = <InventoryShape>{...additionalShapes}
      ..remove(primaryShape);
    _applyEventInventory(
      current.copyWith(
        primaryShape: primaryShape,
        additionalShapes: normalized,
      ),
    );
  }

  String? addEventInventoryPool({
    required String label,
    required InventoryShape shape,
    required InventoryChannel channel,
    required EventCapacityMode capacityMode,
    int? capacity,
    List<String> roleIds = const <String>[],
    String? zoneRef,
  }) {
    if (!_eventAdmissionConfigurationEnabled) return null;
    if (!_eventAccessWritable('inventory')) return null;
    final EventInventoryConfiguration current =
        _state.draft.eventData?.inventory ??
        const EventInventoryConfiguration(authority: InventoryAuthority.none);
    final String id = _localId();
    final EventInventoryPoolDraft pool = EventInventoryPoolDraft(
      id: id,
      label: label.trim(),
      shape: shape,
      channel: channel,
      capacityMode: capacityMode,
      capacity: capacityMode == EventCapacityMode.known ? capacity : null,
      roleIds: List<String>.unmodifiable(roleIds),
      zoneRef: zoneRef?.trim(),
    );
    _applyEventInventory(
      current.copyWith(
        pools: <EventInventoryPoolDraft>[...current.pools, pool],
      ),
    );
    return id;
  }

  void updateEventInventoryPool(EventInventoryPoolDraft pool) {
    if (!_eventAdmissionConfigurationEnabled) return;
    final EventInventoryConfiguration? current =
        _state.draft.eventData?.inventory;
    if (current == null || !current.pools.any((item) => item.id == pool.id)) {
      return;
    }
    _applyEventInventory(
      current.copyWith(
        pools: current.pools
            .map((item) => item.id == pool.id ? pool : item)
            .toList(growable: false),
      ),
    );
  }

  void removeEventInventoryPool(String poolId) {
    if (!_eventAdmissionConfigurationEnabled) return;
    final EventInventoryConfiguration? current =
        _state.draft.eventData?.inventory;
    if (current == null || !current.pools.any((item) => item.id == poolId)) {
      return;
    }
    _applyEventInventory(
      current.copyWith(
        pools: current.pools
            .where((item) => item.id != poolId)
            .toList(growable: false),
      ),
    );
  }

  void reorderEventInventoryPool(int oldIndex, int newIndex) {
    if (!_eventAdmissionConfigurationEnabled) return;
    final EventInventoryConfiguration? current =
        _state.draft.eventData?.inventory;
    if (current == null ||
        oldIndex < 0 ||
        oldIndex >= current.pools.length ||
        newIndex < 0 ||
        newIndex >= current.pools.length ||
        oldIndex == newIndex) {
      return;
    }
    final List<EventInventoryPoolDraft> pools = <EventInventoryPoolDraft>[
      ...current.pools,
    ];
    final EventInventoryPoolDraft moved = pools.removeAt(oldIndex);
    pools.insert(newIndex, moved);
    _applyEventInventory(current.copyWith(pools: pools));
  }

  Future<void> refreshEventMockAvailabilityPreview() async {
    if (!_eventAdmissionConfigurationEnabled ||
        !_eventMockAvailabilityEnabled) {
      return;
    }
    final int request = ++_eventAvailabilityRequestSerial;
    _refreshingEventAvailability = true;
    notifyListeners();
    final EventAvailabilityProjection projection = await _eventCreateCoordinator
        .loadAvailabilityPreview(_state.draft);
    if (request != _eventAvailabilityRequestSerial) return;
    _eventAvailabilityPreview = projection;
    _refreshingEventAvailability = false;
    notifyListeners();
  }

  void updateEventFormat(EventFormat value) {
    _updateEvent((EventDraftData event) => event.copyWith(format: value));
  }

  void updateEventOnlineAccess({
    EventOnlineAccessMode? mode,
    String? publicUrl,
    bool clearMode = false,
    bool clearPublicUrl = false,
  }) {
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        onlineAccessMode: mode,
        clearOnlineAccessMode: clearMode,
        publicOnlineUrl: publicUrl?.trim(),
        clearPublicOnlineUrl: clearPublicUrl,
      ),
    );
  }

  void updateEventLocation({
    String? city,
    String? venueName,
    String? address,
    String? meetingPoint,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    bool? pinConfirmed,
  }) {
    _updateEvent((EventDraftData event) {
      final bool invalidatesPin =
          address != null ||
          latitude != null ||
          longitude != null ||
          clearLatitude ||
          clearLongitude;
      return event.copyWith(
        location: event.location.copyWith(
          city: city?.trim(),
          venueName: venueName?.trim(),
          formattedAddress: address?.trim(),
          meetingPoint: meetingPoint?.trim(),
          latitude: latitude,
          clearLatitude: clearLatitude,
          longitude: longitude,
          clearLongitude: clearLongitude,
          pinConfirmed:
              pinConfirmed ??
              (invalidatesPin ? false : event.location.pinConfirmed),
        ),
      );
    });
  }

  void updateEventSchedule({
    EventScheduleMode? mode,
    bool? allDay,
    String? localStartDate,
    int? startMinute,
    int? durationMinutes,
    String? timezoneId,
  }) {
    _updateEvent((EventDraftData event) {
      final bool nextAllDay = allDay ?? event.allDay;
      final int nextDuration = durationMinutes ?? event.durationMinutes;
      return event.copyWith(
        scheduleMode: mode,
        allDay: allDay,
        localStartDate: localStartDate?.trim(),
        startMinute: startMinute,
        durationMinutes: nextAllDay && nextDuration % 1440 != 0
            ? 1440
            : nextDuration,
        timezoneId: timezoneId?.trim(),
      );
    });
  }

  void updateEventMultiDates(Iterable<String> values) {
    final List<String> dates =
        values
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    _updateEvent(
      (EventDraftData event) => event.copyWith(multiDateLocalDates: dates),
    );
  }

  void updateEventRecurrence(EventRecurrenceRuleDraft value) {
    _updateEvent((EventDraftData event) => event.copyWith(recurrence: value));
  }

  void updateEventMediaMetadata({
    String? coverAltText,
    bool? rightsConfirmed,
    Map<String, String>? galleryAltText,
  }) {
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        mediaMetadata: event.mediaMetadata.copyWith(
          coverAltText: coverAltText,
          rightsConfirmed: rightsConfirmed,
          galleryAltText: galleryAltText,
        ),
      ),
    );
  }

  void updateEventGalleryAltText(String mediaReference, String value) {
    final EventDraftData? event = _state.draft.eventData;
    if (event == null || !_state.draft.media.gallery.contains(mediaReference)) {
      return;
    }
    updateEventMediaMetadata(
      galleryAltText: <String, String>{
        ...event.mediaMetadata.galleryAltText,
        mediaReference: value,
      },
    );
  }

  void setEventAmenity(String id, bool enabled) {
    _updateEvent((EventDraftData event) {
      final Set<String> ids = <String>{...event.amenityIds};
      enabled ? ids.add(id) : ids.remove(id);
      return event.copyWith(amenityIds: ids);
    });
  }

  void updateEventRequirements(String value) {
    _updateEvent(
      (EventDraftData event) => event.copyWith(requirements: value.trim()),
    );
  }

  void updateEventAudience({
    int? ageMin,
    int? ageMax,
    bool clearAgeMin = false,
    bool clearAgeMax = false,
    bool? familyFriendly,
    bool? kidsAllowed,
    bool? petFriendly,
    bool? allowsPartialAttendance,
  }) {
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        ageMin: ageMin,
        clearAgeMin: clearAgeMin,
        ageMax: ageMax,
        clearAgeMax: clearAgeMax,
        familyFriendly: familyFriendly,
        kidsAllowed: kidsAllowed,
        petFriendly: petFriendly,
        allowsPartialAttendance: allowsPartialAttendance,
      ),
    );
  }

  void updateEventPricing({
    required EventPricingMode mode,
    EventPaymentCollectionMode? collectionMode,
    int? amountMinor,
  }) {
    _updateEvent((EventDraftData event) {
      final bool free = mode == EventPricingMode.free;
      return event.copyWith(
        pricingMode: mode,
        paymentCollectionMode: free
            ? EventPaymentCollectionMode.none
            : (collectionMode ?? event.paymentCollectionMode),
        price: free
            ? null
            : EventMoneyDraft(
                amountMinor: amountMinor ?? event.price?.amountMinor ?? 0,
                currencyCode: event.currencyCode,
              ),
        clearPrice: free,
      );
    });
  }

  void updateEventCapacity(EventCapacityMode mode, {int? capacity}) {
    if (_eventAdmissionConfigurationEnabled &&
        !_eventAccessWritable('inventory')) {
      return;
    }
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        schemaVersion: _eventAdmissionConfigurationEnabled
            ? EventDraftData.accessSchemaVersion
            : event.schemaVersion,
        capacityMode: mode,
        capacity: mode == EventCapacityMode.known ? capacity : null,
        clearCapacity: mode != EventCapacityMode.known,
      ),
    );
  }

  void updateEventRegistration({
    required EventRegistrationMode mode,
    String? externalBookingUrl,
  }) {
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        registrationMode: mode,
        externalBookingUrl: externalBookingUrl?.trim(),
        clearExternalBookingUrl: mode != EventRegistrationMode.external,
      ),
    );
  }

  void updateEventExternalRegistrationUrl(String value) {
    if (!_eventAdmissionConfigurationEnabled) return;
    if (!_eventAccessWritable('admission')) return;
    _updateEvent(
      (event) => event.copyWith(
        schemaVersion: EventDraftData.accessSchemaVersion,
        externalBookingUrl: value.trim(),
        clearExternalBookingUrl: value.trim().isEmpty,
      ),
    );
  }

  void updateEventVisibility(EventVisibility value) {
    _updateEvent((EventDraftData event) => event.copyWith(visibility: value));
  }

  Future<bool> goToEventStep(int step) async {
    final int nextStep = step.clamp(0, 4);
    if (nextStep > _state.eventStep) {
      final List<EventValidationIssue> issues = _eventIssues(
        draft: _state.draft,
        throughStep: nextStep - 1,
      );
      final List<EventValidationIssue> blocking = issues
          .where((EventValidationIssue issue) => issue.isBlocking)
          .toList(growable: false);
      if (blocking.isNotEmpty) {
        final int firstInvalidStep = blocking
            .map((EventValidationIssue issue) => issue.step)
            .reduce((int left, int right) => left < right ? left : right);
        _setState(
          _state.copyWith(
            eventStep: firstInvalidStep,
            eventValidationIssues: issues,
            message: 'Проверьте обязательные поля шага Event',
          ),
        );
        return false;
      }
    }
    _setState(
      _state.copyWith(
        eventStep: nextStep,
        eventValidationIssues: _eventIssues(),
        clearMessage: true,
      ),
    );
    await saveDraft();
    return true;
  }

  void updatePlaceKind(PlaceKind value) {
    _updatePlace((PlaceDraftData place) => place.copyWith(placeKind: value));
  }

  void updatePlaceRelationship(PlaceRelationship value) {
    _updatePlace((PlaceDraftData place) {
      final PlaceSourceType sourceType = switch (value) {
        PlaceRelationship.owner => PlaceSourceType.ownerSubmission,
        PlaceRelationship.staff => PlaceSourceType.staffSubmission,
        PlaceRelationship.visitor ||
        PlaceRelationship.curator => PlaceSourceType.creatorSubmission,
      };
      final PlaceDataProvenance previous = place.provenance;
      return place.copyWith(
        relationshipToPlace: value,
        provenance: PlaceDataProvenance(
          sourceType: sourceType,
          submittedByUserId: previous.submittedByUserId,
          createdAtUtc: previous.createdAtUtc,
          lastConfirmedAtUtc: DateTime.now().toUtc(),
          hoursConfirmedAtUtc: previous.hoursConfirmedAtUtc,
          pricingConfirmedAtUtc: previous.pricingConfirmedAtUtc,
          contactsConfirmedAtUtc: previous.contactsConfirmedAtUtc,
        ),
      );
    });
  }

  void updatePlaceContentLocale(String value) {
    if (!_runtimeDefaults.supportedContentLocales.contains(value)) return;
    _updatePlace(
      (PlaceDraftData place) => place.copyWith(contentLocale: value),
    );
  }

  void updatePlaceLanguages(Set<String> values) {
    _updatePlace(
      (PlaceDraftData place) => place.copyWith(
        languages: values
            .where(_runtimeDefaults.supportedServiceLanguages.contains)
            .toSet(),
      ),
    );
  }

  void updatePlaceAddress(String value) {
    final String? normalized = _nullableText(value);
    _updatePlace(
      (PlaceDraftData place) {
        return place.copyWith(
          location: place.location.copyWith(
            formattedAddress: normalized,
            clearFormattedAddress: normalized == null,
          ),
        );
      },
      commonDraft: (CreateDraftEntity draft) {
        return draft.copyWith(addressLine1: normalized ?? '');
      },
    );
  }

  void updatePlaceLocationLabel(String value) {
    final String? normalized = _nullableText(value);
    _updatePlace(
      (PlaceDraftData place) {
        return place.copyWith(
          location: place.location.copyWith(
            locationLabel: normalized,
            clearLocationLabel: normalized == null,
          ),
        );
      },
      commonDraft: (CreateDraftEntity draft) {
        return draft.copyWith(venueName: normalized ?? '');
      },
    );
  }

  void updatePlaceEntranceHint(String value) {
    final String? normalized = _nullableText(value);
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(
        location: place.location.copyWith(
          entranceHint: normalized,
          clearEntranceHint: normalized == null,
        ),
      );
    });
  }

  void updatePlaceCoordinates({
    required String latitude,
    required String longitude,
  }) {
    final double? lat = _parseDouble(latitude);
    final double? lng = _parseDouble(longitude);
    _updatePlace(
      (PlaceDraftData place) {
        return place.copyWith(
          location: place.location.copyWith(
            latitude: lat,
            clearLatitude: lat == null,
            longitude: lng,
            clearLongitude: lng == null,
            timezoneId: '',
            accuracy: PlaceLocationAccuracy.manual,
            pinConfirmed: false,
            clearGeocodedAtUtc: true,
          ),
        );
      },
      commonDraft: (CreateDraftEntity draft) {
        return draft.copyWith(
          latitude: lat,
          clearLatitude: lat == null,
          longitude: lng,
          clearLongitude: lng == null,
        );
      },
    );
  }

  void confirmPlacePin() {
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(
        location: place.location.copyWith(
          pinConfirmed: true,
          timezoneId: _runtimeDefaults.timezone,
        ),
      );
    });
  }

  void updateActivityCoordinates({
    required String latitude,
    required String longitude,
  }) {
    final double? lat = _parseDouble(latitude);
    final double? lng = _parseDouble(longitude);
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(
          latitude: lat,
          clearLatitude: lat == null,
          longitude: lng,
          clearLongitude: lng == null,
          pinConfirmed: false,
        ),
      ),
    );
  }

  void confirmActivityPin() {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(pinConfirmed: true),
      ),
    );
  }

  void updateActivityAddressLine(String value) {
    final String trimmed = value.trim();
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(
          addressLine: trimmed,
          clearAddressLine: trimmed.isEmpty,
        ),
      ),
    );
  }

  void updateActivityAccessNotes(String value) {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(accessNotes: value.trim()),
      ),
    );
  }

  void updateActivityAccessCaution({required bool isInformal, String? note}) {
    _updateActivity((ActivityDraftData activity) {
      final String trimmedNote = (note ?? '').trim();
      return activity.copyWith(
        location: activity.location.copyWith(
          accessCaution: isInformal
              ? ActivityAccessCautionDraft(
                  isInformal: true,
                  note: trimmedNote.isEmpty ? null : trimmedNote,
                )
              : null,
          clearAccessCaution: !isInformal,
        ),
      );
    });
  }

  void updateActivityLinkedPlaceId(String? placeId) {
    final String trimmed = (placeId ?? '').trim();
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        location: activity.location.copyWith(
          linkedPlaceId: trimmed.isEmpty ? null : trimmed,
          clearLinkedPlaceId: trimmed.isEmpty,
        ),
      ),
    );
  }

  void updateActivityOptionalContribution({
    ActivityContributionKind? kind,
    String? note,
    int? amountMinor,
  }) {
    _updateActivity((ActivityDraftData activity) {
      final String trimmedNote = (note ?? '').trim();
      return activity.copyWith(
        optionalContribution: ActivityOptionalContributionDraft(
          kind: kind,
          note: trimmedNote.isEmpty ? null : trimmedNote,
          amountHint: amountMinor == null
              ? null
              : ActivityContributionAmountDraft(
                  amountMinor: amountMinor,
                  currencyCode: _runtimeDefaults.currency,
                ),
        ),
      );
    });
  }

  void clearActivityOptionalContribution() {
    _updateActivity(
      (ActivityDraftData activity) =>
          activity.copyWith(clearOptionalContribution: true),
    );
  }

  void updateActivityBestTime({
    ActivityTimeOfDay? timeOfDay,
    ActivitySeason? season,
  }) {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        bestTime: ActivityBestTimeDraft(timeOfDay: timeOfDay, season: season),
      ),
    );
  }

  void updateActivityTypicalDuration({required int min, required int max}) {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        typicalDurationMinutes: ActivityIntRangeDraft(min: min, max: max),
      ),
    );
  }

  void updateActivitySuggestedGroupSize({required int min, required int max}) {
    _updateActivity(
      (ActivityDraftData activity) => activity.copyWith(
        suggestedGroupSize: ActivityIntRangeDraft(min: min, max: max),
      ),
    );
  }

  void clearActivitySuggestedGroupSize() {
    _updateActivity(
      (ActivityDraftData activity) =>
          activity.copyWith(clearSuggestedGroupSize: true),
    );
  }

  void updatePlaceHoursMode(PlaceHoursMode mode) {
    _updatePlace((PlaceDraftData place) {
      final bool clearsPeriods =
          mode == PlaceHoursMode.alwaysOpen ||
          mode == PlaceHoursMode.unknown ||
          mode == PlaceHoursMode.seasonal;
      return place.copyWith(
        hours: place.hours.copyWith(
          mode: mode,
          weeklyPeriods: clearsPeriods
              ? const <LocalOpeningPeriod>[]
              : place.hours.weeklyPeriods,
          exceptions: mode == PlaceHoursMode.unknown
              ? const <OpeningException>[]
              : place.hours.exceptions,
        ),
      );
    });
  }

  void addPlaceOpeningPeriod({
    required int dayOfWeek,
    required int openMinute,
    required int closeMinute,
    required bool closesNextDay,
  }) {
    _updatePlace((PlaceDraftData place) {
      final LocalOpeningPeriod period = LocalOpeningPeriod(
        id: _localId(),
        dayOfWeek: dayOfWeek,
        openMinute: openMinute,
        closeMinute: closeMinute,
        closesNextDay: closesNextDay,
      );
      return place.copyWith(
        hours: place.hours.copyWith(
          weeklyPeriods: <LocalOpeningPeriod>[
            ...place.hours.weeklyPeriods,
            period,
          ],
        ),
      );
    });
  }

  void removePlaceOpeningPeriod(String id) {
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(
        hours: place.hours.copyWith(
          weeklyPeriods: place.hours.weeklyPeriods
              .where((LocalOpeningPeriod period) => period.id != id)
              .toList(growable: false),
        ),
      );
    });
  }

  void addPlaceException({
    required String localDate,
    required OpeningExceptionKind kind,
  }) {
    _updatePlace((PlaceDraftData place) {
      final OpeningException exception = OpeningException(
        id: _localId(),
        localDate: localDate.trim(),
        kind: kind,
        periods: kind == OpeningExceptionKind.customHours
            ? <LocalOpeningPeriod>[
                LocalOpeningPeriod(
                  id: _localId(),
                  dayOfWeek: DateTime.tryParse(localDate)?.weekday ?? 1,
                  openMinute: 9 * 60,
                  closeMinute: 18 * 60,
                  closesNextDay: false,
                ),
              ]
            : const <LocalOpeningPeriod>[],
      );
      return place.copyWith(
        hours: place.hours.copyWith(
          exceptions: <OpeningException>[...place.hours.exceptions, exception],
        ),
      );
    });
  }

  void removePlaceException(String id) {
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(
        hours: place.hours.copyWith(
          exceptions: place.hours.exceptions
              .where((OpeningException exception) => exception.id != id)
              .toList(growable: false),
        ),
      );
    });
  }

  void updatePlaceOperationalStatus({
    required PlaceOperationalStatus status,
    String? closedFromLocalDate,
    String? closedUntilLocalDate,
    String? publicNote,
  }) {
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(
        operationalStatus: PlaceOperationalStatusDraft(
          status: status,
          closedFromLocalDate:
              status == PlaceOperationalStatus.temporarilyClosed
              ? _nullableText(closedFromLocalDate)
              : null,
          closedUntilLocalDate:
              status == PlaceOperationalStatus.temporarilyClosed
              ? _nullableText(closedUntilLocalDate)
              : null,
          publicNote: _nullableText(publicNote),
        ),
      );
    });
  }

  void updatePlaceVisitPlanning({
    String? recommendedMinutes,
    String? minimumMinutes,
    bool? allowsShortVisit,
    bool? weatherDependent,
    int? arrivalBufferMinutes,
    int? exitBufferMinutes,
  }) {
    _updatePlace((PlaceDraftData place) {
      final int? recommended = recommendedMinutes == null
          ? place.visitPlanning.recommendedVisitMinutes
          : int.tryParse(recommendedMinutes.trim());
      final int? minimum = minimumMinutes == null
          ? place.visitPlanning.minimumVisitMinutes
          : int.tryParse(minimumMinutes.trim());
      return place.copyWith(
        visitPlanning: place.visitPlanning.copyWith(
          recommendedVisitMinutes: recommended,
          clearRecommendedVisitMinutes:
              recommendedMinutes != null && recommended == null,
          minimumVisitMinutes: minimum,
          clearMinimumVisitMinutes: minimumMinutes != null && minimum == null,
          allowsShortVisit: allowsShortVisit,
          weatherDependent: weatherDependent,
          arrivalBufferMinutes: arrivalBufferMinutes,
          exitBufferMinutes: exitBufferMinutes,
        ),
      );
    });
  }

  void setPlaceAmenity(String id, {required bool? available}) {
    _updatePlace((PlaceDraftData place) {
      final Set<String> present = <String>{...place.amenityIds}..remove(id);
      final Set<String> unknown = <String>{...place.amenityUnknownIds}
        ..remove(id);
      if (available == true) present.add(id);
      if (available == null) unknown.add(id);
      return place.copyWith(amenityIds: present, amenityUnknownIds: unknown);
    });
  }

  void updatePlaceEntryType(PlaceEntryType value) {
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(pricing: place.pricing.copyWith(entryType: value));
    });
  }

  void updatePlacePricing({
    String? entryFrom,
    String? entryTo,
    String? spendFrom,
    String? spendTo,
    String? note,
    String? pricingUrl,
  }) {
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(
        pricing: place.pricing.copyWith(
          entryPriceFrom: entryFrom == null ? null : _parseDouble(entryFrom),
          clearEntryPriceFrom:
              entryFrom != null && _parseDouble(entryFrom) == null,
          entryPriceTo: entryTo == null ? null : _parseDouble(entryTo),
          clearEntryPriceTo: entryTo != null && _parseDouble(entryTo) == null,
          typicalSpendFrom: spendFrom == null ? null : _parseDouble(spendFrom),
          clearTypicalSpendFrom:
              spendFrom != null && _parseDouble(spendFrom) == null,
          typicalSpendTo: spendTo == null ? null : _parseDouble(spendTo),
          clearTypicalSpendTo: spendTo != null && _parseDouble(spendTo) == null,
          pricingNote: note == null ? null : _nullableText(note),
          clearPricingNote: note != null && _nullableText(note) == null,
          officialPricingUrl: pricingUrl == null
              ? null
              : _nullableText(pricingUrl),
          clearOfficialPricingUrl:
              pricingUrl != null && _nullableText(pricingUrl) == null,
        ),
      );
    });
  }

  void updatePlaceContacts({
    String? websiteUrl,
    String? phone,
    String? email,
    String? bookingUrl,
  }) {
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(
        contacts: place.contacts.copyWith(
          websiteUrl: websiteUrl == null ? null : _nullableText(websiteUrl),
          clearWebsiteUrl:
              websiteUrl != null && _nullableText(websiteUrl) == null,
          phone: phone == null ? null : _nullableText(phone),
          clearPhone: phone != null && _nullableText(phone) == null,
          email: email == null ? null : _nullableText(email),
          clearEmail: email != null && _nullableText(email) == null,
          bookingUrl: bookingUrl == null ? null : _nullableText(bookingUrl),
          clearBookingUrl:
              bookingUrl != null && _nullableText(bookingUrl) == null,
        ),
      );
    });
  }

  void acceptPlaceWarnings(Iterable<String> codes) {
    _updatePlace((PlaceDraftData place) {
      return place.copyWith(
        acceptedWarningCodes: <String>{...place.acceptedWarningCodes, ...codes},
      );
    }, invalidateDuplicateCheck: false);
  }

  void confirmPlaceIsDifferent() {
    _setState(
      _state.copyWith(duplicateOverrideConfirmed: true, clearMessage: true),
    );
  }

  Future<void> generatePlaceEnrichment() async {
    final PlaceEnrichmentCoordinator? coordinator = _placeEnrichmentCoordinator;
    if (coordinator == null || _state.draft.placeData == null) return;
    final int requestSerial = ++_placeEnrichmentRequestSerial;
    _setState(
      _state.copyWith(
        placeEnrichmentLoading: true,
        clearPlaceEnrichmentProposal: true,
        clearPlaceEnrichmentError: true,
      ),
    );
    try {
      final PlaceEnrichmentProposal proposal = await coordinator.generate(
        _state.draft,
      );
      if (requestSerial != _placeEnrichmentRequestSerial) return;
      _setState(
        _state.copyWith(
          placeEnrichmentLoading: false,
          placeEnrichmentProposal: proposal,
          clearPlaceEnrichmentError: true,
        ),
      );
    } catch (error) {
      if (requestSerial != _placeEnrichmentRequestSerial) return;
      _setState(
        _state.copyWith(
          placeEnrichmentLoading: false,
          placeEnrichmentError:
              'The local helper could not review this draft. Manual creation still works.',
          clearPlaceEnrichmentProposal: true,
        ),
      );
    }
  }

  void applyPlaceEnrichment() {
    final PlaceEnrichmentCoordinator? coordinator = _placeEnrichmentCoordinator;
    final PlaceEnrichmentProposal? proposal = _state.placeEnrichmentProposal;
    if (coordinator == null || proposal == null) return;
    try {
      final CreateDraftEntity next = coordinator.apply(_state.draft, proposal);
      _updateDraft(next);
      _invalidatePlaceDuplicateCheck();
      _setState(
        _state.copyWith(
          message: 'Local suggestions applied. Review them before publishing.',
          clearPlaceEnrichmentProposal: true,
          clearPlaceEnrichmentError: true,
        ),
      );
    } on PlaceEnrichmentStaleFailure {
      _setState(
        _state.copyWith(
          placeEnrichmentError:
              'The draft changed. Run the local review again.',
          clearPlaceEnrichmentProposal: true,
        ),
      );
    }
  }

  void discardPlaceEnrichment() {
    ++_placeEnrichmentRequestSerial;
    _setState(
      _state.copyWith(
        placeEnrichmentLoading: false,
        clearPlaceEnrichmentProposal: true,
        clearPlaceEnrichmentError: true,
      ),
    );
  }

  Future<bool> goToPlaceStep(int step) async {
    final int nextStep = step.clamp(0, 2);
    if (nextStep > _state.placeStep) {
      final List<PlaceValidationIssue> issues = _placeIssues();
      final Set<String> currentSections = switch (_state.placeStep) {
        0 => <String>{'identity', 'category'},
        1 => <String>{'location', 'hours', 'planning', 'amenities', 'pricing'},
        _ => <String>{},
      };
      final List<PlaceValidationIssue> blocking = issues
          .where(
            (PlaceValidationIssue issue) =>
                issue.severity == PlaceValidationSeverity.error &&
                currentSections.contains(issue.sectionId),
          )
          .toList(growable: false);
      if (blocking.isNotEmpty) {
        _setPlaceIssues(issues, message: 'Проверьте обязательные поля шага');
        return false;
      }
    }
    _setState(_state.copyWith(placeStep: nextStep, clearMessage: true));
    await saveDraft();
    return true;
  }

  void resolveRentalReview({required bool convertToRental}) {
    final Map<String, Object?> sectionData = <String, Object?>{
      ..._state.draft.sectionData,
    };
    final Map<String, Object?> migration = <String, Object?>{
      ...?sectionData['migration'] as Map<String, Object?>?,
    }..remove('review_as_rental');
    if (migration.isEmpty) {
      sectionData.remove('migration');
    } else {
      sectionData['migration'] = migration;
    }
    _updateDraft(
      _state.draft.copyWith(
        objectType: convertToRental
            ? CreateObjectType.rental
            : CreateObjectType.session,
        sectionData: sectionData,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateShortDescription(String value) => _updateDraft(
    _state.draft.copyWith(
      shortDescription: value.trim(),
      updatedAtUtc: DateTime.now().toUtc(),
    ),
  );

  void updateFullDescription(String value) => _updateDraft(
    _state.draft.copyWith(
      fullDescription: value.trim(),
      updatedAtUtc: DateTime.now().toUtc(),
    ),
  );

  void updateCity(String value) => _updateDraft(
    _state.draft.copyWith(
      city: value.trim(),
      updatedAtUtc: DateTime.now().toUtc(),
    ),
  );

  void updateVenueName(String value) => _updateDraft(
    _state.draft.copyWith(
      venueName: value.trim(),
      updatedAtUtc: DateTime.now().toUtc(),
    ),
  );

  void updateAddress(String value) => _updateDraft(
    _state.draft.copyWith(
      addressLine1: value.trim(),
      updatedAtUtc: DateTime.now().toUtc(),
    ),
  );

  void updateCoverImage(String value) => _updateDraft(
    _state.draft.copyWith(
      media: _state.draft.media.copyWith(coverImage: value.trim()),
      updatedAtUtc: DateTime.now().toUtc(),
    ),
  );

  void addGalleryImage(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (_state.draft.objectType == CreateObjectType.place &&
        _state.draft.media.gallery.length >= 12) {
      _setState(
        _state.copyWith(message: 'В галерее Place можно сохранить до 12 фото'),
      );
      return;
    }
    final List<String> gallery = <String>[
      ..._state.draft.media.gallery,
      trimmed,
    ];
    if (_state.draft.objectType == CreateObjectType.event &&
        _state.draft.eventData != null) {
      final EventDraftData event = _state.draft.eventData!;
      final CreateDraftEntity base = _state.draft.copyWith(
        media: _state.draft.media.copyWith(gallery: gallery),
      );
      _updateDraft(
        _eventCreateCoordinator.apply(
          base,
          event.copyWith(
            mediaMetadata: event.mediaMetadata.copyWith(
              galleryAltText: <String, String>{
                ...event.mediaMetadata.galleryAltText,
                trimmed: event.mediaMetadata.galleryAltText[trimmed] ?? '',
              },
            ),
          ),
        ),
      );
      return;
    }
    _updateDraft(
      _state.draft.copyWith(
        media: _state.draft.media.copyWith(gallery: gallery),
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void removeGalleryImageAt(int index) {
    if (index < 0 || index >= _state.draft.media.gallery.length) return;
    final String removed = _state.draft.media.gallery[index];
    final List<String> gallery = List<String>.from(_state.draft.media.gallery)
      ..removeAt(index);
    if (_state.draft.objectType == CreateObjectType.event &&
        _state.draft.eventData != null) {
      final EventDraftData event = _state.draft.eventData!;
      final Map<String, String> galleryAltText = <String, String>{
        ...event.mediaMetadata.galleryAltText,
      }..remove(removed);
      final CreateDraftEntity base = _state.draft.copyWith(
        media: _state.draft.media.copyWith(gallery: gallery),
      );
      _updateDraft(
        _eventCreateCoordinator.apply(
          base,
          event.copyWith(
            mediaMetadata: event.mediaMetadata.copyWith(
              galleryAltText: galleryAltText,
            ),
          ),
        ),
      );
      return;
    }
    _updateDraft(
      _state.draft.copyWith(
        media: _state.draft.media.copyWith(gallery: gallery),
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateIsFree(bool isFree) {
    _updateDraft(
      _state.draft.copyWith(
        isFree: isFree,
        clearBasePrice: isFree,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateBasePrice(String value) {
    final double? parsed = parseLocaleDecimalInput(value);
    _updateDraft(
      _state.draft.copyWith(
        basePrice: parsed,
        clearBasePrice: parsed == null,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateStartDateTime(String value) {
    final DateTime? parsed = DateTime.tryParse(value.trim())?.toUtc();
    final List<CreateTimeSlotDraft> slots =
        parsed != null &&
            _state.draft.availabilityKind ==
                CreateAvailabilityKind.eventSlots &&
            _state.draft.scheduleSlots.isEmpty
        ? <CreateTimeSlotDraft>[
            CreateTimeSlotDraft(
              localId: 'loc_${DateTime.now().toUtc().microsecondsSinceEpoch}',
              startAtUtc: parsed,
              endAtUtc: parsed.add(
                Duration(minutes: _state.draft.durationMinutes ?? 60),
              ),
            ),
          ]
        : _state.draft.scheduleSlots;
    _updateDraft(
      _state.draft.copyWith(
        startDateTimeUtc: parsed,
        clearStartDateTimeUtc: parsed == null,
        scheduleSlots: slots,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateDurationMinutes(String value) {
    final int? minutes = int.tryParse(value.trim());
    _updateDraft(
      _state.draft.copyWith(
        durationMinutes: minutes != null && minutes > 0 ? minutes : null,
        clearDurationMinutes: minutes == null || minutes <= 0,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateAvailabilityKind(CreateAvailabilityKind kind) {
    _updateDraft(
      _state.draft.copyWith(
        availabilityKind: kind,
        scheduleSlots: kind == CreateAvailabilityKind.eventSlots
            ? _state.draft.scheduleSlots
            : const <CreateTimeSlotDraft>[],
        openingHours: kind == CreateAvailabilityKind.openingHours
            ? _state.draft.openingHours
            : const <CreateOpeningHoursDraftRule>[],
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void addScheduleSlot({
    required DateTime startAtUtc,
    required DateTime endAtUtc,
  }) {
    if (!startAtUtc.isBefore(endAtUtc)) return;
    final CreateTimeSlotDraft slot = CreateTimeSlotDraft(
      localId: 'loc_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      startAtUtc: startAtUtc.toUtc(),
      endAtUtc: endAtUtc.toUtc(),
    );
    _updateDraft(
      _state.draft.copyWith(
        availabilityKind: CreateAvailabilityKind.eventSlots,
        scheduleSlots: <CreateTimeSlotDraft>[
          ..._state.draft.scheduleSlots,
          slot,
        ],
        openingHours: const <CreateOpeningHoursDraftRule>[],
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void replaceScheduleSlots(List<CreateTimeSlotDraft> slots) {
    final List<CreateTimeSlotDraft> sorted =
        List<CreateTimeSlotDraft>.from(slots)..sort(
          (CreateTimeSlotDraft left, CreateTimeSlotDraft right) =>
              left.startAtUtc.compareTo(right.startAtUtc),
        );
    _updateDraft(
      _state.draft.copyWith(
        availabilityKind: CreateAvailabilityKind.eventSlots,
        scheduleSlots: sorted,
        openingHours: const <CreateOpeningHoursDraftRule>[],
        startDateTimeUtc: sorted.isEmpty ? null : sorted.first.startAtUtc,
        clearStartDateTimeUtc: sorted.isEmpty,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void setFindPeopleExactLocation({
    required String latitude,
    required String longitude,
  }) {
    final double? lat = _parseDouble(latitude);
    final double? lng = _parseDouble(longitude);
    final FindPeopleDraftData? current = _state.draft.findPeopleData;
    if (current == null) return;
    final bool valid =
        lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
    final FindPeopleGeoPointDraft? exact = valid
        ? FindPeopleGeoPointDraft(latitude: lat, longitude: lng)
        : null;
    final FindPeopleGeoPointDraft? public = valid
        ? FindPeopleGeoPointDraft(
            latitude: (lat * 1000).round() / 1000,
            longitude: (lng * 1000).round() / 1000,
          )
        : null;
    updateFindPeopleData(
      current.copyWith(
        exactGeo: exact,
        clearExactGeo: exact == null,
        publicGeo: public,
        clearPublicGeo: public == null,
      ),
    );
  }

  void removeScheduleSlot(String localId) {
    _updateDraft(
      _state.draft.copyWith(
        scheduleSlots: _state.draft.scheduleSlots
            .where((CreateTimeSlotDraft slot) => slot.localId != localId)
            .toList(growable: false),
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void setOpeningRule(CreateOpeningHoursDraftRule rule) {
    final List<CreateOpeningHoursDraftRule> next =
        _state.draft.openingHours
            .where(
              (CreateOpeningHoursDraftRule current) =>
                  current.dayOfWeek != rule.dayOfWeek ||
                  current.exceptionDateIso != rule.exceptionDateIso,
            )
            .toList()
          ..add(rule);
    _updateDraft(
      _state.draft.copyWith(
        availabilityKind: CreateAvailabilityKind.openingHours,
        scheduleSlots: const <CreateTimeSlotDraft>[],
        openingHours: next,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void removeOpeningRule(CreateOpeningHoursDraftRule rule) {
    _updateDraft(
      _state.draft.copyWith(
        openingHours: _state.draft.openingHours
            .where((CreateOpeningHoursDraftRule current) => current != rule)
            .toList(growable: false),
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updatePartialAttendance(bool enabled) {
    _updateDraft(
      _state.draft.copyWith(
        allowsPartialAttendance: enabled,
        clearMinimumVisitDurationMinutes: !enabled,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateMinimumVisitDuration(String value) {
    final int? minutes = int.tryParse(value.trim());
    _updateDraft(
      _state.draft.copyWith(
        minimumVisitDurationMinutes: minutes != null && minutes > 0
            ? minutes
            : null,
        clearMinimumVisitDurationMinutes: minutes == null || minutes <= 0,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateAvailabilityBuffers({required int before, required int after}) {
    _updateDraft(
      _state.draft.copyWith(
        bufferBeforeMinutes: before < 0 ? 0 : before,
        bufferAfterMinutes: after < 0 ? 0 : after,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateCapacity({required int? maximum, required int current}) {
    _updateDraft(
      _state.draft.copyWith(
        maxParticipants: maximum != null && maximum > 0 ? maximum : null,
        clearMaxParticipants: maximum == null || maximum <= 0,
        currentParticipants: current < 0 ? 0 : current,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateRegistrationDeadline(String value) {
    final DateTime? parsed = DateTime.tryParse(value.trim())?.toUtc();
    _updateDraft(
      _state.draft.copyWith(
        registrationDeadlineUtc: parsed,
        clearRegistrationDeadlineUtc: parsed == null,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateFindPeopleData(FindPeopleDraftData value) {
    if (_state.draft.objectType != CreateObjectType.findPeople) return;
    _updateDraft(
      _state.draft.copyWith(
        findPeopleData: value.nextRevision(),
        format: switch (value.meetingMode) {
          FindPeopleMeetingMode.inPerson => 'offline',
          FindPeopleMeetingMode.online => 'online',
          FindPeopleMeetingMode.hybrid => 'hybrid',
        },
        minParticipants: value.hostSeatCount,
        maxParticipants: value.targetGroupSize,
        approvalRequired: value.approvalMode == FindPeopleApprovalMode.manual,
        waitlistEnabled: value.waitlistEnabled,
        isFree: value.costType == FindPeopleCostType.free,
        basePrice: value.costType == FindPeopleCostType.estimated
            ? value.expectedSpendAmount
            : null,
        clearBasePrice: value.costType != FindPeopleCostType.estimated,
        currency: value.currencyCode,
        visibility: switch (value.visibility) {
          FindPeopleVisibility.public => VisibilityType.public,
          FindPeopleVisibility.unlisted => VisibilityType.unlisted,
          FindPeopleVisibility.inviteOnly => VisibilityType.private,
        },
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  Future<bool> goToFindPeopleStep(int step) async {
    final int nextStep = step.clamp(0, 5);
    if (nextStep > _state.findPeopleStep) {
      final List<FindPeopleValidationIssue> issues = _findPeopleIssues();
      final String currentSection = <String>[
        'activity',
        'schedule',
        'meeting',
        'group',
        'hosts',
        'publish',
      ][_state.findPeopleStep];
      final bool blocked = issues.any(
        (FindPeopleValidationIssue issue) =>
            issue.severity == FindPeopleValidationSeverity.error &&
            issue.sectionId == currentSection,
      );
      if (blocked) {
        _setState(
          _state.copyWith(
            findPeopleValidationIssues: issues,
            message: 'Проверьте обязательные поля шага',
          ),
        );
        return false;
      }
    }
    _setState(
      _state.copyWith(
        findPeopleStep: nextStep,
        clearMessage: true,
        findPeopleValidationIssues: _findPeopleIssues(),
      ),
    );
    await saveDraft();
    return true;
  }

  Future<void> saveDraft() async {
    if (_state.userId.isEmpty) return;
    _autosaveTimer?.cancel();
    if (_state.draft.objectType == CreateObjectType.route) {
      final coordinator = _routeCoordinator;
      if (coordinator == null) {
        _setState(
          _state.copyWith(
            saveStatus: CreateSaveStatus.failed,
            message: 'Редактор Route ещё загружается.',
          ),
        );
        return;
      }
      _setState(
        _state.copyWith(
          status: CreateStatus.saving,
          saveStatus: CreateSaveStatus.saving,
          clearMessage: true,
        ),
      );
      final RouteDraftSaveResult result = await coordinator.flushAutosave();
      final bool saved = result.isSaved;
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          draft: coordinator.state.createDraft,
          saveStatus: saved
              ? CreateSaveStatus.saved
              : (result.status == RouteDraftSaveStatus.invalidDraft
                    ? CreateSaveStatus.unsaved
                    : CreateSaveStatus.failed),
          message: saved
              ? 'Черновик Route сохранён'
              : (result.status == RouteDraftSaveStatus.invalidDraft
                    ? 'Дождитесь завершения операций с участками.'
                    : 'Не удалось сохранить Route. Черновик остался в форме.'),
        ),
      );
      return;
    }
    _setState(
      _state.copyWith(
        status: CreateStatus.saving,
        saveStatus: CreateSaveStatus.saving,
        clearMessage: true,
      ),
    );
    try {
      await _saveCreateDraftUseCase(userId: _state.userId, draft: _state.draft);
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          saveStatus: CreateSaveStatus.saved,
          message: 'Черновик сохранен',
        ),
      );
      _analyticsService.track(
        'create_draft_saved',
        params: <String, Object?>{
          'object_type': _state.draft.objectType.taxonomyId,
        },
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          saveStatus: CreateSaveStatus.failed,
          message: 'Не удалось сохранить. Данные остались в форме.',
        ),
      );
    }
  }

  Future<bool> publishDraft() async {
    if (_state.userId.isEmpty) return false;
    if (_state.draft.objectType == CreateObjectType.route) {
      return _publishRouteDraft();
    }
    if (_state.draft.objectType == CreateObjectType.scenario) {
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          message:
              'Public Scenario publishing is not enabled yet. Save it to My Scenarios.',
        ),
      );
      return false;
    }
    await saveDraft();
    if (_state.saveStatus == CreateSaveStatus.failed) return false;
    final Map<String, String> errors = _validate(_state.draft);
    if (errors.isNotEmpty) {
      if (_state.draft.objectType == CreateObjectType.event) {
        final List<EventValidationIssue> eventIssues = _eventIssues();
        final int firstInvalidStep = eventIssues
            .where((EventValidationIssue issue) => issue.isBlocking)
            .map((EventValidationIssue issue) => issue.step)
            .fold<int>(
              4,
              (int current, int value) => value < current ? value : current,
            );
        _setState(
          _state.copyWith(
            status: CreateStatus.ready,
            eventStep: firstInvalidStep,
            validationErrors: errors,
            eventValidationIssues: eventIssues,
            message: 'Проверьте обязательные поля Event',
            clearPublishedDraft: true,
          ),
        );
      } else if (_state.draft.objectType == CreateObjectType.place) {
        _setPlaceIssues(_placeIssues(), message: 'Заполните обязательные поля');
      } else if (_state.draft.objectType == CreateObjectType.activity) {
        _setActivityIssues(
          _activityIssues(),
          message: 'Проверьте обязательные поля Recharge Activity',
        );
      } else if (_state.draft.objectType == CreateObjectType.findPeople) {
        _setState(
          _state.copyWith(
            status: CreateStatus.ready,
            validationErrors: errors,
            findPeopleValidationIssues: _findPeopleIssues(),
            message: 'Проверьте обязательные поля Find People',
            clearPublishedDraft: true,
          ),
        );
      } else {
        _setState(
          _state.copyWith(
            status: CreateStatus.ready,
            validationErrors: errors,
            message: 'Заполните обязательные поля',
            clearPublishedDraft: true,
          ),
        );
      }
      return false;
    }

    if (_state.draft.objectType == CreateObjectType.place) {
      final List<PlaceDuplicateMatch> duplicateMatches = _checkPlaceDuplicates(
        _state.draft,
      );
      if (duplicateMatches.isNotEmpty && !_state.duplicateOverrideConfirmed) {
        _setState(
          _state.copyWith(
            status: CreateStatus.ready,
            placeDuplicateMatches: duplicateMatches,
            message: 'Проверьте похожие места перед публикацией',
          ),
        );
        return false;
      }
      final List<PlaceValidationIssue> issues = _placeIssues();
      final Set<String> accepted =
          _state.draft.placeData?.acceptedWarningCodes ?? const <String>{};
      final List<PlaceValidationIssue> unacceptedWarnings = issues
          .where(
            (PlaceValidationIssue issue) =>
                issue.severity == PlaceValidationSeverity.warning &&
                !accepted.contains(issue.code),
          )
          .toList(growable: false);
      if (unacceptedWarnings.isNotEmpty) {
        _setPlaceIssues(
          issues,
          message: 'Подтвердите предупреждения перед публикацией',
        );
        return false;
      }
    }

    CreateDraftEntity draftToPublish = _state.draft;
    if (draftToPublish.objectType == CreateObjectType.activity) {
      final ActivityAccessCautionDraft? caution =
          draftToPublish.activityData?.location.accessCaution;
      final bool isInformal = caution?.isInformal ?? false;
      if (isInformal) {
        final int priorInformalCount = _countActivityInformalAccess(
          draftToPublish,
        );
        if (priorInformalCount >= 3) {
          draftToPublish = draftToPublish.copyWith(
            moderationStatus: ModerationStatus.flaggedForReview,
          );
        }
      }
    }

    _setState(
      _state.copyWith(
        status: CreateStatus.publishing,
        clearMessage: true,
        clearValidationErrors: true,
      ),
    );

    final CreateDraftEntity published = await _publishCreateDraftUseCase(
      userId: _state.userId,
      draft: draftToPublish,
    );

    // RNT-PUB-01 §1.4: a single, bounded, Rental-only trusted direct-publish
    // attempt immediately after the generic publish above. `rentalData` is
    // checked explicitly here rather than assumed from `objectType ==
    // rental` — that assumption is not a guarantee the code should rely on.
    CreateDraftEntity finalPublished = published;
    bool directPublishApplied = false;
    final RentalDraftData? rentalData = published.rentalData;
    final PromoteRentalToPublishedUseCase? promoteRentalToPublished =
        _promoteRentalToPublished;
    if (published.objectType == CreateObjectType.rental &&
        rentalData != null &&
        promoteRentalToPublished != null) {
      final RentalDirectPublishDecision decision = _resolveRentalDirectPublish(
        RentalDirectPublishContext(
          actorUserId: _state.userId,
          isVerifiedCreator: _isVerifiedCreator,
          capabilities: _capabilities,
          draftPublisherRef: rentalData.publisherRef,
          isPolicyTrusted: _rentalDirectPublishPolicy.isTrusted,
        ),
      );
      if (decision.authorized) {
        try {
          finalPublished = await promoteRentalToPublished(
            userId: _state.userId,
            rentalId: published.id,
            expectedRentalRevision: rentalData.revision,
          );
          directPublishApplied = true;
        } on Object {
          // Fail-closed: keep the pending_review result already obtained
          // above — the user sees a normal successful submit, not an error.
          finalPublished = published;
        }
        // DTL-OBJ-01 §3.5: activate the Discover-facing sink only after a
        // confirmed `published` promotion, never speculatively. Best-effort
        // — a sink failure here does not roll back the already-genuine
        // publish; it only means Discover indexing is delayed (acceptable
        // in this local/mock slice, no retry queue exists yet).
        final RentalPublicationIndexSink? sink = _rentalPublicationIndexSink;
        if (directPublishApplied && sink != null) {
          try {
            await sink.activate(
              RentalPublishedVersion(
                listing: _buildRentalPublicProjection(
                  id: finalPublished.id,
                  draft: finalPublished.rentalData ?? rentalData,
                ),
                publishedAtUtc:
                    finalPublished.publishedAtUtc ?? DateTime.now().toUtc(),
              ),
            );
          } on Object {
            // Swallowed deliberately — see comment above.
          }
        }
      }
    }

    _setState(
      _state.copyWith(
        status: CreateStatus.publishSuccess,
        draft: finalPublished,
        publishedDraft: finalPublished,
        message: directPublishApplied
            ? 'Опубликовано'
            : 'Отправлено на модерацию',
      ),
    );
    _analyticsService.track(
      'create_publish_succeeded',
      params: <String, Object?>{
        'object_type': finalPublished.objectType.taxonomyId,
        'publish_status': finalPublished.publishStatus.name,
        if (directPublishApplied) 'direct_publish': true,
      },
    );
    return true;
  }

  Future<bool> _publishRouteDraft() async {
    final publication = _routePublicationCoordinator;
    if (publication == null) {
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          message: 'Сервис публикации Route недоступен.',
        ),
      );
      return false;
    }
    await saveDraft();
    if (_state.saveStatus == CreateSaveStatus.failed) return false;
    _setState(
      _state.copyWith(
        status: CreateStatus.publishing,
        clearMessage: true,
        clearValidationErrors: true,
        clearRoutePublishReceipt: true,
      ),
    );
    try {
      final receipt = await publication.publish(
        actorId: _state.userId,
        capabilities: _capabilities,
        draft: _state.draft,
      );
      if (!receipt.isSuccess) {
        _setState(
          _state.copyWith(
            status: CreateStatus.ready,
            routePublishReceipt: receipt,
            message:
                'Route не опубликован: ${receipt.reasonCode ?? receipt.status.name}.',
          ),
        );
        return false;
      }
      _setState(
        _state.copyWith(
          status: CreateStatus.publishSuccess,
          draft: receipt.displayDraft,
          publishedDraft: receipt.displayDraft,
          routePublishReceipt: receipt,
          message: receipt.isPublished
              ? 'Route опубликован.'
              : 'Route отправлен на проверку.',
        ),
      );
      _analyticsService.track(
        'route_publish_succeeded',
        params: <String, Object?>{
          'route_id': receipt.routeId,
          'version_id': receipt.versionId,
          'status': receipt.status.name,
          'direct': receipt.isPublished,
        },
      );
      return true;
    } on RoutePublicationAuthorizationException catch (error) {
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          message: 'Операция Route запрещена: ${error.reasonCode}.',
        ),
      );
    } on RoutePublicationBuildException catch (error) {
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          message: 'Route не готов: ${error.codes.join(', ')}.',
        ),
      );
    } catch (_) {
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          message: 'Не удалось отправить Route. Черновик сохранён.',
        ),
      );
    }
    return false;
  }

  Future<bool> loadRouteModerationQueue() async {
    final publication = _routePublicationCoordinator;
    if (publication == null || _state.userId.isEmpty) return false;
    try {
      final requests = await publication.pendingRequests(
        actorId: _state.userId,
        capabilities: _capabilities,
      );
      _setState(
        _state.copyWith(routeModerationRequests: requests, clearMessage: true),
      );
      return true;
    } on RoutePublicationAuthorizationException catch (error) {
      _setState(
        _state.copyWith(
          message: 'Очередь Route недоступна: ${error.reasonCode}.',
        ),
      );
      return false;
    }
  }

  Future<RoutePublishReceipt?> moderateRouteRequest({
    required String requestId,
    required bool approved,
    String? reasonCode,
  }) async {
    final publication = _routePublicationCoordinator;
    if (publication == null || _state.userId.isEmpty) return null;
    try {
      final receipt = await publication.moderate(
        actorId: _state.userId,
        capabilities: _capabilities,
        requestId: requestId,
        approved: approved,
        reasonCode: reasonCode,
      );
      await loadRouteModerationQueue();
      _setState(
        _state.copyWith(
          routePublishReceipt: receipt,
          message: receipt.isPublished
              ? 'Версия Route одобрена и стала активной.'
              : 'Версия Route отклонена.',
        ),
      );
      return receipt;
    } on RoutePublicationAuthorizationException catch (error) {
      _setState(
        _state.copyWith(message: 'Решение запрещено: ${error.reasonCode}.'),
      );
      return null;
    }
  }

  Future<bool> startRouteRevision(String versionId) async {
    final publication = _routePublicationCoordinator;
    if (publication == null || _state.userId.isEmpty) return false;
    try {
      final revision = await publication.createRevision(
        actorId: _state.userId,
        capabilities: _capabilities,
        versionId: versionId,
      );
      _routeCoordinator = null;
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          draft: revision,
          saveStatus: CreateSaveStatus.unsaved,
          clearPublishedDraft: true,
          clearRoutePublishReceipt: true,
          routeStep: 0,
          message:
              'Создана новая версия. Опубликованный Route пока не изменён.',
        ),
      );
      return true;
    } on RoutePublicationAuthorizationException catch (error) {
      _setState(
        _state.copyWith(
          message: 'Новая версия недоступна: ${error.reasonCode}.',
        ),
      );
      return false;
    }
  }

  Future<bool> archiveRoute(String routeId) async {
    final publication = _routePublicationCoordinator;
    if (publication == null || _state.userId.isEmpty) return false;
    try {
      final archived = await publication.archive(
        actorId: _state.userId,
        capabilities: _capabilities,
        routeId: routeId,
      );
      _setState(
        _state.copyWith(
          message: archived == null
              ? 'Route не найден.'
              : 'Route снят с публикации. История версий сохранена.',
        ),
      );
      return archived != null;
    } on RoutePublicationAuthorizationException catch (error) {
      _setState(
        _state.copyWith(message: 'Архивация запрещена: ${error.reasonCode}.'),
      );
      return false;
    }
  }

  void resetToFreshDraft({
    required String organizerId,
    required String organizerEmail,
    required String organizerName,
  }) {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: organizerId,
      organizerEmail: organizerEmail,
      organizerName: organizerName,
      marketCityId: _runtimeDefaults.marketCityId,
      timezone: _runtimeDefaults.timezone,
      country: _runtimeDefaults.country,
      city: _runtimeDefaults.city,
      currency: _runtimeDefaults.currency,
    );
    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        draft: draft,
        clearMessage: true,
        clearValidationErrors: true,
        clearPublishedDraft: true,
        clearRoutePublishReceipt: true,
        clearRouteModerationRequests: true,
        eventStep: 0,
        clearEventValidationIssues: true,
        placeStep: 0,
        findPeopleStep: 0,
        clearFindPeopleValidationIssues: true,
        clearPlaceValidationIssues: true,
        clearPlaceDuplicateMatches: true,
        duplicateOverrideConfirmed: false,
      ),
    );
  }

  Map<String, String> _validate(CreateDraftEntity draft) {
    if (draft.objectType == CreateObjectType.event) {
      return <String, String>{
        for (final EventValidationIssue issue in _eventIssues(draft: draft))
          if (issue.isBlocking) issue.fieldId: issue.message,
      };
    }
    if (draft.objectType == CreateObjectType.place) {
      final List<PlaceValidationIssue> issues = _placeIssues(draft);
      return <String, String>{
        for (final PlaceValidationIssue issue in issues)
          if (issue.severity == PlaceValidationSeverity.error)
            issue.fieldId ?? issue.code: issue.messageKey,
      };
    }
    if (draft.objectType == CreateObjectType.activity) {
      final List<ActivityValidationIssue> issues = _activityIssues(draft);
      return <String, String>{
        for (final ActivityValidationIssue issue in issues)
          if (issue.severity == ActivityValidationSeverity.error)
            issue.fieldId ?? issue.code: issue.messageKey,
      };
    }
    if (draft.objectType == CreateObjectType.findPeople) {
      return <String, String>{
        for (final FindPeopleValidationIssue issue in _findPeopleIssues(draft))
          if (issue.severity == FindPeopleValidationSeverity.error)
            issue.fieldId: issue.message,
      };
    }
    if (draft.objectType == CreateObjectType.scenario) {
      final ScenarioDraftData? scenario = draft.scenarioData;
      if (scenario == null || _scenarioCreateCoordinator == null) {
        return const <String, String>{'scenario': 'Scenario data is missing'};
      }
      return <String, String>{
        if (draft.title.trim().isEmpty) 'title': 'Give the Scenario a title',
        for (final ScenarioValidationIssue issue
            in _scenarioCreateCoordinator.evaluate(scenario).validation.issues)
          if (issue.severity == ScenarioValidationSeverity.error)
            issue.path: issue.message,
      };
    }
    final Map<String, String> errors = <String, String>{
      ..._validateCreateAvailability(draft),
    };
    if (draft.title.trim().isEmpty) {
      errors['title'] = 'Введите title';
    }
    if (draft.mainCategory.trim().isEmpty) {
      errors['mainCategory'] = 'Введите category';
    }
    if (draft.city.trim().isEmpty) {
      errors['city'] = 'Введите city';
    }
    if (draft.media.coverImage.trim().isEmpty) {
      errors['coverImage'] = 'Cover image обязательна';
    }
    final CreateBlockConfig config = createBlockConfigFor(draft.objectType);
    if (config.requiresStartDateTime && draft.startDateTimeUtc == null) {
      errors['startDateTimeUtc'] = 'Для ${config.title} укажите start datetime';
    }
    return errors;
  }

  CreateAvailabilityKind _availabilityKindFor(CreateObjectType type) {
    return switch (type) {
      CreateObjectType.event ||
      CreateObjectType.session ||
      CreateObjectType.classWorkshop ||
      CreateObjectType.findPeople => CreateAvailabilityKind.eventSlots,
      CreateObjectType.rental => CreateAvailabilityKind.openingHours,
      CreateObjectType.place => CreateAvailabilityKind.none,
      _ => CreateAvailabilityKind.none,
    };
  }

  void _updateDraft(CreateDraftEntity next) {
    var resolved = next;
    final coordinator = _routeCoordinator;
    if (next.objectType == CreateObjectType.route && coordinator != null) {
      coordinator.synchronizeEnvelope(next);
      resolved = coordinator.state.createDraft;
    }
    final bool invalidatesPlaceHelper =
        _state.draft.objectType == CreateObjectType.place ||
        resolved.objectType == CreateObjectType.place;
    if (invalidatesPlaceHelper) {
      ++_placeEnrichmentRequestSerial;
    }
    _setState(
      _state.copyWith(
        draft: resolved,
        saveStatus:
            resolved.objectType == CreateObjectType.event ||
                resolved.objectType == CreateObjectType.place ||
                resolved.objectType == CreateObjectType.activity ||
                resolved.objectType == CreateObjectType.findPeople ||
                resolved.objectType == CreateObjectType.scenario ||
                resolved.objectType == CreateObjectType.route ||
                resolved.objectType == CreateObjectType.rental
            ? CreateSaveStatus.unsaved
            : _state.saveStatus,
        clearMessage: true,
        clearValidationErrors: true,
        clearEventValidationIssues: true,
        clearPlaceValidationIssues: true,
        clearActivityValidationIssues: true,
        clearRentalValidationIssues: true,
        placeEnrichmentLoading: invalidatesPlaceHelper ? false : null,
        clearPlaceEnrichmentProposal: invalidatesPlaceHelper,
        clearPlaceEnrichmentError: invalidatesPlaceHelper,
        clearFindPeopleValidationIssues: true,
      ),
    );
    if ((resolved.objectType == CreateObjectType.event ||
            resolved.objectType == CreateObjectType.place ||
            resolved.objectType == CreateObjectType.activity ||
            resolved.objectType == CreateObjectType.findPeople ||
            resolved.objectType == CreateObjectType.scenario ||
            resolved.objectType == CreateObjectType.rental) &&
        _state.userId.isNotEmpty) {
      _autosaveTimer?.cancel();
      _autosaveTimer = Timer(const Duration(milliseconds: 700), saveDraft);
    }
  }

  void _adoptRouteCoordinatorState({RouteCommandOutcome? outcome}) {
    final coordinator = _routeCoordinator;
    if (coordinator == null) return;
    _setState(
      _state.copyWith(
        draft: coordinator.state.createDraft,
        saveStatus: CreateSaveStatus.unsaved,
        message: outcome != null && !outcome.accepted
            ? 'Команда Route отклонена: ${outcome.failureCode?.name ?? 'unknown'}.'
            : null,
        clearMessage: outcome == null || outcome.accepted,
      ),
    );
  }

  PlaceDraftData _placeDefaults(String userId) {
    return PlaceDraftData.defaults(
      userId: userId,
      marketCityId: _runtimeDefaults.marketCityId,
      countryCode: _runtimeDefaults.country,
      city: _runtimeDefaults.city,
      timezoneId: _runtimeDefaults.timezone,
      currencyCode: _runtimeDefaults.currency,
      contentLocale: _runtimeDefaults.defaultContentLocale,
    );
  }

  ActivityDraftData _activityDefaults(String userId) {
    return ActivityDraftData.defaults(
      userId: userId,
      currencyCode: _runtimeDefaults.currency,
    );
  }

  RentalDraftData _rentalDefaults(String userId) {
    final CreateBlockConfig config = createBlockConfigFor(
      CreateObjectType.rental,
    );
    return RentalDraftData.defaults(
      userId: userId,
      currencyCode: _runtimeDefaults.currency,
      timeZoneId: _runtimeDefaults.timezone,
      categoryId: config.defaultCategoryId,
      subcategoryId: config.defaultSubcategoryId,
    ).copyWith(
      publisherRef:
          _activePublisherRef ??
          PublisherRef(type: PublisherType.user, id: userId),
    );
  }

  EventDraftData _eventDefaults() => EventDraftData.defaults(
    marketCityId: _runtimeDefaults.marketCityId,
    countryCode: _runtimeDefaults.country,
    city: _runtimeDefaults.city,
    timezoneId: _runtimeDefaults.timezone,
    currencyCode: _runtimeDefaults.currency,
    publisherRef:
        _activePublisherRef ??
        PublisherRef(type: PublisherType.user, id: _state.draft.organizerId),
  );

  List<EventValidationIssue> _eventIssues({
    CreateDraftEntity? draft,
    int? throughStep,
  }) => _eventCreateCoordinator.validate(
    draft ?? _state.draft,
    throughStep: throughStep,
    includeClassification: _eventClassificationEnabled,
    includeAccessConfiguration: _eventAdmissionConfigurationEnabled,
  );

  bool _applyEventAdmission(EventAdmissionDraft admission) {
    if (!_eventAccessWritable('admission')) return false;
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        schemaVersion: event.schemaVersion < EventDraftData.accessSchemaVersion
            ? EventDraftData.accessSchemaVersion
            : event.schemaVersion,
        admission: admission,
      ),
    );
    return true;
  }

  void _updateEventAdmissionPolicy(
    EventAdmissionDraft Function(EventAdmissionDraft current) transform,
  ) {
    if (!_eventAdmissionConfigurationEnabled) return;
    final EventAdmissionDraft current =
        _state.draft.eventData?.admission ??
        const EventAdmissionDraft(
          admissionMode: null,
          registrationMode: null,
          confirmationMode: null,
        );
    _clearAdmissionPresetSelection();
    _applyEventAdmission(transform(current));
  }

  void _clearAdmissionPresetSelection() {
    _selectedAdmissionPreset = null;
    _admissionPresetPreview = null;
    _admissionPresetIssues = const <EventValidationIssue>[];
    _admissionPresetRevision = null;
  }

  void _applyEventInventory(EventInventoryConfiguration inventory) {
    if (!_eventAccessWritable('inventory')) return;
    _eventAvailabilityRequestSerial++;
    _eventAvailabilityPreview = EventAvailabilityProjection.unknown;
    _refreshingEventAvailability = false;
    _updateEvent(
      (EventDraftData event) => event.copyWith(
        schemaVersion: event.schemaVersion < EventDraftData.accessSchemaVersion
            ? EventDraftData.accessSchemaVersion
            : event.schemaVersion,
        inventory: inventory,
      ),
    );
  }

  bool _eventAccessWritable(String fieldId) {
    final EventDraftData? event = _state.draft.eventData;
    final bool writable =
        event != null &&
        event.schemaVersion <= EventDraftData.currentSchemaVersion &&
        !event.unsupportedFieldIds.contains('eventData') &&
        !event.unsupportedFieldIds.contains(fieldId);
    if (!writable) {
      _setState(
        _state.copyWith(
          message:
              'This Event uses a newer access contract and cannot be changed here.',
        ),
      );
    }
    return writable;
  }

  void _updateEvent(
    EventDraftData Function(EventDraftData event) transform, {
    bool incrementRevision = true,
  }) {
    final EventDraftData? current = _state.draft.eventData;
    if (_state.draft.objectType != CreateObjectType.event || current == null) {
      return;
    }
    _updateDraft(
      _eventCreateCoordinator.apply(
        _state.draft,
        transform(current),
        incrementRevision: incrementRevision,
      ),
    );
  }

  FindPeopleDraftData _findPeopleDefaults(String userId) {
    return FindPeopleDraftData.defaults(
      userId: userId,
      currencyCode: _runtimeDefaults.currency,
      defaultLanguageCode: _runtimeDefaults.defaultContentLocale,
    );
  }

  ScenarioDraftData _scenarioDefaults() {
    final ScenarioCreateCoordinator? coordinator = _scenarioCreateCoordinator;
    if (coordinator == null) {
      final String dayId =
          'draft-day-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      return ScenarioDraftData.defaults(
        timezoneId: _runtimeDefaults.timezone,
        currencyCode: _runtimeDefaults.currency,
      ).copyWith(
        days: <ScenarioDayDraft>[
          ScenarioDayDraft(
            id: dayId,
            title: 'Day 1',
            dayIndex: 0,
            timezoneId: _runtimeDefaults.timezone,
            itemIds: const <String>[],
          ),
        ],
      );
    }
    return coordinator.initial(
      timezoneId: _runtimeDefaults.timezone,
      currencyCode: _runtimeDefaults.currency,
    );
  }

  void _applyScenario(ScenarioDraftData next) {
    final ScenarioDraftData? current = _state.draft.scenarioData;
    if (_state.draft.objectType != CreateObjectType.scenario ||
        current == null ||
        identical(current, next)) {
      return;
    }
    final List<ScenarioDraftData> history = <ScenarioDraftData>[
      ..._state.scenarioUndoStack,
      current,
    ];
    final List<ScenarioDraftData> boundedHistory = history.length <= 50
        ? history
        : history.sublist(history.length - 50);
    _setState(
      _state.copyWith(
        scenarioUndoStack: boundedHistory,
        clearScenarioRedoStack: true,
      ),
    );
    _updateDraft(
      _state.draft.copyWith(
        scenarioData: next,
        format: next.format.name,
        timezone: next.defaultTimezoneId,
        currency: next.displayCurrencyCode,
        visibility: VisibilityType.private,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void _scheduleScenarioAutosave() {
    if (_state.userId.isEmpty) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 700), saveDraft);
  }

  String _transitMutationFailureMessage(
    ScenarioTransitMutationFailure? failure,
  ) => switch (failure) {
    ScenarioTransitMutationFailure.revisionConflict =>
      'Scenario changed. Review the selected service and try again.',
    ScenarioTransitMutationFailure.invalidSelection =>
      'The selected service cannot be applied safely.',
    ScenarioTransitMutationFailure.missingTarget =>
      'The planned transport item no longer exists.',
    ScenarioTransitMutationFailure.targetNotOfficial =>
      'Only an official schedule item can be replaced here.',
    null => 'The selected service was not applied.',
  };

  List<FindPeopleValidationIssue> _findPeopleIssues([
    CreateDraftEntity? draft,
  ]) {
    return _validateFindPeopleDraft(draft ?? _state.draft);
  }

  void _updatePlace(
    PlaceDraftData Function(PlaceDraftData place) transform, {
    CreateDraftEntity Function(CreateDraftEntity draft)? commonDraft,
    bool invalidateDuplicateCheck = true,
  }) {
    final PlaceDraftData? current = _state.draft.placeData;
    if (_state.draft.objectType != CreateObjectType.place || current == null) {
      return;
    }
    final PlaceDraftData nextPlace = transform(current).nextRevision();
    final CreateDraftEntity base =
        commonDraft?.call(_state.draft) ?? _state.draft;
    _updateDraft(
      base.copyWith(placeData: nextPlace, updatedAtUtc: DateTime.now().toUtc()),
    );
    if (invalidateDuplicateCheck) {
      _invalidatePlaceDuplicateCheck();
    }
  }

  void _updateActivity(
    ActivityDraftData Function(ActivityDraftData activity) transform,
  ) {
    final ActivityDraftData? current = _state.draft.activityData;
    if (_state.draft.objectType != CreateObjectType.activity ||
        current == null) {
      return;
    }
    final ActivityDraftData next = transform(current).nextRevision();
    _updateDraft(
      _state.draft.copyWith(
        activityData: next,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  /// Mutates the typed Rental payload. Deliberately a single broad
  /// transform (mirrors `_updateActivity`) rather than one setter per
  /// nested field — `RentalDraftData` has far more nested structure
  /// (inventory/availability/handover/terms/pricing) than the codebase's
  /// other typed drafts, so callers reach any field through the
  /// `copyWith`-chain inside `transform` instead of a huge parallel method
  /// surface here.
  void _updateRental(
    RentalDraftData Function(RentalDraftData rental) transform,
  ) {
    final RentalDraftData? current = _state.draft.rentalData;
    if (_state.draft.objectType != CreateObjectType.rental || current == null) {
      return;
    }
    final RentalDraftData next = transform(current).nextRevision();
    _updateDraft(
      _state.draft.copyWith(
        rentalData: next,
        updatedAtUtc: DateTime.now().toUtc(),
      ),
    );
  }

  void updateRentalCategory({
    required String categoryId,
    required String subcategoryId,
  }) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        categoryConfirmed: false,
      ),
    );
  }

  void confirmRentalCategory() {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(categoryConfirmed: true),
    );
  }

  void updateRentalTitle(String value) {
    _updateRental((RentalDraftData rental) => rental.copyWith(title: value));
  }

  void updateRentalShortDescription(String value) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(shortDescription: value),
    );
  }

  void updateRentalFullDescription(String value) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(fullDescription: value),
    );
  }

  void updateRentalBrandModel(String value) {
    final String? normalized = _nullableText(value);
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        brandModel: normalized,
        clearBrandModel: normalized == null,
      ),
    );
  }

  void addRentalInventoryGroup(RentalInventoryGroup group) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        inventoryGroups: <RentalInventoryGroup>[
          ...rental.inventoryGroups,
          group,
        ],
      ),
    );
  }

  void updateRentalInventoryGroup(
    String groupId,
    RentalInventoryGroup Function(RentalInventoryGroup group) transform,
  ) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        inventoryGroups: rental.inventoryGroups
            .map((RentalInventoryGroup g) => g.id == groupId ? transform(g) : g)
            .toList(growable: false),
      ),
    );
  }

  void removeRentalInventoryGroup(String groupId) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        inventoryGroups: rental.inventoryGroups
            .where((RentalInventoryGroup g) => g.id != groupId)
            .toList(growable: false),
        availability: rental.availability.copyWith(
          blocks: rental.availability.blocks
              .where((RentalAvailabilityBlock b) => b.groupId != groupId)
              .toList(growable: false),
        ),
      ),
    );
  }

  void duplicateRentalInventoryGroup(String groupId) {
    final RentalDraftData? current = _state.draft.rentalData;
    if (current == null) return;
    final RentalInventoryGroup? source = current.inventoryGroups
        .where((RentalInventoryGroup g) => g.id == groupId)
        .cast<RentalInventoryGroup?>()
        .firstWhere((_) => true, orElse: () => null);
    if (source == null) return;
    addRentalInventoryGroup(source.copyWith(id: _localId()));
  }

  void confirmRentalAvailabilityCoverage({
    required DateTime startsAtUtc,
    required DateTime endsAtUtc,
  }) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        availability: rental.availability.copyWith(
          coverage: RentalAvailabilityCoverage(
            startsAtUtc: startsAtUtc,
            endsAtUtc: endsAtUtc,
            confirmedAtUtc: DateTime.now().toUtc(),
          ),
        ),
      ),
    );
  }

  /// Returns `false` without mutating anything if the block would push
  /// concurrent blocked units above the group's `quantity` (spec §8.2) —
  /// the invariant is checked at entry, not after the fact.
  bool addRentalAvailabilityBlock(RentalAvailabilityBlock block) {
    final RentalDraftData? current = _state.draft.rentalData;
    if (current == null) return false;
    final RentalInventoryGroup? group = current.inventoryGroups
        .where((RentalInventoryGroup g) => g.id == block.groupId)
        .cast<RentalInventoryGroup?>()
        .firstWhere((_) => true, orElse: () => null);
    if (group == null) return false;
    final bool exceeds = _evaluateRentalAvailability.wouldExceedCapacity(
      group: group,
      existingActiveBlocksForGroup: current.availability.blocks
          .where(
            (RentalAvailabilityBlock b) =>
                b.groupId == block.groupId && b.isActive,
          )
          .toList(growable: false),
      candidate: block,
    );
    if (exceeds) return false;
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        availability: rental.availability.copyWith(
          blocks: <RentalAvailabilityBlock>[
            ...rental.availability.blocks,
            block,
          ],
        ),
      ),
    );
    return true;
  }

  void cancelRentalAvailabilityBlock(String blockId) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        availability: rental.availability.copyWith(
          blocks: rental.availability.blocks
              .map(
                (RentalAvailabilityBlock b) => b.id == blockId
                    ? b.copyWith(
                        status: RentalBlockStatus.cancelled,
                        updatedAtUtc: DateTime.now().toUtc(),
                      )
                    : b,
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  void updateRentalHandover(
    RentalHandoverDraft Function(RentalHandoverDraft handover) transform,
  ) {
    _updateRental(
      (RentalDraftData rental) =>
          rental.copyWith(handover: transform(rental.handover)),
    );
  }

  void updateRentalTerms(RentalTerms Function(RentalTerms terms) transform) {
    _updateRental(
      (RentalDraftData rental) =>
          rental.copyWith(terms: transform(rental.terms)),
    );
  }

  /// Applies the category's adaptive suggestion (spec §5/§7) into the
  /// current terms — an explicit Creator action, never automatic.
  void applyRentalAdaptiveHint() {
    final RentalDraftData? current = _state.draft.rentalData;
    if (current == null) return;
    final RentalAdaptiveHint? hint = rentalAdaptiveHintFor(current.categoryId);
    if (hint == null) return;
    updateRentalTerms(
      (RentalTerms terms) => terms.copyWith(
        minRenterAge: hint.suggestedMinRenterAge ?? terms.minRenterAge,
        idRequiredAtHandover:
            hint.suggestIdRequired || terms.idRequiredAtHandover,
        safetyNotice: terms.safetyNotice ?? hint.safetyNoticeTemplate,
      ),
    );
  }

  void updateRentalPricing(
    RentalPricingPolicy Function(RentalPricingPolicy pricing) transform,
  ) {
    _updateRental(
      (RentalDraftData rental) =>
          rental.copyWith(pricing: transform(rental.pricing)),
    );
  }

  void addRentalRateStep(RentalRateStep step) {
    updateRentalPricing(
      (RentalPricingPolicy pricing) => pricing.copyWith(
        rateSteps: <RentalRateStep>[...pricing.rateSteps, step]
          ..sort(
            (RentalRateStep a, RentalRateStep b) =>
                a.minUnits.compareTo(b.minUnits),
          ),
      ),
    );
  }

  void removeRentalRateStepAt(int index) {
    updateRentalPricing((RentalPricingPolicy pricing) {
      if (index < 0 || index >= pricing.rateSteps.length) return pricing;
      final List<RentalRateStep> next = List<RentalRateStep>.of(
        pricing.rateSteps,
      )..removeAt(index);
      return pricing.copyWith(rateSteps: next);
    });
  }

  void updateRentalExternalBookingUrl(String value) {
    final String? normalized = _nullableText(value);
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        fulfillment: rental.fulfillment.copyWith(
          externalBookingUrl: normalized,
          clearExternalBookingUrl: normalized == null,
        ),
      ),
    );
  }

  void acceptRentalAttestation({
    required bool hasRightToOffer,
    required bool listingAccurate,
    required bool prohibitedItemsAcknowledged,
  }) {
    _updateRental(
      (RentalDraftData rental) => rental.copyWith(
        attestation: rental.attestation.copyWith(
          acceptedAtUtc: DateTime.now().toUtc(),
          acceptedByUserId: _state.userId,
          hasRightToOffer: hasRightToOffer,
          listingAccurate: listingAccurate,
          prohibitedItemsAcknowledged: prohibitedItemsAcknowledged,
        ),
      ),
    );
  }

  /// Reads the private authoring data for the current draft — always
  /// through `RentalPrivateAuthoringRepository`, never the shared
  /// `CreateRepository` (spec §7.3, AC 12).
  Future<RentalPrivateAuthoringData> loadRentalPrivateAuthoring() async {
    final RentalPrivateAuthoringRepository? repository =
        _rentalPrivateAuthoringRepository;
    if (repository == null) return const RentalPrivateAuthoringData();
    return repository.read(_state.draft.id);
  }

  Future<void> updateRentalPrivateAuthoring(
    RentalPrivateAuthoringData Function(RentalPrivateAuthoringData data)
    transform,
  ) async {
    final RentalPrivateAuthoringRepository? repository =
        _rentalPrivateAuthoringRepository;
    if (repository == null) return;
    final RentalPrivateAuthoringData current = await repository.read(
      _state.draft.id,
    );
    await repository.write(_state.draft.id, transform(current));
  }

  Future<bool> goToRentalStep(int step) async {
    final int nextStep = step.clamp(0, rentalCreateSteps.length - 1);
    if (nextStep > _state.rentalStep) {
      final List<RentalValidationIssue> issues = _rentalIssues();
      final String currentSectionId = rentalCreateSteps[_state.rentalStep].id;
      final List<RentalValidationIssue> blocking = issues
          .where(
            (RentalValidationIssue issue) =>
                issue.isBlocking &&
                _rentalStepIdForSection(issue.sectionId) == currentSectionId,
          )
          .toList(growable: false);
      if (blocking.isNotEmpty) {
        _setRentalIssues(issues, message: 'Проверьте обязательные поля шага');
        return false;
      }
    }
    _setState(_state.copyWith(rentalStep: nextStep, clearMessage: true));
    await saveDraft();
    return true;
  }

  String _rentalStepIdForSection(String sectionId) {
    return switch (sectionId) {
      'rental_listing' => 'listing',
      'rental_inventory' => 'inventory',
      'rental_availability' => 'availability',
      'rental_handover' => 'handover',
      'rental_terms' => 'terms',
      'rental_pricing' => 'pricing',
      'rental_fulfillment' => 'fulfillment',
      'rental_attestation' => 'review',
      _ => 'listing',
    };
  }

  List<RentalValidationIssue> _rentalIssues([CreateDraftEntity? draft]) {
    final CreateDraftEntity target = draft ?? _state.draft;
    return _validateRentalDraft(
      target,
      policy: RentalCreatePolicy.safeFallback,
    );
  }

  void _setRentalIssues(
    List<RentalValidationIssue> issues, {
    required String message,
  }) {
    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        rentalValidationIssues: issues,
        validationErrors: <String, String>{
          for (final RentalValidationIssue issue in issues)
            if (issue.isBlocking)
              (issue.fieldId ?? issue.code): issue.messageKey,
        },
        message: message,
      ),
    );
  }

  Future<bool> saveCurrentRentalAsTemplate(String name) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    final ManageCreateTemplateUseCase? useCase = _manageCreateTemplate;
    if (repository == null || useCase == null || _state.userId.isEmpty) {
      _setState(_state.copyWith(message: 'Хранилище шаблонов недоступно.'));
      return false;
    }
    try {
      final CreateTemplateEntity template = useCase.createRentalTemplate(
        userId: _state.userId,
        name: name,
        draft: _state.draft,
      );
      await repository.upsertTemplate(
        userId: _state.userId,
        template: template,
      );
      await _loadRentalTemplates(_state.userId);
      _setState(
        _state.copyWith(message: 'Шаблон «${template.name}» сохранён.'),
      );
      return true;
    } on Object catch (error) {
      _setState(_state.copyWith(message: _templateErrorMessage(error)));
      return false;
    }
  }

  Future<bool> applyRentalTemplate(String templateId) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    final ManageCreateTemplateUseCase? useCase = _manageCreateTemplate;
    final CreateTemplateEntity? current = _rentalTemplateById(templateId);
    if (repository == null || useCase == null || current == null) return false;
    try {
      final CreateDraftEntity draft = useCase.materializeRental(
        template: current,
        userId: _state.userId,
        currencyCode: _runtimeDefaults.currency,
        timeZoneId: _runtimeDefaults.timezone,
        publisherRef: _activePublisherRef,
      );
      final CreateTemplateEntity used = useCase.markUsed(
        template: current,
        userId: _state.userId,
      );
      await repository.upsertTemplate(userId: _state.userId, template: used);
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          draft: draft,
          rentalStep: 0,
          clearRentalValidationIssues: true,
          clearValidationErrors: true,
          clearPublishedDraft: true,
          message: 'Применён шаблон «${used.name}».',
        ),
      );
      await _loadRentalTemplates(_state.userId);
      await saveDraft();
      return true;
    } on Object catch (error) {
      _setState(_state.copyWith(message: _templateErrorMessage(error)));
      return false;
    }
  }

  /// spec §15.4 `Duplicate listing` — builds a sanitized snapshot from the
  /// currently published/edited listing and materializes it immediately,
  /// without ever persisting a hidden template.
  Future<bool> duplicateRentalListing() async {
    final ManageCreateTemplateUseCase? useCase = _manageCreateTemplate;
    if (useCase == null || _state.userId.isEmpty) return false;
    try {
      final CreateDraftEntity draft = useCase.duplicateRental(
        draft: _state.draft,
        userId: _state.userId,
        currencyCode: _runtimeDefaults.currency,
        timeZoneId: _runtimeDefaults.timezone,
        publisherRef: _activePublisherRef,
      );
      _setState(
        _state.copyWith(
          status: CreateStatus.ready,
          draft: draft,
          rentalStep: 0,
          clearRentalValidationIssues: true,
          clearValidationErrors: true,
          clearPublishedDraft: true,
          message: 'Создан новый черновик на основе этого объявления.',
        ),
      );
      await saveDraft();
      return true;
    } on Object catch (error) {
      _setState(_state.copyWith(message: _templateErrorMessage(error)));
      return false;
    }
  }

  Future<void> startAnotherRental({required String userId}) async {
    await _loadRentalTemplates(userId);
    final CreateTemplateEntity? template = lastRentalTemplate;
    if (template != null) {
      setObjectType(CreateObjectType.rental);
      final bool applied = await applyRentalTemplate(template.id);
      if (applied) return;
    }
    setObjectType(CreateObjectType.rental);
  }

  Future<void> _loadRentalTemplates(String userId) async {
    final CreateTemplateRepository? repository = _createTemplateRepository;
    if (repository == null) {
      _rentalTemplates = const <CreateTemplateEntity>[];
      return;
    }
    _rentalTemplates = await repository.listTemplates(
      userId: userId,
      objectType: CreateObjectType.rental,
    );
    notifyListeners();
  }

  CreateTemplateEntity? _rentalTemplateById(String templateId) {
    for (final CreateTemplateEntity template in _rentalTemplates) {
      if (template.id == templateId &&
          template.ownerUserId == _state.userId &&
          template.objectType == CreateObjectType.rental) {
        return template;
      }
    }
    return null;
  }

  void _invalidatePlaceDuplicateCheck() {
    if (_state.draft.objectType != CreateObjectType.place) return;
    _setState(
      _state.copyWith(
        duplicateOverrideConfirmed: false,
        clearPlaceDuplicateMatches: true,
      ),
    );
  }

  List<PlaceValidationIssue> _placeIssues([CreateDraftEntity? draft]) {
    final CreateDraftEntity target = draft ?? _state.draft;
    final List<PlaceValidationIssue> issues = _validatePlaceDraft(
      target,
      supportedContentLocales: _runtimeDefaults.supportedContentLocales,
      activeMarketCityId: _runtimeDefaults.marketCityId,
      activeMarketCenterLat: _runtimeDefaults.marketCenterLat,
      activeMarketCenterLng: _runtimeDefaults.marketCenterLng,
      canPublish: canManagePlace,
      policy: placeCreationPolicyFor(target.subcategory),
    );
    final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
      target.mainCategory,
    );
    final bool subcategoryAllowed =
        category?.subcategories.any(
          (CreateTaxonomySubcategory item) => item.id == target.subcategory,
        ) ??
        false;
    if (!subcategoryAllowed && target.subcategory.isNotEmpty) {
      issues.add(
        const PlaceValidationIssue(
          code: 'subcategory_not_applicable',
          severity: PlaceValidationSeverity.error,
          sectionId: 'category',
          fieldId: 'subcategory',
          messageKey: 'place.validation.subcategory_not_applicable',
        ),
      );
    }
    final CategoryCriteriaResult? criteria = const GetCategoryCriteriaUseCase()(
      target.subcategory,
    );
    final Map<String, Object?> values = <String, Object?>{
      ...?target.sectionData['criteria'] as Map<String, Object?>?,
    };
    for (final String fieldId
        in criteria?.profile.requiredFieldIds ?? const <String>{}) {
      final Object? value = values[fieldId];
      if (value == null || (value is String && value.trim().isEmpty)) {
        issues.add(
          PlaceValidationIssue(
            code: 'criterion_required',
            severity: PlaceValidationSeverity.error,
            sectionId: 'category',
            fieldId: fieldId,
            messageKey: 'place.validation.criterion_required',
            messageParams: <String, Object?>{'fieldId': fieldId},
          ),
        );
      }
    }
    return issues;
  }

  List<ActivityValidationIssue> _activityIssues([CreateDraftEntity? draft]) {
    final CreateDraftEntity target = draft ?? _state.draft;
    final List<ActivityValidationIssue> issues =
        List<ActivityValidationIssue>.of(_validateActivityDraft(target));
    final CreateTaxonomyCategory? category = createTaxonomyCategoryById(
      target.mainCategory,
    );
    final bool subcategoryAllowed =
        category?.subcategories.any(
          (CreateTaxonomySubcategory item) => item.id == target.subcategory,
        ) ??
        false;
    if (!subcategoryAllowed && target.subcategory.isNotEmpty) {
      issues.add(
        const ActivityValidationIssue(
          code: 'subcategory_not_applicable',
          severity: ActivityValidationSeverity.error,
          sectionId: 'basics',
          fieldId: 'subcategory',
          messageKey: 'activity.validation.subcategory_not_applicable',
        ),
      );
    }
    final CategoryCriteriaResult? criteria = const GetCategoryCriteriaUseCase()(
      target.subcategory,
    );
    final Map<String, Object?> values = <String, Object?>{
      ...?target.sectionData['criteria'] as Map<String, Object?>?,
    };
    for (final String fieldId
        in criteria?.profile.requiredFieldIds ?? const <String>{}) {
      final Object? value = values[fieldId];
      if (value == null || (value is String && value.trim().isEmpty)) {
        issues.add(
          ActivityValidationIssue(
            code: 'criterion_required',
            severity: ActivityValidationSeverity.error,
            sectionId: 'whenFor',
            fieldId: fieldId,
            messageKey: 'activity.validation.criterion_required',
            messageParams: <String, Object?>{'fieldId': fieldId},
          ),
        );
      }
    }
    return issues;
  }

  void _setActivityIssues(
    List<ActivityValidationIssue> issues, {
    required String message,
  }) {
    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        activityValidationIssues: issues,
        validationErrors: <String, String>{
          for (final ActivityValidationIssue issue in issues)
            if (issue.severity == ActivityValidationSeverity.error)
              issue.fieldId ?? issue.code: issue.messageKey,
        },
        message: message,
      ),
    );
  }

  Future<bool> goToActivityStep(int step) async {
    final int nextStep = step.clamp(0, activityCreateSteps.length - 1);
    if (nextStep > _state.activityStep) {
      final List<ActivityValidationIssue> issues = _activityIssues();
      final String currentSectionId =
          activityCreateSteps[_state.activityStep].id;
      final List<ActivityValidationIssue> blocking = issues
          .where(
            (ActivityValidationIssue issue) =>
                issue.severity == ActivityValidationSeverity.error &&
                issue.sectionId == currentSectionId,
          )
          .toList(growable: false);
      if (blocking.isNotEmpty) {
        _setActivityIssues(issues, message: 'Проверьте обязательные поля шага');
        return false;
      }
    }
    _setState(_state.copyWith(activityStep: nextStep, clearMessage: true));
    await saveDraft();
    return true;
  }

  void _setPlaceIssues(
    List<PlaceValidationIssue> issues, {
    required String message,
  }) {
    _setState(
      _state.copyWith(
        status: CreateStatus.ready,
        placeValidationIssues: issues,
        validationErrors: <String, String>{
          for (final PlaceValidationIssue issue in issues)
            if (issue.severity == PlaceValidationSeverity.error)
              issue.fieldId ?? issue.code: issue.messageKey,
        },
        message: message,
      ),
    );
  }

  static String? _nullableText(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static double? _parseDouble(String value) {
    return parseLocaleDecimalInput(value);
  }

  String _localId() =>
      'loc_${DateTime.now().toUtc().microsecondsSinceEpoch}_${_localIdCounter++}';

  void _setState(CreateState state) {
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _scenarioGenerationRequestSerial++;
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
