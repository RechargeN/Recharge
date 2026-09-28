import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/telemetry/analytics_service.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/application/controllers/auth_controller.dart';
import '../../features/auth/presentation/widgets/auth_gate_sheet.dart';
import '../../features/discover/domain/entities/published_event_discovery_entity.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';
import '../../features/discover/presentation/renderers/object_offer_details_renderer.dart';
import '../../features/discover/presentation/shell/details_shell.dart';
import '../../features/favorites/application/controllers/favorites_controller.dart';
import '../../features/favorites/application/favorites_providers.dart';
import '../../features/favorites/domain/entities/favorite_item_entity.dart';
import '../../shared/models/catalog_object_ref.dart';
import '../di/service_locator.dart';
import '../router/route_names.dart';
import 'scenario_object_intake_sheet.dart';

/// Reader-facing Details for one published Event
/// (`docs/product/DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §3/§4), on the
/// same footing as `RentalDetailsPage`/`CollectionDetailsPage` — takes the
/// already-resolved [projection] directly, not a bare id (the canonical
/// route already loaded it once via `EventDetailsLookup`).
///
/// This is the **Event interaction coordinator** §4 designs: exactly five
/// actions (Save/Unsave, Share, Add to Scenario, Open map, analytics) plus
/// the honest primary CTA (§0.7) — deliberately not a copy of
/// `DiscoverDetailsPage`'s much larger side-effect surface, and
/// deliberately not reviving `DetailsActionHub`'s removed
/// Find-similar/Create-similar/Mark-as-visited tiles (§4.2).
///
/// Lives in `app/presentation/`, not `features/discover/presentation/
/// pages/` where `RentalDetailsPage`/`CollectionDetailsPage` sit: this
/// page imports `features/auth/`, `features/favorites/` and
/// `app/di/`/`app/presentation/scenario_object_intake_sheet.dart` for its
/// five kept actions, which the boundary gate
/// (`tools/scripts/check_boundaries.dart`) correctly flags as
/// `cross_feature_import`/`feature_to_app_di_or_app_presentation` from
/// inside a feature — Rental/Collection never needed this wiring, so they
/// never hit it. `app/presentation/scenario_object_intake_sheet.dart` is
/// the exact same "spans more than one feature" reasoning already applied
/// there; the exception budget is already full (71/71,
/// `tools/scripts/boundary-exceptions.json`), so relocating — not adding
/// a new suppression — is this repo's established resolution (see
/// `CLG-CRT-01`'s own provider relocation for the identical reason).
class EventDetailsPage extends ConsumerStatefulWidget {
  const EventDetailsPage({super.key, required this.projection});

  final PublishedEventDiscoveryEntity projection;

  @override
  ConsumerState<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends ConsumerState<EventDetailsPage> {
  late final AnalyticsService _analyticsService;
  late final TimezoneRepository _timezoneRepository;
  bool _viewTracked = false;

  @override
  void initState() {
    super.initState();
    _analyticsService = sl<AnalyticsService>();
    _timezoneRepository = sl<TimezoneRepository>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesControllerProvider).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final PublishedEventDiscoveryEntity projection = widget.projection;
    _trackViewOnce(projection);

    final AuthController authController = ref.watch(authControllerProvider);
    final bool isAuthenticated = authController.state.isAuthenticated;
    final FavoritesController favoritesController = ref.watch(
      favoritesControllerProvider,
    );
    final bool isFavorite = favoritesController.isFavorite(projection.eventId);

    return DetailsShell(
      state: DetailsScreenAvailable(
        immersiveHero: true,
        renderer: ObjectOfferDetailsRenderer.event(
          projection: projection,
          timezoneRepository: _timezoneRepository,
          isFavorite: isFavorite,
          onFavoriteTap: () => _onFavoriteTap(
            projection: projection,
            isAuthenticated: isAuthenticated,
            authController: authController,
            favoritesController: favoritesController,
          ),
          onShareTap: () => _onShareTap(projection),
          onMap: () => _onMap(projection),
          onAddToScenario: () => _onAddToScenario(projection),
          onOrganizerTap:
              projection.publisherType == 'page' &&
                  projection.publisherId.trim().isNotEmpty
              ? () => _onOrganizerTap(projection)
              : null,
          onAddToCalendar: projection.hasActionableDisplayOccurrence
              ? () => _onAddToCalendar(projection)
              : null,
          onPrimaryAction: () => _onPrimaryAction(projection),
        ),
      ),
    );
  }

