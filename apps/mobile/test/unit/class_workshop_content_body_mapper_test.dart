import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/class_workshop_draft_mapper.dart';
import 'package:recharge/features/create/data/models/create_draft_model.dart';
import 'package:recharge/features/create/data/repositories/event_timezone_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/class_workshop_draft_data.dart';
import 'package:recharge/features/create/domain/entities/create_availability.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/build_class_workshop_content_body.dart';

import '../fixtures/create/user_class_workshop_draft.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(
          File(
            '../../packages/api_contracts/schema/content/v1/fixtures/class_workshop_create_compat.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

Object? _case(String name) => (_fixture()['cases'] as List).firstWhere(
  (dynamic c) => c['name'] == name,
)['body'];

void main() {
  const user = '11111111-1111-4111-8111-111111111111';
  final scope = ClassWorkshopPublicationScope(
    accountId: user,
    publisherRef: const PublisherRef(type: PublisherType.user, id: user),
    localDraftId: 'local-class-1',
  );
  final mapper = ClassWorkshopContentBodyMapper(EventTimezoneRepositoryImpl());
  ClassWorkshopContentBody map(CreateDraftEntity draft) => mapper.map(
    draft,
    scope: scope,
    defaultContentLocale: 'en',
    assetIds: <String, String>{
      scope.coverAttachmentId: '33333333-3333-4333-8333-333333333333',
    },
  );

  test('real Class draft maps byte-for-byte to the shared valid fixture', () {
    final mapped = map(
      userClassWorkshopDraft(userId: user, coverPath: 'c.png'),
    );
    expect(mapped.unsupported, isEmpty);
    expect(mapped.body, _case('valid'));
  });

  test('series with full-series price maps to the shared series fixture', () {
    final draft = userClassWorkshopDraft(
      userId: user,
      coverPath: 'c.png',
      occurrences: const <ClassWorkshopOccurrence>[
        ClassWorkshopOccurrence(
          id: 'loc_occ_1',
          localDate: '2027-05-15',
          startMinuteLocal: 600,
          endMinuteLocal: 780,
        ),
        ClassWorkshopOccurrence(
          id: 'loc_occ_2',
          localDate: '2027-05-22',
          startMinuteLocal: 600,
          endMinuteLocal: 780,
        ),
      ],
    );
    final data = draft.classWorkshopData!;
    final mapped = map(
      draft.copyWith(
        classWorkshopData: data.copyWith(
          contextKind: ClassWorkshopContextKind.fixedSeries,
          price: const ClassWorkshopPrice(
            mode: ClassWorkshopPriceMode.fixed,
            amountMinor: 4500,
            currencyCode: 'EUR',
            scope: ClassWorkshopPriceScope.perPersonFullSeries,
          ),
        ),
      ),
    );
    expect(mapped.unsupported, isEmpty);
    expect(mapped.body, _case('valid_full_series_price'));
  });

  test('DST overlap with an explicit fold maps to the shared fold fixture', () {
    final draft = userClassWorkshopDraft(
      userId: user,
      coverPath: 'c.png',
      occurrences: const <ClassWorkshopOccurrence>[
        ClassWorkshopOccurrence(
          id: 'loc_occ_1',
          localDate: '2027-10-31',
          startMinuteLocal: 210,
          endMinuteLocal: 300,
          fold: ClassWorkshopFold.earlier,
        ),
      ],
    );
    final mapped = map(draft);
    expect(mapped.unsupported, isEmpty);
    expect(mapped.body, _case('valid_dst_overlap_fold'));
  });

  test('a DST gap or an unresolved overlap is refused before sending', () {
    for (final occurrence in const <ClassWorkshopOccurrence>[
      ClassWorkshopOccurrence(
        id: 'loc_gap',
        localDate: '2027-03-28',
        startMinuteLocal: 210,
        endMinuteLocal: 360,
      ),
      ClassWorkshopOccurrence(
        id: 'loc_overlap',
        localDate: '2027-10-31',
        startMinuteLocal: 210,
        endMinuteLocal: 300,
      ),
    ]) {
      final mapped = map(
        userClassWorkshopDraft(
          userId: user,
          coverPath: 'c.png',
          occurrences: <ClassWorkshopOccurrence>[occurrence],
        ),
      );
      expect(
        mapped.unsupported,
        contains('occurrence_time:1'),
        reason: occurrence.id,
      );
    }
  });

  test(
    'unknown, legacy, Booking and foreign section data refuse; nothing is dropped',
    () {
      final draft = userClassWorkshopDraft(userId: user, coverPath: 'c.png');
      final data = draft.classWorkshopData!;
      final cases = <String, CreateDraftEntity>{
        'unknown_fields': draft.copyWith(
          classWorkshopData: data.copyWith(
            unknownFields: <String, Object?>{'future': true},
          ),
        ),
        'eventSlots': draft.copyWith(
          scheduleSlots: <CreateTimeSlotDraft>[
            CreateTimeSlotDraft(
              localId: 'loc_slot',
              startAtUtc: DateTime.utc(2027, 5, 15, 7),
              endAtUtc: DateTime.utc(2027, 5, 15, 10),
            ),
          ],
        ),
        'booking_claims': draft.copyWith(waitlistEnabled: true),
        'section:class_workshop_details': draft.copyWith(
          sectionData: <String, Object?>{
            ...draft.sectionData,
            'class_workshop_details': <String, Object?>{'schema_version': 2},
          },
        ),
      };
      for (final entry in cases.entries) {
        expect(
          map(entry.value).unsupported,
          contains(entry.key),
          reason: entry.key,
        );
      }
    },
  );

  test('changing the confirmed address unconfirms the pin', () {
    final draft = userClassWorkshopDraft(userId: user, coverPath: 'c.png');
    expect(ClassWorkshopContentBodyMapper.pinConfirmed(draft), isTrue);
    expect(
      ClassWorkshopContentBodyMapper.pinConfirmed(
        draft.copyWith(addressLine1: 'Different address'),
      ),
      isFalse,
    );
  });

  test('online-live delivery sends no location and no fake coordinates', () {
    final draft = userClassWorkshopDraft(userId: user, coverPath: 'c.png');
    final body = map(
      draft.copyWith(
        classWorkshopData: draft.classWorkshopData!.copyWith(
          deliveryFormat: ClassWorkshopDeliveryFormat.onlineLive,
          onlineProviderLabel: 'Video call',
        ),
      ),
    ).body;
    expect(body.containsKey('location'), isFalse);
    final payload = body['class_workshop']! as Map<String, Object?>;
    expect(payload.containsKey('public_location_mode'), isFalse);
    expect(payload['online_provider_label'], 'Video call');
  });

  test(
    'persistence mapper round-trips losslessly and never coerces bad raw values',
    () {
      final data = userClassWorkshopDraft(
        userId: user,
        coverPath: 'c.png',
      ).classWorkshopData!;
      final json = ClassWorkshopDraftMapper.toJson(data);
      final back = ClassWorkshopDraftMapper.fromJson(
        json,
        defaultTimezoneId: 'Europe/Riga',
      );
      expect(ClassWorkshopDraftMapper.toJson(back), json);
      final broken = <String, Object?>{
        ...json,
        'declared_group_limit': 'eight',
        'future': <String, Object?>{'x': 1},
      };
      final parsed = ClassWorkshopDraftMapper.fromJson(
        broken,
        defaultTimezoneId: 'Europe/Riga',
      );
      expect(parsed.declaredGroupLimit, isNull);
      expect(parsed.unknownFields, <String, Object?>{
        'declared_group_limit': 'eight',
        'future': <String, Object?>{'x': 1},
      });
      expect(
        () => ClassWorkshopDraftMapper.fromJson(<String, Object?>{
          'schema_version': 2,
        }, defaultTimezoneId: 'Europe/Riga'),
        throwsA(isA<UnsupportedClassWorkshopSchemaException>()),
      );
    },
  );

  test(
    'Create persistence keeps the typed Class draft and a newer schema raw',
    () {
      final draft = userClassWorkshopDraft(userId: user, coverPath: 'c.png');
      final restored = CreateDraftModel.fromEntity(draft).toEntity();
      expect(
        ClassWorkshopDraftMapper.toJson(restored.classWorkshopData!),
        ClassWorkshopDraftMapper.toJson(draft.classWorkshopData!),
      );
      final newer = CreateDraftModel.fromEntity(
        draft.copyWith(
          clearClassWorkshopData: true,
          sectionData: <String, Object?>{
            ...draft.sectionData,
            'class_workshop_details': <String, Object?>{'schema_version': 2},
          },
        ),
      ).toEntity();
      expect(newer.classWorkshopData, isNull);
      expect(newer.sectionData['class_workshop_details'], <String, Object?>{
        'schema_version': 2,
      });
    },
  );
}
