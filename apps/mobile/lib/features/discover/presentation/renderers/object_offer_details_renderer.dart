import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/event_occurrence.dart';
import '../../domain/entities/opening_hours_rule.dart';
import '../../domain/entities/bookable_session_schedule_evaluation.dart';
import '../../domain/entities/published_bookable_session_discovery_entity.dart';
import '../../domain/entities/published_event_discovery_entity.dart';
import '../../domain/entities/published_find_people_discovery_entity.dart';
import '../../domain/entities/published_event_program_item.dart';
import '../../domain/entities/published_rental_discovery_entity.dart';
import '../../domain/entities/publisher_verification_display_state.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/repositories/timezone_repository.dart';
import '../shell/compatibility_object_renderer.dart';
import '../shell/details_renderer.dart';
import 'object_offer_section_matrix.dart';
import '../../domain/entities/published_class_workshop_discovery_entity.dart';
import 'object_offer_visual_primitives.dart';

/// [DetailsRenderer] for the shared Object/Offer visual profiles. Rental's
/// legacy constructor remains here only for runtime compatibility while its
/// separate Details format is specified; it is not part of the shared visual
/// system.
///
/// Place, Event and Activity iterate their own ordered section matrices on
/// shared primitives. Rental still iterates [rentalDetailsSections] through
/// its pre-existing independent composition. [CompatibilityObjectRenderer] remains
/// the data/callback carrier for legacy [DiscoverItemEntity] inputs, not
/// their visible layout.
/// `objectOfferProfileFor` is likewise load-bearing, not decorative: the
/// `.discoverItem` constructor's `assert` below calls it on every
/// construction, so a caller routing an out-of-scope or `offer`-profile
/// type through `.discoverItem` fails loudly in debug builds instead of
/// silently rendering the wrong layout.
class ObjectOfferDetailsRenderer implements DetailsRenderer {
  ObjectOfferDetailsRenderer.discoverItem({
    required DiscoverItemEntity item,
    required bool isFavorite,
    required bool ctaSubmitted,
    required VoidCallback onFavoriteTap,
    required VoidCallback onShareTap,
    required VoidCallback onMap,
    required VoidCallback onRouteMap,
    VoidCallback? onAddToScenario,
    required VoidCallback onSearch,
    required VoidCallback onCreateSimilar,
    required VoidCallback onCreateRoute,
    required VoidCallback onMarkVisited,
    required VoidCallback onCtaTap,
    required VoidCallback onReportRoute,
  }) : assert(
         objectOfferProfileFor(item.catalogObjectType) ==
                 ObjectOfferProfile.venue ||
             objectOfferProfileFor(item.catalogObjectType) ==
                 ObjectOfferProfile.participation,
         'ObjectOfferDetailsRenderer.discoverItem is for the venue/'
         'participation profiles only — Rental is outside this visual system. '
         'objectOfferProfileFor also throws here for any type outside '
         "this slice's scope (DTL-OBJ-01 §1.1), catching a misrouted "
         'caller instead of silently rendering something generic.',
       ),
       _delegate = CompatibilityObjectRenderer(
         item: item,
         isFavorite: isFavorite,
         ctaSubmitted: ctaSubmitted,
         onFavoriteTap: onFavoriteTap,
         onShareTap: onShareTap,
         onMap: onMap,
         onRouteMap: onRouteMap,
         onAddToScenario: onAddToScenario,
         onSearch: onSearch,
         onCreateSimilar: onCreateSimilar,
         onCreateRoute: onCreateRoute,
         onMarkVisited: onMarkVisited,
         onCtaTap: onCtaTap,
         onReportRoute: onReportRoute,
       ),
       _rentalProjection = null,
       _onExternalCtaTap = null,
       _eventProjection = null,
       _eventTimezoneRepository = null,
       _eventIsFavorite = false,
       _eventOnFavoriteTap = null,
       _eventOnShareTap = null,
       _eventOnMap = null,
       _eventOnAddToScenario = null,
       _eventOnOrganizerTap = null,
       _eventOnAddToCalendar = null,
       _eventOnPrimaryAction = null,
       _findPeopleProjection = null,
       _findPeopleTimezoneRepository = null,
       _findPeopleOnShareTap = null,
       _findPeopleOnMap = null,
       _classWorkshopProps = null,
       _classWorkshopOnShareTap = null,
       _classWorkshopOnMap = null,
       _classWorkshopOnPrimaryAction = null,
       _bookableSessionProjection = null,
       _bookableSessionEvaluation = null,
       _bookableSessionTimezoneRepository = null,
       _bookableSessionOnShareTap = null,
       _bookableSessionOnMap = null,
       _bookableSessionOnPrimaryAction = null;

  ObjectOfferDetailsRenderer.rental({
    required PublishedRentalDiscoveryEntity projection,
    required Future<void> Function() onExternalCtaTap,
  }) : _delegate = null,
       _rentalProjection = projection,
       _onExternalCtaTap = onExternalCtaTap,
       _eventProjection = null,
       _eventTimezoneRepository = null,
       _eventIsFavorite = false,
       _eventOnFavoriteTap = null,
       _eventOnShareTap = null,
       _eventOnMap = null,
       _eventOnAddToScenario = null,
       _eventOnOrganizerTap = null,
       _eventOnAddToCalendar = null,
       _eventOnPrimaryAction = null,
       _findPeopleProjection = null,
       _findPeopleTimezoneRepository = null,
       _findPeopleOnShareTap = null,
       _findPeopleOnMap = null,
       _classWorkshopProps = null,
       _classWorkshopOnShareTap = null,
       _classWorkshopOnMap = null,
       _classWorkshopOnPrimaryAction = null,
       _bookableSessionProjection = null,
       _bookableSessionEvaluation = null,
       _bookableSessionTimezoneRepository = null,
       _bookableSessionOnShareTap = null,
       _bookableSessionOnMap = null,
       _bookableSessionOnPrimaryAction = null;

  /// `DTL-EVT-01` §1.1 — Event stays inside this one shared renderer
  /// (`DISCOVER_DETAILS_SYSTEM_SPEC.md` §3: "три профиля — визуальные
  /// варианты одного renderer'а, не отдельные страницы"), by the same
  /// internal-branch shape `.rental` already uses, not a new top-level
  /// class. `.discoverItem` (Activity/Place) is not touched by this
  /// constructor's existence.
  ObjectOfferDetailsRenderer.event({
    required PublishedEventDiscoveryEntity projection,
    required TimezoneRepository timezoneRepository,
    required bool isFavorite,
    required VoidCallback onFavoriteTap,
    required VoidCallback onShareTap,
    required VoidCallback onMap,
    Future<void> Function()? onAddToScenario,
    VoidCallback? onOrganizerTap,
    Future<void> Function()? onAddToCalendar,
    required Future<void> Function() onPrimaryAction,
  }) : _delegate = null,
       _rentalProjection = null,
       _onExternalCtaTap = null,
       _eventProjection = projection,
       _eventTimezoneRepository = timezoneRepository,
       _eventIsFavorite = isFavorite,
       _eventOnFavoriteTap = onFavoriteTap,
       _eventOnShareTap = onShareTap,
       _eventOnMap = onMap,
       _eventOnAddToScenario = onAddToScenario,
       _eventOnOrganizerTap = onOrganizerTap,
       _eventOnAddToCalendar = onAddToCalendar,
       _eventOnPrimaryAction = onPrimaryAction,
       _findPeopleProjection = null,
       _findPeopleTimezoneRepository = null,
       _findPeopleOnShareTap = null,
       _findPeopleOnMap = null,
       _classWorkshopProps = null,
       _classWorkshopOnShareTap = null,
       _classWorkshopOnMap = null,
       _classWorkshopOnPrimaryAction = null,
       _bookableSessionProjection = null,
       _bookableSessionEvaluation = null,
       _bookableSessionTimezoneRepository = null,
       _bookableSessionOnShareTap = null,
       _bookableSessionOnMap = null,
       _bookableSessionOnPrimaryAction = null;

  /// Typed Find People runtime composition (`DTL-FP-01`). The coordinator
  /// owns actions; this renderer only receives a real Share callback and an
  /// optional public-point Map callback. Save and Join are intentionally not
  /// part of this slice.
  ObjectOfferDetailsRenderer.findPeople({
    required PublishedFindPeopleDiscoveryEntity projection,
    required TimezoneRepository timezoneRepository,
    required VoidCallback onShareTap,
    VoidCallback? onMap,
  }) : _delegate = null,
       _rentalProjection = null,
       _onExternalCtaTap = null,
       _eventProjection = null,
       _eventTimezoneRepository = null,
       _eventIsFavorite = false,
       _eventOnFavoriteTap = null,
       _eventOnShareTap = null,
       _eventOnMap = null,
       _eventOnAddToScenario = null,
       _eventOnOrganizerTap = null,
       _eventOnAddToCalendar = null,
       _eventOnPrimaryAction = null,
       _findPeopleProjection = projection,
       _findPeopleTimezoneRepository = timezoneRepository,
       _findPeopleOnShareTap = onShareTap,
       _findPeopleOnMap = onMap,
       _classWorkshopProps = null,
       _classWorkshopOnShareTap = null,
       _classWorkshopOnMap = null,
       _classWorkshopOnPrimaryAction = null,
       _bookableSessionProjection = null,
       _bookableSessionEvaluation = null,
       _bookableSessionTimezoneRepository = null,
       _bookableSessionOnShareTap = null,
       _bookableSessionOnMap = null,
       _bookableSessionOnPrimaryAction = null;

  /// Typed Class / Workshop runtime (DTL-CLS-01). Private display values
  /// format this projection; they are never an alternative loader input.
  ObjectOfferDetailsRenderer.classWorkshop({
    required PublishedClassWorkshopDiscoveryEntity projection,
    required TimezoneRepository timezoneRepository,
    required VoidCallback onShareTap,
    VoidCallback? onMap,
    Future<void> Function()? onPrimaryAction,
  }) : _delegate = null,
       _rentalProjection = null,
       _onExternalCtaTap = null,
       _eventProjection = null,
       _eventTimezoneRepository = null,
       _eventIsFavorite = false,
       _eventOnFavoriteTap = null,
       _eventOnShareTap = null,
       _eventOnMap = null,
       _eventOnAddToScenario = null,
       _eventOnOrganizerTap = null,
       _eventOnAddToCalendar = null,
       _eventOnPrimaryAction = null,
       _findPeopleProjection = null,
       _findPeopleTimezoneRepository = null,
       _findPeopleOnShareTap = null,
       _findPeopleOnMap = null,
       _classWorkshopProps = _ClassWorkshopDisplay(
         projection,
         timezoneRepository,
       ),
       _classWorkshopOnShareTap = onShareTap,
       _classWorkshopOnMap = onMap,
       _classWorkshopOnPrimaryAction = onPrimaryAction,
       _bookableSessionProjection = null,
       _bookableSessionEvaluation = null,
       _bookableSessionTimezoneRepository = null,
       _bookableSessionOnShareTap = null,
       _bookableSessionOnMap = null,
       _bookableSessionOnPrimaryAction = null;

  /// Typed Bookable Session runtime composition (`DTL-SES-01`). Freshness
  /// and action eligibility are already resolved by the coordinator.
  ObjectOfferDetailsRenderer.bookableSession({
    required PublishedBookableSessionDiscoveryEntity projection,
    required BookableSessionScheduleEvaluation scheduleEvaluation,
    required TimezoneRepository timezoneRepository,
    required VoidCallback onShareTap,
    VoidCallback? onMap,
    required Future<void> Function() onPrimaryAction,
  }) : _delegate = null,
       _rentalProjection = null,
       _onExternalCtaTap = null,
       _eventProjection = null,
       _eventTimezoneRepository = null,
       _eventIsFavorite = false,
       _eventOnFavoriteTap = null,
       _eventOnShareTap = null,
       _eventOnMap = null,
       _eventOnAddToScenario = null,
       _eventOnOrganizerTap = null,
       _eventOnAddToCalendar = null,
       _eventOnPrimaryAction = null,
       _findPeopleProjection = null,
       _findPeopleTimezoneRepository = null,
       _findPeopleOnShareTap = null,
       _findPeopleOnMap = null,
       _classWorkshopProps = null,
       _classWorkshopOnShareTap = null,
       _classWorkshopOnMap = null,
       _classWorkshopOnPrimaryAction = null,
       _bookableSessionProjection = projection,
       _bookableSessionEvaluation = scheduleEvaluation,
       _bookableSessionTimezoneRepository = timezoneRepository,
       _bookableSessionOnShareTap = onShareTap,
       _bookableSessionOnMap = onMap,
       _bookableSessionOnPrimaryAction = onPrimaryAction;

  final CompatibilityObjectRenderer? _delegate;
  final PublishedRentalDiscoveryEntity? _rentalProjection;
  final Future<void> Function()? _onExternalCtaTap;

