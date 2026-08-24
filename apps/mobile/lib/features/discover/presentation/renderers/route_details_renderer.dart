import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/published_route_discovery_entity.dart';
import '../shell/compatibility_object_renderer.dart';
import '../shell/details_renderer.dart';
import '../widgets/published_route_polyline_builder.dart';
import '../widgets/route_elevation_summary.dart';

/// [DetailsRenderer] for `CatalogObjectType.route`
/// (`docs/product/DTL_RTE_01_ROUTE_DETAILS_SLICE_SPEC.md`).
///
/// Replaces the photo-hero + `_PublishedRouteCard`-bolted-onto-a-generic-
/// card treatment `CompatibilityObjectRenderer` gave Route before this
/// slice, with an interactive map-hero, an honest elevation summary
/// (never a graph — the read model has no per-point samples), and
/// difficulty/surface/POI/field-verified as their own first-class section
/// instead of pills inside someone else's card. Everything else
/// (summary, action hub, organizer, info grid, highlights, location,
/// sticky CTA) is reused unchanged from `CompatibilityObjectRenderer`'s
/// now-public widgets — this slice's scope is the Route-specific sections,
/// not a redesign of the shared ones.
class RouteDetailsRenderer implements DetailsRenderer {
  RouteDetailsRenderer({
    required this.item,
    required this.isFavorite,
    required this.ctaSubmitted,
    required this.onFavoriteTap,
    required this.onShareTap,
    required this.onMap,
    required this.onRouteMap,
    required this.onAddToScenario,
    required this.onSearch,
    required this.onCreateSimilar,
    required this.onCreateRoute,
    required this.onMarkVisited,
    required this.onCtaTap,
    required this.onReportRoute,
  }) : assert(
         item.publishedRoute != null,
         'RouteDetailsRenderer requires a DiscoverItemEntity with a '
         'populated publishedRoute — the registry that selects this '
         'renderer (discover_details_page.dart) must only do so once '
         'item.catalogObjectType == CatalogObjectType.route, which is '
         'exactly when publishedRoute is non-null.',
       );

  final DiscoverItemEntity item;
  final bool isFavorite;
  final bool ctaSubmitted;
  final VoidCallback onFavoriteTap;
  final VoidCallback onShareTap;
  final VoidCallback onMap;
  final VoidCallback onRouteMap;
  final VoidCallback? onAddToScenario;
  final VoidCallback onSearch;
  final VoidCallback onCreateSimilar;
  final VoidCallback onCreateRoute;
  final VoidCallback onMarkVisited;
  final VoidCallback onCtaTap;
  final VoidCallback onReportRoute;

  PublishedRouteDiscoveryEntity get _route => item.publishedRoute!;

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    return <Widget>[
      IconButton(
        tooltip: isFavorite ? 'Unsave' : 'Save',
        onPressed: onFavoriteTap,
        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
      ),
      IconButton(
        tooltip: 'Share',
        onPressed: onShareTap,
        icon: const Icon(Icons.ios_share_rounded),
      ),
    ];
  }

  @override
  Widget buildHero(BuildContext context) {
    return _RouteMapHero(route: _route, onOpenMap: onMap);
  }

  @override
  Widget buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The map-hero has nowhere natural to overlay a title (unlike
          // the old photo-hero's title panel) — shown here instead, same
          // place CollectionDetailsRenderer puts its own title.
          Text(
            item.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SummaryCard(item: item),
          const SizedBox(height: 12),
          RouteElevationSummary(route: _route),
          const SizedBox(height: 12),
          _RouteCompositionCard(route: _route, onReport: onReportRoute),
          const SizedBox(height: 12),
          DetailsActionHub(
            item: item,
            isFavorite: isFavorite,
            ctaSubmitted: ctaSubmitted,
            onFavoriteTap: onFavoriteTap,
            onMap: onMap,
            onRouteMap: onRouteMap,
            onAddToScenario: onAddToScenario,
            onSearch: onSearch,
            onCreateSimilar: onCreateSimilar,
            onCreateRoute: onCreateRoute,
            onMarkVisited: onMarkVisited,
            onCtaTap: onCtaTap,
          ),
          const SizedBox(height: 12),
          OrganizerCard(item: item),
          const SizedBox(height: 12),
          InfoGrid(item: item),
          const SizedBox(height: 12),
          HighlightsCard(item: item),
          const SizedBox(height: 12),
          LocationCard(item: item, onOpenMap: onMap),
        ],
      ),
    );
  }

  @override
  Widget? buildStickyAction(BuildContext context) {
    return DetailsBottomBar(
      item: item,
      isFavorite: isFavorite,
      ctaSubmitted: ctaSubmitted,
      onFavoriteTap: onFavoriteTap,
      onCtaTap: onCtaTap,
    );
  }
}

