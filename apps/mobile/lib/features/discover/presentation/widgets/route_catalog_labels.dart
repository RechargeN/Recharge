import '../../../../core/localization/l10n_context.dart';
import '../../domain/entities/route_catalog_facts.dart';
import '../discover_formats.dart';

/// DTL-RTE-02 RD-12: kilometres with one decimal.
String routeCatalogDistanceLabel(
  AppLocalizations l10n,
  RouteCatalogFacts facts,
) => discoverKm(l10n, facts.distanceMeters / 1000);

/// RD-12: whole metres; `null` when the snapshot has no elevation — never 0.
String? routeCatalogAscentLabel(
  AppLocalizations l10n,
  RouteCatalogFacts facts,
) {
  final double? ascent = facts.ascentMeters;
  return ascent == null ? null : l10n.discoverAscentShort('${ascent.round()}');
}

/// RD-04 card/Map line: distance, ascent when known, direct segments when any.
String routeCatalogMetricLabel(
  AppLocalizations l10n,
  RouteCatalogFacts facts,
) => <String>[
  routeCatalogDistanceLabel(l10n, facts),
  ?routeCatalogAscentLabel(l10n, facts),
  if (facts.directSegmentCount > 0)
    l10n.discoverDirectSegmentsInline(facts.directSegmentCount),
].join(' · ');

/// RD-11: only the publisher kind; the Catalog has no public name.
String routeCatalogPublisherLabel(
  AppLocalizations l10n,
  RouteCatalogFacts facts,
) => switch (facts.publisherKind) {
  RouteCatalogPublisherKind.personal => l10n.discoverPublisherAuthor,
  RouteCatalogPublisherKind.page => l10n.discoverPublisherPage,
};

String routeCatalogShapeLabel(AppLocalizations l10n, String shape) =>
    switch (shape) {
      'loop' => l10n.discoverShapeLoop,
      'outAndBack' => l10n.discoverShapeOutAndBack,
      'oneWay' => l10n.discoverShapeOneWay,
      // An unknown shape id is never shown raw.
      _ => l10n.discoverRouteLabel,
    };
