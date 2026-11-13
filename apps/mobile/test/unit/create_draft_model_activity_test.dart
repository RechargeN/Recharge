import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('activity draft round-trips through CreateDraftModel toJson/fromJson', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'User',
    ).copyWith(
      objectType: CreateObjectType.activity,
      activityData: ActivityDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      ).copyWith(
        location: const ActivityLocationDraft(
          latitude: 56.95,
          longitude: 24.11,
          accessNotes: 'Gravel path from parking.',
        ),
      ),
    );

    final Map<String, Object?> json = CreateDraftModel.fromEntity(draft).toJson();
    final CreateDraftEntity restored = CreateDraftModel.fromJson(json).toEntity();

    expect(restored.objectType, CreateObjectType.activity);
    expect(restored.activityData, isNotNull);
    expect(restored.activityData!.location.accessNotes, 'Gravel path from parking.');
  });

  test('non-activity draft has null activityData after round-trip', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'user@example.com',
      organizerName: 'User',
    );
    final Map<String, Object?> json = CreateDraftModel.fromEntity(draft).toJson();
    final CreateDraftEntity restored = CreateDraftModel.fromJson(json).toEntity();
    expect(restored.activityData, isNull);
  });
}
