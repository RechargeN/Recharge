import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

void main() {
  test('legacy offer draft migrates to session and rental review flag', () {
    final CreateDraftEntity draft = CreateDraftModel.fromJson(<String, dynamic>{
      'id': 'legacy-offer',
      'objectType': 'offer',
      'mainCategory': 'sport',
      'subcategory': 'sport_cycling',
    }).toEntity();

    expect(draft.objectType, CreateObjectType.session);
    expect(draft.mainCategory, 'sport');
    expect(draft.subcategory, 'cycling');
    expect(
      (draft.sectionData['migration']
          as Map<String, Object?>)['review_as_rental'],
      isTrue,
    );
  });

  test('all legacy create types map to accepted ContentType values', () {
    expect(
      createObjectTypeFromId('social_request'),
      CreateObjectType.findPeople,
    );
    expect(createObjectTypeFromId('private_plan'), CreateObjectType.quickPlan);
    expect(createObjectTypeFromId('venue'), CreateObjectType.place);
    expect(createObjectTypeFromId('bookable_slot'), CreateObjectType.session);
    expect(createObjectTypeFromId('announcement'), CreateObjectType.event);
  });
}
