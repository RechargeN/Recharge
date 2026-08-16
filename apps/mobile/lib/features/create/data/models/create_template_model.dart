import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/create_template_entity.dart';
import '../models/create_draft_model.dart';

class CreateTemplateModel {
  const CreateTemplateModel({
    required this.schemaVersion,
    required this.id,
    required this.ownerUserId,
    required this.objectType,
    required this.name,
    required this.snapshot,
    required this.createdAtUtcIso,
    required this.updatedAtUtcIso,
    required this.lastUsedAtUtcIso,
  });

  final int schemaVersion;
  final String id;
  final String ownerUserId;
  final String objectType;
  final String name;
  final CreateDraftModel snapshot;
  final String createdAtUtcIso;
  final String updatedAtUtcIso;
  final String? lastUsedAtUtcIso;

  factory CreateTemplateModel.fromEntity(CreateTemplateEntity entity) {
    return CreateTemplateModel(
      schemaVersion: entity.schemaVersion,
      id: entity.id,
      ownerUserId: entity.ownerUserId,
      objectType: entity.objectType.taxonomyId,
      name: entity.name,
      snapshot: CreateDraftModel.fromEntity(entity.snapshot),
      createdAtUtcIso: entity.createdAtUtc.toIso8601String(),
      updatedAtUtcIso: entity.updatedAtUtc.toIso8601String(),
      lastUsedAtUtcIso: entity.lastUsedAtUtc?.toIso8601String(),
    );
  }

  factory CreateTemplateModel.fromJson(
    Map<String, dynamic> json, {
    required String activeMarketCityId,
    required String activeTimezone,
    required String activeCountry,
    required String activeCity,
    required String activeCurrency,
  }) {
    final int schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (schemaVersion != CreateTemplateEntity.currentSchemaVersion) {
      throw const FormatException('Unsupported create template schema.');
    }
    final Object? rawSnapshot = json['snapshot'];
    if (rawSnapshot is! Map<dynamic, dynamic>) {
      throw const FormatException('Create template snapshot is missing.');
    }
    return CreateTemplateModel(
      schemaVersion: schemaVersion,
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String,
      objectType: json['objectType'] as String,
      name: json['name'] as String,
      snapshot: CreateDraftModel.fromJson(
        Map<String, dynamic>.from(rawSnapshot),
        activeMarketCityId: activeMarketCityId,
        activeTimezone: activeTimezone,
        activeCountry: activeCountry,
        activeCity: activeCity,
        activeCurrency: activeCurrency,
      ),
      createdAtUtcIso: json['createdAtUtcIso'] as String,
      updatedAtUtcIso: json['updatedAtUtcIso'] as String,
      lastUsedAtUtcIso: json['lastUsedAtUtcIso'] as String?,
    );
  }

  CreateTemplateEntity toEntity() {
    final CreateDraftEntity entity = snapshot.toEntity();
    final CreateObjectType parsedType = createObjectTypeFromId(objectType);
    if (entity.objectType != parsedType) {
      throw const FormatException('Template and snapshot types differ.');
    }
    return CreateTemplateEntity(
      schemaVersion: schemaVersion,
      id: id,
      ownerUserId: ownerUserId,
      objectType: parsedType,
      name: name,
      snapshot: entity,
      createdAtUtc: DateTime.parse(createdAtUtcIso).toUtc(),
      updatedAtUtc: DateTime.parse(updatedAtUtcIso).toUtc(),
      lastUsedAtUtc: lastUsedAtUtcIso == null
          ? null
          : DateTime.parse(lastUsedAtUtcIso!).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'id': id,
      'ownerUserId': ownerUserId,
      'objectType': objectType,
      'name': name,
      'snapshot': snapshot.toJson(),
      'createdAtUtcIso': createdAtUtcIso,
      'updatedAtUtcIso': updatedAtUtcIso,
      'lastUsedAtUtcIso': lastUsedAtUtcIso,
    };
  }
}
