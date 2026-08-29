import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/discover_item_entity.dart';
import '../../domain/entities/published_rental_discovery_entity.dart';
import '../shell/compatibility_object_renderer.dart';
import '../shell/details_renderer.dart';
import 'object_offer_section_matrix.dart';

/// [DetailsRenderer] for the three Object/Offer visual profiles
/// (`DTL-OBJ-01` §2): `venue` (Place), `participation` (Event/Activity),
/// `offer` (Rental). One class registered under
/// `DetailsRendererFamily.objectOffer`.
///
/// `venue`/`participation` deliberately delegate every build method to an
/// internally-built [CompatibilityObjectRenderer] rather than
/// reconstructing an equivalent layout from `offerProfileSections` — this
/// is what makes OBJ-AC-02 (visual/functional parity with the pre-existing
/// output) true by construction, not by careful reimplementation.
/// `offerProfileSections` genuinely drives `offer` (Rental)'s body below —
/// [buildBody] iterates it and dispatches each [ObjectOfferSection] to its
/// widget, so adding/removing/reordering an entry in the matrix changes
/// what actually renders (OBJ-AC-01/06), not just documents an intent.
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
         objectOfferProfileFor(item.catalogObjectType) !=
             ObjectOfferProfile.offer,
         'ObjectOfferDetailsRenderer.discoverItem is for the venue/'
         'participation profiles only — Rental (offer) must use .rental. '
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
       _onExternalCtaTap = null;

  ObjectOfferDetailsRenderer.rental({
    required PublishedRentalDiscoveryEntity projection,
    required Future<void> Function() onExternalCtaTap,
  }) : _delegate = null,
       _rentalProjection = projection,
       _onExternalCtaTap = onExternalCtaTap;

  final CompatibilityObjectRenderer? _delegate;
  final PublishedRentalDiscoveryEntity? _rentalProjection;
  final Future<void> Function()? _onExternalCtaTap;

  @override
  List<Widget> buildAppBarActions(BuildContext context) {
    final CompatibilityObjectRenderer? delegate = _delegate;
    if (delegate != null) return delegate.buildAppBarActions(context);
    // Rental Details has no save/share wiring yet — matches
    // CollectionDetailsPage's own current scope, not a Rental-specific gap.
    return const <Widget>[];
  }

  @override
  Widget buildHero(BuildContext context) {
    final CompatibilityObjectRenderer? delegate = _delegate;
    if (delegate != null) return delegate.buildHero(context);
    return _RentalHero(projection: _rentalProjection!);
  }

  @override
  Widget buildBody(BuildContext context) {
    final CompatibilityObjectRenderer? delegate = _delegate;
    if (delegate != null) return delegate.buildBody(context);
    final PublishedRentalDiscoveryEntity projection = _rentalProjection!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ObjectOfferSection section in offerProfileSections)
            if (_bodySectionFor(section, projection) case final Widget widget) ...<Widget>[
              widget,
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  /// `hero` and `externalCta` are handled by [buildHero]/[buildStickyAction]
  /// respectively, not the scrollable body — returns `null` for them so
  /// the loop above skips them cleanly rather than special-casing the
  /// section list itself.
  Widget? _bodySectionFor(
    ObjectOfferSection section,
    PublishedRentalDiscoveryEntity projection,
  ) {
    return switch (section) {
      ObjectOfferSection.hero => null,
      ObjectOfferSection.inventory => _RentalInventoryCard(
        projection: projection,
      ),
      ObjectOfferSection.availability => const _RentalAvailabilityNote(),
      ObjectOfferSection.pricing => _RentalPricingCard(projection: projection),
      ObjectOfferSection.pickup => _RentalPickupCard(projection: projection),
      ObjectOfferSection.duration => _RentalDurationSafetyCard(
        projection: projection,
      ),
      ObjectOfferSection.publisher => _RentalPublisherCard(
        projection: projection,
      ),
      ObjectOfferSection.externalCta => null,
    };
  }

  @override
  Widget? buildStickyAction(BuildContext context) {
    final CompatibilityObjectRenderer? delegate = _delegate;
    if (delegate != null) return delegate.buildStickyAction(context);
    return _RentalExternalCtaBar(
      projection: _rentalProjection!,
      onTap: _onExternalCtaTap!,
    );
  }
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
      child: Center(
        child: Icon(Icons.handyman, color: Colors.white, size: 72),
      ),
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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

String rentalSafetyRequirementsLabel(PublishedRentalDiscoveryEntity projection) {
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
