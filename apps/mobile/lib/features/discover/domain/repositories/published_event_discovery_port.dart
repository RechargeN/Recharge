import '../entities/published_event_discovery_entity.dart';

/// Read side of the Create→Discover boundary for Event
/// (`docs/product/discover/DTL_EVT_01_EVENT_DETAILS_SLICE_SPEC.md` §3), by the same
/// shape as `PublishedRentalDiscoveryPort`. Unlike Rental, there is no
/// write-side sink here yet — no live Create → Discover Event publish
/// pipeline exists (§0.6) — so this slice's implementation
/// (`PublishedEventDiscoveryLocalDataSource`) is mock-first, not a
/// boundary-compliant `app/adapters/` adapter. A later slice that builds
/// the real pipeline adds the write side without changing this read
/// contract.
///
/// Deliberately no `loadActiveEvents()`-style listing method: this slice
/// is Details-only (`DTL-EVT-01` §1.2) — Discover's feed/search for Event
/// stays on the legacy `DiscoverItemEntity` mock path, so a listing method
/// here would be unused surface (the same is already true of Rental's own
/// `loadActiveRentals()`, which today has zero callers).
abstract interface class PublishedEventDiscoveryPort {
  Future<PublishedEventDiscoveryEntity?> getActiveEvent(String eventId);
}
