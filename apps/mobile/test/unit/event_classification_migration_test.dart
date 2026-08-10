import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/event_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/event_classification.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/publisher_ref.dart';
import 'package:recharge/features/create/domain/usecases/suggest_event_classification_usecase.dart';

void main() {
  EventDraftData defaults({PublisherRef? publisherRef}) =>
      EventDraftData.defaults(
        marketCityId: 'riga',
        countryCode: 'LV',
        city: 'Riga',
        timezoneId: 'Europe/Riga',
        currencyCode: 'EUR',
        publisherRef: publisherRef,
      );

  test('new Event draft gets one stable user PublisherRef', () {
    final CreateDraftEntity draft = CreateDraftEntity.defaults(
      organizerId: 'user-1',
      organizerEmail: 'creator@example.com',
      organizerName: 'Creator',
    );

    expect(draft.eventData!.publisherRef, isNotNull);
    expect(draft.eventData!.publisherRef!.type, PublisherType.user);
    expect(draft.eventData!.publisherRef!.id, 'user-1');
    expect(draft.eventData!.publisherRef!.isValid, isTrue);
  });

  test(
    'v2 round-trip preserves classification, publisher and unknown fields',
    () {
      final EventDraftData source =
          defaults(
            publisherRef: const PublisherRef(
              type: PublisherType.page,
              id: 'page-7',
            ),
          ).copyWith(
            classification: EventClassificationDraft(
              archetype: EventArchetype.workshop,
              primaryParticipationMode: ParticipationMode.create,
              additionalParticipationModes: const <ParticipationMode>{
                ParticipationMode.support,
                ParticipationMode.learn,
              },
            ),
            unknownFields: const <String, Object?>{'futureField': 42},
          );

      final Map<String, Object?> json = EventDraftMapper.toJson(source);
      final EventDraftData restored = EventDraftMapper.fromJson(
        json,
        defaults: defaults(),
      );

      expect(json['schemaVersion'], 2);
      expect(json['publisherRef'], <String, Object?>{
        'type': 'page',
        'id': 'page-7',
      });
      expect(
        (json['classification'] as Map)['additionalParticipationModes'],
        <String>['learn', 'support'],
      );
      expect(restored.publisherRef, source.publisherRef);
      expect(restored.classification!.archetype, EventArchetype.workshop);
      expect(
        restored.classification!.additionalParticipationModes,
        <ParticipationMode>{ParticipationMode.learn, ParticipationMode.support},
      );
      expect(restored.unknownFields['futureField'], 42);
    },
  );

  test('v1 read does not inject authority, classification or schema bump', () {
    final EventDraftData restored = EventDraftMapper.fromJson(
      const <String, Object?>{
        'schemaVersion': 1,
        'revision': 4,
        'format': 'offline',
      },
      defaults: defaults(
        publisherRef: const PublisherRef(
          type: PublisherType.user,
          id: 'active-user',
        ),
      ),
    );
    final Map<String, Object?> written = EventDraftMapper.toJson(restored);

    expect(restored.schemaVersion, 1);
    expect(restored.publisherRef, isNull);
    expect(restored.classification, isNull);
    expect(restored.unsupportedFieldIds, isEmpty);
    expect(written['schemaVersion'], 1);
    expect(written, isNot(contains('publisherRef')));
    expect(written, isNot(contains('classification')));
  });

  test('unknown v2 enum remains raw and is never coerced to other', () {
    const Map<String, Object?> rawClassification = <String, Object?>{
      'archetype': 'future_archetype',
      'primaryParticipationMode': 'attend',
      'additionalParticipationModes': <String>[],
    };
    final EventDraftData restored = EventDraftMapper.fromJson(
      const <String, Object?>{
        'schemaVersion': 2,
        'classification': rawClassification,
      },
      defaults: defaults(),
    );

    expect(restored.classification, isNull);
    expect(restored.unsupportedFieldIds, contains('classification'));
    expect(restored.unknownFields['classification'], rawClassification);
    expect(
      EventDraftMapper.toJson(restored)['classification'],
      rawClassification,
    );
  });

  test(
    'valid v2 values retain unknown nested publisher/classification data',
    () {
      final EventDraftData restored = EventDraftMapper.fromJson(
        const <String, Object?>{
          'schemaVersion': 2,
          'publisherRef': <String, Object?>{
            'type': 'user',
            'id': 'user-1',
            'futureAuthority': 'preserve-me',
          },
          'classification': <String, Object?>{
            'archetype': 'talk',
            'primaryParticipationMode': 'learn',
            'additionalParticipationModes': <String>['attend'],
            'futureFacet': <String, Object?>{'version': 3},
          },
        },
        defaults: defaults(),
      );
      final Map<String, Object?> written = EventDraftMapper.toJson(restored);

      expect(restored.unsupportedFieldIds, isEmpty);
      expect(
        (written['publisherRef'] as Map)['futureAuthority'],
        'preserve-me',
      );
      expect(
        (written['classification'] as Map)['futureFacet'],
        <String, Object?>{'version': 3},
      );
    },
  );

  test('newer schema is emitted byte-for-structure without downgrade', () {
    const Map<String, Object?> raw = <String, Object?>{
      'schemaVersion': 7,
      'classification': <String, Object?>{'archetype': 'future_archetype'},
      'futureContract': <String, Object?>{'enabled': true},
    };
    final EventDraftData restored = EventDraftMapper.fromJson(
      raw,
      defaults: defaults(),
    );

    expect(restored.schemaVersion, 7);
    expect(EventDraftMapper.toJson(restored), raw);
  });

  test('duplicate persisted participation mode fails closed', () {
    final EventDraftData restored = EventDraftMapper.fromJson(
      const <String, Object?>{
        'schemaVersion': 2,
        'classification': <String, Object?>{
          'archetype': 'talk',
          'primaryParticipationMode': 'learn',
          'additionalParticipationModes': <String>['attend', 'attend'],
        },
      },
      defaults: defaults(),
    );

    expect(restored.classification, isNull);
    expect(restored.unsupportedFieldIds, contains('classification'));
  });

  group('legacy suggestion', () {
    const SuggestEventClassificationUseCase suggest =
        SuggestEventClassificationUseCase();

    test('canonical subcategory has priority over legacy event type', () {
      final EventClassificationSuggestion? result = suggest(
        subcategoryId: 'hackathon',
        legacyEventType: 'concert',
      );

      expect(result!.archetype, EventArchetype.competition);
      expect(result.reasonCode, 'canonical_subcategory_exact');
      expect(result.confidence, EventClassificationSuggestionConfidence.high);
    });

    test('ambiguous input produces no fabricated suggestion', () {
      expect(
        suggest(subcategoryId: 'other_event', legacyEventType: 'standard'),
        isNull,
      );
    });
  });
}
