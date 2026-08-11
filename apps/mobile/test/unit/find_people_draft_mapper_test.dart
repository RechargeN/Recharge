import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/models/find_people_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';
import 'package:recharge/shared/primitives/money/currency_code.dart';
import 'package:recharge/shared/primitives/money/money.dart';

void main() {
  test('Find People typed draft survives current schema round-trip', () {
    final CreateDraftEntity source =
        CreateDraftEntity.defaults(
          organizerId: 'user-1',
          organizerEmail: 'user@example.com',
          organizerName: 'Host',
          marketCityId: 'riga',
          timezone: 'Europe/Riga',
          country: 'LV',
          city: 'Riga',
          currency: 'EUR',
        ).copyWith(
          objectType: CreateObjectType.findPeople,
          findPeopleData:
              FindPeopleDraftData.defaults(
                userId: 'user-1',
                currencyCode: 'EUR',
              ).copyWith(
                scheduleMode: FindPeopleScheduleMode.timePoll,
                meetingMode: FindPeopleMeetingMode.hybrid,
                languageCodes: const <String>{'en', 'lv'},
                targetGroupSize: 8,
                exactGeo: const FindPeopleGeoPointDraft(
                  latitude: 56.9496,
                  longitude: 24.1052,
                ),
                onlineProvider: 'Meet',
                onlineAccessSecretRef: 'secret-ref-1',
              ),
        );

    final Map<String, dynamic> json = CreateDraftModel.fromEntity(
      source,
    ).toJson();
    final CreateDraftEntity restored = CreateDraftModel.fromJson(
      json,
      activeCurrency: 'EUR',
    ).toEntity();

    expect(json['schemaVersion'], 9);
    expect(restored.objectType, CreateObjectType.findPeople);
    expect(restored.findPeopleData, isNotNull);
    expect(
      restored.findPeopleData!.scheduleMode,
      FindPeopleScheduleMode.timePoll,
    );
    expect(restored.findPeopleData!.meetingMode, FindPeopleMeetingMode.hybrid);
    expect(restored.findPeopleData!.languageCodes, <String>{'en', 'lv'});
    expect(restored.findPeopleData!.targetGroupSize, 8);
    expect(restored.findPeopleData!.exactGeo!.latitude, 56.9496);
    expect(restored.findPeopleData!.onlineAccessSecretRef, 'secret-ref-1');
  });

  test('legacy social_request migrates to find_people without losing data', () {
    final CreateDraftEntity source =
        CreateDraftEntity.defaults(
          organizerId: 'user-1',
          organizerEmail: 'user@example.com',
          organizerName: 'Host',
          currency: 'EUR',
        ).copyWith(
          objectType: CreateObjectType.findPeople,
          title: 'Weekend tennis partner',
          findPeopleData: FindPeopleDraftData.defaults(
            userId: 'user-1',
            currencyCode: 'EUR',
          ),
        );
    final Map<String, dynamic> legacy = CreateDraftModel.fromEntity(
      source,
    ).toJson();
    legacy['schemaVersion'] = 3;
    legacy['objectType'] = 'social_request';
    final Map<String, dynamic> sections = Map<String, dynamic>.from(
      legacy['sectionData'] as Map<dynamic, dynamic>,
    );
    sections['social_request_details'] = sections.remove('find_people_details');
    legacy['sectionData'] = sections;

    final CreateDraftEntity migrated = CreateDraftModel.fromJson(
      legacy,
      activeCurrency: 'EUR',
    ).toEntity();

    expect(migrated.objectType, CreateObjectType.findPeople);
    expect(migrated.title, 'Weekend tennis partner');
    expect(migrated.findPeopleData, isNotNull);
    expect(
      (migrated.sectionData['migration']
          as Map<String, Object?>)['source_type'],
      'social_request',
    );
  });

  test(
    'writes canonical expense amounts and rejects fractional minor units',
    () {
      final FindPeopleDraftData defaults = FindPeopleDraftData.defaults(
        userId: 'user-1',
        currencyCode: 'EUR',
      );
      final FindPeopleDraftData priced = defaults.copyWith(
      costType: FindPeopleCostType.estimated,
        expectedSpendAmount: const Money(
          minorUnits: 2500,
          currency: CurrencyCode.eur,
        ),
        plannedExpenseItems: const <FindPeopleExpenseItemDraft>[
          FindPeopleExpenseItemDraft(
            id: 'expense-1',
            category: 'court',
            amount: Money(minorUnits: 1200, currency: CurrencyCode.eur),
            payerNote: '',
          ),
        ],
      );
      final Map<String, Object?> encoded = FindPeopleDraftMapper.toJson(priced);

      expect(encoded['expectedSpendAmountMinorUnits'], 2500);
      expect(encoded, isNot(contains('expectedSpendAmount')));
      expect(
        (encoded['plannedExpenseItems']! as List<Object?>).single,
        containsPair('amountMinorUnits', 1200),
      );
      expect(
        () => FindPeopleDraftMapper.fromJson(const <String, Object?>{
          'currencyCode': 'EUR',
          'expectedSpendAmountMinorUnits': 12.5,
        }, defaults: defaults),
        throwsFormatException,
      );
    },
  );
}