/// Interactive, read-only map hero — replaces the photo hero
/// (`published_route_polyline_builder.dart` supplies the same polyline
/// the Map page draws for this route, so the two never disagree).
/// Geometry-derived start/end pins only — never a one-way/loop/
/// out-and-back claim, since `PublishedRouteDiscoveryEntity` carries no
/// topology field to honestly support one (RTE-D-AC-05).
class _RouteMapHero extends StatelessWidget {
  const _RouteMapHero({required this.route, required this.onOpenMap});

  final PublishedRouteDiscoveryEntity route;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final Polyline? polyline = buildPublishedRoutePolyline(route);
    final LatLng start = LatLng(
      route.startPoint.latitude,
      route.startPoint.longitude,
    );
    final Set<Marker> markers = <Marker>{
      Marker(
        markerId: const MarkerId('route_start'),
        position: start,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      ),
      if (polyline != null && polyline.points.length > 1)
        Marker(
          markerId: const MarkerId('route_end'),
          position: polyline.points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.35,
          child: polyline == null
              ? const _RouteMapUnavailable()
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      (route.bounds.southwest.latitude +
                              route.bounds.northeast.latitude) /
                          2,
                      (route.bounds.southwest.longitude +
                              route.bounds.northeast.longitude) /
                          2,
                    ),
                    zoom: 13,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    controller.animateCamera(
                      CameraUpdate.newLatLngBounds(
                        LatLngBounds(
                          southwest: LatLng(
                            route.bounds.southwest.latitude,
                            route.bounds.southwest.longitude,
                          ),
                          northeast: LatLng(
                            route.bounds.northeast.latitude,
                            route.bounds.northeast.longitude,
                          ),
                        ),
                        40,
                      ),
                    );
                  },
                  polylines: <Polyline>{polyline},
                  markers: markers,
                  liteModeEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(color: RechargeTheme.travelPanel),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: OutlinedButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Открыть на карте'),
            ),
          ),
        ),
      ],
    );
  }
}

/// `temporarilyUnavailable`-style degrade for a route whose polyline
/// can't be decoded (RTE-D-AC-02) — a broken snapshot must not crash the
/// hero.
class _RouteMapUnavailable extends StatelessWidget {
  const _RouteMapUnavailable();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: RechargeTheme.travelPanel),
      child: Center(
        child: Text(
          'Не удалось загрузить карту маршрута',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// Difficulty/profile/surface/POI-count/field-verified as a first-class
/// section — moved out of `_PublishedRouteCard`'s `Wrap` (that class stays
/// only as dead code in `compatibility_object_renderer.dart`, no longer
/// reachable once `route` dispatches here). Safety reporting stays in the
/// main flow, as a button inside this card, exactly as it was before
/// (RTE-D-AC-06) — not promoted to a standalone link.
class _RouteCompositionCard extends StatelessWidget {
  const _RouteCompositionCard({required this.route, required this.onReport});

  final PublishedRouteDiscoveryEntity route;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Route details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                DetailsPill(
                  label: routeProfileLabelForDetails(route.routingProfileId),
                ),
                DetailsPill(
                  label: routeDifficultyLabelForDetails(route.difficultyId),
                ),
                if (route.recommendedDifficultyId.isNotEmpty &&
                    route.recommendedDifficultyId != route.difficultyId)
                  DetailsPill(
                    label:
                        'Recommended '
                        '${routeDifficultyLabelForDetails(route.recommendedDifficultyId)}',
                  ),
                DetailsPill(label: '${route.waypointCount} POI'),
                if (route.fieldVerifiedAtUtc != null)
                  const DetailsPill(label: 'Field verified'),
                DetailsPill(label: 'Version ${route.versionId}'),
                if (route.demoOnly) const DetailsPill(label: 'Demo data'),
              ],
            ),
            if (route.surfaceIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Surface',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: route.surfaceIds
                    .map(
                      (String surfaceId) =>
                          DetailsPill(label: _surfaceLabel(surfaceId)),
                    )
                    .toList(growable: false),
              ),
            ],
            if (route.unknownSurfaceDistanceMeters > 0) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '${route.unknownSurfaceDistanceMeters.round()} m of surface '
                'data is unknown.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (route.attributions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                route.attributions.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.report_outlined),
                label: const Text('Сообщить о проблеме на маршруте'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _surfaceLabel(String surfaceId) {
  final String normalized = surfaceId.trim().replaceAll('_', ' ');
  if (normalized.isEmpty) return surfaceId;
  return normalized[0].toUpperCase() + normalized.substring(1);
}
