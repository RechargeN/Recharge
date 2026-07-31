import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/core/id/id_generator.dart';
import 'package:recharge/features/create/data/datasources/create_template_local_datasource.dart';
import 'package:recharge/features/create/data/repositories/create_template_repository_impl.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:recharge/features/create/domain/entities/create_template_entity.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/usecases/manage_create_template_usecase.dart';

void main() {
  late ManageCreateTemplateUseCase useCase;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    useCase = ManageCreateTemplateUseCase(_SequentialIdGenerator());
  });

  test('template materialization strips instance data and creates new ids', () {
    final CreateDraftEntity source = _eventDraft().copyWith(
      id: 'loc-source',
      media: const MediaEntity(
        coverImage: 'local://cover.jpg',
        gallery: <String>['local://gallery.jpg'],
      ),
      bookingLink: 'https://booking.example.test/event',
      draftStatus: DraftStatus.pendingReview,
      moderationStatus: ModerationStatus.pending,
      publishStatus: PublishStatus.pendingReview,
      publishedAtUtc: DateTime.utc(2026, 7, 20),
      eventData: _eventDraft().eventData!.copyWith(
        publicOnlineUrl: 'https://live.example.test/event',
        externalBookingUrl: 'https://booking.example.test/event',
        occurrences: <EventOccurrenceDraft>[
          EventOccurrenceDraft(
            id: 'loc-occurrence-old',
            localDate: '2026-08-01',
            startAtUtc: DateTime.utc(2026, 8, 1, 15),
            endAtUtc: DateTime.utc(2026, 8, 1, 17),
          ),
        ],
        occurrenceOverrides: <String, EventOccurrenceOverrideDraft>{
          'loc-occurrence-old': const EventOccurrenceOverrideDraft(
            occurrenceId: 'loc-occurrence-old',
            capacity: 10,
          ),
        },
      ),
    );
    final CreateTemplateEntity template = useCase.create(
      userId: 'user-1',
      name: '  Friday   meetup ',
      draft: source,
      nowUtc: DateTime.utc(2026, 7, 31),
    );

    final CreateDraftEntity materialized = useCase.materializeEvent(
      template: template,
      userId: 'user-1',
      organizerEmail: 'new@example.com',
      organizerName: 'New host',
      marketCityId: 'riga',
      timezone: 'Europe/Riga',
      country: 'LV',
      city: 'Riga',
      currency: 'EUR',
      nowUtc: DateTime.utc(2026, 8, 2),
    );

    expect(template.name, 'Friday meetup');
    expect(materialized.id, startsWith('loc_'));
    expect(materialized.id, isNot(source.id));
    expect(materialized.organizerId, 'user-1');
    expect(materialized.organizerEmail, 'new@example.com');
    expect(materialized.eventData!.occurrences, isEmpty);
    expect(materialized.eventData!.occurrenceOverrides, isEmpty);
    expect(materialized.eventData!.publicOnlineUrl, isNull);
    expect(materialized.eventData!.externalBookingUrl, isNull);
    expect(materialized.media.coverImage, isEmpty);
    expect(materialized.media.gallery, isEmpty);
    expect(materialized.bookingLink, isEmpty);
    expect(materialized.publishStatus, PublishStatus.draft);
    expect(materialized.moderationStatus, ModerationStatus.none);
    expect(materialized.publishedAtUtc, isNull);
  });

  test(
    'repository keeps multiple templates isolated by owner and type',
    () async {
      const CreateTemplateLocalDataSource dataSource =
          CreateTemplateLocalDataSource(
            FlutterSecureStorage(),
            activeMarketCityId: 'riga',
            activeTimezone: 'Europe/Riga',
            activeCountry: 'LV',
            activeCity: 'Riga',
          );
      const CreateTemplateRepositoryImpl repository =
          CreateTemplateRepositoryImpl(dataSource);
      final CreateTemplateEntity first = useCase.create(
        userId: 'user-1',
        name: 'Morning class',
        draft: _eventDraft(),
        nowUtc: DateTime.utc(2026, 7, 30),
      );
      final CreateTemplateEntity second = useCase.create(
        userId: 'user-1',
        name: 'Evening class',
        draft: _eventDraft(),
        nowUtc: DateTime.utc(2026, 7, 31),
      );
      final CreateTemplateEntity otherUser = useCase.create(
        userId: 'user-2',
        name: 'Private template',
        draft: _eventDraft(organizerId: 'user-2'),
      );

      await repository.upsertTemplate(userId: 'user-1', template: first);
      await repository.upsertTemplate(userId: 'user-1', template: second);
      await repository.upsertTemplate(userId: 'user-2', template: otherUser);

      final List<CreateTemplateEntity> templates = await repository
          .listTemplates(userId: 'user-1', objectType: CreateObjectType.event);

      expect(templates.map((CreateTemplateEntity item) => item.name), <String>[
        'Evening class',
        'Morning class',
      ]);
      await repository.deleteTemplate(userId: 'user-1', templateId: first.id);
      expect(
        await repository.listTemplates(
          userId: 'user-1',
          objectType: CreateObjectType.event,
        ),
        hasLength(1),
      );
      expect(
        await repository.listTemplates(
          userId: 'user-2',
          objectType: CreateObjectType.event,
        ),
        hasLength(1),
      );
    },
  );

  test('foreign template cannot be materialized', () {
    final CreateTemplateEntity template = useCase.create(
      userId: 'owner',
      name: 'Owner template',
      draft: _eventDraft(organizerId: 'owner'),
    );

    expect(
      () => useCase.materializeEvent(
        template: template,
        userId: 'intruder',
        organizerEmail: 'intruder@example.com',
        organizerName: 'Intruder',
        marketCityId: 'riga',
        timezone: 'Europe/Riga',
        country: 'LV',
        city: 'Riga',
        currency: 'EUR',
      ),
      throwsStateError,
    );
  });
}

CreateDraftEntity _eventDraft({String organizerId = 'user-1'}) {
  return CreateDraftEntity.defaults(
    organizerId: organizerId,
    organizerEmail: '$organizerId@example.com',
    organizerName: 'Host',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  ).copyWith(
    title: 'Community Friday',
    mainCategory: 'entertainment',
    subcategory: 'community_event',
    shortDescription: 'A reusable community meetup configuration.',
  );
}

class _SequentialIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String generate() => 'template-${_next++}';
}
