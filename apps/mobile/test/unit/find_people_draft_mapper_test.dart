import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/find_people_draft_data.dart';

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
    ).toEntity();

    expect(json['schemaVersion'], 8);
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
}
