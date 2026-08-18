import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/activity_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/usecases/count_activity_informal_access_usecase.dart';

void main() {
  test('returns 0 for an unknown publisher', () {
    const CountActivityInformalAccessUseCase usecase =
        CountActivityInformalAccessUseCase();
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'new-user',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    ).copyWith(
      objectType: CreateObjectType.activity,
      activityData: ActivityDraftData.defaults(
        userId: 'new-user',
        currencyCode: 'EUR',
      ),
    );
    expect(usecase(draft), 0);
  });

  test('returns the injected count for a known publisher', () {
    const CountActivityInformalAccessUseCase usecase =
        CountActivityInformalAccessUseCase(
      publishedInformalActivityCounts: <String, int>{'user-3': 3},
    );
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-3',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    ).copyWith(
      objectType: CreateObjectType.activity,
      activityData: ActivityDraftData.defaults(
        userId: 'user-3',
        currencyCode: 'EUR',
      ),
    );
    expect(usecase(draft), 3);
  });

  test('returns 0 when activityData is missing', () {
    const CountActivityInformalAccessUseCase usecase =
        CountActivityInformalAccessUseCase(
      publishedInformalActivityCounts: <String, int>{'user-1': 5},
    );
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'e@example.com',
      organizerName: 'n',
    );
    expect(usecase(draft), 0);
  });
}
