enum BookingCountingRule { onePerBookingOrActiveHold }

class BookingPolicy {
  const BookingPolicy({
    required this.schemaVersion,
    required this.policyVersion,
    required this.maxConcurrentFiniteAllocations,
    required this.countingRule,
    required this.unlimitedBookingCounts,
  });

  static const BookingPolicy v1 = BookingPolicy(
    schemaVersion: 1,
    policyVersion: 1,
    maxConcurrentFiniteAllocations: 5,
    countingRule: BookingCountingRule.onePerBookingOrActiveHold,
    unlimitedBookingCounts: false,
  );

  final int schemaVersion;
  final int policyVersion;
  final int maxConcurrentFiniteAllocations;
  final BookingCountingRule countingRule;
  final bool unlimitedBookingCounts;
}
