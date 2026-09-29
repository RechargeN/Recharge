import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
/// canonical route (`app/router/app_router.dart`'s `ResolvedDetailsRoute`)
/// already loaded it once via `RentalDetailsLookup` to verify the object
/// exists; a second fetch here would be redundant.
class RentalDetailsPage extends StatelessWidget {
  const RentalDetailsPage({super.key, required this.projection});

  final PublishedRentalDiscoveryEntity projection;

  @override
  Widget build(BuildContext context) {
    Future<void> onExternalCtaTap() async {
      final String? url = projection.externalBookingUrl;
      if (url == null || url.isEmpty) return;
      // Canonical RENTAL_EQUIPMENT_CREATE_BLOCK_SPEC.md §12: "CTA: `Check
      // availability on provider site`" is a real off-platform redirect,
      // not a no-op — every product Viewer is already authenticated
      // (§17.5: "Все product users уже authenticated; Guest-row в
      // матрице нет"), and the sibling generic-Details CTA
      // (`discover_details_page.dart`'s `_onCtaTap`) does not auth-gate
      // either, so no auth check is added here to stay consistent with
      // that established convention.
      final Uri? parsed = Uri.tryParse(url);
      if (parsed == null) return;
      final bool launched = await launchUrl(
        parsed,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${parsed.host}.')),
        );
      }
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