  final PublishedEventDiscoveryEntity? _eventProjection;
  final TimezoneRepository? _eventTimezoneRepository;
  final bool _eventIsFavorite;
  final VoidCallback? _eventOnFavoriteTap;
  final VoidCallback? _eventOnShareTap;
  final VoidCallback? _eventOnMap;
  final Future<void> Function()? _eventOnAddToScenario;
  final VoidCallback? _eventOnOrganizerTap;
  final Future<void> Function()? _eventOnAddToCalendar;
  final Future<void> Function()? _eventOnPrimaryAction;

  final PublishedFindPeopleDiscoveryEntity? _findPeopleProjection;
  final TimezoneRepository? _findPeopleTimezoneRepository;
  final VoidCallback? _findPeopleOnShareTap;
  final VoidCallback? _findPeopleOnMap;

  final _ClassWorkshopDisplay? _classWorkshopProps;
  final VoidCallback? _classWorkshopOnShareTap;
  final VoidCallback? _classWorkshopOnMap;
  final Future<void> Function()? _classWorkshopOnPrimaryAction;

  final PublishedBookableSessionDiscoveryEntity? _bookableSessionProjection;
  final BookableSessionScheduleEvaluation? _bookableSessionEvaluation;
  final TimezoneRepository? _bookableSessionTimezoneRepository;
  final VoidCallback? _bookableSessionOnShareTap;
  final VoidCallback? _bookableSessionOnMap;
  final Future<void> Function()? _bookableSessionOnPrimaryAction;

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    final CompatibilityObjectRenderer? delegate = _delegate;
    if (delegate != null) {
      if (delegate.item.objectKind == DiscoverObjectKind.place ||
          delegate.item.objectKind == DiscoverObjectKind.activity) {
        return _buildDiscoverItemAppBarActions(delegate);
      }
      return delegate.buildAppBarActions(context);
    }
    if (_eventProjection != null) {
      return <Widget>[
        ObjectOfferHeroActionButton(
          tooltip: _eventIsFavorite ? 'Unsave' : 'Save',
          onPressed: _eventOnFavoriteTap,
          icon: _eventIsFavorite ? Icons.favorite : Icons.favorite_border,
        ),
        _EventHeroShareMenu(
          onShare: _eventOnShareTap!,
          onAddToScenario: _eventOnAddToScenario,
        ),
      ];
    }
    if (_findPeopleProjection != null) {
      return <Widget>[
        ObjectOfferHeroActionButton(
          tooltip: 'Share',
          onPressed: _findPeopleOnShareTap,
          icon: Icons.ios_share_rounded,
        ),
      ];
    }
    if (_classWorkshopProps != null) {
      return <Widget>[
        ObjectOfferHeroActionButton(
          tooltip: 'Share',
          onPressed: _classWorkshopOnShareTap,
          icon: Icons.ios_share_rounded,
        ),
      ];
    }
    if (_bookableSessionProjection != null) {
      return <Widget>[
        ObjectOfferHeroActionButton(
          tooltip: 'Share',
          onPressed: _bookableSessionOnShareTap,
          icon: Icons.ios_share_rounded,
        ),
      ];
    }
    // Rental Details has no save/share wiring yet — matches
    // CollectionDetailsPage's own current scope, not a Rental-specific gap.
    return const <Widget>[];
  }

  @override
  Widget buildHero(BuildContext context) {
    final CompatibilityObjectRenderer? delegate = _delegate;
    if (delegate != null) {
      return switch (delegate.item.objectKind) {
        DiscoverObjectKind.place => ObjectOfferSingleImageHero(
          imageUrl: delegate.item.coverImageUrl,
          imageSemanticLabel: delegate.item.title,
          fallbackIcon: Icons.place_outlined,
          fallbackColor: RechargeTheme.emerald900,
          typeLabel: 'PLACE',
          typeForegroundColor: RechargeTheme.placeAccent,
          typeBackgroundColor: RechargeTheme.placeAccentSurface,
        ),
        DiscoverObjectKind.activity => ObjectOfferSingleImageHero(
          imageUrl: delegate.item.coverImageUrl,
          imageSemanticLabel: delegate.item.title,
          fallbackIcon: Icons.self_improvement_rounded,
          fallbackColor: RechargeTheme.emerald900,
          typeLabel: 'ACTIVITY',
          typeForegroundColor: RechargeTheme.activityAccent,
          typeBackgroundColor: RechargeTheme.activityAccentSurface,
        ),
        DiscoverObjectKind.event ||
        DiscoverObjectKind.route => delegate.buildHero(context),
      };
    }
    if (_eventProjection != null) {
      return _EventHero(projection: _eventProjection);
    }
    if (_findPeopleProjection
        case final PublishedFindPeopleDiscoveryEntity projection) {
      return ObjectOfferSingleImageHero(
        imageUrl: projection.coverImageUrl,
        imageSemanticLabel: projection.title,
        fallbackIcon: Icons.diversity_3_outlined,
        fallbackColor: RechargeTheme.emerald900,
        typeLabel: 'FIND PEOPLE',
        typeForegroundColor: RechargeTheme.findPeopleAccent,
        typeBackgroundColor: RechargeTheme.findPeopleAccentSurface,
      );
    }
    if (_classWorkshopProps case final _ClassWorkshopDisplay props) {
      return _ClassWorkshopHero(
        key: ObjectKey(props.projection),
        projection: props.projection,
      );
    }
    if (_bookableSessionProjection
        case final PublishedBookableSessionDiscoveryEntity projection) {
      return _BookableSessionHero(
        key: ObjectKey(projection),
        projection: projection,
      );
    }
    return _RentalHero(projection: _rentalProjection!);
  }

  @override
  Widget buildBody(BuildContext context) {
    final CompatibilityObjectRenderer? delegate = _delegate;
    if (delegate != null) {
      if (delegate.item.objectKind == DiscoverObjectKind.place) {
        return _buildPlaceBody(delegate);
      }
      if (delegate.item.objectKind == DiscoverObjectKind.activity) {
        return _buildActivityBody(delegate);
      }
      return delegate.buildBody(context);
    }
    if (_eventProjection != null) {
      return _buildEventBody(_eventProjection);
    }
    if (_findPeopleProjection
        case final PublishedFindPeopleDiscoveryEntity projection) {
      return _buildFindPeopleBody(projection);
    }
    if (_classWorkshopProps case final _ClassWorkshopDisplay props) {
      return _buildClassWorkshopBody(props);
    }
    if (_bookableSessionProjection
        case final PublishedBookableSessionDiscoveryEntity projection) {
      return _buildBookableSessionBody(projection, _bookableSessionEvaluation!);
    }
    final PublishedRentalDiscoveryEntity projection = _rentalProjection!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final RentalDetailsSection section in rentalDetailsSections)
            if (_bodySectionFor(section, projection)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildEventBody(PublishedEventDiscoveryEntity projection) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final EventDetailsSection section in eventProfileSections)
            if (_eventBodySectionFor(section, projection)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  /// `hero`/`stickyCta` are handled by [buildHero]/[buildStickyAction], not
  /// the scrollable body — `null` here lets the loop above skip them.
  Widget? _eventBodySectionFor(
    EventDetailsSection section,
    PublishedEventDiscoveryEntity projection,
  ) {
    return switch (section) {
      EventDetailsSection.hero => null,
      EventDetailsSection.header => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _EventEssentialsHeader(
          projection: projection,
          timezoneRepository: _eventTimezoneRepository!,
        ),
      ),
      EventDetailsSection.metrics => _EventCompactMetrics(
        projection: projection,
      ),
      // No organizer-profile navigation target is in this slice's scope
      // (`DTL-EVT-01` §4.1 keeps exactly Save/Share/Add to Scenario/Map/
      // analytics) — the card is informational only, no fake tap target.
      EventDetailsSection.organizer =>
        projection.publisherName.trim().isEmpty
            ? null
            : _EventOrganizerCard(
                projection: projection,
                onTap: _eventOnOrganizerTap,
              ),
      EventDetailsSection.about =>
        projection.fullDescription.trim().isEmpty
            ? null
            : _EventAboutCard(projection: projection),
      EventDetailsSection.program =>
        projection.programItems.isEmpty
            ? null
            : _EventProgramCard(
                projection: projection,
                timezoneRepository: _eventTimezoneRepository!,
                onAddToCalendar: projection.hasActionableDisplayOccurrence
                    ? _eventOnAddToCalendar
                    : null,
              ),
      EventDetailsSection.location =>
        _hasEventLocation(projection)
            ? _EventLocationCard(projection: projection, onTap: _eventOnMap!)
            : null,
      EventDetailsSection.stickyCta => null,
    };
  }

  /// `hero` and `externalCta` are handled by [buildHero]/[buildStickyAction]
  /// respectively, not the scrollable body — returns `null` for them so
  /// the loop above skips them cleanly rather than special-casing the
  /// section list itself.
  Widget? _bodySectionFor(
    RentalDetailsSection section,
    PublishedRentalDiscoveryEntity projection,
  ) {
    return switch (section) {
      RentalDetailsSection.hero => null,
      RentalDetailsSection.inventory => _RentalInventoryCard(
        projection: projection,
      ),
      RentalDetailsSection.availability => const _RentalAvailabilityNote(),
      RentalDetailsSection.pricing => _RentalPricingCard(
        projection: projection,
      ),
      RentalDetailsSection.pickup => _RentalPickupCard(projection: projection),
      RentalDetailsSection.duration => _RentalDurationSafetyCard(
        projection: projection,
      ),
      RentalDetailsSection.publisher => _RentalPublisherCard(
        projection: projection,
      ),
      RentalDetailsSection.externalCta => null,
    };
  }

  @override
  Widget? buildStickyAction(BuildContext context) {
    final CompatibilityObjectRenderer? delegate = _delegate;
    if (delegate != null) {
      if (delegate.item.objectKind == DiscoverObjectKind.place ||
          delegate.item.objectKind == DiscoverObjectKind.activity) {
        return ObjectOfferStickyActionShell(
          child: FilledButton(
            onPressed: delegate.ctaSubmitted ? null : delegate.onCtaTap,
            child: Text(
              delegate.ctaSubmitted
                  ? 'Заявка отправлена'
                  : ctaLabelForDetails(delegate.item),
            ),
          ),
        );
      }
      return delegate.buildStickyAction(context);
    }
    if (_eventProjection != null) {
      final PublishedEventDiscoveryEntity projection = _eventProjection;
      final bool hasExternalUrl =
          eventExternalBookingUri(projection.externalBookingUrl) != null;
      // `DTL-EVT-01` §0.7/EVT-D-AC-14: a priced Event with no
      // `externalBookingUrl` gets no sticky action at all — never a
      // disabled placeholder pretending a booking flow exists.
      if (!projection.hasActionableDisplayOccurrence ||
          (!projection.isFree && !hasExternalUrl)) {
        return null;
      }
      return _EventStickyCta(onTap: _eventOnPrimaryAction!);
    }
    if (_findPeopleProjection != null) {
      // DTL-FP-01 is reader-only. A disabled/no-op Join control would imply
      // application runtime that this slice deliberately does not provide.
      return null;
    }
    if (_classWorkshopProps case final _ClassWorkshopDisplay props) {
      return _ClassWorkshopFooter(
        enrollment: props.projection.enrollment,
        onExternal: _classWorkshopOnPrimaryAction,
      );
    }
    if (_bookableSessionProjection != null) {
      final BookableSessionScheduleState state =
          _bookableSessionEvaluation!.state;
      return ObjectOfferStickyActionShell(
        child: FilledButton(
          onPressed: () => unawaited(_bookableSessionOnPrimaryAction!()),
          child: Text(
            state == BookableSessionScheduleState.freshWithOffers
                ? 'Проверить и забронировать'
                : 'Проверить время на сайте',
          ),
        ),
      );
    }
    return _RentalExternalCtaBar(
      projection: _rentalProjection!,
      onTap: _onExternalCtaTap!,
    );
  }

  List<Widget> _buildDiscoverItemAppBarActions(
    CompatibilityObjectRenderer delegate,
  ) {
    final List<ObjectOfferUtilityActionData> utilityActions =
        <ObjectOfferUtilityActionData>[
          ObjectOfferUtilityActionData(
            label: 'Поделиться',
            icon: Icons.ios_share_rounded,
            onSelected: delegate.onShareTap,
          ),
          if (delegate.onAddToScenario != null)
            ObjectOfferUtilityActionData(
              label: 'Добавить в сценарий',
              icon: Icons.playlist_add_outlined,
              onSelected: delegate.onAddToScenario!,
            ),
          ObjectOfferUtilityActionData(
            label: 'Найти похожее',
            icon: Icons.search,
            onSelected: delegate.onSearch,
          ),
          ObjectOfferUtilityActionData(
            label: 'Создать похожее',
            icon: Icons.add_circle_outline,
            onSelected: delegate.onCreateSimilar,
          ),
          ObjectOfferUtilityActionData(
            label: 'Посмотреть маршрут',
            icon: Icons.route_outlined,
            onSelected: delegate.onRouteMap,
          ),
          ObjectOfferUtilityActionData(
            label: 'Создать маршрут',
            icon: Icons.alt_route,
            onSelected: delegate.onCreateRoute,
          ),
          // Visit History accepts explicit Place visits only (VIS-HIST-01).
          if (delegate.item.objectKind == DiscoverObjectKind.place)
            ObjectOfferUtilityActionData(
              label: 'Отметить посещённым',
              icon: Icons.history_toggle_off,
              onSelected: delegate.onMarkVisited,
            ),
        ];
    return <Widget>[
      ObjectOfferHeroActionButton(
        tooltip: delegate.isFavorite ? 'Unsave' : 'Save',
        onPressed: delegate.onFavoriteTap,
        icon: delegate.isFavorite ? Icons.favorite : Icons.favorite_border,
      ),
      ObjectOfferUtilityMenu(
        tooltip: 'Поделиться и другие действия',
        icon: Icons.ios_share_rounded,
        actions: utilityActions,
      ),
    ];
  }

  Widget _buildPlaceBody(CompatibilityObjectRenderer delegate) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final PlaceDetailsSection section in placeProfileSections)
            if (_placeBodySectionFor(section, delegate)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _placeBodySectionFor(
    PlaceDetailsSection section,
    CompatibilityObjectRenderer delegate,
  ) {
    final DiscoverItemEntity item = delegate.item;
    return switch (section) {
      PlaceDetailsSection.hero || PlaceDetailsSection.stickyCta => null,
      PlaceDetailsSection.header => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _PlaceEssentialsHeader(item: item),
      ),
      PlaceDetailsSection.metrics => _PlaceMetrics(item: item),
      PlaceDetailsSection.publisher =>
        item.organizerName.trim().isEmpty
            ? null
            : _DiscoverPublisherCard(
                item: item,
                label: 'Публикатор',
                accentColor: RechargeTheme.placeAccent,
              ),
      PlaceDetailsSection.about =>
        item.subtitle.trim().isEmpty && item.highlights.isEmpty
            ? null
            : _PlaceAboutCard(item: item),
      PlaceDetailsSection.openingHours =>
        item.openingHours.isEmpty && item.timeFitEvaluation == null
            ? null
            : _PlaceOpeningHoursCard(item: item),
      PlaceDetailsSection.location => _DiscoverLocationCard(
        item: item,
        onTap: delegate.onMap,
        accentColor: RechargeTheme.placeAccent,
      ),
    };
  }

  Widget _buildActivityBody(CompatibilityObjectRenderer delegate) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ActivityDetailsSection section in activityProfileSections)
            if (_activityBodySectionFor(section, delegate)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _activityBodySectionFor(
    ActivityDetailsSection section,
    CompatibilityObjectRenderer delegate,
  ) {
    final DiscoverItemEntity item = delegate.item;
    return switch (section) {
      ActivityDetailsSection.hero || ActivityDetailsSection.stickyCta => null,
      ActivityDetailsSection.header => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _ActivityEssentialsHeader(item: item),
      ),
      ActivityDetailsSection.metrics => _ActivityMetrics(item: item),
      ActivityDetailsSection.organizer =>
        item.organizerName.trim().isEmpty
            ? null
            : _DiscoverPublisherCard(
                item: item,
                label: 'Организатор',
                accentColor: RechargeTheme.activityAccent,
              ),
      ActivityDetailsSection.about =>
        item.subtitle.trim().isEmpty && item.highlights.isEmpty
            ? null
            : _ActivityAboutCard(item: item),
      ActivityDetailsSection.schedule =>
        item.scheduleSlots.isEmpty ? null : _ActivityScheduleCard(item: item),
      ActivityDetailsSection.location => _DiscoverLocationCard(
        item: item,
        onTap: delegate.onMap,
        accentColor: RechargeTheme.activityAccent,
      ),
    };
  }

  Widget _buildFindPeopleBody(PublishedFindPeopleDiscoveryEntity projection) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final FindPeopleDetailsSection section
              in findPeopleProfileSections)
            if (_findPeopleBodySectionFor(section, projection)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _findPeopleBodySectionFor(
    FindPeopleDetailsSection section,
    PublishedFindPeopleDiscoveryEntity projection,
  ) {
    return switch (section) {
      FindPeopleDetailsSection.hero ||
      FindPeopleDetailsSection.stickyCta => null,
      FindPeopleDetailsSection.header => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _FindPeopleEssentialsHeader(
          projection: projection,
          timezoneRepository: _findPeopleTimezoneRepository!,
        ),
      ),
      FindPeopleDetailsSection.metrics => _findPeopleMetrics(projection),
      FindPeopleDetailsSection.organizer =>
        projection.publisherName.trim().isEmpty
            ? null
            : _PreviewPublisherCard(
                name: projection.publisherName,
                handle: projection.publisherHandle,
                label: 'Организатор',
                accentColor: RechargeTheme.findPeopleAccent,
                verification: projection.publisherVerification,
              ),
      FindPeopleDetailsSection.about =>
        projection.fullDescription.trim().isEmpty
            ? null
            : _PreviewAboutCard(
                title: 'О встрече',
                text: projection.fullDescription,
                accentColor: RechargeTheme.findPeopleAccent,
                accentIcon: Icons.diversity_3_outlined,
              ),
      FindPeopleDetailsSection.schedule => _PreviewBulletListCard(
        title:
            projection.scheduleMode == PublishedFindPeopleScheduleMode.timePoll
            ? 'Варианты времени'
            : 'Время встречи',
        items: projection.timeOptions
            .map(
              (option) => findPeopleTimeOptionLabelRu(
                option,
                projection.timezoneId,
                _findPeopleTimezoneRepository!,
              ),
            )
            .toList(growable: false),
        accentColor: RechargeTheme.findPeopleAccent,
      ),
      FindPeopleDetailsSection.meetingFormat =>
        _findPeopleMeetingFormatText(projection).isEmpty
            ? null
            : _PreviewLabeledTextCard(
                title: 'Формат встречи',
                text: _findPeopleMeetingFormatText(projection),
              ),
      FindPeopleDetailsSection.requirements =>
        _findPeopleRequirements(projection).isEmpty
            ? null
            : _PreviewBulletListCard(
                title: 'Требования к участникам',
                items: _findPeopleRequirements(projection),
                accentColor: RechargeTheme.findPeopleAccent,
              ),
      FindPeopleDetailsSection.cost => _PreviewLabeledTextCard(
        title: 'Ожидаемые расходы',
        text: _findPeopleCostText(projection),
      ),
      FindPeopleDetailsSection.location => _FindPeopleLocationCard(
        location: projection.publicLocation,
        onMap: projection.publicLocation is PublishedFindPeoplePointLocation
            ? _findPeopleOnMap
            : null,
      ),
    };
  }

  Widget? _findPeopleMetrics(PublishedFindPeopleDiscoveryEntity projection) {
    final List<ObjectOfferMetricData> metrics = <ObjectOfferMetricData>[
      if (projection.currentGroupSize case final int value)
        ObjectOfferMetricData(value: '$value', label: 'Сейчас в группе'),
      ObjectOfferMetricData(
        value: 'до ${projection.targetGroupSize}',
        label: 'Желаемый размер',
      ),
      if (projection.durationMinutes case final int value)
        ObjectOfferMetricData(
          value: _objectOfferDurationLabel(value),
          label: 'Длительность',
        ),
    ];
    // `ObjectOfferMetricsStrip` requires more than one column — with a
    // single supplied value there is nothing honest to compare it
    // against, so the whole strip is hidden rather than shown lopsided.
    if (metrics.length < 2) return null;
    return ObjectOfferMetricsStrip(metrics: metrics);
  }

  String _findPeopleMeetingFormatText(
    PublishedFindPeopleDiscoveryEntity projection,
  ) {
    final String mode = switch (projection.publicLocation.meetingMode) {
      PublishedFindPeopleMeetingMode.inPerson => 'Оффлайн',
      PublishedFindPeopleMeetingMode.online => 'Онлайн',
      PublishedFindPeopleMeetingMode.hybrid => 'Гибридный формат',
    };
    return <String>[
      mode,
      if (projection.skillLevelLabel.trim().isNotEmpty)
        projection.skillLevelLabel.trim(),
      if (projection.paceLabel.trim().isNotEmpty) projection.paceLabel.trim(),
      if (projection.languageLabels.isNotEmpty)
        'Языки: ${projection.languageLabels.join(', ')}',
      _findPeopleRecruitmentLabel(projection.recruitmentStatus),
    ].join('\n');
  }

  List<String> _findPeopleRequirements(
    PublishedFindPeopleDiscoveryEntity projection,
  ) {
    return <String>[
      ...projection.publicRequirements
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
      if (projection.equipmentNote.trim().isNotEmpty)
        'Снаряжение: ${projection.equipmentNote.trim()}',
      if (projection.accessibilityNote.trim().isNotEmpty)
        'Доступность: ${projection.accessibilityNote.trim()}',
    ];
  }

  String _findPeopleCostText(PublishedFindPeopleDiscoveryEntity projection) {
    final String disclosure = switch (projection.costType) {
      PublishedFindPeopleCostType.free => 'Без обязательных расходов',
      PublishedFindPeopleCostType.estimated =>
        'Около ${_currencySymbol(projection.currencyCode)}'
            '${_formatAmount(projection.expectedSpendAmount!)} на человека',
      PublishedFindPeopleCostType.unknown => 'Расходы не указаны',
    };
    final String note = projection.costNote.trim();
    return note.isEmpty ? disclosure : '$disclosure\n$note';
  }

  Widget _buildClassWorkshopBody(_ClassWorkshopDisplay props) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ClassWorkshopDetailsSection section
              in classWorkshopProfileSections)
            if (_classWorkshopBodySectionFor(section, props)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _classWorkshopBodySectionFor(
    ClassWorkshopDetailsSection section,
    _ClassWorkshopDisplay props,
  ) {
    return switch (section) {
      ClassWorkshopDetailsSection.hero ||
      ClassWorkshopDetailsSection.stickyCta => null,
      ClassWorkshopDetailsSection.header => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _ClassWorkshopEssentialsHeader(props: props),
      ),
      ClassWorkshopDetailsSection.metrics => _classWorkshopMetrics(props),
      ClassWorkshopDetailsSection.teacher => _ClassWorkshopTeacherCard(
        props: props,
      ),
      ClassWorkshopDetailsSection.about =>
        props.aboutText.trim().isEmpty
            ? null
            : _PreviewAboutCard(
                title: 'О занятии',
                text: props.aboutText,
                accentColor: RechargeTheme.classWorkshopAccent,
                accentIcon: Icons.school_outlined,
              ),
      ClassWorkshopDetailsSection.schedule =>
        props.scheduleItems.isEmpty
            ? const _PreviewLabeledTextCard(
                title: 'Расписание',
                text: 'Даты уточняются',
              )
            : _ClassWorkshopScheduleCard(items: props.scheduleItems),
      ClassWorkshopDetailsSection.materials =>
        props.includedMaterials.isEmpty
            ? null
            : _PreviewBulletListCard(
                title: 'Материалы и что включено',
                items: props.includedMaterials,
                accentColor: RechargeTheme.classWorkshopAccent,
              ),
      ClassWorkshopDetailsSection.requirements =>
        props.requirements.isEmpty
            ? null
            : _PreviewBulletListCard(
                title: 'Требования',
                items: props.requirements,
                accentColor: RechargeTheme.classWorkshopAccent,
              ),
      ClassWorkshopDetailsSection.location => _ClassWorkshopLocationCard(
        location: props.projection.publicLocation,
        onMap: _classWorkshopOnMap,
      ),
    };
  }

  Widget? _classWorkshopMetrics(_ClassWorkshopDisplay props) {
    final List<ObjectOfferMetricData> metrics = <ObjectOfferMetricData>[
      if (props.priceLabel case final String value when value.trim().isNotEmpty)
        ObjectOfferMetricData(value: value, label: props.priceUnitLabel),
      if (props.groupSizeLabel case final String value
          when value.trim().isNotEmpty)
        ObjectOfferMetricData(value: value, label: 'Размер группы'),
      if (props.durationLabel case final String value
          when value.trim().isNotEmpty)
        ObjectOfferMetricData(value: value, label: props.durationUnitLabel),
    ];
    if (metrics.length < 2) return null;
    return ObjectOfferMetricsStrip(metrics: metrics);
  }

  Widget _buildBookableSessionBody(
    PublishedBookableSessionDiscoveryEntity projection,
    BookableSessionScheduleEvaluation evaluation,
  ) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final BookableSessionDetailsSection section
              in bookableSessionProfileSections)
            if (_bookableSessionBodySectionFor(section, projection, evaluation)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _bookableSessionBodySectionFor(
    BookableSessionDetailsSection section,
    PublishedBookableSessionDiscoveryEntity projection,
    BookableSessionScheduleEvaluation evaluation,
  ) {
    return switch (section) {
      BookableSessionDetailsSection.hero ||
      BookableSessionDetailsSection.stickyCta => null,
      BookableSessionDetailsSection.header => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _BookableSessionEssentialsHeader(projection: projection),
      ),
      BookableSessionDetailsSection.metrics => _bookableSessionMetrics(
        projection,
      ),
      BookableSessionDetailsSection.provider => _PreviewPublisherCard(
        name: projection.publisherName,
        handle: projection.publisherHandle,
        label: projection.publisherType == 'page'
            ? 'Организация'
            : 'Специалист',
        accentColor: RechargeTheme.bookableSessionAccent,
        verification: projection.publisherVerification,
      ),
      BookableSessionDetailsSection.about =>
        _bookableSessionAboutText(projection).isEmpty
            ? null
            : _PreviewAboutCard(
                title: 'Об услуге',
                text: _bookableSessionAboutText(projection),
                accentColor: RechargeTheme.bookableSessionAccent,
                accentIcon: Icons.event_available_outlined,
              ),
      BookableSessionDetailsSection.availability =>
        _BookableSessionAvailabilityCard(
          evaluation: evaluation,
          timezoneRepository: _bookableSessionTimezoneRepository!,
        ),
      BookableSessionDetailsSection.location => _BookableSessionLocationCard(
        location: projection.publicLocation,
        onMap:
            projection.publicLocation is PublishedBookableSessionPointLocation
            ? _bookableSessionOnMap
            : null,
      ),
    };
  }

  Widget _bookableSessionMetrics(
    PublishedBookableSessionDiscoveryEntity projection,
  ) {
    return ObjectOfferMetricsStrip(
      metrics: <ObjectOfferMetricData>[
        ObjectOfferMetricData(
          value: _bookableSessionPriceLabel(projection),
          label: 'Цена',
        ),
        ObjectOfferMetricData(
          value: _objectOfferDurationLabel(projection.durationMinutes),
          label: 'Длительность',
        ),
      ],
    );
  }
}

