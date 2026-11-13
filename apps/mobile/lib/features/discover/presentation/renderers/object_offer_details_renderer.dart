import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../../../shared/primitives/money/money.dart';
import '../discover_formats.dart';
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
import 'package:intl/intl.dart';

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
         'ObjectOfferDetailsRenderer.discoverItem is for the venue/' // l10n-ignore: developer error
         'participation profiles only — Rental is outside this visual system. ' // l10n-ignore: developer error
         'objectOfferProfileFor also throws here for any type outside ' // l10n-ignore: developer error
         "this slice's scope (DTL-OBJ-01 §1.1), catching a misrouted "
         'caller instead of silently rendering something generic.', // l10n-ignore: developer error or list formatting, not copy
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
        return _buildDiscoverItemAppBarActions(context, delegate);
      }
      return delegate.buildAppBarActions(context);
    }
    if (_eventProjection != null) {
      return <Widget>[
        ObjectOfferHeroActionButton(
          tooltip: _eventIsFavorite
              ? context.l10n.discoverUnsave
              : context.l10n.discoverSave,
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
          tooltip: context.l10n.discoverShare,
          onPressed: _findPeopleOnShareTap,
          icon: Icons.ios_share_rounded,
        ),
      ];
    }
    if (_classWorkshopProps != null) {
      return <Widget>[
        ObjectOfferHeroActionButton(
          tooltip: context.l10n.discoverShare,
          onPressed: _classWorkshopOnShareTap,
          icon: Icons.ios_share_rounded,
        ),
      ];
    }
    if (_bookableSessionProjection != null) {
      return <Widget>[
        ObjectOfferHeroActionButton(
          tooltip: context.l10n.discoverShare,
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
          typeLabel: context.l10n.discoverBadgePlace,
          typeForegroundColor: RechargeTheme.placeAccent,
          typeBackgroundColor: RechargeTheme.placeAccentSurface,
        ),
        DiscoverObjectKind.activity => ObjectOfferSingleImageHero(
          imageUrl: delegate.item.coverImageUrl,
          imageSemanticLabel: delegate.item.title,
          fallbackIcon: Icons.self_improvement_rounded,
          fallbackColor: RechargeTheme.emerald900,
          typeLabel: context.l10n.discoverBadgeActivity,
          typeForegroundColor: RechargeTheme.activityAccent,
          typeBackgroundColor: RechargeTheme.activityAccentSurface,
        ),
        DiscoverObjectKind.event ||
        DiscoverObjectKind.route ||
        DiscoverObjectKind.findPeople => delegate.buildHero(context),
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
        typeLabel: context.l10n.discoverBadgeFindPeople,
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
        return _buildPlaceBody(context, delegate);
      }
      if (delegate.item.objectKind == DiscoverObjectKind.activity) {
        return _buildActivityBody(context, delegate);
      }
      return delegate.buildBody(context);
    }
    if (_eventProjection != null) {
      return _buildEventBody(_eventProjection);
    }
    if (_findPeopleProjection
        case final PublishedFindPeopleDiscoveryEntity projection) {
      return _buildFindPeopleBody(context, projection);
    }
    if (_classWorkshopProps case final _ClassWorkshopDisplay props) {
      return _buildClassWorkshopBody(context, props);
    }
    if (_bookableSessionProjection
        case final PublishedBookableSessionDiscoveryEntity projection) {
      return _buildBookableSessionBody(
        context,
        projection,
        _bookableSessionEvaluation!,
      );
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
                  ? context.l10n.discoverRequestSent
                  : ctaLabelForDetails(context.l10n, delegate.item),
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
                ? context.l10n.discoverReviewAndBook
                : context.l10n.discoverCheckTimeOnSite,
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
    BuildContext context,
    CompatibilityObjectRenderer delegate,
  ) {
    final List<ObjectOfferUtilityActionData> utilityActions =
        <ObjectOfferUtilityActionData>[
          ObjectOfferUtilityActionData(
            label: context.l10n.discoverShare,
            icon: Icons.ios_share_rounded,
            onSelected: delegate.onShareTap,
          ),
          if (delegate.onAddToScenario != null)
            ObjectOfferUtilityActionData(
              label: context.l10n.discoverAddToScenario,
              icon: Icons.playlist_add_outlined,
              onSelected: delegate.onAddToScenario!,
            ),
          ObjectOfferUtilityActionData(
            label: context.l10n.discoverFindSimilar,
            icon: Icons.search,
            onSelected: delegate.onSearch,
          ),
          ObjectOfferUtilityActionData(
            label: context.l10n.discoverCreateSimilar,
            icon: Icons.add_circle_outline,
            onSelected: delegate.onCreateSimilar,
          ),
          ObjectOfferUtilityActionData(
            label: context.l10n.discoverViewRoute,
            icon: Icons.route_outlined,
            onSelected: delegate.onRouteMap,
          ),
          ObjectOfferUtilityActionData(
            label: context.l10n.discoverCreateRoute,
            icon: Icons.alt_route,
            onSelected: delegate.onCreateRoute,
          ),
          // Visit History accepts explicit Place visits only (VIS-HIST-01).
          if (delegate.item.objectKind == DiscoverObjectKind.place)
            ObjectOfferUtilityActionData(
              label: context.l10n.discoverMarkVisited,
              icon: Icons.history_toggle_off,
              onSelected: delegate.onMarkVisited,
            ),
        ];
    return <Widget>[
      ObjectOfferHeroActionButton(
        tooltip: delegate.isFavorite
            ? context.l10n.discoverUnsave
            : context.l10n.discoverSave,
        onPressed: delegate.onFavoriteTap,
        icon: delegate.isFavorite ? Icons.favorite : Icons.favorite_border,
      ),
      ObjectOfferUtilityMenu(
        tooltip: context.l10n.discoverShareAndMore,
        icon: Icons.ios_share_rounded,
        actions: utilityActions,
      ),
    ];
  }

  Widget _buildPlaceBody(
    BuildContext context,
    CompatibilityObjectRenderer delegate,
  ) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final PlaceDetailsSection section in placeProfileSections)
            if (_placeBodySectionFor(context, section, delegate)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _placeBodySectionFor(
    BuildContext context,
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
                label: context.l10n.discoverPublisher,
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

  Widget _buildActivityBody(
    BuildContext context,
    CompatibilityObjectRenderer delegate,
  ) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ActivityDetailsSection section in activityProfileSections)
            if (_activityBodySectionFor(context, section, delegate)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _activityBodySectionFor(
    BuildContext context,
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
                label: context.l10n.discoverOrganizer,
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

  Widget _buildFindPeopleBody(
    BuildContext context,
    PublishedFindPeopleDiscoveryEntity projection,
  ) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final FindPeopleDetailsSection section
              in findPeopleProfileSections)
            if (_findPeopleBodySectionFor(context, section, projection)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _findPeopleBodySectionFor(
    BuildContext context,
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
      FindPeopleDetailsSection.metrics => _findPeopleMetrics(
        context,
        projection,
      ),
      FindPeopleDetailsSection.organizer =>
        projection.publisherName.trim().isEmpty
            ? null
            : _PreviewPublisherCard(
                name: projection.publisherName,
                handle: projection.publisherHandle,
                label: context.l10n.discoverOrganizer,
                accentColor: RechargeTheme.findPeopleAccent,
                verification: projection.publisherVerification,
              ),
      FindPeopleDetailsSection.about =>
        projection.fullDescription.trim().isEmpty
            ? null
            : _PreviewAboutCard(
                title: context.l10n.discoverAboutMeetup,
                text: projection.fullDescription,
                accentColor: RechargeTheme.findPeopleAccent,
                accentIcon: Icons.diversity_3_outlined,
              ),
      FindPeopleDetailsSection.schedule => _PreviewBulletListCard(
        title:
            projection.scheduleMode == PublishedFindPeopleScheduleMode.timePoll
            ? context.l10n.discoverTimeOptions
            : context.l10n.discoverMeetupTime,
        items: projection.timeOptions
            .map(
              (option) => findPeopleTimeOptionLabel(
                context.l10n,
                option,
                projection.timezoneId,
                _findPeopleTimezoneRepository!,
              ),
            )
            .toList(growable: false),
        accentColor: RechargeTheme.findPeopleAccent,
      ),
      FindPeopleDetailsSection.meetingFormat =>
        _findPeopleMeetingFormatText(context, projection).isEmpty
            ? null
            : _PreviewLabeledTextCard(
                title: context.l10n.discoverMeetupFormat,
                text: _findPeopleMeetingFormatText(context, projection),
              ),
      FindPeopleDetailsSection.requirements =>
        _findPeopleRequirements(context, projection).isEmpty
            ? null
            : _PreviewBulletListCard(
                title: context.l10n.discoverParticipantRequirements,
                items: _findPeopleRequirements(context, projection),
                accentColor: RechargeTheme.findPeopleAccent,
              ),
      FindPeopleDetailsSection.cost => _PreviewLabeledTextCard(
        title: context.l10n.discoverExpectedCosts,
        text: _findPeopleCostText(context, projection),
      ),
      FindPeopleDetailsSection.location => _FindPeopleLocationCard(
        location: projection.publicLocation,
        onMap: projection.publicLocation is PublishedFindPeoplePointLocation
            ? _findPeopleOnMap
            : null,
      ),
    };
  }

  Widget? _findPeopleMetrics(
    BuildContext context,
    PublishedFindPeopleDiscoveryEntity projection,
  ) {
    final List<ObjectOfferMetricData> metrics = <ObjectOfferMetricData>[
      if (projection.currentGroupSize case final int value)
        ObjectOfferMetricData(
          value: '$value',
          label: context.l10n.discoverInGroupNow,
        ),
      ObjectOfferMetricData(
        value: context.l10n.discoverUpTo(projection.targetGroupSize),
        label: context.l10n.discoverDesiredSize,
      ),
      if (projection.durationMinutes case final int value)
        ObjectOfferMetricData(
          value: _objectOfferDurationLabel(context.l10n, value),
          label: context.l10n.discoverDuration,
        ),
    ];
    // `ObjectOfferMetricsStrip` requires more than one column — with a
    // single supplied value there is nothing honest to compare it
    // against, so the whole strip is hidden rather than shown lopsided.
    if (metrics.length < 2) return null;
    return ObjectOfferMetricsStrip(metrics: metrics);
  }

  String _findPeopleMeetingFormatText(
    BuildContext context,
    PublishedFindPeopleDiscoveryEntity projection,
  ) {
    final String mode = switch (projection.publicLocation.meetingMode) {
      PublishedFindPeopleMeetingMode.inPerson => context.l10n.discoverInPerson,
      PublishedFindPeopleMeetingMode.online => context.l10n.discoverOnline,
      PublishedFindPeopleMeetingMode.hybrid => context.l10n.discoverHybrid,
    };
    return <String>[
      mode,
      if (projection.skillLevelLabel.trim().isNotEmpty)
        projection.skillLevelLabel.trim(),
      if (projection.paceLabel.trim().isNotEmpty) projection.paceLabel.trim(),
      if (projection.languageLabels.isNotEmpty)
        '${context.l10n.discoverLanguagesLabel} ${projection.languageLabels.join(', ')}',
      _findPeopleRecruitmentLabel(context.l10n, projection.recruitmentStatus),
    ].join('\n');
  }

  List<String> _findPeopleRequirements(
    BuildContext context,
    PublishedFindPeopleDiscoveryEntity projection,
  ) {
    return <String>[
      ...projection.publicRequirements
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
      if (projection.equipmentNote.trim().isNotEmpty)
        '${context.l10n.discoverEquipmentLabel} ${projection.equipmentNote.trim()}',
      if (projection.accessibilityNote.trim().isNotEmpty)
        '${context.l10n.discoverAccessibilityLabel} ${projection.accessibilityNote.trim()}',
    ];
  }

  String _findPeopleCostText(
    BuildContext context,
    PublishedFindPeopleDiscoveryEntity projection,
  ) {
    final String disclosure = switch (projection.costType) {
      PublishedFindPeopleCostType.free => context.l10n.discoverNoRequiredCosts,
      PublishedFindPeopleCostType.estimated =>
        context.l10n.discoverAboutPerPerson(
          discoverMoney(
            context.l10n,
            projection.expectedSpendAmount!,
            projection.currencyCode,
          ),
        ),
      PublishedFindPeopleCostType.unknown =>
        context.l10n.discoverCostsNotSpecified,
    };
    final String note = projection.costNote.trim();
    return note.isEmpty ? disclosure : '$disclosure\n$note';
  }

  Widget _buildClassWorkshopBody(
    BuildContext context,
    _ClassWorkshopDisplay props,
  ) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ClassWorkshopDetailsSection section
              in classWorkshopProfileSections)
            if (_classWorkshopBodySectionFor(context, section, props)
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _classWorkshopBodySectionFor(
    BuildContext context,
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
      ClassWorkshopDetailsSection.metrics => _classWorkshopMetrics(
        context,
        props,
      ),
      ClassWorkshopDetailsSection.teacher => _ClassWorkshopTeacherCard(
        props: props,
      ),
      ClassWorkshopDetailsSection.about =>
        props.aboutText(context.l10n).trim().isEmpty
            ? null
            : _PreviewAboutCard(
                title: context.l10n.discoverAboutClass,
                text: props.aboutText(context.l10n),
                accentColor: RechargeTheme.classWorkshopAccent,
                accentIcon: Icons.school_outlined,
              ),
      ClassWorkshopDetailsSection.schedule =>
        props.scheduleItems(context.l10n).isEmpty
            ? _PreviewLabeledTextCard(
                title: context.l10n.discoverSchedule,
                text: context.l10n.discoverDatesTbc,
              )
            : _ClassWorkshopScheduleCard(
                items: props.scheduleItems(context.l10n),
              ),
      ClassWorkshopDetailsSection.materials =>
        props.includedMaterials.isEmpty
            ? null
            : _PreviewBulletListCard(
                title: context.l10n.discoverMaterialsIncluded,
                items: props.includedMaterials,
                accentColor: RechargeTheme.classWorkshopAccent,
              ),
      ClassWorkshopDetailsSection.requirements =>
        props.requirements.isEmpty
            ? null
            : _PreviewBulletListCard(
                title: context.l10n.discoverRequirements,
                items: props.requirements,
                accentColor: RechargeTheme.classWorkshopAccent,
              ),
      ClassWorkshopDetailsSection.location => _ClassWorkshopLocationCard(
        location: props.projection.publicLocation,
        onMap: _classWorkshopOnMap,
      ),
    };
  }

  Widget? _classWorkshopMetrics(
    BuildContext context,
    _ClassWorkshopDisplay props,
  ) {
    final List<ObjectOfferMetricData> metrics = <ObjectOfferMetricData>[
      if (props.priceLabel(context.l10n) case final String value
          when value.trim().isNotEmpty)
        ObjectOfferMetricData(
          value: value,
          label: props.priceUnitLabel(context.l10n),
        ),
      if (props.groupSizeLabel(context.l10n) case final String value
          when value.trim().isNotEmpty)
        ObjectOfferMetricData(
          value: value,
          label: context.l10n.discoverGroupSize,
        ),
      if (props.durationLabel(context.l10n) case final String value
          when value.trim().isNotEmpty)
        ObjectOfferMetricData(
          value: value,
          label: props.durationUnitLabel(context.l10n),
        ),
    ];
    if (metrics.length < 2) return null;
    return ObjectOfferMetricsStrip(metrics: metrics);
  }

  Widget _buildBookableSessionBody(
    BuildContext context,
    PublishedBookableSessionDiscoveryEntity projection,
    BookableSessionScheduleEvaluation evaluation,
  ) {
    return ObjectOfferContentSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final BookableSessionDetailsSection section
              in bookableSessionProfileSections)
            if (_bookableSessionBodySectionFor(
                  context,
                  section,
                  projection,
                  evaluation,
                )
                case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: RechargeTheme.objectOfferSectionGap),
            ],
        ],
      ),
    );
  }

  Widget? _bookableSessionBodySectionFor(
    BuildContext context,
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
        context,
        projection,
      ),
      BookableSessionDetailsSection.provider => _PreviewPublisherCard(
        name: projection.publisherName,
        handle: projection.publisherHandle,
        label: projection.publisherType == 'page'
            ? context.l10n.discoverOrganization
            : context.l10n.discoverSpecialist,
        accentColor: RechargeTheme.bookableSessionAccent,
        verification: projection.publisherVerification,
      ),
      BookableSessionDetailsSection.about =>
        _bookableSessionAboutText(projection).isEmpty
            ? null
            : _PreviewAboutCard(
                title: context.l10n.discoverAboutService,
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
    BuildContext context,
    PublishedBookableSessionDiscoveryEntity projection,
  ) {
    return ObjectOfferMetricsStrip(
      metrics: <ObjectOfferMetricData>[
        ObjectOfferMetricData(
          value: _bookableSessionPriceLabel(context.l10n, projection),
          label: context.l10n.discoverPrice,
        ),
        ObjectOfferMetricData(
          value: _objectOfferDurationLabel(
            context.l10n,
            projection.durationMinutes,
          ),
          label: context.l10n.discoverDuration,
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
          value: item.isFree
              ? context.l10n.discoverFree
              : priceLabelForDetails(context.l10n, item),
          label: context.l10n.discoverPrice,
        ),
        ObjectOfferMetricData(
          value: discoverKm(context.l10n, item.distanceKm),
          label: context.l10n.discoverFromYou,
        ),
        ObjectOfferMetricData(
          value: _objectOfferDurationLabel(context.l10n, item.durationMinutes),
          label: context.l10n.discoverTime,
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
                  context.l10n.discoverAboutPlace,
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
                  Flexible(
                    child: Text(
                      _expanded
                          ? context.l10n.discoverShowLess
                          : context.l10n.discoverReadMore,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: RechargeTheme.placeAccent,
                        fontWeight: FontWeight.w600,
                      ),
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
                  context.l10n.discoverOpeningHours,
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
                      openingLabelForDetails(
                        context.l10n,
                        item.timeFitEvaluation!,
                      ),
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
                        _openingRuleLabel(context.l10n, rule),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: RechargeTheme.objectOfferSecondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      rule.isClosedAllDay
                          ? context.l10n.discoverClosed
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
                        context.l10n.discoverShowOnMap,
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

String _openingRuleLabel(AppLocalizations l10n, OpeningHoursRule rule) {
  if (rule.exceptionDate case final exceptionDate?) {
    return exceptionDate.toString();
  }
  // A weekday heads its table row, so it starts with a capital letter.
  return toBeginningOfSentenceCase(
    RechargeFormats.weekdayLong(rule.dayOfWeek!.index + 1, l10n.localeName),
    l10n.localeName,
  );
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
          text: dateTimeLabelForDetails(context.l10n, item.startsAtUtc),
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
          value: item.isFree
              ? context.l10n.discoverFree
              : priceLabelForDetails(context.l10n, item),
          label: context.l10n.discoverPrice,
        ),
        ObjectOfferMetricData(
          value: item.participantsCount?.toString() ?? '—',
          label: context.l10n.discoverParticipants,
          semanticsLabel: item.participantsCount == null
              ? context.l10n.discoverParticipantCountUnknown
              : null,
        ),
        ObjectOfferMetricData(
          value: _objectOfferDurationLabel(context.l10n, item.durationMinutes),
          label: context.l10n.discoverDuration,
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
                  context.l10n.discoverAboutClass,
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
                  Flexible(
                    child: Text(
                      _expanded
                          ? context.l10n.discoverShowLess
                          : context.l10n.discoverReadMore,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: RechargeTheme.activityAccent,
                        fontWeight: FontWeight.w600,
                      ),
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
            context.l10n.discoverSchedule,
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
                _activitySlotLabel(context.l10n, slot),
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

String _objectOfferDurationLabel(AppLocalizations l10n, int? durationMinutes) =>
    discoverDuration(l10n, durationMinutes);

String _activitySlotLabel(AppLocalizations l10n, TimeSlot slot) {
  final DateTime endLocal = slot.endAtUtc.toLocal();
  final String endHour = endLocal.hour.toString().padLeft(2, '0');
  final String endMinute = endLocal.minute.toString().padLeft(2, '0');
  return '${dateTimeLabelForDetails(l10n, slot.startAtUtc)}–$endHour:$endMinute';
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
              Positioned(
                left: 12,
                top: 12,
                child: _RentalBadge(label: context.l10n.discoverBadgeRental),
              ),
              if (!projection.hasActiveInventory)
                Positioned(
                  right: 12,
                  top: 12,
                  child: _RentalBadge(
                    label: context.l10n.discoverCurrentlyUnavailable
                        .toUpperCase(),
                  ),
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
                  rentalBaseRateLabel(context.l10n, projection),
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
              context.l10n.discoverWhatIsRented,
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
                        rentalInventoryGroupLabel(context.l10n, group),
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
                context.l10n.discoverRentalQuantitiesDisclaimer,
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
              context.l10n.discoverRatePlan,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final PublishedRentalRateStepRef step in projection.rateSteps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  rentalRateStepLabel(context.l10n, projection, step),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              rentalDepositLabel(context.l10n, projection),
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
                      rentalDeliveryLabel(context.l10n, projection),
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
              rentalDurationLabel(context.l10n, projection),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (projection.minRenterAge != null ||
                projection.idRequiredAtHandover) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                rentalSafetyRequirementsLabel(context.l10n, projection),
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
                    ? '${context.l10n.discoverListedByPageLabel} ${projection.publisherId}'
                    : '${context.l10n.discoverListedByLabel} ${projection.publisherId}',
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
                  ? context.l10n.discoverConfirmOnProviderSite
                  : context.l10n.discoverCurrentlyUnavailable,
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
              label: context.l10n.discoverBadgeEvent,
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
        tooltip: context.l10n.discoverShare,
        icon: Icons.ios_share_rounded,
        onPressed: onShare,
      );
    }
    return ObjectOfferHeroActionSurface(
      endPadding: 12,
      child: PopupMenuButton<_EventUtilityAction>(
        tooltip: context.l10n.discoverShare,
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
            <PopupMenuEntry<_EventUtilityAction>>[
              PopupMenuItem<_EventUtilityAction>(
                value: _EventUtilityAction.share,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.ios_share_rounded),
                  title: Text(context.l10n.discoverShare),
                ),
              ),
              PopupMenuItem<_EventUtilityAction>(
                value: _EventUtilityAction.addToScenario,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.playlist_add_outlined),
                  title: Text(context.l10n.discoverAddToScenario),
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
            text: eventDateTimeLabel(
              context.l10n,
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
            cancelled ? context.l10n.discoverCancelledSuffix(text) : text,
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
          value: priceMetricLabel(context.l10n, projection),
          label: context.l10n.discoverPrice,
        ),
        ObjectOfferMetricData(
          value: participantsMetricLabel(projection),
          label: context.l10n.discoverParticipants,
          semanticsLabel: projection.participantsCount == null
              ? context.l10n.discoverParticipantCountUnknown
              : null,
        ),
        ObjectOfferMetricData(
          value: durationMetricLabel(context.l10n, projection),
          label: context.l10n.discoverDuration,
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
                  context.l10n.discoverOrganizer,
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
                          ? context.l10n.discoverClubProfile
                          : context.l10n.discoverProfile,
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
                  context.l10n.discoverAboutEvent,
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
                Flexible(
                  child: Text(
                    _expanded
                        ? context.l10n.discoverShowLess
                        : context.l10n.discoverReadMore,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: RechargeTheme.emerald900,
                      fontWeight: FontWeight.w600,
                    ),
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
                context.l10n.discoverSchedule,
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
                    context.l10n.discoverAddToCalendar,
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
                    discoverWallTime(context.l10n, start),
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
                        context.l10n.discoverShowOnMap,
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
        child: Text(
          context.l10n.discoverSignUp,
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

String rentalBaseRateLabel(
  AppLocalizations l10n,
  PublishedRentalDiscoveryEntity projection,
) {
  if (projection.rateSteps.isEmpty) return l10n.discoverPriceOnRequest;
  final PublishedRentalRateStepRef first = projection.rateSteps.first;
  return l10n.discoverRentalBaseRate(
    projection.billingUnit,
    _moneyLabel(l10n, first.unitPriceMinor, projection.currencyCode),
  );
}

/// Canonical §17.3: "Без requested interval card показывает `N units
/// listed`, а не `N available`" — this Details-page listing has no
/// requested-interval query either, so the same discipline applies: never
/// claim a verified-available count, only the declared quantity.
String rentalInventoryGroupLabel(
  AppLocalizations l10n,
  PublishedRentalInventoryGroupRef group,
) {
  // Label and variant are the Creator's text; the status code is never shown.
  final String variant = group.sizeOrVariant == null
      ? ''
      : ' · ${group.sizeOrVariant}';
  final String status = group.isAvailable
      ? ''
      : ' · ${l10n.discoverCurrentlyUnavailable}';
  return '${group.label}$variant — '
      '${l10n.discoverRentalUnitsListed(group.quantity)}$status';
}

String rentalRateStepLabel(
  AppLocalizations l10n,
  PublishedRentalDiscoveryEntity projection,
  PublishedRentalRateStepRef step,
) => l10n.discoverRentalRateStep(
  projection.billingUnit,
  _moneyLabel(l10n, step.unitPriceMinor, projection.currencyCode),
  step.minUnits,
);

String rentalDepositLabel(
  AppLocalizations l10n,
  PublishedRentalDiscoveryEntity projection,
) {
  if (!projection.hasDeposit) return l10n.discoverNoDepositRequired;
  final int? amount = projection.depositAmountMinor;
  return amount == null
      ? l10n.discoverDepositRequired
      : l10n.discoverDeposit(
          _moneyLabel(l10n, amount, projection.currencyCode),
        );
}

String rentalDeliveryLabel(
  AppLocalizations l10n,
  PublishedRentalDiscoveryEntity projection,
) {
  final double? radius = projection.deliveryRadiusKm;
  return radius == null
      ? l10n.discoverDeliveryAvailable
      : l10n.discoverDeliveryWithin(discoverOneDecimal(l10n, radius));
}

String rentalDurationLabel(
  AppLocalizations l10n,
  PublishedRentalDiscoveryEntity projection,
) => l10n.discoverRentalPeriod(
  _minutesLabel(l10n, projection.offeredMinMinutes),
  _minutesLabel(l10n, projection.offeredMaxMinutes),
);

String rentalSafetyRequirementsLabel(
  AppLocalizations l10n,
  PublishedRentalDiscoveryEntity projection,
) {
  final List<String> parts = <String>[
    if (projection.minRenterAge case final int age) l10n.discoverMinAge(age),
    if (projection.idRequiredAtHandover) l10n.discoverIdRequired,
  ];
  return parts.join(' · ');
}

String _moneyLabel(
  AppLocalizations l10n,
  int amountMinor,
  String currencyCode,
) => RechargeFormats.money(
  Money(minorUnits: amountMinor, currencyCode: currencyCode),
  l10n.localeName,
);

String _minutesLabel(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.discoverMinutes(minutes);
  if (minutes < 1440) return l10n.discoverHours('${(minutes / 60).round()}');
  return l10n.discoverDays((minutes / 1440).round());
}

/// Event formatting helpers (`DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §7.4).
/// L4.5: dates and times follow the reader's language; the zone is always
/// the object's own, never the device zone.

/// Start date with weekday plus start–end time, both resolved against the
/// Event's own [timezoneId], never the viewing device's local timezone
/// (`DTL-EVT-01` EVT-D-AC-20).
String eventDateTimeLabel(
  AppLocalizations l10n,
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
  return l10n.discoverDateTimeRange(
    discoverWallDateWithWeekday(l10n, start),
    discoverWallTime(l10n, start),
    discoverWallTime(l10n, end),
  );
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
      typeLabel: context.l10n.discoverBadgeSession,
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
String bookableSessionOfferLabel(
  AppLocalizations l10n,
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
  final bool sameDay =
      start.date.year == end.date.year &&
      start.date.month == end.date.month &&
      start.date.day == end.date.day;
  return sameDay
      ? l10n.discoverDateTimeRange(
          discoverWallDayWithWeekday(l10n, start),
          discoverWallTime(l10n, start),
          discoverWallTime(l10n, end),
        )
      : l10n.discoverDateTimeRange(
          discoverWallDayWithWeekday(l10n, start),
          discoverWallTime(l10n, start),
          '${discoverWallDayWithWeekday(l10n, end)} · ${discoverWallTime(l10n, end)}',
        );
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

/// `isFree` → «Бесплатно»; otherwise an amount with currency — never a
/// bare "0" for a free event (`DTL-EVT-01` EVT-D-AC-07).
String priceMetricLabel(
  AppLocalizations l10n,
  PublishedEventDiscoveryEntity projection,
) {
  if (projection.isFree) return l10n.discoverFree;
  return discoverMoney(l10n, projection.priceAmount, projection.currencyCode);
}

/// `null` → visual «—» (honest unknown, never a fake `0`) — the
/// accompanying `Semantics` label lives in the shared metrics primitive.
String participantsMetricLabel(PublishedEventDiscoveryEntity projection) {
  final int? count = projection.participantsCount;
  return count == null ? '—' : '$count';
}

String durationMetricLabel(
  AppLocalizations l10n,
  PublishedEventDiscoveryEntity projection,
) {
  final int? minutes = projection.durationMinutes;
  if (minutes == null) return '—';
  if (minutes % 60 == 0) return l10n.discoverHours('${minutes ~/ 60}');
  return l10n.discoverHours(discoverOneDecimal(l10n, minutes / 60));
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
          label: _findPeopleScheduleSummary(
            context.l10n,
            projection,
            timezoneRepository,
          ),
        ),
        const SizedBox(height: 8),
        _PreviewEssentialLine(
          icon:
              projection.publicLocation.meetingMode ==
                  PublishedFindPeopleMeetingMode.online
              ? Icons.videocam_outlined
              : Icons.location_on_outlined,
          label: _findPeopleLocationSummary(
            context.l10n,
            projection.publicLocation,
          ),
        ),
      ],
    );
  }
}

String findPeopleTimeOptionLabel(
  AppLocalizations l10n,
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
  final String time = l10n.discoverDateTimeRange(
    discoverWallDateWithWeekday(l10n, start),
    discoverWallTime(l10n, start),
    discoverWallTime(l10n, end),
  );
  return option.kind == PublishedFindPeopleTimeOptionKind.candidate
      ? l10n.discoverTimeOptionCandidate(time)
      : time;
}

String _findPeopleScheduleSummary(
  AppLocalizations l10n,
  PublishedFindPeopleDiscoveryEntity projection,
  TimezoneRepository timezoneRepository,
) {
  final String first = findPeopleTimeOptionLabel(
    l10n,
    projection.timeOptions.first,
    projection.timezoneId,
    timezoneRepository,
  );
  return switch (projection.scheduleMode) {
    PublishedFindPeopleScheduleMode.single => first,
    PublishedFindPeopleScheduleMode.timePoll => l10n.discoverTimeOptionCount(
      projection.timeOptions.length,
    ),
    PublishedFindPeopleScheduleMode.recurring =>
      projection.timeOptions.length == 1
          ? first
          : l10n.discoverFirstAndMore(first, projection.timeOptions.length - 1),
  };
}

String _findPeopleLocationSummary(
  AppLocalizations l10n,
  PublishedFindPeoplePublicLocation location,
) {
  return switch (location) {
    PublishedFindPeoplePointLocation(:final areaLabel) => areaLabel,
    PublishedFindPeopleOnlineLocation(:final providerLabel) =>
      providerLabel.trim().isEmpty
          ? l10n.discoverOnline
          : '${l10n.discoverOnline} · $providerLabel',
    PublishedFindPeopleHiddenLocation(:final safeAreaLabel) =>
      safeAreaLabel.trim().isEmpty
          ? l10n.discoverLocationNotPublished
          : safeAreaLabel,
  };
}

String _findPeopleRecruitmentLabel(
  AppLocalizations l10n,
  PublishedFindPeopleRecruitmentStatus status,
) {
  return switch (status) {
    PublishedFindPeopleRecruitmentStatus.collectingAvailability =>
      l10n.discoverCollectingTimeOptions,
    PublishedFindPeopleRecruitmentStatus.open => l10n.discoverRecruitmentOpen,
    PublishedFindPeopleRecruitmentStatus.waitlistOnly =>
      l10n.discoverWaitlistOnly,
    PublishedFindPeopleRecruitmentStatus.full => l10n.discoverGroupFull,
    PublishedFindPeopleRecruitmentStatus.completed => l10n.discoverMeetupEnded,
    PublishedFindPeopleRecruitmentStatus.cancelled =>
      l10n.discoverMeetupCancelled,
    PublishedFindPeopleRecruitmentStatus.expired =>
      l10n.discoverRecruitmentClosed,
  };
}

/// Internal formatting adapter only. Public renderer input is always typed.
class _ClassWorkshopDisplay {
  _ClassWorkshopDisplay(this.projection, this.timezone);
  final PublishedClassWorkshopDiscoveryEntity projection;
  final TimezoneRepository timezone;
  String get title => projection.title;
  String get discipline => projection.disciplineLabel;
  String levelOrFormat(AppLocalizations l10n) => [
    switch (projection.kind) {
      ClassWorkshopKind.classLesson => l10n.discoverKindClass,
      ClassWorkshopKind.workshop => l10n.discoverKindWorkshop,
      ClassWorkshopKind.masterclass => l10n.discoverKindMasterclass,
      ClassWorkshopKind.course => l10n.discoverKindCourse,
      ClassWorkshopKind.experience => l10n.discoverKindHandsOn,
    },
    projection.levelLabel,
    switch (projection.publicLocation.delivery) {
      ClassWorkshopDelivery.offline => l10n.discoverInPerson,
      ClassWorkshopDelivery.onlineLive => l10n.discoverOnline,
      ClassWorkshopDelivery.hybrid => l10n.discoverHybrid,
    },
    ...projection.languageLabels,
  ].where((s) => s.trim().isNotEmpty).join(' · ');
  String dateAndPlaceLabel(AppLocalizations l10n) {
    final schedule = projection.schedule;
    final date = schedule is ClassWorkshopAnnouncedSchedule
        ? classWorkshopOccurrenceLabel(
            l10n,
            schedule.occurrences.first,
            timezone,
          )
        : l10n.discoverDatesTbc;
    final area = switch (projection.publicLocation) {
      ClassWorkshopPointLocation(:final venueName) => venueName,
      ClassWorkshopHiddenLocation(:final safeAreaLabel) => safeAreaLabel,
      ClassWorkshopOnlineLocation() => '',
    };
    return [date, area].where((s) => s.isNotEmpty).join(' · ');
  }

  String? priceLabel(AppLocalizations l10n) => switch (projection.price) {
    ClassWorkshopPriceNotProvided() => null,
    ClassWorkshopPriceFree() => l10n.discoverFree,
    final ClassWorkshopPriceFixed price => classWorkshopPriceLabel(l10n, price),
  };
  String priceUnitLabel(AppLocalizations l10n) => switch (projection.price) {
    ClassWorkshopPriceFixed(:final scope) =>
      scope == ClassWorkshopPriceScope.perPersonPerClass
          ? l10n.discoverPricePerPersonSession
          : l10n.discoverPricePerPersonCourse,
    _ => l10n.discoverPrice,
  };
  String? groupSizeLabel(AppLocalizations l10n) =>
      projection.declaredGroupLimit == null
      ? null
      : l10n.discoverUpToPeople(projection.declaredGroupLimit!);
  String? durationLabel(AppLocalizations l10n) =>
      projection.durationMinutes == null
      ? null
      : l10n.discoverMinutes(projection.durationMinutes!);
  String durationUnitLabel(AppLocalizations l10n) =>
      projection.durationScope == ClassWorkshopDurationScope.wholeSeries
      ? l10n.discoverCourseDuration
      : l10n.discoverSessionDuration;
  String get teacherName => switch (projection.instructor) {
    ClassWorkshopInstructorSameAsPublisher() => projection.publisherName,
    ClassWorkshopGuestInstructor(:final name) => name,
  };
  String get teacherHandle => switch (projection.instructor) {
    ClassWorkshopInstructorSameAsPublisher() => projection.publisherHandle,
    ClassWorkshopGuestInstructor(:final handle) => handle,
  };
  String aboutText(AppLocalizations l10n) => [
    projection.fullDescription.trim().isEmpty
        ? projection.shortDescription.trim()
        : projection.fullDescription.trim(),
    if (projection.learningOutcomes.isNotEmpty)
      '${l10n.discoverLearningOutcomesLabel}\n${projection.learningOutcomes.map((s) => '• $s').join('\n')}', // l10n-ignore: developer error or list formatting, not copy
  ].where((s) => s.isNotEmpty).join('\n\n');
  List<String> get includedMaterials => projection.includedMaterials;
  List<String> get requirements => projection.requirements;
  List<_ClassWorkshopScheduleItem> scheduleItems(AppLocalizations l10n) =>
      switch (projection.schedule) {
        ClassWorkshopDatesNotAnnounced() => const [],
        ClassWorkshopAnnouncedSchedule(:final occurrences) =>
          occurrences
              .map(
                (row) => _ClassWorkshopScheduleItem(
                  timeLabel: classWorkshopOccurrenceLabel(l10n, row, timezone),
                  description: row.title,
                ),
              )
              .toList(growable: false),
      };
}

/// The fixed price with the currency's own number of minor digits (JPY 0,
/// KWD 3), formatted for the reader's language.
String classWorkshopPriceLabel(
  AppLocalizations l10n,
  ClassWorkshopPriceFixed price,
) => RechargeFormats.minorUnits(
  price.amountMinor,
  price.currencyCode,
  price.minorUnitDigits,
  l10n.localeName,
);

String classWorkshopOccurrenceLabel(
  AppLocalizations l10n,
  ClassWorkshopOccurrence row,
  TimezoneRepository timezone,
) {
  final start = timezone.toLocal(row.startAtUtc, row.timezoneId);
  final end = timezone.toLocal(row.endAtUtc, row.timezoneId);
  return start.date == end.date
      ? l10n.discoverDateTimeRange(
          discoverWallDate(l10n, start),
          discoverWallTime(l10n, start),
          discoverWallTime(l10n, end),
        )
      : l10n.discoverDateTimeRange(
          discoverWallDate(l10n, start),
          discoverWallTime(l10n, start),
          '${discoverWallDate(l10n, end)} · ${discoverWallTime(l10n, end)}',
        );
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
                  context.l10n.discoverTeacher,
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
                    '${context.l10n.discoverOrganizerLabel} ${props.projection.publisherName}',
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
                              ? context.l10n.discoverProfileVerified
                              : context.l10n.discoverOrganizerVerified,
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
        title: context.l10n.discoverOnlineClass,
        text: providerLabel.trim().isEmpty
            ? context.l10n.discoverOrganizerSendsInstructions
            : providerLabel,
      ),
    ClassWorkshopHiddenLocation(:final safeAreaLabel) =>
      _PreviewLabeledTextCard(
        title: context.l10n.discoverLocationTbc,
        text: safeAreaLabel,
      ),
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
        context.l10n.discoverAvailabilityOnOrganizerSite,
      ClassWorkshopInformationOnly(:final reason) => switch (reason) {
        ClassWorkshopInformationReason.closed =>
          context.l10n.discoverEnrollmentClosed,
        ClassWorkshopInformationReason.onSite =>
          context.l10n.discoverTermsOnSite,
        ClassWorkshopInformationReason.notProvided =>
          context.l10n.discoverEnrollmentMethodUnknown,
        ClassWorkshopInformationReason.unsupportedInternal =>
          context.l10n.discoverInAppEnrollmentUnavailable,
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
                child: Text(context.l10n.discoverCheckEnrollmentOnSite),
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
      typeLabel: context.l10n.discoverBadgeClassWorkshop,
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
        if (props.levelOrFormat(context.l10n).trim().isNotEmpty) ...<Widget>[
          _PreviewEssentialLine(
            icon: Icons.bar_chart_outlined,
            label: props.levelOrFormat(context.l10n),
          ),
          const SizedBox(height: 8),
        ],
        if (props.dateAndPlaceLabel(context.l10n).trim().isNotEmpty)
          _PreviewEssentialLine(
            icon: Icons.calendar_month_outlined,
            label: props.dateAndPlaceLabel(context.l10n),
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
            context.l10n,
            projection.publicLocation.meetingMode,
          ),
        ),
      ],
    );
  }
}

String _bookableSessionMeetingModeLabel(
  AppLocalizations l10n,
  PublishedBookableSessionMeetingMode mode,
) {
  return switch (mode) {
    PublishedBookableSessionMeetingMode.inPerson => l10n.discoverInPerson,
    PublishedBookableSessionMeetingMode.online => l10n.discoverOnline,
    PublishedBookableSessionMeetingMode.hybrid => l10n.discoverHybrid,
  };
}

String _bookableSessionAboutText(
  PublishedBookableSessionDiscoveryEntity projection,
) {
  final String full = projection.fullDescription.trim();
  return full.isNotEmpty ? full : projection.shortDescription.trim();
}

String _bookableSessionPriceLabel(
  AppLocalizations l10n,
  PublishedBookableSessionDiscoveryEntity projection,
) {
  return switch (projection.priceType) {
    PublishedBookableSessionPriceType.free => l10n.discoverFree,
    PublishedBookableSessionPriceType.fixed => RechargeFormats.money(
      Money(
        minorUnits: projection.priceAmountMinor!,
        currencyCode: projection.currencyCode,
      ),
      l10n.localeName,
    ),
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
        detail = context.l10n.discoverApproximateMeetingArea;
        fallbackIcon = Icons.location_on_outlined;
      case PublishedFindPeopleOnlineLocation(:final providerLabel):
        title = context.l10n.discoverOnline;
        detail = providerLabel.trim().isEmpty
            ? context.l10n.discoverAccessDetailsNotPublished
            : providerLabel.trim();
        fallbackIcon = Icons.videocam_outlined;
      case PublishedFindPeopleHiddenLocation(:final safeAreaLabel):
        title = safeAreaLabel.trim().isEmpty
            ? context.l10n.discoverLocationNotPublished
            : safeAreaLabel.trim();
        detail = context.l10n.discoverCoordinatesNotPublic;
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
                          context.l10n.discoverShowOnMap,
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
        context.l10n.discoverNoTimeInWindow,
      BookableSessionScheduleState.stale =>
        context.l10n.discoverScheduleNeedsRefresh,
    };
    return ObjectOfferCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.discoverTimesToBook,
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
                        bookableSessionOfferLabel(
                          context.l10n,
                          offer,
                          timezoneRepository,
                        ),
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
                  context.l10n.discoverPartnerConfirmsTime,
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
        title = context.l10n.discoverOnline;
        detail = providerLabel.trim().isEmpty
            ? context.l10n.discoverLinkFromBookingService
            : providerLabel.trim();
        fallbackIcon = Icons.videocam_outlined;
      case PublishedBookableSessionHiddenLocation(:final safeAreaLabel):
        title = safeAreaLabel.trim().isEmpty
            ? context.l10n.discoverLocationNotPublished
            : safeAreaLabel.trim();
        detail = context.l10n.discoverExactAddressNotPublished;
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
                          context.l10n.discoverShowOnMap,
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
                Flexible(
                  child: Text(
                    _expanded
                        ? context.l10n.discoverShowLess
                        : context.l10n.discoverReadMore,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: widget.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
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
                        context.l10n.discoverShowOnMap,
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
            context.l10n.discoverSchedule,
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
