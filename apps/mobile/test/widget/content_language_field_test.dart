import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/usecases/build_event_content_body.dart';

import '../fixtures/create/user_event_draft.dart';

void main() {
  final CreateDraftEntity base = userEventDraft(
    pageId: '5d1e0000-0000-4000-8000-00000000a001',
    coverPath: 'cover.png',
    localId: 'loc_1700000000000000',
  );
  CreateDraftEntity withLanguage(Object? value) => base.copyWith(
    sectionData: <String, Object?>{
      ...base.sectionData,
      draftContentLanguageSection: value,
    },
  );

  test('no language is declared until the author chooses one', () {
    expect(base.declaredContentLocale, isNull);
    expect(withLanguage('').declaredContentLocale, isNull);
    expect(withLanguage(42).declaredContentLocale, isNull);
    expect(withLanguage('lv').declaredContentLocale, 'lv');
  });

  test('the Event body carries the language only when it was chosen', () {
    const EventContentBodyMapper mapper = EventContentBodyMapper();
    expect(mapper.map(base).body.containsKey('contentLocale'), isFalse);
    expect(mapper.map(withLanguage('ru')).body['contentLocale'], 'ru');
  });

  test('the choice survives the local draft round trip', () {
    final CreateDraftEntity restored = CreateDraftModel.fromJson(
      CreateDraftModel.fromEntity(withLanguage('lv')).toJson(),
    ).toEntity();
    expect(restored.declaredContentLocale, 'lv');
  });
}
