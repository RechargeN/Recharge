import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test(
    'AC-34 legacy Latvia identities are never guessed from active market',
    () {
      final CreateDraftModel model =
          CreateDraftModel.fromJson(<String, dynamic>{
            'id': 'draft_1',
            'createdAtUtcIso': '2026-01-01T00:00:00Z',
            'updatedAtUtcIso': '2026-01-01T00:00:00Z',
            'objectType': 'event',
            'country': 'Latvia',
            'city': '',
            'timezone': 'Europe/Moscow',
          });

      expect(model.schemaVersion, 9);
      expect(model.marketCityId, isEmpty);
      expect(model.timezone, 'Europe/Moscow');
      expect(model.toJson()['schemaVersion'], 9);
    },
  );

  test(
    'AC-36 legacy Rezekne preserves recorded timezone without market inference',
    () {
      final CreateDraftModel model =
          CreateDraftModel.fromJson(<String, dynamic>{
            'id': 'draft_2',
            'createdAtUtcIso': '2026-01-01T00:00:00Z',
            'updatedAtUtcIso': '2026-01-01T00:00:00Z',
            'objectType': 'place',
            'country': 'Latvia',
            'city': 'Rezekne',
            'timezone': 'Europe/Moscow',
          });

      expect(model.marketCityId, isEmpty);
      expect(model.timezone, 'Europe/Moscow');
    },
  );

  test('unknown legacy location is not overwritten', () {
    final CreateDraftModel model = CreateDraftModel.fromJson(<String, dynamic>{
      'id': 'draft_3',
      'createdAtUtcIso': '2026-01-01T00:00:00Z',
      'updatedAtUtcIso': '2026-01-01T00:00:00Z',
      'objectType': 'place',
      'country': 'Estonia',
      'city': 'Tartu',
      'timezone': 'Europe/Tallinn',
    });

    expect(model.marketCityId, isEmpty);
    expect(model.timezone, 'Europe/Tallinn');
  });

  test('schema v8 preserves published Route version lineage', () {
    final draft = CreateDraftEntity.defaults(
      organizerId: 'creator-1',
      organizerEmail: 'creator@example.com',
      organizerName: 'Creator',
    ).copyWith(basedOnPublishedVersionId: 'version-42');

    final restored = CreateDraftModel.fromJson(
      CreateDraftModel.fromEntity(draft).toJson(),
    ).toEntity();

    expect(restored.basedOnPublishedVersionId, 'version-42');
  });
}
