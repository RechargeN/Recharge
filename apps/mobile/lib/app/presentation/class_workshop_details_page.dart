import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/telemetry/analytics_service.dart';
import '../../features/discover/domain/entities/published_class_workshop_discovery_entity.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';
import '../../features/discover/presentation/renderers/object_offer_details_renderer.dart';
import '../../features/discover/presentation/shell/details_shell.dart';
import '../../shared/models/catalog_object_ref.dart';
import '../router/route_names.dart';

typedef ClassWorkshopExternalLauncher = Future<bool> Function(Uri uri);

class ClassWorkshopDetailsPage extends StatefulWidget {
  const ClassWorkshopDetailsPage({
    super.key,
    required this.projection,
    required this.analyticsService,
    required this.timezoneRepository,
    this.externalLauncher = _launchExternal,
  });
  final PublishedClassWorkshopDiscoveryEntity projection;
  final AnalyticsService analyticsService;
  final TimezoneRepository timezoneRepository;
  final ClassWorkshopExternalLauncher externalLauncher;
  @override
  State<ClassWorkshopDetailsPage> createState() =>
      _ClassWorkshopDetailsPageState();
}

class _ClassWorkshopDetailsPageState extends State<ClassWorkshopDetailsPage> {
  @override
  void initState() {
    super.initState();
    _track('discover_details_viewed');
  }

  @override
  void didUpdateWidget(covariant ClassWorkshopDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projection.offeringId != widget.projection.offeringId) {
      _track('discover_details_viewed');
    }
  }

  void _track(String event) {
    widget.analyticsService.track(
      event,
      params: {
        'item_id': widget.projection.offeringId,
        'object_type': 'class_workshop',
        'category': widget.projection.category,
        'enrollment_state': switch (widget.projection.enrollment) {
          ClassWorkshopExternalEnrollment() => 'external',
          ClassWorkshopInformationOnly(:final reason) => reason.name,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final projection = widget.projection;
    final location = projection.publicLocation;
    final enrollment = projection.enrollment;
    return DetailsShell(
      state: DetailsScreenAvailable(
        immersiveHero: true,
        renderer: ObjectOfferDetailsRenderer.classWorkshop(
          projection: projection,
          timezoneRepository: widget.timezoneRepository,
          onShareTap: () => unawaited(_share()),
          onMap: location is ClassWorkshopPointLocation
              ? () => _map(location)
              : null,
          onPrimaryAction: enrollment is ClassWorkshopExternalEnrollment
              ? () => _external(enrollment.uri)
              : null,
        ),
      ),
    );
  }

  Future<void> _share() async {
    final route = RouteNames.discoverDetailsCanonicalFor(
      CatalogObjectRef(
        objectType: CatalogObjectType.classWorkshop,
        objectId: widget.projection.offeringId,
      ),
    );
    await Clipboard.setData(ClipboardData(text: 'recharge:/$route'));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  void _map(ClassWorkshopPointLocation location) {
    context.push(
      Uri(
        path: RouteNames.discoverMap,
        queryParameters: {
          'q': widget.projection.title,
          'category': widget.projection.category,
          'free': widget.projection.price is ClassWorkshopPriceFree ? '1' : '0',
          'radius': '5000',
          'unlimited': '0',
          'itemId': widget.projection.offeringId,
          'itemLat': location.latitude.toStringAsFixed(6),
          'itemLng': location.longitude.toStringAsFixed(6),
          'source': 'class_workshop_details',
        },
      ).toString(),
    );
  }

  Future<void> _external(Uri uri) async {
    _track('discover_details_external_cta_tapped');
    bool launched = false;
    try {
      launched = await widget.externalLauncher(uri);
    } on PlatformException {
      /* Honest failure below. */
    }
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть сайт записи')),
      );
    }
  }
}

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
