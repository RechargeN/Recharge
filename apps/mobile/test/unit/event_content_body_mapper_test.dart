import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';
import 'package:recharge/features/create/domain/usecases/build_event_content_body.dart';

import 'package:recharge/features/create/data/models/event_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';

import '../fixtures/create/user_event_draft.dart';

void main() {
  const EventContentBodyMapper mapper = EventContentBodyMapper();
  final draft = userEventDraft(
    pageId: '5d1e0000-0000-4000-8000-00000000a001',
    coverPath: 'cover.png',
    localId: 'loc_1700000000000000',
  );

  test('maps the user draft without inventing fields', () {
    final body = mapper.map(draft).body;
    expect(body['title'], draft.title);
    expect(body['categoryId'], 'workshops_masterclasses');
    expect(body['subcategoryId'], 'pottery');
    expect(body['eventArchetype'], 'workshop');
    expect(body['primaryParticipationMode'], 'learn');
    expect(body['additionalParticipationModes'], <String>['create']);
    expect(body['format'], 'offline');
    expect(body.containsKey('onlineAccessMode'), isFalse);
    expect(body['registration'], <String, Object?>{'mode': 'none'});
    expect(body['pricing'], <String, Object?>{
      'mode': 'free',
      'paymentCollectionMode': 'none',
    });
    expect(body['participants'], <String, Object?>{'capacityMode': 'unknown'});
    final schedule = body['schedule']! as Map<String, Object?>;
    expect(schedule['timezoneId'], 'Europe/Riga');
    expect(schedule['scheduleMode'], 'oneTime');
    expect(schedule.containsKey('recurrence'), isFalse);
  });

  test(
    'local occurrence ids become stable UUIDs; times stay as materialized',
    () {
      final first = mapper.map(draft).body['eventSlots']! as List<Object?>;
      final second = mapper.map(draft).body['eventSlots']! as List<Object?>;
      expect(first, hasLength(1));
      final slot = first.single! as Map<String, Object?>;
      expect(slot['id'], isNot(startsWith('loc_')));
      expect(
        RegExp(r'^[0-9a-f-]{36}$').hasMatch(slot['id']! as String),
        isTrue,
      );
      expect((second.single! as Map<String, Object?>)['id'], slot['id']);
      final occurrence = draft.eventData!.occurrences.single;
      expect(slot['startAtUtc'], occurrence.startAtUtc.toIso8601String());
      expect(slot['localDate'], occurrence.localDate);
      // Another local draft never shares the server ids.
      final other =
          mapper
                  .map(
                    userEventDraft(
                      pageId: 'p',
                      coverPath: 'cover.png',
                      localId: 'loc_other',
                    ),
                  )
                  .body['eventSlots']!
              as List<Object?>;
      expect((other.single! as Map<String, Object?>)['id'], isNot(slot['id']));
    },
  );

  test('the cover is a local reference until the server asset exists', () {
    Map<String, Object?> cover(String? asset) =>
        ((mapper.map(draft, coverMediaId: asset).body['media']!
                as Map<String, Object?>)['coverImage']!
            as Map<String, Object?>);
    expect(cover(null)['mediaId'], EventContentBodyMapper.localCoverId);
    expect(cover('asset-1')['mediaId'], 'asset-1');
    expect(cover(null)['altText'], 'Hands shaping clay on a pottery wheel');
  });

  test('capabilities outside the Content subset are reported, not dropped', () {
    final withAdmission = draft.copyWith(
      eventData: draft.eventData!.copyWith(
        admission: const EventAdmissionDraft(
          admissionMode: null,
          registrationMode: EventRegistrationMode.internal,
          confirmationMode: null,
        ),
        registrationMode: EventRegistrationMode.internal,
      ),
    );
    final mapped = mapper.map(withAdmission);
    // E2.0: an incomplete internal registration names exactly what is missing.
    expect(
      mapped.unsupported,
      containsAll(<String>[
        'admission.admissionMode',
        'admission.confirmationMode',
        'registrationWindow.unset',
        'guestPolicy.unset',
        'cancellationDeadline.unset',
      ]),
    );
    // An enum the server refuses by name is sent as it is, never rewritten.
    expect(
      (mapped.body['registration']! as Map<String, Object?>)['mode'],
      'internal',
    );
  });

  test('internal registration v1 maps the explicit choices only', () {
    final mapped = mapper.map(withInternalRegistration(draft));
    expect(mapped.unsupported, isEmpty);
    expect(mapped.body['registration'], <String, Object?>{
      'mode': 'internal',
      'confirmationMode': 'instant',
      'maxPartySize': 2,
      'opensMinutesBeforeStart': 525600,
      'closesMinutesBeforeStart': 60,
      'cancellationClosesMinutesBeforeStart': 120,
    });
    expect(mapped.body['participants'], <String, Object?>{
      'capacityMode': 'known',
      'capacity': 20,
    });
    // Party size includes the booker: none → 1, plus N → N + 1.
    Object? party(GuestPolicy policy) =>
        (mapper
                .map(withInternalRegistration(draft, guestPolicy: policy))
                .body['registration']!
            as Map<String, Object?>)['maxPartySize'];
    expect(party(const GuestPolicy(mode: GuestPolicyMode.none)), 1);
    expect(
      party(const GuestPolicy(mode: GuestPolicyMode.plusN, maxGuests: 4)),
      5,
    );
  });

  test('internal registration survives the local draft store round trip', () {
    final CreateDraftEntity internal = withInternalRegistration(draft);
    // Read back over the plain Create defaults, exactly like the local store.
    final restored = EventDraftMapper.fromJson(
      EventDraftMapper.toJson(internal.eventData!),
      defaults: draft.eventData!,
    );
    expect(
      restored.admission?.registrationMode,
      EventRegistrationMode.internal,
    );
    final mapped = mapper.map(internal.copyWith(eventData: restored));
    expect(mapped.unsupported, isEmpty);
    expect(
      (mapped.body['registration']! as Map<String, Object?>)['maxPartySize'],
      2,
    );
  });

  test('internal registration refuses what v1 cannot carry, by name', () {
    List<String> reasons(CreateDraftEntity value) =>
        mapper.map(value).unsupported;
    final base = withInternalRegistration(draft);
    expect(
      reasons(withInternalRegistration(draft, cancellationBeforeMinutes: null)),
      <String>['cancellationDeadline.unset'],
    );
    expect(
      reasons(
        withInternalRegistration(
          draft,
          guestPolicy: const GuestPolicy(
            mode: GuestPolicyMode.namedGuestsOnly,
            maxGuests: 2,
          ),
        ),
      ),
      <String>['guestPolicy.namedGuestsOnly'],
    );
    expect(
      reasons(
        base.copyWith(
          eventData: base.eventData!.copyWith(
            admission: base.eventData!.admission!.copyWith(
              registrationWindow: const EventAccessWindow(
                kind: EventAccessWindowKind.absolute,
              ),
            ),
          ),
        ),
      ),
      <String>['registrationWindow.absolute'],
    );
    expect(
      reasons(
        base.copyWith(
          eventData: base.eventData!.copyWith(
            admission: base.eventData!.admission!.copyWith(
              clearGuestPolicy: true,
            ),
          ),
        ),
      ),
      <String>['guestPolicy.unset'],
      reason: 'no choice is not the same as no guests',
    );
  });

  test('a draft that is not an Event is refused', () {
    expect(
      () => mapper.map(draft.copyWith(clearEventData: true)),
      throwsArgumentError,
    );
  });
}
