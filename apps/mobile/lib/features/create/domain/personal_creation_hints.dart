/// ADR 0023 (User = Creator, OQ-2): every active User may author free personal
/// content. These are interface hints only: the server decides every command
/// (identity verification still gates paid, booking, rental and money types).
/// Rental is deliberately absent; Activity and Scenario have no hub gate.
const Set<String> personalCreationHints = <String>{
  'create.place',
  'create.route',
  'create.collection',
};

/// Server capabilities plus the ADR 0023 personal hints, without duplicates.
List<String> withPersonalCreationHints(Iterable<String> serverCapabilities) =>
    List<String>.unmodifiable(<String>{
      ...serverCapabilities,
      ...personalCreationHints,
    });
