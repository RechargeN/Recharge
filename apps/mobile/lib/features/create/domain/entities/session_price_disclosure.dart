enum SessionPricingMode { free, fixed }

class SessionMoneyDraft {
  const SessionMoneyDraft({
    required this.amountMinor,
    required this.currencyCode,
  });

  final int amountMinor;
  final String currencyCode;

  bool get isValid => amountMinor > 0 && currencyCode.trim().isNotEmpty;

  SessionMoneyDraft copyWith({int? amountMinor, String? currencyCode}) =>
      SessionMoneyDraft(
        amountMinor: amountMinor ?? this.amountMinor,
        currencyCode: currencyCode ?? this.currencyCode,
      );

  @override
  bool operator ==(Object other) =>
      other is SessionMoneyDraft &&
      amountMinor == other.amountMinor &&
      currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(amountMinor, currencyCode);
}

class SessionPriceDisclosure {
  const SessionPriceDisclosure({required this.mode, this.amount});

  final SessionPricingMode mode;
  final SessionMoneyDraft? amount;

  bool get isValid => switch (mode) {
    SessionPricingMode.free => true,
    SessionPricingMode.fixed => amount != null && amount!.isValid,
  };

  SessionPriceDisclosure copyWith({
    SessionPricingMode? mode,
    SessionMoneyDraft? amount,
    bool clearAmount = false,
  }) => SessionPriceDisclosure(
    mode: mode ?? this.mode,
    amount: clearAmount ? null : (amount ?? this.amount),
  );

  static const SessionPriceDisclosure free = SessionPriceDisclosure(
    mode: SessionPricingMode.free,
  );
}
