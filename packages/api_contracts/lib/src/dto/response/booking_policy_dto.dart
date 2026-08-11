import '../../contracts/booking/booking_contract.dart';

class BookingPolicyDto {
  const BookingPolicyDto({
    required this.schemaVersion,
    required this.policyVersion,
    required this.maxConcurrentFiniteAllocations,
    required this.countingRule,
    required this.unlimitedBookingCounts,
  });

  factory BookingPolicyDto.fromJson(Map<String, Object?> json) {
    const keys = <String>{
      'schemaVersion',
      'policyVersion',
      'maxConcurrentFiniteAllocations',
      'countingRule',
      'unlimitedBookingCounts',
    };
    requireExactKeys(
      json,
      allowed: keys,
      required: keys,
      objectName: 'BookingPolicy',
    );
    final dto = BookingPolicyDto(
      schemaVersion: requireNonNegativeInt(
        json['schemaVersion'],
        'schemaVersion',
      ),
      policyVersion: requireNonNegativeInt(
        json['policyVersion'],
        'policyVersion',
      ),
      maxConcurrentFiniteAllocations: requirePositiveInt(
        json['maxConcurrentFiniteAllocations'],
        'maxConcurrentFiniteAllocations',
      ),
      countingRule: parseWireEnum(
        json['countingRule'],
        BookingCountingRule.values,
        field: 'countingRule',
      ),
      unlimitedBookingCounts: json['unlimitedBookingCounts'] is bool
          ? json['unlimitedBookingCounts']! as bool
          : throw const BookingContractFormatException(
              'unlimitedBookingCounts must be bool',
            ),
    );
    if (dto.schemaVersion != bookingContractSchemaVersion ||
        dto.policyVersion != bookingPolicyVersion ||
        dto.maxConcurrentFiniteAllocations !=
            bookingMaxConcurrentFiniteAllocations ||
        dto.countingRule != BookingCountingRule.onePerBookingOrActiveHold ||
        dto.unlimitedBookingCounts) {
      throw const BookingContractFormatException(
        'Unsupported Booking policy values',
      );
    }
    return dto;
  }

  final int schemaVersion;
  final int policyVersion;
  final int maxConcurrentFiniteAllocations;
  final BookingCountingRule countingRule;
  final bool unlimitedBookingCounts;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'policyVersion': policyVersion,
        'maxConcurrentFiniteAllocations': maxConcurrentFiniteAllocations,
        'countingRule': countingRule.name,
        'unlimitedBookingCounts': unlimitedBookingCounts,
      };
}
