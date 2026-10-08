/// Last line of defence for the Booking test entry. The gateway calls
/// [assertAllowed] before every read or command, so hiding a button or a route
/// is never the only protection.
abstract interface class BookingCommandGate {
  bool get allowed;

  /// Throws [StateError] unless the test entry is fully enabled.
  void assertAllowed();
}

/// Default gate: nothing is allowed.
final class DeniedBookingCommandGate implements BookingCommandGate {
  const DeniedBookingCommandGate();

  @override
  bool get allowed => false;

  @override
  void assertAllowed() => throw StateError('Booking test entry is not enabled');
}
