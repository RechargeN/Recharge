/// ADR 0023, owner decision 2026-11-08 (marketplace rule, DSA Art. 30): before
/// paid or bookable content goes live its author declares whether they act as
/// a private person or a trader. The server owns the record; this is its view.
enum SellerStatus { private, trader }

enum Dac7ActivityType { personalServices, rentalOfGoods }

final class SellerAddress {
  const SellerAddress({
    required this.line1,
    required this.city,
    required this.postalCode,
    required this.countryCode,
  });

  final String line1;
  final String city;
  final String postalCode;
  final String countryCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'line1': line1.trim(),
    'city': city.trim(),
    'postalCode': postalCode.trim(),
    'countryCode': countryCode.trim().toUpperCase(),
  };
}

final class TraderDetails {
  const TraderDetails({
    required this.legalName,
    required this.registrationNumber,
    required this.address,
    this.vatId,
  });

  final String legalName;
  final String registrationNumber;
  final String? vatId;
  final SellerAddress address;

  Map<String, Object?> toJson() => <String, Object?>{
    'legalName': legalName.trim(),
    'registrationNumber': registrationNumber.trim(),
    if (vatId != null && vatId!.trim().isNotEmpty)
      'vatId': vatId!.trim().toUpperCase(),
    'address': address.toJson(),
  };
}

final class SellerDeclaration {
  const SellerDeclaration({
    required this.status,
    this.email,
    this.phone,
    this.trader,
    this.dac7ActivityTypes = const <Dac7ActivityType>{},
  });

  final SellerStatus status;
  final String? email;
  final String? phone;
  final TraderDetails? trader;
  final Set<Dac7ActivityType> dac7ActivityTypes;

  /// The wire body of `declareSeller`; a private seller never carries trader data.
  Map<String, Object?> toJson() => <String, Object?>{
    'status': status.name,
    'contact': <String, Object?>{
      if (email != null && email!.trim().isNotEmpty) 'email': email!.trim(),
      if (phone != null && phone!.trim().isNotEmpty)
        'phone': phone!.replaceAll(' ', ''),
    },
    if (status == SellerStatus.trader && trader != null)
      'trader': trader!.toJson(),
    'dac7ActivityTypes': <String>[
      for (final Dac7ActivityType type in Dac7ActivityType.values)
        if (dac7ActivityTypes.contains(type)) type.name,
    ],
  };

  static SellerDeclaration? fromJson(Object? value) {
    if (value is! Map) return null;
    final Object? contact = value['contact'];
    final Object? trader = value['trader'];
    final Object? types = value['dac7ActivityTypes'];
    final SellerStatus? status = switch (value['status']) {
      'private' => SellerStatus.private,
      'trader' => SellerStatus.trader,
      _ => null,
    };
    if (status == null || contact is! Map || types is! List) return null;
    TraderDetails? details;
    if (trader is Map && trader['address'] is Map) {
      final Map<Object?, Object?> address = trader['address'] as Map;
      details = TraderDetails(
        legalName: '${trader['legalName'] ?? ''}',
        registrationNumber: '${trader['registrationNumber'] ?? ''}',
        vatId: trader['vatId'] as String?,
        address: SellerAddress(
          line1: '${address['line1'] ?? ''}',
          city: '${address['city'] ?? ''}',
          postalCode: '${address['postalCode'] ?? ''}',
          countryCode: '${address['countryCode'] ?? ''}',
        ),
      );
    }
    return SellerDeclaration(
      status: status,
      email: contact['email'] as String?,
      phone: contact['phone'] as String?,
      trader: details,
      dac7ActivityTypes: <Dac7ActivityType>{
        for (final Dac7ActivityType type in Dac7ActivityType.values)
          if (types.contains(type.name)) type,
      },
    );
  }
}

/// The stored declaration and its server revision (0 = none yet).
final class SellerDeclarationRecord {
  const SellerDeclarationRecord({
    required this.declaration,
    required this.revision,
  });

  final SellerDeclaration? declaration;
  final int revision;
}