class _PlaceEssentialsHeader extends StatelessWidget {
  const _PlaceEssentialsHeader({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: RechargeTheme.objectOfferPrimaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _PlaceEssentialLine(
          icon: Icons.category_outlined,
          label: item.subcategory.trim().isEmpty
              ? item.category
              : item.subcategory,
        ),
        const SizedBox(height: 8),
        _PlaceEssentialLine(
          icon: Icons.location_on_outlined,
          label: venueLabelForDetails(item),
        ),
      ],
    );
  }
}

class _PlaceEssentialLine extends StatelessWidget {
  const _PlaceEssentialLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: RechargeTheme.objectOfferSecondaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RechargeTheme.objectOfferSecondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceMetrics extends StatelessWidget {
  const _PlaceMetrics({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferMetricsStrip(
      metrics: <ObjectOfferMetricData>[
        ObjectOfferMetricData(
          value: item.isFree ? 'Бесплатно' : priceLabelForDetails(item),
          label: 'Цена',
        ),
        ObjectOfferMetricData(
          value: '${item.distanceKm.toStringAsFixed(1)} км',
          label: 'От вас',
        ),
        ObjectOfferMetricData(
          value: _objectOfferDurationLabel(item.durationMinutes),
          label: 'Время',
        ),
      ],
    );
  }
}

class _DiscoverPublisherCard extends StatelessWidget {
  const _DiscoverPublisherCard({
    required this.item,
    required this.label,
    required this.accentColor,
  });

  final DiscoverItemEntity item;
  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final String name = item.organizerName.trim();
    return ObjectOfferCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 25,
            backgroundColor: accentColor,
            foregroundColor: RechargeTheme.objectOfferOnHero,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: RechargeTheme.objectOfferSecondaryText,
                  ),
                ),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: RechargeTheme.objectOfferPrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.organizerHandle.trim().isNotEmpty)
                  Text(
                    item.organizerHandle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RechargeTheme.objectOfferSecondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceAboutCard extends StatefulWidget {
  const _PlaceAboutCard({required this.item});

  final DiscoverItemEntity item;

  @override
  State<_PlaceAboutCard> createState() => _PlaceAboutCardState();
}

class _PlaceAboutCardState extends State<_PlaceAboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final DiscoverItemEntity item = widget.item;
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'О месте',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: RechargeTheme.placeAccentSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_outlined,
                  size: 19,
                  color: RechargeTheme.placeAccent,
                ),
              ),
            ],
          ),
          if (item.subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              item.subtitle,
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: RechargeTheme.objectOfferPrimaryText,
              ),
            ),
          ],
          if (item.highlights.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (final String highlight in item.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: RechargeTheme.placeAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(highlight)),
                  ],
                ),
              ),
          ],
          if (item.subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _expanded ? 'Свернуть' : 'Читать далее',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: RechargeTheme.placeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.chevron_right,
                    size: 18,
                    color: RechargeTheme.placeAccent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceOpeningHoursCard extends StatelessWidget {
  const _PlaceOpeningHoursCard({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Часы работы',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.timeFitEvaluation != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: RechargeTheme.placeAccentSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      openingLabelForDetails(item.timeFitEvaluation!),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: RechargeTheme.placeAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (item.openingHours.isNotEmpty) ...<Widget>[
            const SizedBox(height: 13),
            for (final OpeningHoursRule rule in item.openingHours)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _openingRuleLabel(rule),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: RechargeTheme.objectOfferSecondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      rule.isClosedAllDay
                          ? 'Закрыто'
                          : '${_placeClockLabel(rule.openMinutesSinceLocalMidnight!)}–${_placeClockLabel(rule.closeMinutesSinceLocalMidnight!)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: RechargeTheme.objectOfferPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DiscoverLocationCard extends StatelessWidget {
  const _DiscoverLocationCard({
    required this.item,
    required this.onTap,
    required this.accentColor,
  });

  final DiscoverItemEntity item;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Flexible(flex: 4, child: _ObjectOfferMapPreview()),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.venueName.trim().isEmpty ? item.title : item.venueName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  item.addressLine.trim().isEmpty
                      ? item.city
                      : item.addressLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RechargeTheme.objectOfferSecondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Показать на карте',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: accentColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _openingRuleLabel(OpeningHoursRule rule) {
  if (rule.exceptionDate case final exceptionDate?) {
    return exceptionDate.toString();
  }
  return switch (rule.dayOfWeek!) {
    DayOfWeek.monday => 'Понедельник',
    DayOfWeek.tuesday => 'Вторник',
    DayOfWeek.wednesday => 'Среда',
    DayOfWeek.thursday => 'Четверг',
    DayOfWeek.friday => 'Пятница',
    DayOfWeek.saturday => 'Суббота',
    DayOfWeek.sunday => 'Воскресенье',
  };
}

String _placeClockLabel(int minutesSinceMidnight) {
  final int hours = minutesSinceMidnight ~/ 60;
  final int minutes = minutesSinceMidnight % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}';
}

class _ActivityEssentialsHeader extends StatelessWidget {
  const _ActivityEssentialsHeader({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    final String activityKind = item.subcategory.trim().isEmpty
        ? item.category
        : item.subcategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: RechargeTheme.objectOfferPrimaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        if (activityKind.trim().isNotEmpty) ...<Widget>[
          _EssentialRow(
            icon: Icons.self_improvement_outlined,
            text: activityKind,
          ),
          const SizedBox(height: 9),
        ],
        _EssentialRow(
          icon: Icons.calendar_month_outlined,
          text: dateTimeLabelForDetails(item.startsAtUtc),
        ),
        const SizedBox(height: 9),
        _EssentialRow(
          icon: Icons.location_on_outlined,
          text: venueLabelForDetails(item),
        ),
      ],
    );
  }
}

class _ActivityMetrics extends StatelessWidget {
  const _ActivityMetrics({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferMetricsStrip(
      metrics: <ObjectOfferMetricData>[
        ObjectOfferMetricData(
          value: item.isFree ? 'Бесплатно' : priceLabelForDetails(item),
          label: 'Цена',
        ),
        ObjectOfferMetricData(
          value: item.participantsCount?.toString() ?? '—',
          label: 'Участники',
          semanticsLabel: item.participantsCount == null
              ? 'Количество участников неизвестно'
              : null,
        ),
        ObjectOfferMetricData(
          value: _objectOfferDurationLabel(item.durationMinutes),
          label: 'Длительность',
        ),
      ],
    );
  }
}

class _ActivityAboutCard extends StatefulWidget {
  const _ActivityAboutCard({required this.item});

  final DiscoverItemEntity item;

  @override
  State<_ActivityAboutCard> createState() => _ActivityAboutCardState();
}

class _ActivityAboutCardState extends State<_ActivityAboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final DiscoverItemEntity item = widget.item;
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'О занятии',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: RechargeTheme.activityAccentSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.self_improvement_rounded,
                  size: 20,
                  color: RechargeTheme.activityAccent,
                ),
              ),
            ],
          ),
          if (item.subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              item.subtitle,
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: RechargeTheme.objectOfferPrimaryText,
              ),
            ),
          ],
          if (item.highlights.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (final String highlight in item.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: RechargeTheme.activityAccent,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(highlight)),
                  ],
                ),
              ),
          ],
          if (item.subtitle.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 5),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _expanded ? 'Свернуть' : 'Читать далее',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: RechargeTheme.activityAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.chevron_right,
                    size: 18,
                    color: RechargeTheme.activityAccent,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityScheduleCard extends StatelessWidget {
  const _ActivityScheduleCard({required this.item});

  final DiscoverItemEntity item;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Расписание',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (int index = 0; index < item.scheduleSlots.length; index++)
            _ActivitySlotRow(
              slot: item.scheduleSlots[index],
              isLast: index == item.scheduleSlots.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ActivitySlotRow extends StatelessWidget {
  const _ActivitySlotRow({required this.slot, required this.isLast});

  final TimeSlot slot;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 16,
            child: Column(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(
                    color: RechargeTheme.activityAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  const Expanded(
                    child: VerticalDivider(
                      width: 1.5,
                      thickness: 1.5,
                      color: RechargeTheme.objectOfferTimelineLine,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Text(
                _activitySlotLabel(slot),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: RechargeTheme.objectOfferPrimaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _objectOfferDurationLabel(int? durationMinutes) {
  if (durationMinutes == null) return 'Гибко';
  if (durationMinutes < 60) return '$durationMinutes мин';
  final int hours = durationMinutes ~/ 60;
  final int minutes = durationMinutes % 60;
  return minutes == 0 ? '$hours ч' : '$hours ч $minutes мин';
}

String _activitySlotLabel(TimeSlot slot) {
  final DateTime endLocal = slot.endAtUtc.toLocal();
  final String endHour = endLocal.hour.toString().padLeft(2, '0');
  final String endMinute = endLocal.minute.toString().padLeft(2, '0');
  return '${dateTimeLabelForDetails(slot.startAtUtc)}–$endHour:$endMinute';
}

class _RentalHero extends StatelessWidget {
  const _RentalHero({required this.projection});

  final PublishedRentalDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.35,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (projection.mediaRefs.isNotEmpty)
                Image.network(
                  projection.mediaRefs.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _RentalCoverFallback(),
                )
              else
                const _RentalCoverFallback(),
              const Positioned(
                left: 12,
                top: 12,
                child: _RentalBadge(label: 'RENTAL'),
              ),
              if (!projection.hasActiveInventory)
                const Positioned(
                  right: 12,
                  top: 12,
                  child: _RentalBadge(label: 'CURRENTLY UNAVAILABLE'),
                ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(color: RechargeTheme.travelGreen),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  projection.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rentalBaseRateLabel(projection),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RentalCoverFallback extends StatelessWidget {
  const _RentalCoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: RechargeTheme.travelGreenDark),
      child: Center(child: Icon(Icons.handyman, color: Colors.white, size: 72)),
    );
  }
}

class _RentalBadge extends StatelessWidget {
  const _RentalBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: RechargeTheme.travelLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: RechargeTheme.travelGreenDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _RentalInventoryCard extends StatelessWidget {
  const _RentalInventoryCard({required this.projection});

  final PublishedRentalDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'What is rented',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final PublishedRentalInventoryGroupRef group
                in projection.inventoryGroups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      group.isAvailable
                          ? Icons.check_circle_rounded
                          : Icons.pause_circle_outline,
                      color: group.isAvailable
                          ? RechargeTheme.travelGreen
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rentalInventoryGroupLabel(group),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RentalAvailabilityNote extends StatelessWidget {
  const _RentalAvailabilityNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.event_available_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                // Canonical spec §8.3: no confirmedAt/freshness field
                // exists anywhere in this projection (RentalListing never
                // carried it — a pre-existing gap, not introduced here),
                // so this must never claim current/fresh availability —
                // only that Creator-declared numbers exist and require
                // confirmation.
                'Listed quantities are Creator-declared, not a live '
                'booking guarantee or confirmed-fresh count. Confirm on '
                'the provider site before relying on them.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalPricingCard extends StatelessWidget {
  const _RentalPricingCard({required this.projection});

  final PublishedRentalDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Rate plan',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final PublishedRentalRateStepRef step in projection.rateSteps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  rentalRateStepLabel(projection, step),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              rentalDepositLabel(projection),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalPickupCard extends StatelessWidget {
  const _RentalPickupCard({required this.projection});

  final PublishedRentalDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: RechargeTheme.travelPanel,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: RechargeTheme.travelLine),
              ),
              child: Icon(
                Icons.place_outlined,
                color: RechargeTheme.travelGreenDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    projection.publicAddress ?? projection.publicAreaLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (projection.deliveryAvailable) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      rentalDeliveryLabel(projection),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalDurationSafetyCard extends StatelessWidget {
  const _RentalDurationSafetyCard({required this.projection});

  final PublishedRentalDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              rentalDurationLabel(projection),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (projection.minRenterAge != null ||
                projection.idRequiredAtHandover) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                rentalSafetyRequirementsLabel(projection),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (projection.safetyNotice case final String notice
                when notice.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(notice, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _RentalPublisherCard extends StatelessWidget {
  const _RentalPublisherCard({required this.projection});

  final PublishedRentalDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    final bool isPage = projection.publisherType == 'page';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 20,
              backgroundColor: RechargeTheme.travelPanel,
              child: Icon(
                isPage ? Icons.storefront_outlined : Icons.person_outline,
                color: RechargeTheme.travelGreenDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPage
                    ? 'Listed by page ${projection.publisherId}'
                    : 'Listed by ${projection.publisherId}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalExternalCtaBar extends StatelessWidget {
  const _RentalExternalCtaBar({required this.projection, required this.onTap});

  final PublishedRentalDiscoveryEntity projection;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasUrl = (projection.externalBookingUrl ?? '').isNotEmpty;
    final bool hasInventory = projection.hasActiveInventory;
    return SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: RechargeTheme.travelLine)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton(
            onPressed: hasUrl && hasInventory
                ? () {
                    unawaited(onTap());
                  }
                : null,
            child: Text(
              hasInventory
                  // Canonical §17.5 CTA matrix: this projection never
                  // carries a freshness/confirmedAt signal (see
                  // _RentalAvailabilityNote), so the "unknown/stale" row
                  // applies unconditionally here, never the "fresh" row.
                  ? 'Confirm on provider site'
                  : 'Currently unavailable',
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event (`DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md`) — widgets colocated in
// this one file, matching how the Rental widgets above already live here
// rather than in separate `presentation/widgets/` files.
// ---------------------------------------------------------------------------

class _EventHero extends StatefulWidget {
  const _EventHero({required this.projection});

  final PublishedEventDiscoveryEntity projection;

  @override
  State<_EventHero> createState() => _EventHeroState();
}

class _EventHeroState extends State<_EventHero> {
  int _pageIndex = 0;

  /// Cover de-duplicated against gallery by URL value (§1.1 п.11) —
  /// counter only makes sense over the de-duplicated set.
  List<String> get _pages {
    final String cover = widget.projection.coverImageUrl;
    final List<String> gallery = widget.projection.galleryImageUrls;
    if (cover.isEmpty) return gallery;
    return <String>[cover, ...gallery.where((String url) => url != cover)];
  }

  @override
  Widget build(BuildContext context) {
    final List<String> pages = _pages;
    return SizedBox(
      height: RechargeTheme.objectOfferHeroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (pages.isEmpty)
            const _EventHeroFallback()
          else
            PageView.builder(
              itemCount: pages.length,
              onPageChanged: (int index) {
                if (_pageIndex == index) return;
                setState(() => _pageIndex = index);
              },
              itemBuilder: (BuildContext context, int index) {
                return Semantics(
                  image: true,
                  label:
                      widget.projection.galleryAltText[pages[index]] ??
                      widget.projection.title,
                  child: Image.network(
                    pages[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _EventHeroFallback(),
                  ),
                );
              },
            ),
          Positioned(
            left: 16,
            bottom: 16,
            child: ObjectOfferTypeBadge(
              label: 'EVENT',
              foregroundColor: RechargeTheme.eventLavender,
              backgroundColor: RechargeTheme.eventLavenderSurface,
            ),
          ),
          // Counter only when there is more than one page to count
          // (`DTL-EVT-01` EVT-D-AC-15) — never a hardcoded "1/5".
          if (pages.length > 1)
            Positioned(
              right: 16,
              bottom: 16,
              child: _HeroPageCounter(
                pageIndex: _pageIndex,
                pageCount: pages.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroPageCounter extends StatelessWidget {
  const _HeroPageCounter({required this.pageIndex, required this.pageCount});

  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RechargeTheme.objectOfferHeroCounterSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '${pageIndex + 1}/$pageCount',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: RechargeTheme.objectOfferOnHero,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

enum _EventUtilityAction { share, addToScenario }

class _EventHeroShareMenu extends StatelessWidget {
  const _EventHeroShareMenu({
    required this.onShare,
    required this.onAddToScenario,
  });

  final VoidCallback onShare;
  final Future<void> Function()? onAddToScenario;

  @override
  Widget build(BuildContext context) {
    if (onAddToScenario == null) {
      return ObjectOfferHeroActionButton(
        tooltip: 'Share',
        icon: Icons.ios_share_rounded,
        onPressed: onShare,
      );
    }
    return ObjectOfferHeroActionSurface(
      endPadding: 12,
      child: PopupMenuButton<_EventUtilityAction>(
        tooltip: 'Share',
        icon: const Icon(Icons.ios_share_rounded, size: 21),
        color: RechargeTheme.objectOfferCardSurface,
        onSelected: (_EventUtilityAction action) {
          switch (action) {
            case _EventUtilityAction.share:
              onShare();
            case _EventUtilityAction.addToScenario:
              unawaited(onAddToScenario!());
          }
        },
        itemBuilder: (BuildContext context) =>
            const <PopupMenuEntry<_EventUtilityAction>>[
              PopupMenuItem<_EventUtilityAction>(
                value: _EventUtilityAction.share,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.ios_share_rounded),
                  title: Text('Поделиться'),
                ),
              ),
              PopupMenuItem<_EventUtilityAction>(
                value: _EventUtilityAction.addToScenario,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.playlist_add_outlined),
                  title: Text('Добавить в сценарий'),
                ),
              ),
            ],
      ),
    );
  }
}

class _EventHeroFallback extends StatelessWidget {
  const _EventHeroFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: RechargeTheme.emerald900),
      child: Center(
        child: Icon(
          Icons.event_outlined,
          color: RechargeTheme.objectOfferOnHero,
          size: 64,
        ),
      ),
    );
  }
}

class _EventEssentialsHeader extends StatelessWidget {
  const _EventEssentialsHeader({
    required this.projection,
    required this.timezoneRepository,
  });

  final PublishedEventDiscoveryEntity projection;
  final TimezoneRepository timezoneRepository;

  @override
  Widget build(BuildContext context) {
    final EventOccurrence? occurrence = projection.displayOccurrence;
    final String venueLabel = eventVenueLabel(projection);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          projection.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: RechargeTheme.emerald900,
            fontWeight: FontWeight.w800,
            fontSize: 30,
            height: 1.08,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        if (occurrence != null) ...<Widget>[
          _EssentialRow(
            icon: Icons.calendar_month_outlined,
            // §7.4: RU-only formatter, same convention as the rest of this
            // screen's hardcoded Russian copy — not a locale-aware system.
            text: eventDateTimeLabelRu(
              occurrence,
              projection.timezoneId,
              timezoneRepository,
            ),
            cancelled: occurrence.status == EventOccurrenceStatus.cancelled,
          ),
          const SizedBox(height: 10),
        ],
        if (venueLabel.isNotEmpty)
          _EssentialRow(icon: Icons.location_on_outlined, text: venueLabel),
      ],
    );
  }
}

class _EssentialRow extends StatelessWidget {
  const _EssentialRow({
    required this.icon,
    required this.text,
    this.cancelled = false,
  });

  final IconData icon;
  final String text;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: RechargeTheme.objectOfferSecondaryText),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            cancelled ? '$text · Отменено' : text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cancelled
                  ? Theme.of(context).colorScheme.error
                  : RechargeTheme.objectOfferSecondaryText,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCompactMetrics extends StatelessWidget {
  const _EventCompactMetrics({required this.projection});

  final PublishedEventDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferMetricsStrip(
      metrics: <ObjectOfferMetricData>[
        ObjectOfferMetricData(
          value: priceMetricLabel(projection),
          label: 'Цена',
        ),
        ObjectOfferMetricData(
          value: participantsMetricLabel(projection),
          label: 'Участники',
          semanticsLabel: projection.participantsCount == null
              ? 'Количество участников неизвестно'
              : null,
        ),
        ObjectOfferMetricData(
          value: durationMetricLabel(projection),
          label: 'Длительность',
        ),
      ],
    );
  }
}

class _EventOrganizerCard extends StatelessWidget {
  const _EventOrganizerCard({required this.projection, required this.onTap});

  final PublishedEventDiscoveryEntity projection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool verified =
        projection.publisherVerification !=
        PublisherVerificationDisplayState.none;
    return ObjectOfferCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 26,
            backgroundColor: RechargeTheme.emerald900,
            child: Text(
              projection.publisherName.isEmpty
                  ? '?'
                  : projection.publisherName[0].toUpperCase(),
              style: const TextStyle(
                color: RechargeTheme.objectOfferOnHero,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Организатор',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: RechargeTheme.objectOfferSecondaryText,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        projection.publisherName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // §2.3: renders iff `!= none` — never unconditionally.
                    if (verified) ...<Widget>[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 15,
                        color: RechargeTheme.emerald900,
                      ),
                    ],
                  ],
                ),
                if (projection.publisherHandle.isNotEmpty)
                  Text(
                    projection.publisherHandle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RechargeTheme.objectOfferSecondaryText,
                    ),
                  ),
              ],
            ),
          ),
          // `Flexible`, not a bare min-sized `Row`: at 150% text scale
          // (EVT-D-AC-11) this label can outgrow what the outer Row has
          // left after the avatar and the flexible name column — it must
          // shrink and ellipsize rather than overflow the card.
          if (onTap != null)
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      projection.publisherType == 'page'
                          ? 'Профиль клуба'
                          : 'Профиль',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: RechargeTheme.emerald900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: RechargeTheme.emerald900,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EventAboutCard extends StatefulWidget {
  const _EventAboutCard({required this.projection});

  final PublishedEventDiscoveryEntity projection;

  @override
  State<_EventAboutCard> createState() => _EventAboutCardState();
}

class _EventAboutCardState extends State<_EventAboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Empty body → whole section hidden, not an empty card
    // (`DISCOVER_DETAILS_SYSTEM_SPEC.md` §4, `DTL-EVT-01` EVT-D-AC-05).
    if (widget.projection.fullDescription.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'О событии',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: RechargeTheme.objectOfferSoftAccentSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headphones_outlined,
                  size: 19,
                  color: RechargeTheme.emerald900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.projection.fullDescription,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: RechargeTheme.objectOfferPrimaryText,
            ),
          ),
          const SizedBox(height: 8),
          // §0.5: real inline expand/collapse, no navigation/backend.
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _expanded ? 'Свернуть' : 'Читать далее',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: RechargeTheme.emerald900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.chevron_right,
                  size: 18,
                  color: RechargeTheme.emerald900,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventProgramCard extends StatelessWidget {
  const _EventProgramCard({
    required this.projection,
    required this.timezoneRepository,
    required this.onAddToCalendar,
  });

  final PublishedEventDiscoveryEntity projection;
  final TimezoneRepository timezoneRepository;
  final Future<void> Function()? onAddToCalendar;

  @override
  Widget build(BuildContext context) {
    final List<PublishedEventProgramItem> items = projection.programItems;
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: <Widget>[
              Text(
                'Расписание',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onAddToCalendar != null)
                OutlinedButton.icon(
                  onPressed: () => unawaited(onAddToCalendar!()),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: Text(
                    'Добавить в календарь',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: RechargeTheme.emerald900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RechargeTheme.emerald900,
                    side: const BorderSide(
                      color: RechargeTheme.objectOfferActionBorder,
                    ),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < items.length; i++)
            _ProgramRow(
              item: items[i],
              timezoneId: projection.timezoneId,
              timezoneRepository: timezoneRepository,
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({
    required this.item,
    required this.timezoneId,
    required this.timezoneRepository,
    required this.isLast,
  });

  final PublishedEventProgramItem item;
  final String timezoneId;
  final TimezoneRepository timezoneRepository;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final LocalDateTimeValue start = timezoneRepository.toLocal(
      item.startAtUtc,
      timezoneId,
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 16,
            child: Column(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(
                    color: RechargeTheme.emerald900,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  const Expanded(
                    child: VerticalDivider(
                      width: 1.5,
                      thickness: 1.5,
                      color: RechargeTheme.objectOfferTimelineLine,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _hm(start),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RechargeTheme.objectOfferSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLocationCard extends StatelessWidget {
  const _EventLocationCard({required this.projection, required this.onTap});

  final PublishedEventDiscoveryEntity projection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Flexible(flex: 4, child: _ObjectOfferMapPreview()),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  projection.venueName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  projection.city,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RechargeTheme.objectOfferSecondaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Показать на карте',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: RechargeTheme.emerald900,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: RechargeTheme.emerald900,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectOfferMapPreview extends StatelessWidget {
  const _ObjectOfferMapPreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const ColoredBox(color: RechargeTheme.objectOfferSubtleSurface),
            CustomPaint(painter: const _ObjectOfferMapGridPainter()),
            Align(
              alignment: const Alignment(-0.35, 0),
              child: Container(
                width: 58,
                height: 46,
                decoration: BoxDecoration(
                  color: RechargeTheme.objectOfferMapHighlight,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.location_on_outlined,
                color: RechargeTheme.emerald900,
                size: 25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectOfferMapGridPainter extends CustomPainter {
  const _ObjectOfferMapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = RechargeTheme.objectOfferMapGrid
      ..strokeWidth = 0.7;
    const double step = 14;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ObjectOfferMapGridPainter oldDelegate) => false;
}

class _EventStickyCta extends StatelessWidget {
  const _EventStickyCta({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferStickyActionShell(
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: RechargeTheme.emerald900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              RechargeTheme.objectOfferCtaRadius,
            ),
          ),
        ),
        onPressed: () => unawaited(onTap()),
        // isFree → internal Join-acknowledgement; priced → external booking
        // redirect. Either way the label is the same "Записаться" per §7.5
        // — the behavior differs, not the visual primitive.
        child: const Text(
          'Записаться',
          style: TextStyle(
            color: RechargeTheme.objectOfferOnHero,
            fontWeight: FontWeight.w600,
            fontSize: 16.5,
          ),
        ),
      ),
    );
  }
}

/// Public: formatting helpers, following `compatibility_object_renderer.dart`'s
/// own `*ForDetails` naming convention for the equivalent free functions.

String rentalBaseRateLabel(PublishedRentalDiscoveryEntity projection) {
  if (projection.rateSteps.isEmpty) return 'Price on request';
  final PublishedRentalRateStepRef first = projection.rateSteps.first;
  final String unit = _billingUnitLabel(projection.billingUnit);
  return '${_moneyLabel(first.unitPriceMinor, projection.currencyCode)} / $unit';
}

/// Canonical §17.3: "Без requested interval card показывает `N units
/// listed`, а не `N available`" — this Details-page listing has no
/// requested-interval query either, so the same discipline applies: never
/// claim a verified-available count, only the declared quantity.
String rentalInventoryGroupLabel(PublishedRentalInventoryGroupRef group) {
  final String variant = group.sizeOrVariant == null
      ? ''
      : ' · ${group.sizeOrVariant}';
  final String status = group.isAvailable ? '' : ' · ${group.status}';
  return '${group.label}$variant — ${group.quantity} units listed$status';
}

String rentalRateStepLabel(
  PublishedRentalDiscoveryEntity projection,
  PublishedRentalRateStepRef step,
) {
  final String unit = _billingUnitLabel(projection.billingUnit);
  return 'From ${step.minUnits} $unit${step.minUnits == 1 ? '' : 's'}: '
      '${_moneyLabel(step.unitPriceMinor, projection.currencyCode)} / $unit';
}

String rentalDepositLabel(PublishedRentalDiscoveryEntity projection) {
  if (!projection.hasDeposit) return 'No deposit required';
  final int? amount = projection.depositAmountMinor;
  return amount == null
      ? 'Deposit required'
      : 'Deposit: ${_moneyLabel(amount, projection.currencyCode)}';
}

String rentalDeliveryLabel(PublishedRentalDiscoveryEntity projection) {
  final double? radius = projection.deliveryRadiusKm;
  return radius == null
      ? 'Delivery available'
      : 'Delivery available within ${radius.toStringAsFixed(1)} km';
}

String rentalDurationLabel(PublishedRentalDiscoveryEntity projection) {
  return 'Rental period: ${_minutesLabel(projection.offeredMinMinutes)} – '
      '${_minutesLabel(projection.offeredMaxMinutes)}';
}

String rentalSafetyRequirementsLabel(
  PublishedRentalDiscoveryEntity projection,
) {
  final List<String> parts = <String>[
    if (projection.minRenterAge != null) 'Min age ${projection.minRenterAge}',
    if (projection.idRequiredAtHandover) 'ID required at handover',
  ];
  return parts.join(' · ');
}

String _billingUnitLabel(String billingUnit) => switch (billingUnit) {
  'hour' => 'hour',
  'week' => 'week',
  _ => 'day',
};

String _moneyLabel(int amountMinor, String currencyCode) {
  final double amount = amountMinor / 100;
  return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)} $currencyCode';
}

String _minutesLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  if (minutes < 1440) return '${(minutes / 60).round()} h';
  return '${(minutes / 1440).round()} d';
}

/// Event formatting helpers (`DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §7.4).
/// RU-only by deliberate, named decision — same convention as every other
/// hardcoded Russian string on this screen, not a locale-aware system
/// (localization is out of this slice's scope).

const List<String> _ruWeekdayShort = <String>[
  'пн',
  'вт',
  'ср',
  'чт',
  'пт',
  'сб',
  'вс',
];

const List<String> _ruMonthGenitive = <String>[
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// `21 июня 2026, вс · 18:00–20:30` — start date/weekday plus start–end
/// time, both resolved against the Event's own [timezoneId], never the
/// viewing device's local timezone (`DTL-EVT-01` EVT-D-AC-20).
String eventDateTimeLabelRu(
  EventOccurrence occurrence,
  String timezoneId,
  TimezoneRepository timezoneRepository,
) {
  final LocalDateTimeValue start = timezoneRepository.toLocal(
    occurrence.startAtUtc,
    timezoneId,
  );
  final LocalDateTimeValue end = timezoneRepository.toLocal(
    occurrence.endAtUtc,
    timezoneId,
  );
  final String weekday = _ruWeekdayShort[(start.weekday - 1).clamp(0, 6)];
  final String month = _ruMonthGenitive[(start.date.month - 1).clamp(0, 11)];
  return '${start.date.day} $month ${start.date.year}, $weekday · '
      '${_hm(start)}–${_hm(end)}';
}

class _BookableSessionHero extends StatefulWidget {
  const _BookableSessionHero({super.key, required this.projection});

  final PublishedBookableSessionDiscoveryEntity projection;

  @override
  State<_BookableSessionHero> createState() => _BookableSessionHeroState();
}

class _BookableSessionHeroState extends State<_BookableSessionHero> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final List<String> images = <String>{
      widget.projection.coverImageUrl.trim(),
      ...widget.projection.galleryImageUrls.map((url) => url.trim()),
    }.where((url) => url.isNotEmpty).toList(growable: false);
    Widget hero(String url) => ObjectOfferSingleImageHero(
      imageUrl: url,
      imageSemanticLabel: widget.projection.title,
      fallbackIcon: Icons.event_available_outlined,
      fallbackColor: RechargeTheme.emerald900,
      typeLabel: 'SESSION',
      typeForegroundColor: RechargeTheme.bookableSessionAccent,
      typeBackgroundColor: RechargeTheme.bookableSessionAccentSurface,
    );
    if (images.length < 2) return hero(images.isEmpty ? '' : images.single);
    return SizedBox(
      height: RechargeTheme.objectOfferHeroHeight,
      child: Stack(
        children: <Widget>[
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, index) => hero(images[index]),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: ObjectOfferTypeBadge(
              label: '${_index + 1}/${images.length}',
              foregroundColor: RechargeTheme.objectOfferOnHero,
              backgroundColor: RechargeTheme.emerald900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats one already-approved public Session offer in the listing timezone.
/// It does not claim provider availability or consult the device timezone.
String bookableSessionOfferLabelRu(
  PublishedBookableSessionOffer offer,
  TimezoneRepository timezoneRepository,
) {
  final LocalDateTimeValue start = timezoneRepository.toLocal(
    offer.startAtUtc,
    offer.timezoneId,
  );
  final LocalDateTimeValue end = timezoneRepository.toLocal(
    offer.endAtUtc,
    offer.timezoneId,
  );
  final String weekday = _ruWeekdayShort[(start.weekday - 1).clamp(0, 6)];
  final String month = _ruMonthGenitive[(start.date.month - 1).clamp(0, 11)];
  final bool sameDay =
      start.date.year == end.date.year &&
      start.date.month == end.date.month &&
      start.date.day == end.date.day;
  final String endLabel = sameDay
      ? _hm(end)
      : '${end.date.day} ${_ruMonthGenitive[end.date.month - 1]} · ${_hm(end)}';
  return '${start.date.day} $month, $weekday · ${_hm(start)}–$endLabel';
}

/// A venue line is assembled from the fields the projection actually has;
/// no demo string is embedded in the renderer.
String eventVenueLabel(PublishedEventDiscoveryEntity projection) {
  final String address = projection.addressLine.trim();
  if (address.isNotEmpty) return address;
  final List<String> parts = <String>[
    if (projection.venueName.trim().isNotEmpty) projection.venueName.trim(),
    if (projection.city.trim().isNotEmpty) projection.city.trim(),
  ];
  return parts.toSet().join(', ');
}

bool _hasEventLocation(PublishedEventDiscoveryEntity projection) {
  return eventVenueLabel(projection).isNotEmpty &&
      projection.latitude.isFinite &&
      projection.longitude.isFinite &&
      projection.latitude >= -90 &&
      projection.latitude <= 90 &&
      projection.longitude >= -180 &&
      projection.longitude <= 180;
}

/// Only absolute web URLs are valid external booking targets. Relative URLs
/// and non-web schemes must not make the sticky CTA appear.
Uri? eventExternalBookingUri(String? raw) {
  final Uri? uri = Uri.tryParse((raw ?? '').trim());
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.trim().isEmpty) {
    return null;
  }
  return uri;
}

String _hm(LocalDateTimeValue value) {
  final int hour = value.minutesSinceMidnight ~/ 60;
  final int minute = value.minutesSinceMidnight % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// `isFree` → «Бесплатно»; otherwise an amount with currency — never a
/// bare "0" for a free event (`DTL-EVT-01` EVT-D-AC-07).
String priceMetricLabel(PublishedEventDiscoveryEntity projection) {
  if (projection.isFree) return 'Бесплатно';
  final double amount = projection.priceAmount;
  final String formatted = amount.truncateToDouble() == amount
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '${_currencySymbol(projection.currencyCode)}$formatted';
}

String _currencySymbol(String currencyCode) => switch (currencyCode) {
  'EUR' => '€',
  'USD' => r'$',
  _ => '$currencyCode ',
};

/// `null` → visual «—» (honest unknown, never a fake `0`) — the
/// accompanying `Semantics` label lives in the shared metrics primitive.
String participantsMetricLabel(PublishedEventDiscoveryEntity projection) {
  final int? count = projection.participantsCount;
  return count == null ? '—' : '$count';
}

String durationMetricLabel(PublishedEventDiscoveryEntity projection) {
  final int? minutes = projection.durationMinutes;
  if (minutes == null) return '—';
  if (minutes % 60 == 0) return '${minutes ~/ 60} ч';
  final double hours = minutes / 60;
  return '${hours.toStringAsFixed(1)} ч';
}

// ---------------------------------------------------------------------------
// Find People / Class Workshop — presentation-only visual compositions
// (`OBJECT_OFFER_DETAILS_VISUAL_SYSTEM_PLAN.md`). `_PreviewPublisherCard`,
// `_PreviewAboutCard`, `_PreviewLabeledTextCard`, `_PreviewBulletListCard`
// and `_PreviewLocationCard` are shared between the two because both take
// plain preview props (not a domain entity). Bookable Session now consumes
// its typed runtime projection; only genuinely visual primitives remain
// shared between it and Class / Workshop.
// ---------------------------------------------------------------------------

class _FindPeopleEssentialsHeader extends StatelessWidget {
  const _FindPeopleEssentialsHeader({
    required this.projection,
    required this.timezoneRepository,
  });

  final PublishedFindPeopleDiscoveryEntity projection;
  final TimezoneRepository timezoneRepository;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          projection.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: RechargeTheme.objectOfferPrimaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (projection.purposeLabel.trim().isNotEmpty) ...<Widget>[
          _PreviewEssentialLine(
            icon: Icons.flag_outlined,
            label: projection.purposeLabel,
          ),
          const SizedBox(height: 8),
        ],
        _PreviewEssentialLine(
          icon: Icons.calendar_month_outlined,
          label: _findPeopleScheduleSummary(projection, timezoneRepository),
        ),
        const SizedBox(height: 8),
        _PreviewEssentialLine(
          icon:
              projection.publicLocation.meetingMode ==
                  PublishedFindPeopleMeetingMode.online
              ? Icons.videocam_outlined
              : Icons.location_on_outlined,
          label: _findPeopleLocationSummary(projection.publicLocation),
        ),
      ],
    );
  }
}

String findPeopleTimeOptionLabelRu(
  PublishedFindPeopleTimeOption option,
  String timezoneId,
  TimezoneRepository timezoneRepository,
) {
  final LocalDateTimeValue start = timezoneRepository.toLocal(
    option.startAtUtc,
    timezoneId,
  );
  final LocalDateTimeValue end = timezoneRepository.toLocal(
    option.endAtUtc,
    timezoneId,
  );
  final String weekday = _ruWeekdayShort[(start.weekday - 1).clamp(0, 6)];
  final String month = _ruMonthGenitive[(start.date.month - 1).clamp(0, 11)];
  final String prefix =
      option.kind == PublishedFindPeopleTimeOptionKind.candidate
      ? 'Вариант · '
      : '';
  return '$prefix${start.date.day} $month ${start.date.year}, $weekday · '
      '${_hm(start)}–${_hm(end)}';
}

String _findPeopleScheduleSummary(
  PublishedFindPeopleDiscoveryEntity projection,
  TimezoneRepository timezoneRepository,
) {
  final String first = findPeopleTimeOptionLabelRu(
    projection.timeOptions.first,
    projection.timezoneId,
    timezoneRepository,
  );
  return switch (projection.scheduleMode) {
    PublishedFindPeopleScheduleMode.single => first,
    PublishedFindPeopleScheduleMode.timePoll =>
      '${projection.timeOptions.length} варианта времени',
    PublishedFindPeopleScheduleMode.recurring =>
      projection.timeOptions.length == 1
          ? first
          : '$first · ещё ${projection.timeOptions.length - 1}',
  };
}

String _findPeopleLocationSummary(PublishedFindPeoplePublicLocation location) {
  return switch (location) {
    PublishedFindPeoplePointLocation(:final areaLabel) => areaLabel,
    PublishedFindPeopleOnlineLocation(:final providerLabel) =>
      providerLabel.trim().isEmpty ? 'Онлайн' : 'Онлайн · $providerLabel',
    PublishedFindPeopleHiddenLocation(:final safeAreaLabel) =>
      safeAreaLabel.trim().isEmpty ? 'Место не опубликовано' : safeAreaLabel,
  };
}

String _findPeopleRecruitmentLabel(
  PublishedFindPeopleRecruitmentStatus status,
) {
  return switch (status) {
    PublishedFindPeopleRecruitmentStatus.collectingAvailability =>
      'Собираются варианты времени',
    PublishedFindPeopleRecruitmentStatus.open => 'Набор открыт',
    PublishedFindPeopleRecruitmentStatus.waitlistOnly => 'Только лист ожидания',
    PublishedFindPeopleRecruitmentStatus.full => 'Группа заполнена',
    PublishedFindPeopleRecruitmentStatus.completed => 'Встреча завершена',
    PublishedFindPeopleRecruitmentStatus.cancelled => 'Встреча отменена',
    PublishedFindPeopleRecruitmentStatus.expired => 'Набор завершён',
  };
}

String _formatAmount(double amount) {
  return amount.truncateToDouble() == amount
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}

/// Internal formatting adapter only. Public renderer input is always typed.
class _ClassWorkshopDisplay {
  _ClassWorkshopDisplay(this.projection, this.timezone);
  final PublishedClassWorkshopDiscoveryEntity projection;
  final TimezoneRepository timezone;
  String get title => projection.title;
  String get discipline => projection.disciplineLabel;
  String get levelOrFormat => [
    switch (projection.kind) {
      ClassWorkshopKind.classLesson => 'Занятие',
      ClassWorkshopKind.workshop => 'Воркшоп',
      ClassWorkshopKind.masterclass => 'Мастер-класс',
      ClassWorkshopKind.course => 'Курс',
      ClassWorkshopKind.experience => 'Практический опыт',
    },
    projection.levelLabel,
    switch (projection.publicLocation.delivery) {
      ClassWorkshopDelivery.offline => 'Офлайн',
      ClassWorkshopDelivery.onlineLive => 'Онлайн',
      ClassWorkshopDelivery.hybrid => 'Гибридный формат',
    },
    ...projection.languageLabels,
  ].where((s) => s.trim().isNotEmpty).join(' · ');
  String get dateAndPlaceLabel {
    final schedule = projection.schedule;
    final date = schedule is ClassWorkshopAnnouncedSchedule
        ? classWorkshopOccurrenceLabelRu(schedule.occurrences.first, timezone)
        : 'Даты уточняются';
    final area = switch (projection.publicLocation) {
      ClassWorkshopPointLocation(:final venueName) => venueName,
      ClassWorkshopHiddenLocation(:final safeAreaLabel) => safeAreaLabel,
      ClassWorkshopOnlineLocation() => '',
    };
    return [date, area].where((s) => s.isNotEmpty).join(' · ');
  }

  String? get priceLabel => switch (projection.price) {
    ClassWorkshopPriceNotProvided() => null,
    ClassWorkshopPriceFree() => 'Бесплатно',
    final ClassWorkshopPriceFixed price => classWorkshopPriceLabel(price),
  };
  String get priceUnitLabel => switch (projection.price) {
    ClassWorkshopPriceFixed(:final scope) =>
      scope == ClassWorkshopPriceScope.perPersonPerClass
          ? 'Цена за человека / занятие'
          : 'Цена за человека / курс',
    _ => 'Цена',
  };
  String? get groupSizeLabel => projection.declaredGroupLimit == null
      ? null
      : 'до ${projection.declaredGroupLimit} чел.';
  String? get durationLabel => projection.durationMinutes == null
      ? null
      : '${projection.durationMinutes} мин';
  String get durationUnitLabel =>
      projection.durationScope == ClassWorkshopDurationScope.wholeSeries
      ? 'Длительность курса'
      : 'Длительность занятия';
  String get teacherName => switch (projection.instructor) {
    ClassWorkshopInstructorSameAsPublisher() => projection.publisherName,
    ClassWorkshopGuestInstructor(:final name) => name,
  };
  String get teacherHandle => switch (projection.instructor) {
    ClassWorkshopInstructorSameAsPublisher() => projection.publisherHandle,
    ClassWorkshopGuestInstructor(:final handle) => handle,
  };
  String get aboutText => [
    projection.fullDescription.trim().isEmpty
        ? projection.shortDescription.trim()
        : projection.fullDescription.trim(),
    if (projection.learningOutcomes.isNotEmpty)
      'Чему научитесь:\n${projection.learningOutcomes.map((s) => '• $s').join('\n')}',
  ].where((s) => s.isNotEmpty).join('\n\n');
  List<String> get includedMaterials => projection.includedMaterials;
  List<String> get requirements => projection.requirements;
  List<_ClassWorkshopScheduleItem> get scheduleItems =>
      switch (projection.schedule) {
        ClassWorkshopDatesNotAnnounced() => const [],
        ClassWorkshopAnnouncedSchedule(:final occurrences) =>
          occurrences
              .map(
                (row) => _ClassWorkshopScheduleItem(
                  timeLabel: classWorkshopOccurrenceLabelRu(row, timezone),
                  description: row.title,
                ),
              )
              .toList(growable: false),
      };
}

String classWorkshopPriceLabel(ClassWorkshopPriceFixed price) {
  final scale = int.parse('1${'0' * price.minorUnitDigits}');
  final remainder = price.amountMinor % scale;
  final fraction = remainder == 0 ? '' : '.${remainder.toString().padLeft(price.minorUnitDigits, '0')}';
  return '${price.amountMinor ~/ scale}$fraction ${price.currencyCode}';
}

String classWorkshopOccurrenceLabelRu(
  ClassWorkshopOccurrence row,
  TimezoneRepository timezone,
) {
  final start = timezone.toLocal(row.startAtUtc, row.timezoneId);
  final end = timezone.toLocal(row.endAtUtc, row.timezoneId);
  String date(LocalDateTimeValue value) =>
      '${value.date.day} ${_ruMonthGenitive[value.date.month - 1]} ${value.date.year}';
  final sameDate = start.date == end.date;
  return '${date(start)} · ${_hm(start)}–${sameDate ? '' : '${date(end)} · '}${_hm(end)}';
}

class _ClassWorkshopScheduleItem {
  const _ClassWorkshopScheduleItem({
    required this.timeLabel,
    required this.description,
  });
  final String timeLabel;
  final String description;
}

class _ClassWorkshopTeacherCard extends StatelessWidget {
  const _ClassWorkshopTeacherCard({required this.props});
  final _ClassWorkshopDisplay props;
  @override
  Widget build(BuildContext context) {
    final same =
        props.projection.instructor is ClassWorkshopInstructorSameAsPublisher;
    return ObjectOfferCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: RechargeTheme.classWorkshopAccent,
            foregroundColor: RechargeTheme.objectOfferOnHero,
            child: Text(
              props.teacherName.trim().characters.first.toUpperCase(),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Преподаватель',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  props.teacherName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (props.teacherHandle.trim().isNotEmpty)
                  Text(
                    props.teacherHandle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (!same)
                  Text(
                    'Организатор: ${props.projection.publisherName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (props.projection.publisherVerification !=
                    PublisherVerificationDisplayState.none)
                  Row(
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 15,
                        color: RechargeTheme.classWorkshopAccent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          same
                              ? 'Профиль подтверждён'
                              : 'Организатор подтверждён',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassWorkshopLocationCard extends StatelessWidget {
  const _ClassWorkshopLocationCard({required this.location, this.onMap});
  final ClassWorkshopPublicLocation location;
  final VoidCallback? onMap;
  @override
  Widget build(BuildContext context) => switch (location) {
    ClassWorkshopPointLocation(
      :final venueName,
      :final areaLabel,
      :final publicAddress,
    ) =>
      onMap == null
          ? _PreviewLabeledTextCard(
              title: venueName,
              text: [
                areaLabel,
                publicAddress,
              ].where((s) => s.trim().isNotEmpty).join('\n'),
            )
          : _PreviewLocationCard(
              title: venueName,
              address: publicAddress.trim().isEmpty ? areaLabel : publicAddress,
              onTap: onMap,
              accentColor: RechargeTheme.classWorkshopAccent,
            ),
    ClassWorkshopOnlineLocation(:final providerLabel) =>
      _PreviewLabeledTextCard(
        title: 'Онлайн-занятие',
        text: providerLabel.trim().isEmpty
            ? 'Инструкции предоставит организатор'
            : providerLabel,
      ),
    ClassWorkshopHiddenLocation(:final safeAreaLabel) =>
      _PreviewLabeledTextCard(title: 'Место уточняется', text: safeAreaLabel),
  };
}

class _ClassWorkshopFooter extends StatelessWidget {
  const _ClassWorkshopFooter({required this.enrollment, this.onExternal});
  final ClassWorkshopEnrollment enrollment;
  final Future<void> Function()? onExternal;
  @override
  Widget build(BuildContext context) {
    final external = enrollment is ClassWorkshopExternalEnrollment;
    final disclosure = switch (enrollment) {
      ClassWorkshopExternalEnrollment() =>
        'Наличие мест, итоговая стоимость и условия — на сайте организатора',
      ClassWorkshopInformationOnly(:final reason) => switch (reason) {
        ClassWorkshopInformationReason.closed => 'Запись закрыта',
        ClassWorkshopInformationReason.onSite =>
          'Условия участия уточняются на месте',
        ClassWorkshopInformationReason.notProvided =>
          'Способ записи пока не указан',
        ClassWorkshopInformationReason.unsupportedInternal =>
          'Запись через приложение пока не подключена',
      },
    };
    // The shared action shell has a fixed button height. Keep explanatory
    // text outside it so large text can grow without altering other families.
    return ColoredBox(
      color: RechargeTheme.objectOfferScreenBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: !external || onExternal == null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RechargeTheme.objectOfferHorizontalPadding,
                14,
                RechargeTheme.objectOfferHorizontalPadding,
                8,
              ),
              child: Text(
                disclosure,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (external && onExternal != null)
            ObjectOfferStickyActionShell(
              child: FilledButton(
                onPressed: () => unawaited(onExternal!()),
                child: const Text('Проверить запись на сайте'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClassWorkshopHero extends StatefulWidget {
  const _ClassWorkshopHero({super.key, required this.projection});
  final PublishedClassWorkshopDiscoveryEntity projection;
  @override
  State<_ClassWorkshopHero> createState() => _ClassWorkshopHeroState();
}

class _ClassWorkshopHeroState extends State<_ClassWorkshopHero> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final images = <String>{
      widget.projection.coverImageUrl.trim(),
      ...widget.projection.galleryImageUrls,
    }.where((s) => s.isNotEmpty).toList(growable: false);
    Widget hero(String url) => ObjectOfferSingleImageHero(
      imageUrl: url,
      imageSemanticLabel: widget.projection.title,
      fallbackIcon: Icons.school_outlined,
      fallbackColor: RechargeTheme.emerald900,
      typeLabel: 'CLASS / WORKSHOP',
      typeForegroundColor: RechargeTheme.classWorkshopAccent,
      typeBackgroundColor: RechargeTheme.classWorkshopAccentSurface,
    );
    if (images.length < 2) return hero(images.isEmpty ? '' : images.single);
    return SizedBox(
      height: RechargeTheme.objectOfferHeroHeight,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => hero(images[i]),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: ObjectOfferTypeBadge(
              label: '${_index + 1}/${images.length}',
              foregroundColor: RechargeTheme.objectOfferOnHero,
              backgroundColor: RechargeTheme.emerald900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassWorkshopEssentialsHeader extends StatelessWidget {
  const _ClassWorkshopEssentialsHeader({required this.props});

  final _ClassWorkshopDisplay props;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          props.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: RechargeTheme.objectOfferPrimaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (props.discipline.trim().isNotEmpty) ...<Widget>[
          _PreviewEssentialLine(
            icon: Icons.category_outlined,
            label: props.discipline,
          ),
          const SizedBox(height: 8),
        ],
        if (props.levelOrFormat.trim().isNotEmpty) ...<Widget>[
          _PreviewEssentialLine(
            icon: Icons.bar_chart_outlined,
            label: props.levelOrFormat,
          ),
          const SizedBox(height: 8),
        ],
        if (props.dateAndPlaceLabel.trim().isNotEmpty)
          _PreviewEssentialLine(
            icon: Icons.calendar_month_outlined,
            label: props.dateAndPlaceLabel,
          ),
      ],
    );
  }
}

class _BookableSessionEssentialsHeader extends StatelessWidget {
  const _BookableSessionEssentialsHeader({required this.projection});

  final PublishedBookableSessionDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          projection.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: RechargeTheme.objectOfferPrimaryText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _PreviewEssentialLine(
          icon: Icons.category_outlined,
          label: projection.serviceCategoryLabel,
        ),
        const SizedBox(height: 8),
        _PreviewEssentialLine(
          icon:
              projection.publicLocation.meetingMode ==
                  PublishedBookableSessionMeetingMode.online
              ? Icons.videocam_outlined
              : Icons.location_on_outlined,
          label: _bookableSessionMeetingModeLabel(
            projection.publicLocation.meetingMode,
          ),
        ),
      ],
    );
  }
}

String _bookableSessionMeetingModeLabel(
  PublishedBookableSessionMeetingMode mode,
) {
  return switch (mode) {
    PublishedBookableSessionMeetingMode.inPerson => 'Офлайн',
    PublishedBookableSessionMeetingMode.online => 'Онлайн',
    PublishedBookableSessionMeetingMode.hybrid => 'Гибридный формат',
  };
}

String _bookableSessionAboutText(
  PublishedBookableSessionDiscoveryEntity projection,
) {
  final String full = projection.fullDescription.trim();
  return full.isNotEmpty ? full : projection.shortDescription.trim();
}

String _bookableSessionPriceLabel(
  PublishedBookableSessionDiscoveryEntity projection,
) {
  return switch (projection.priceType) {
    PublishedBookableSessionPriceType.free => 'Бесплатно',
    PublishedBookableSessionPriceType.fixed =>
      '${_formatAmount(projection.priceAmountMinor! / 100)} '
          '${projection.currencyCode}',
  };
}

class _PreviewEssentialLine extends StatelessWidget {
  const _PreviewEssentialLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: RechargeTheme.objectOfferSecondaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: RechargeTheme.objectOfferSecondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _FindPeopleLocationCard extends StatelessWidget {
  const _FindPeopleLocationCard({required this.location, this.onMap});

  final PublishedFindPeoplePublicLocation location;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final bool showsMap =
        location is PublishedFindPeoplePointLocation && onMap != null;
    final String title;
    final String detail;
    final IconData fallbackIcon;
    switch (location) {
      case PublishedFindPeoplePointLocation(:final areaLabel):
        title = areaLabel;
        detail = 'Приблизительная публичная зона встречи';
        fallbackIcon = Icons.location_on_outlined;
      case PublishedFindPeopleOnlineLocation(:final providerLabel):
        title = 'Онлайн';
        detail = providerLabel.trim().isEmpty
            ? 'Данные доступа не публикуются'
            : providerLabel.trim();
        fallbackIcon = Icons.videocam_outlined;
      case PublishedFindPeopleHiddenLocation(:final safeAreaLabel):
        title = safeAreaLabel.trim().isEmpty
            ? 'Место не опубликовано'
            : safeAreaLabel.trim();
        detail = 'Координаты недоступны публично';
        fallbackIcon = Icons.location_off_outlined;
    }

    return ObjectOfferCard(
      padding: const EdgeInsets.all(13),
      onTap: showsMap ? onMap : null,
      child: Row(
        children: <Widget>[
          if (showsMap)
            const Flexible(flex: 4, child: _ObjectOfferMapPreview())
          else
            Flexible(
              flex: 4,
              child: AspectRatio(
                aspectRatio: 1.35,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: RechargeTheme.findPeopleAccentSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    fallbackIcon,
                    color: RechargeTheme.findPeopleAccent,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RechargeTheme.objectOfferSecondaryText,
                  ),
                ),
                if (showsMap) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          'Показать на карте',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: RechargeTheme.findPeopleAccent,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: RechargeTheme.findPeopleAccent,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookableSessionAvailabilityCard extends StatelessWidget {
  const _BookableSessionAvailabilityCard({
    required this.evaluation,
    required this.timezoneRepository,
  });

  final BookableSessionScheduleEvaluation evaluation;
  final TimezoneRepository timezoneRepository;

  @override
  Widget build(BuildContext context) {
    final String stateMessage = switch (evaluation.state) {
      BookableSessionScheduleState.freshWithOffers => '',
      BookableSessionScheduleState.freshEmpty =>
        'В текущем окне время не указано.',
      BookableSessionScheduleState.stale =>
        'Расписание требует обновления — проверьте время на сайте.',
    };
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Время для записи',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (evaluation.state == BookableSessionScheduleState.freshWithOffers)
            for (final PublishedBookableSessionOffer offer
                in evaluation.visibleOffers.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: RechargeTheme.bookableSessionAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bookableSessionOfferLabelRu(offer, timezoneRepository),
                      ),
                    ),
                  ],
                ),
              )
          else
            Text(
              stateMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: RechargeTheme.objectOfferPrimaryText,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.info_outline,
                size: 17,
                color: RechargeTheme.objectOfferSecondaryText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Фактическое время и условия подтверждаются на сайте '
                  'партнёра.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RechargeTheme.objectOfferSecondaryText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookableSessionLocationCard extends StatelessWidget {
  const _BookableSessionLocationCard({required this.location, this.onMap});

  final PublishedBookableSessionPublicLocation location;
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) {
    final bool showsMap =
        location is PublishedBookableSessionPointLocation && onMap != null;
    final String title;
    final String detail;
    final IconData fallbackIcon;
    switch (location) {
      case PublishedBookableSessionPointLocation(
        :final venueName,
        :final areaLabel,
        :final publicAddress,
      ):
        title = venueName;
        detail = publicAddress.trim().isNotEmpty
            ? publicAddress.trim()
            : areaLabel;
        fallbackIcon = Icons.location_on_outlined;
      case PublishedBookableSessionOnlineLocation(:final providerLabel):
        title = 'Онлайн';
        detail = providerLabel.trim().isEmpty
            ? 'Ссылка предоставляется сервисом бронирования'
            : providerLabel.trim();
        fallbackIcon = Icons.videocam_outlined;
      case PublishedBookableSessionHiddenLocation(:final safeAreaLabel):
        title = safeAreaLabel.trim().isEmpty
            ? 'Место не опубликовано'
            : safeAreaLabel.trim();
        detail = 'Точный адрес не опубликован';
        fallbackIcon = Icons.location_off_outlined;
    }

    return ObjectOfferCard(
      padding: const EdgeInsets.all(13),
      onTap: showsMap ? onMap : null,
      child: Row(
        children: <Widget>[
          if (showsMap)
            const Flexible(flex: 4, child: _ObjectOfferMapPreview())
          else
            Flexible(
              flex: 4,
              child: AspectRatio(
                aspectRatio: 1.35,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: RechargeTheme.bookableSessionAccentSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    fallbackIcon,
                    color: RechargeTheme.bookableSessionAccent,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RechargeTheme.objectOfferSecondaryText,
                  ),
                ),
                if (showsMap) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          'Показать на карте',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: RechargeTheme.bookableSessionAccent,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: RechargeTheme.bookableSessionAccent,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPublisherCard extends StatelessWidget {
  const _PreviewPublisherCard({
    required this.name,
    required this.handle,
    required this.label,
    required this.accentColor,
    this.verification = PublisherVerificationDisplayState.none,
  });

  final String name;
  final String handle;
  final String label;
  final Color accentColor;
  final PublisherVerificationDisplayState verification;

  @override
  Widget build(BuildContext context) {
    final String trimmedName = name.trim();
    return ObjectOfferCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 25,
            backgroundColor: accentColor,
            foregroundColor: RechargeTheme.objectOfferOnHero,
            child: Text(
              trimmedName.isEmpty
                  ? '?'
                  : trimmedName.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: RechargeTheme.objectOfferSecondaryText,
                  ),
                ),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        trimmedName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: RechargeTheme.objectOfferPrimaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (verification !=
                        PublisherVerificationDisplayState.none) ...<Widget>[
                      const SizedBox(width: 6),
                      Icon(Icons.verified, size: 15, color: accentColor),
                    ],
                  ],
                ),
                if (handle.trim().isNotEmpty)
                  Text(
                    handle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RechargeTheme.objectOfferSecondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewAboutCard extends StatefulWidget {
  const _PreviewAboutCard({
    required this.title,
    required this.text,
    required this.accentColor,
    required this.accentIcon,
  });

  final String title;
  final String text;
  final Color accentColor;
  final IconData accentIcon;

  @override
  State<_PreviewAboutCard> createState() => _PreviewAboutCardState();
}

class _PreviewAboutCardState extends State<_PreviewAboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.accentIcon,
                  size: 19,
                  color: widget.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.text,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: RechargeTheme.objectOfferPrimaryText,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _expanded ? 'Свернуть' : 'Читать далее',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: widget.accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.chevron_right,
                  size: 18,
                  color: widget.accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLabeledTextCard extends StatelessWidget {
  const _PreviewLabeledTextCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: RechargeTheme.objectOfferPrimaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBulletListCard extends StatelessWidget {
  const _PreviewBulletListCard({
    required this.title,
    required this.items,
    required this.accentColor,
  });

  final String title;
  final List<String> items;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final String item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewLocationCard extends StatelessWidget {
  const _PreviewLocationCard({
    required this.title,
    required this.address,
    required this.onTap,
    required this.accentColor,
  });

  final String title;
  final String address;
  final VoidCallback? onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Flexible(flex: 4, child: _ObjectOfferMapPreview()),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (address.trim().isNotEmpty)
                  Text(
                    address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RechargeTheme.objectOfferSecondaryText,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Показать на карте',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: accentColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassWorkshopScheduleCard extends StatelessWidget {
  const _ClassWorkshopScheduleCard({required this.items});

  final List<_ClassWorkshopScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Расписание',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (int index = 0; index < items.length; index++)
            _ClassWorkshopScheduleRow(
              item: items[index],
              isLast: index == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ClassWorkshopScheduleRow extends StatelessWidget {
  const _ClassWorkshopScheduleRow({required this.item, required this.isLast});

  final _ClassWorkshopScheduleItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 16,
            child: Column(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: const BoxDecoration(
                    color: RechargeTheme.emerald900,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  const Expanded(
                    child: VerticalDivider(
                      width: 1.5,
                      thickness: 1.5,
                      color: RechargeTheme.objectOfferTimelineLine,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.timeLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: RechargeTheme.objectOfferSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