  void _trackViewOnce(PublishedEventDiscoveryEntity projection) {
    if (_viewTracked) return;
    _viewTracked = true;
    _analyticsService.track(
      'discover_details_viewed',
      params: <String, Object?>{
        'item_id': projection.eventId,
        'category': projection.category,
        'city': projection.city,
      },
    );
  }

  Future<void> _onFavoriteTap({
    required PublishedEventDiscoveryEntity projection,
    required bool isAuthenticated,
    required AuthController authController,
    required FavoritesController favoritesController,
  }) async {
    if (!isAuthenticated) {
      authController.trackAuthGateViewed(
        sourceScreen: 'event_details',
        sourceAction: 'favorite_tap',
      );
      await showAuthGateSheet(
        context,
        action: ProtectedAction.favorite,
        sourceScreen: 'event_details',
        sourceAction: 'favorite_tap',
        originRoute: _canonicalRoute(projection),
        onContinueAsGuest: () {
          authController.trackGuestContinueClicked(
            sourceScreen: 'event_details',
            sourceAction: 'favorite_tap',
          );
        },
      );
      return;
    }
    await favoritesController.toggleFavorite(
      _toFavorite(projection),
      sourceScreen: 'event_details',
    );
  }

  Future<void> _onShareTap(PublishedEventDiscoveryEntity projection) async {
    await Clipboard.setData(
      ClipboardData(text: 'recharge:/${_canonicalRoute(projection)}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  void _onMap(PublishedEventDiscoveryEntity projection) {
    context.push(
      Uri(
        path: RouteNames.discoverMap,
        queryParameters: <String, String>{
          'q': projection.title,
          'category': projection.category,
          'free': projection.isFree ? '1' : '0',
          'radius': '5000',
          'unlimited': '0',
          'itemId': projection.eventId,
          'itemLat': projection.latitude.toStringAsFixed(6),
          'itemLng': projection.longitude.toStringAsFixed(6),
          'source': 'event_details',
        },
      ).toString(),
    );
  }

  void _onOrganizerTap(PublishedEventDiscoveryEntity projection) {
    context.push(
      RouteNames.publicProfessionalPageForId(projection.publisherId),
    );
  }

  Future<void> _onAddToCalendar(
    PublishedEventDiscoveryEntity projection,
  ) async {
    final occurrence = projection.displayOccurrence;
    if (occurrence == null || !projection.hasActionableDisplayOccurrence) {
      return;
    }
    final String fileName =
        '${projection.eventId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.ics';
    final String calendar = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Recharge//Event Details//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:${_icalEscape(projection.eventId)}-${_icalEscape(occurrence.id)}@recharge.local',
      'DTSTAMP:${_icalUtc(DateTime.now().toUtc())}',
      'DTSTART:${_icalUtc(occurrence.startAtUtc)}',
      'DTEND:${_icalUtc(occurrence.endAtUtc)}',
      'SUMMARY:${_icalEscape(projection.title)}',
      if (projection.fullDescription.trim().isNotEmpty)
        'DESCRIPTION:${_icalEscape(projection.fullDescription)}',
      if (eventVenueLabel(projection).isNotEmpty)
        'LOCATION:${_icalEscape(eventVenueLabel(projection))}',
      'END:VEVENT',
      'END:VCALENDAR',
      '',
    ].join('\r\n');

    _analyticsService.track(
      'discover_details_calendar_exported',
      params: <String, Object?>{'item_id': projection.eventId},
    );
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    final ShareResult result = await Share.shareXFiles(
      <XFile>[
        XFile.fromData(
          Uint8List.fromList(utf8.encode(calendar)),
          mimeType: 'text/calendar',
          name: fileName,
        ),
      ],
      subject: projection.title,
      fileNameOverrides: <String>[fileName],
      sharePositionOrigin: origin,
    );
    if (!mounted || result.status != ShareResultStatus.unavailable) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Не удалось открыть экспорт календаря')),
    );
  }

