import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/telemetry/analytics_service.dart';
import '../../features/discover/domain/entities/bookable_session_schedule_evaluation.dart';
import '../../features/discover/domain/entities/published_bookable_session_discovery_entity.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';
import '../../features/discover/domain/usecases/evaluate_bookable_session_schedule_usecase.dart';
import '../../features/discover/presentation/renderers/object_offer_details_renderer.dart';
import '../../features/discover/presentation/shell/details_shell.dart';
import '../../shared/models/catalog_object_ref.dart';
import '../router/route_names.dart';

typedef BookableSessionDetailsClock = DateTime Function();
typedef BookableSessionExternalLauncher = Future<bool> Function(Uri uri);

/// Reader-facing coordinator for one already-resolved public Bookable Session
/// projection (`DTL-SES-01`). Booking remains an exact external handoff; Save
/// and in-app slot selection are intentionally absent.
class BookableSessionDetailsPage extends StatefulWidget {
  const BookableSessionDetailsPage({
    super.key,
    required this.projection,
    required this.analyticsService,
    required this.timezoneRepository,
    this.evaluateSchedule = const EvaluateBookableSessionScheduleUseCase(),
    this.clock = _utcNow,
    this.externalLauncher = _launchExternal,
  });

  final PublishedBookableSessionDiscoveryEntity projection;
  final AnalyticsService analyticsService;
  final TimezoneRepository timezoneRepository;
  final EvaluateBookableSessionScheduleUseCase evaluateSchedule;
  final BookableSessionDetailsClock clock;
  final BookableSessionExternalLauncher externalLauncher;

  @override
  State<BookableSessionDetailsPage> createState() =>
      _BookableSessionDetailsPageState();
}

class _BookableSessionDetailsPageState extends State<BookableSessionDetailsPage>
    with WidgetsBindingObserver {
  bool _viewTracked = false;
  Timer? _scheduleTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextRefresh();
  }

  @override
  void didUpdateWidget(covariant BookableSessionDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projection.sessionId != widget.projection.sessionId) {
      _viewTracked = false;
    }
    _scheduleNextRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSchedule();
    } else {
      _scheduleTimer?.cancel();
    }
  }

  void _refreshSchedule() {
    if (!mounted) return;
    setState(() {});
    _scheduleNextRefresh();
  }

  void _scheduleNextRefresh() {
    _scheduleTimer?.cancel();
    final DateTime now = widget.clock().toUtc();
    final PublishedBookableSessionScheduleSnapshot snapshot =
        widget.projection.schedule;
    if (!now.isBefore(snapshot.validUntilUtc)) return;
    DateTime next = snapshot.validUntilUtc;
    for (final DateTime boundary in <DateTime>[
      snapshot.generatedAtUtc,
      ...snapshot.offers.map((offer) => offer.startAtUtc),
    ]) {
      if (boundary.isAfter(now) && boundary.isBefore(next)) next = boundary;
    }
    _scheduleTimer = Timer(next.difference(now), _refreshSchedule);
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PublishedBookableSessionDiscoveryEntity projection =
        widget.projection;
    final BookableSessionScheduleEvaluation evaluation = widget
        .evaluateSchedule(
          snapshot: projection.schedule,
          nowUtc: widget.clock().toUtc(),
        );
    _trackViewOnce(projection, evaluation);
    final PublishedBookableSessionPublicLocation location =
        projection.publicLocation;

    return DetailsShell(
      state: DetailsScreenAvailable(
        immersiveHero: true,
        renderer: ObjectOfferDetailsRenderer.bookableSession(
          projection: projection,
          scheduleEvaluation: evaluation,
          timezoneRepository: widget.timezoneRepository,
          onShareTap: () => unawaited(_onShareTap(projection)),
          onMap: location is PublishedBookableSessionPointLocation
              ? () => _onMap(projection, location)
              : null,
          onPrimaryAction: () => _onExternalBooking(projection),
        ),
      ),
    );
  }

  void _trackViewOnce(
    PublishedBookableSessionDiscoveryEntity projection,
    BookableSessionScheduleEvaluation evaluation,
  ) {
    if (_viewTracked) return;
    _viewTracked = true;
    widget.analyticsService.track(
      'discover_details_viewed',
      params: <String, Object?>{
        'item_id': projection.sessionId,
        'object_type': 'session',
        'category': projection.category,
        'schedule_state': evaluation.state.name,
      },
    );
  }

  Future<void> _onShareTap(
    PublishedBookableSessionDiscoveryEntity projection,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: 'recharge:/${_canonicalRoute(projection)}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  void _onMap(
    PublishedBookableSessionDiscoveryEntity projection,
    PublishedBookableSessionPointLocation location,
  ) {
    context.push(
      Uri(
        path: RouteNames.discoverMap,
        queryParameters: <String, String>{
          'q': projection.title,
          'category': projection.category,
          'free': projection.priceType == PublishedBookableSessionPriceType.free
              ? '1'
              : '0',
          'radius': '5000',
          'unlimited': '0',
          'itemId': projection.sessionId,
          'itemLat': location.latitude.toStringAsFixed(6),
          'itemLng': location.longitude.toStringAsFixed(6),
          'source': 'bookable_session_details',
        },
      ).toString(),
    );
  }

  Future<void> _onExternalBooking(
    PublishedBookableSessionDiscoveryEntity projection,
  ) async {
    final BookableSessionScheduleEvaluation evaluation = widget
        .evaluateSchedule(
          snapshot: projection.schedule,
          nowUtc: widget.clock().toUtc(),
        );
    widget.analyticsService.track(
      'discover_details_external_cta_tapped',
      params: <String, Object?>{
        'item_id': projection.sessionId,
        'object_type': 'session',
        'schedule_state': evaluation.state.name,
      },
    );
    bool launched = false;
    try {
      launched = await widget.externalLauncher(projection.externalBookingUri);
    } on PlatformException {
      // Platform failures use the same honest feedback as a rejected launch.
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть сайт бронирования')),
      );
    }
  }

  String _canonicalRoute(PublishedBookableSessionDiscoveryEntity projection) {
    return RouteNames.discoverDetailsCanonicalFor(
      CatalogObjectRef(
        objectType: CatalogObjectType.session,
        objectId: projection.sessionId,
      ),
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();

Future<bool> _launchExternal(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
