import '../../domain/entities/route_catalog_facts.dart';

/// DTL-RTE-02 RD-12: kilometres with one decimal.
String routeCatalogDistanceLabel(RouteCatalogFacts facts) =>
    '${(facts.distanceMeters / 1000).toStringAsFixed(1)} км';

/// RD-12: whole metres; `null` when the snapshot has no elevation — never 0.
String? routeCatalogAscentLabel(RouteCatalogFacts facts) {
  final double? ascent = facts.ascentMeters;
  return ascent == null ? null : '↑ ${ascent.round()} м';
}

/// RD-04 card/Map line: distance, ascent when known, direct segments when any.
String routeCatalogMetricLabel(RouteCatalogFacts facts) => <String>[
  routeCatalogDistanceLabel(facts),
  ?routeCatalogAscentLabel(facts),
  if (facts.directSegmentCount > 0)
    'прямых участков: ${facts.directSegmentCount}',
].join(' · ');

/// RD-11: only the publisher kind; the Catalog has no public name.
String routeCatalogPublisherLabel(RouteCatalogFacts facts) =>
    switch (facts.publisherKind) {
      RouteCatalogPublisherKind.personal => 'Автор',
      RouteCatalogPublisherKind.page => 'Страница',
    };

String routeCatalogShapeLabel(String shape) => switch (shape) {
  'loop' => 'Кольцевой',
  'outAndBack' => 'Туда и обратно',
  'oneWay' => 'В одну сторону',
  _ => shape,
};
