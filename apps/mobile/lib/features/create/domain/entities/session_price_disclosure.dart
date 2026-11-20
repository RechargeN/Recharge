import 'package:recharge/shared/primitives/money/money.dart';

enum SessionPricingMode { free, fixed }

class SessionPriceDisclosure {
  const SessionPriceDisclosure({required this.mode, this.amount});

  final SessionPricingMode mode;
  final Money? amount;

  bool get isValid => switch (mode) {
    SessionPricingMode.free => true,
    SessionPricingMode.fixed => amount != null && amount!.minorUnits > 0,
  };

  SessionPriceDisclosure copyWith({
    SessionPricingMode? mode,
    Money? amount,
    bool clearAmount = false,
  }) => SessionPriceDisclosure(
    mode: mode ?? this.mode,
    amount: clearAmount ? null : (amount ?? this.amount),
  );

  static const SessionPriceDisclosure free = SessionPriceDisclosure(
    mode: SessionPricingMode.free,
  );
}
