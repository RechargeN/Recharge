/// Shared small "why is this degraded/unavailable" message type for Rental
/// sections — mirrors the role of Event's `EventAccessCapabilityDisclosure`
/// without importing an Event-specific type into Rental (one parallel
/// implementation per type, per repository convention).
enum RentalDisclosureCode {
  categoryPolicyUnknown,
  categoryUnsupported,
  marketPolicyUnsupported,
  featureDisabled,
}

class RentalSectionDisclosure {
  const RentalSectionDisclosure({
    required this.code,
    required this.message,
    this.blocking = false,
  });

  final RentalDisclosureCode code;
  final String message;
  final bool blocking;
}
