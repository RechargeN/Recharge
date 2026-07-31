import 'create_draft_entity.dart';

class CreateTemplateEntity {
  const CreateTemplateEntity({
    required this.schemaVersion,
    required this.id,
    required this.ownerUserId,
    required this.objectType,
    required this.name,
    required this.snapshot,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.lastUsedAtUtc,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String ownerUserId;
  final CreateObjectType objectType;
  final String name;
  final CreateDraftEntity snapshot;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? lastUsedAtUtc;

  CreateTemplateEntity copyWith({
    String? name,
    CreateDraftEntity? snapshot,
    DateTime? updatedAtUtc,
    DateTime? lastUsedAtUtc,
    bool clearLastUsedAtUtc = false,
  }) {
    return CreateTemplateEntity(
      schemaVersion: schemaVersion,
      id: id,
      ownerUserId: ownerUserId,
      objectType: objectType,
      name: name ?? this.name,
      snapshot: snapshot ?? this.snapshot,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      lastUsedAtUtc: clearLastUsedAtUtc
          ? null
          : (lastUsedAtUtc ?? this.lastUsedAtUtc),
    );
  }
}
