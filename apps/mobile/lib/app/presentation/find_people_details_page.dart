import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/telemetry/analytics_service.dart';
import '../../features/discover/domain/entities/published_find_people_discovery_entity.dart';
import '../../features/discover/domain/repositories/timezone_repository.dart';
import '../../features/discover/presentation/renderers/object_offer_details_renderer.dart';
import '../../features/discover/presentation/shell/details_shell.dart';
import '../../shared/models/catalog_object_ref.dart';
import '../router/route_names.dart';

/// Reader-facing coordinator for one already-resolved public Find People
/// projection (`DTL-FP-01`). Save and Join are intentionally absent until
/// their own compatible contracts exist; Share and public-point Map are real.
class FindPeopleDetailsPage extends StatefulWidget {
  const FindPeopleDetailsPage({
    super.key,
    required this.projection,
    required this.analyticsService,
    required this.timezoneRepository,
  });

  final PublishedFindPeopleDiscoveryEntity projection;
  final AnalyticsService analyticsService;
  final TimezoneRepository timezoneRepository;

  @override
  State<FindPeopleDetailsPage> createState() => _FindPeopleDetailsPageState();
}

class _FindPeopleDetailsPageState extends State<FindPeopleDetailsPage> {
  bool _viewTracked = false;

  @override
  Widget build(BuildContext context) {
    final PublishedFindPeopleDiscoveryEntity projection = widget.projection;
    _trackViewOnce(projection);
    final PublishedFindPeoplePublicLocation location =
        projection.publicLocation;

    return DetailsShell(
      state: DetailsScreenAvailable(
        immersiveHero: true,
        renderer: ObjectOfferDetailsRenderer.findPeople(
          projection: projection,
          timezoneRepository: widget.timezoneRepository,
          onShareTap: () => unawaited(_onShareTap(projection)),
          onMap: location is PublishedFindPeoplePointLocation
              ? () => _onMap(projection, location)
              : null,
        ),
      ),
    );
  }

  void _trackViewOnce(PublishedFindPeopleDiscoveryEntity projection) {
    if (_viewTracked) return;
    _viewTracked = true;
    widget.analyticsService.track(
      'discover_details_viewed',
      params: <String, Object?>{
        'item_id': projection.requestId,
        'object_type': 'find_people',
        'category': projection.category,
      },
    );
  }

  Future<void> _onShareTap(
    PublishedFindPeopleDiscoveryEntity projection,
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
    PublishedFindPeopleDiscoveryEntity projection,
    PublishedFindPeoplePointLocation location,
  ) {
    context.push(
      Uri(
        path: RouteNames.discoverMap,
        queryParameters: <String, String>{
          'q': projection.title,
          'category': projection.category,
          'free': projection.costType == PublishedFindPeopleCostType.free
              ? '1'
              : '0',
          'radius': '5000',
          'unlimited': '0',
          'itemId': projection.requestId,
          'itemLat': location.latitude.toStringAsFixed(6),
          'itemLng': location.longitude.toStringAsFixed(6),
          'source': 'find_people_details',
        },
      ).toString(),
    );
  }

  String _canonicalRoute(PublishedFindPeopleDiscoveryEntity projection) {
    return RouteNames.discoverDetailsCanonicalFor(
      CatalogObjectRef(
        objectType: CatalogObjectType.findPeople,
        objectId: projection.requestId,
      ),
    );
  }
}
