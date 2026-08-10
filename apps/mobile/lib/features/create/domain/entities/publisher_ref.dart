enum PublisherType {
  user('user'),
  page('page');

  const PublisherType(this.wireName);

  final String wireName;

  static PublisherType? fromWireName(Object? value) {
    for (final PublisherType type in PublisherType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

/// Stable authority reference shared by all publishable Create aggregates.
class PublisherRef {
  const PublisherRef({required this.type, required this.id});

  final PublisherType type;
  final String id;

  bool get isValid => id.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublisherRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);
}