  Future<void> _onAddToScenario(
    PublishedEventDiscoveryEntity projection,
  ) async {
    if (!isScenarioObjectIntakeSurfaceEnabled(
      ref,
      ScenarioObjectIntakeSurface.details,
    )) {
      return;
    }
    final ScenarioObjectIntakeSheetResult? result =
        await launchScenarioObjectIntakeForEvent(
          context: context,
          ref: ref,
          event: projection,
          sourceScreen: 'event_details',
          sourceAction: 'add_to_scenario',
          originRoute: _canonicalRoute(projection),
        );
    if (result == null || !mounted) return;
    if (result.openScenario) {
      final Uri uri = Uri(
        path: '${RouteNames.createObject}/scenario',
        queryParameters: <String, String>{
          'scenarioDraftId': result.targetDraftId,
        },
      );
      await context.push(uri.toString());
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${result.itemCount} item to Scenario')),
    );
  }

  /// §0.7/EVT-D-AC-14: `isFree` → internal Join-acknowledgement (no
  /// payment/booking is implied — only that a request was sent, the same
  /// honest shape as today's generic `_onCtaTap`); priced → real external
  /// redirect via `url_launcher`, same mechanism as
  /// `rental_details_page.dart`. The sticky CTA is only ever visible when
  /// one of these two paths applies (`ObjectOfferDetailsRenderer.
  /// buildStickyAction`) — this method is never reached for a priced
  /// Event with no `externalBookingUrl`.
  Future<void> _onPrimaryAction(
    PublishedEventDiscoveryEntity projection,
  ) async {
    if (!projection.hasActionableDisplayOccurrence) return;
    _analyticsService.track(
      'discover_details_cta_clicked',
      params: <String, Object?>{
        'item_id': projection.eventId,
        'category': projection.category,
        'price_amount': projection.priceAmount,
      },
    );
    if (projection.isFree) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Интерес к событию отмечен')),
      );
      return;
    }
    final Uri? parsed = eventExternalBookingUri(projection.externalBookingUrl);
    if (parsed == null) return;
    final bool launched = await launchUrl(
      parsed,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open ${parsed.host}.')));
    }
  }

  static String _icalUtc(DateTime value) {
    final DateTime utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}'
        '${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static String _icalEscape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n');

  String _canonicalRoute(PublishedEventDiscoveryEntity projection) {
    return RouteNames.discoverDetailsCanonicalFor(
      CatalogObjectRef(
        objectType: CatalogObjectType.event,
        objectId: projection.eventId,
      ),
    );
  }

  FavoriteItemEntity _toFavorite(PublishedEventDiscoveryEntity projection) {
    // `startsAtUtc` has no direct field on this projection — the
    // occurrence model replaced the flat pair (§2.2) — so it is resolved
    // from the already-picked display occurrence, not read as a literal.
    final DateTime startsAtUtc =
        projection.displayOccurrence?.startAtUtc ?? projection.publishedAtUtc;
    return FavoriteItemEntity(
      id: projection.eventId,
      title: projection.title,
      subtitle: projection.subtitle,
      city: projection.city,
      category: projection.category,
      startsAtUtc: startsAtUtc,
      distanceKm: projection.distanceKm,
      priceAmount: projection.priceAmount,
      isFree: projection.isFree,
      savedAtUtc: DateTime.now().toUtc(),
      targetRoute: null,
      coverImageUrl: projection.coverImageUrl,
    );
  }
}
