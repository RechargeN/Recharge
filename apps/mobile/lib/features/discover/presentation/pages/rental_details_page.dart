import 'package:flutter/material.dart';

import '../../domain/entities/published_rental_discovery_entity.dart';
import '../renderers/object_offer_details_renderer.dart';
import '../shell/details_shell.dart';

/// Reader-facing Details for one published Rental listing (`DTL-OBJ-01`
/// §4). A dedicated page rather than a branch inside the large generic
/// `DiscoverDetailsPage` — mirrors `CollectionDetailsPage`'s own reasoning
/// (Collection has no single coordinate/CTA shape to fit that page's
/// point-object layout; Rental's data shape,
/// `PublishedRentalDiscoveryEntity`, is unrelated to `DiscoverItemEntity`
/// too).
///
/// Takes the already-resolved [projection] directly, not a bare id — the
/// canonical route (`app/router/app_router.dart`'s `_ResolvedDetailsRoute`)
/// already loaded it once via `RentalDetailsLookup` to verify the object
/// exists; a second fetch here would be redundant.
class RentalDetailsPage extends StatelessWidget {
  const RentalDetailsPage({super.key, required this.projection});

  final PublishedRentalDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    void onExternalCtaTap() {
      final String? url = projection.externalBookingUrl;
      if (url == null || url.isEmpty) return;
      // No url_launcher dependency exists anywhere in this codebase yet
      // (verified — Discover has no established "open external URL"
      // pattern today); rather than add one silently for this slice, the
      // destination host is surfaced with the same off-platform warning
      // spec §12 requires, without an actual navigation launch. Adding
      // real external navigation is a disclosed follow-up, not part of
      // DTL-OBJ-01.
      final String host = Uri.tryParse(url)?.host ?? url;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Continues on $host — outside Recharge.')),
      );
    }

    return DetailsShell(
      state: DetailsScreenAvailable(
        renderer: ObjectOfferDetailsRenderer.rental(
          projection: projection,
          onExternalCtaTap: onExternalCtaTap,
        ),
      ),
    );
  }
}
