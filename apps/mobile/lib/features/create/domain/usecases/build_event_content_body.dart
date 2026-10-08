import 'package:uuid/uuid.dart';

import '../entities/create_draft_entity.dart';
import '../entities/event_admission.dart';
import '../entities/event_draft_data.dart';

/// The Content Event body built from the user's own Create draft, plus the
/// parts of that draft the Content Event subset (C0 + schedule-C1) cannot
/// carry. Nothing is invented: a field the draft does not hold is not sent.
final class EventContentBody {
  const EventContentBody({required this.body, required this.unsupported});

  final Map<String, Object?> body;

  /// Draft sections outside the accepted Content Event subset (admission,
  /// inventory, occurrence overrides). They are never dropped silently: a draft
  /// that uses them is not sent at all.
  final List<String> unsupported;
}

/// Maps a Create Event draft to the BCK-07 Event body. Local ids (`loc_*`) of
/// occurrences become stable UUIDs derived from the local draft id, so every
/// save of the same draft sends the same ids. The cover is the server Media id
/// once uploaded, or a local reference until then (Content refuses a local id
/// at submit, so an unuploaded cover can never be published).
final class EventContentBodyMapper {
  const EventContentBodyMapper();

  static const String localCoverId = 'loc_cover';
  static const String _namespace = '6ba7b811-9dad-11d1-80b4-00c04fd430c8';
  static final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String serverOccurrenceId(String localDraftId, String occurrenceId) =>
      _uuid.hasMatch(occurrenceId)
      ? occurrenceId
      : const Uuid().v5(
          _namespace,
          'recharge:event-occurrence:$localDraftId/$occurrenceId',
        );

  EventContentBody map(CreateDraftEntity draft, {String? coverMediaId}) {
    final EventDraftData? event = draft.eventData;
    if (draft.objectType != CreateObjectType.event || event == null) {
      throw ArgumentError('Not an Event draft');
    }
    // E2.0: internal registration v1 is accepted only from explicit choices in
    // the draft; every other admission configuration stays unsupported. With
    // an Admission configuration (draft schema v3) its registration axis is
    // the authority: the legacy top-level mode is not stored next to it.
    final EventAdmissionDraft? admission = event.admission;
    final bool internal = admission != null
        ? admission.registrationMode == EventRegistrationMode.internal
        : event.registrationMode == EventRegistrationMode.internal;
    final List<String> unsupported = <String>[
      if (internal)
        ..._internalUnsupported(event)
      else if (event.admission != null)
        'admission',
      if (event.inventory != null) 'inventory',
      if (event.occurrenceOverrides.isNotEmpty) 'occurrenceOverrides',
    ];
    final classification = event.classification;
    final Map<String, Object?> body = <String, Object?>{
      if (classification?.archetype != null)
        'eventArchetype': classification!.archetype!.wireName,
      if (_text(classification?.otherReason) != null)
        'eventArchetypeOtherReason': _text(classification?.otherReason),
      if (classification?.primaryParticipationMode != null)
        'primaryParticipationMode':
            classification!.primaryParticipationMode!.wireName,
      if (classification != null &&
          classification.additionalParticipationModes.isNotEmpty)
        'additionalParticipationModes':
            (classification.additionalParticipationModes
                    .map((mode) => mode.wireName)
                    .toList()
                  ..sort())
                .toList(),
      'title': draft.title,
      'categoryId': draft.mainCategory,
      'subcategoryId': draft.subcategory,
      if (draft.tags.isNotEmpty) 'tags': List<String>.of(draft.tags),
      'shortDescription': draft.shortDescription,
      'fullDescription': draft.fullDescription,
      'media': _media(draft, event, coverMediaId),
      'format': event.format.name,
      if (event.format != EventFormat.offline && event.onlineAccessMode != null)
        'onlineAccessMode': event.onlineAccessMode!.name,
      if (_text(event.publicOnlineUrl) != null)
        'publicOnlineUrl': _text(event.publicOnlineUrl),
      'location': _location(event.location),
      'schedule': _schedule(draft, event),
      'eventSlots': <Map<String, Object?>>[
        for (final EventOccurrenceDraft occurrence in event.occurrences)
          <String, Object?>{
            'id': serverOccurrenceId(draft.id, occurrence.id),
            'localDate': occurrence.localDate,
            'startAtUtc': occurrence.startAtUtc.toUtc().toIso8601String(),
            'endAtUtc': occurrence.endAtUtc.toUtc().toIso8601String(),
            if (occurrence.shiftedForDst) 'shiftedForDst': true,
          },
      ],
      'audience': <String, Object?>{
        if (event.ageMin != null) 'ageMin': event.ageMin,
        if (event.ageMax != null) 'ageMax': event.ageMax,
        'familyFriendly': event.familyFriendly,
        'kidsAllowed': event.kidsAllowed,
        'petFriendly': event.petFriendly,
        'wheelchairAccessible': draft.wheelchairAccessible,
      },
      if (event.amenityIds.isNotEmpty)
        'amenityIds': (event.amenityIds.toList()..sort()),
      'pricing': _pricing(draft, event),
      'participants': <String, Object?>{
        'capacityMode': event.capacityMode.name,
        if (event.capacityMode == EventCapacityMode.known &&
            event.capacity != null)
          'capacity': event.capacity,
        if (draft.minParticipants != null)
          'minParticipants': draft.minParticipants,
      },
      'registration': internal
          ? _internalRegistration(event)
          : <String, Object?>{
              'mode': event.registrationMode.name,
              if (event.registrationMode == EventRegistrationMode.external &&
                  _text(event.externalBookingUrl) != null)
                'externalBookingUrl': _text(event.externalBookingUrl),
            },
      'visibility': event.visibility.name,
    };
    return EventContentBody(
      body: body,
      unsupported: List<String>.unmodifiable(unsupported),
    );
  }

  Map<String, Object?> _media(
    CreateDraftEntity draft,
    EventDraftData event,
    String? coverMediaId,
  ) {
    final metadata = event.mediaMetadata;
    return <String, Object?>{
      'coverImage': <String, Object?>{
        'mediaId': coverMediaId ?? localCoverId,
        'altText': metadata.coverAltText,
      },
      // Gallery images are not uploaded in this slice: they keep local ids, which
      // Content refuses at submit instead of publishing without them.
      'gallery': <Map<String, Object?>>[
        for (int index = 0; index < draft.media.gallery.length; index += 1)
          <String, Object?>{
            'mediaId': 'loc_gallery_$index',
            'altText':
                metadata.galleryAltText[draft.media.gallery[index]] ?? '',
          },
      ],
      'rightsConfirmed': metadata.rightsConfirmed,
    };
  }

  Map<String, Object?> _location(EventLocationDraft location) =>
      <String, Object?>{
        'marketCityId': location.marketCityId,
        'countryCode': location.countryCode,
        'city': location.city,
        if (_text(location.venueName) != null)
          'venueName': _text(location.venueName),
        if (_text(location.formattedAddress) != null)
          'formattedAddress': _text(location.formattedAddress),
        if (_text(location.meetingPoint) != null)
          'meetingPoint': _text(location.meetingPoint),
        if (location.latitude != null) 'latitude': location.latitude,
        if (location.longitude != null) 'longitude': location.longitude,
        'pinConfirmed': location.pinConfirmed,
      };

  Map<String, Object?> _schedule(
    CreateDraftEntity draft,
    EventDraftData event,
  ) {
    final EventRecurrenceRuleDraft? rule = event.recurrence;
    return <String, Object?>{
      'timezoneId': event.timezoneId,
      'scheduleMode': event.scheduleMode.name,
      'allDay': event.allDay,
      'localStartDate': event.localStartDate,
      'startMinute': event.startMinute,
      'durationMinutes': event.durationMinutes,
      if (event.scheduleMode == EventScheduleMode.multiDate)
        'multiDateLocalDates': List<String>.of(event.multiDateLocalDates),
      if (event.scheduleMode == EventScheduleMode.recurring && rule != null)
        'recurrence': <String, Object?>{
          'frequency': rule.frequency.name,
          'interval': rule.interval,
          if (rule.frequency == EventRecurrenceFrequency.weekly)
            'weekdays': (rule.weekdays.toList()..sort()),
          if (rule.frequency == EventRecurrenceFrequency.monthly)
            'monthlyDayPolicy': rule.monthlyDayPolicy.name,
          'endMode': rule.endMode.name,
          if (rule.endMode == EventRecurrenceEndMode.untilDate)
            'untilLocalDate': rule.untilLocalDate,
          if (rule.endMode == EventRecurrenceEndMode.occurrenceCount)
            'occurrenceCount': rule.occurrenceCount,
          if (rule.exceptionLocalDates.isNotEmpty)
            'exceptionLocalDates': (rule.exceptionLocalDates.toList()..sort()),
          'dstGapPolicy': rule.dstGapPolicy.name,
          'dstOverlapPolicy': rule.dstOverlapPolicy.name,
        },
      'allowsPartialAttendance': event.allowsPartialAttendance,
      if (event.allowsPartialAttendance &&
          draft.minimumVisitDurationMinutes != null)
        'minimumVisitDurationMinutes': draft.minimumVisitDurationMinutes,
      'bufferBeforeMinutes': draft.bufferBeforeMinutes,
      'bufferAfterMinutes': draft.bufferAfterMinutes,
    };
  }

  Map<String, Object?> _pricing(CreateDraftEntity draft, EventDraftData event) {
    final EventMoneyDraft? price = event.price;
    return <String, Object?>{
      'mode': event.pricingMode.name,
      if (event.pricingMode != EventPricingMode.free && price != null)
        'price': <String, Object?>{
          'amountMinor': price.amountMinor,
          'currencyCode': price.currencyCode,
        },
      if (event.pricingMode != EventPricingMode.free &&
          _text(draft.pricingModel) != null)
        'pricingModel': _text(draft.pricingModel),
      'paymentCollectionMode': event.paymentCollectionMode.name,
    };
  }

  /// The reasons a draft with internal registration cannot be sent (§8 of the
  /// E2.0 amendment); empty when it can.
  static List<String> _internalUnsupported(EventDraftData event) {
    final EventAdmissionDraft? admission = event.admission;
    if (admission == null) return const <String>['admission.unset'];
    final EventAccessWindow? window = admission.registrationWindow;
    final GuestPolicy? guest = admission.guestPolicy;
    return <String>[
      if (admission.admissionMode != AdmissionMode.booking)
        'admission.admissionMode',
      if (admission.registrationMode != EventRegistrationMode.internal)
        'admission.registrationMode',
      if (admission.confirmationMode != ConfirmationMode.instant)
        'admission.confirmationMode',
      if (admission.eligibilityRules.isNotEmpty) 'admission.eligibilityRules',
      if (admission.interestPolicy?.optionalRsvpEnabled ?? false)
        'admission.interestPolicy',
      if (admission.onsiteAdmissionPolicy?.allowed ?? false)
        'admission.onsiteAdmissionPolicy',
      if (admission.applicationWindow != null) 'admission.applicationWindow',
      if (admission.waitlistPolicy?.enabled ?? false)
        'admission.waitlistPolicy',
      if (window == null)
        'registrationWindow.unset'
      else if (window.kind == EventAccessWindowKind.absolute)
        'registrationWindow.absolute'
      else if (window.opensBeforeOccurrenceMinutes == null ||
          window.closesBeforeOccurrenceMinutes == null)
        'registrationWindow.incomplete',
      if (guest == null)
        'guestPolicy.unset'
      else if (guest.mode == GuestPolicyMode.namedGuestsOnly)
        'guestPolicy.namedGuestsOnly'
      else if (_partySize(guest) == null)
        'guestPolicy.maxGuests',
      if (admission.cancellationClosesBeforeOccurrenceMinutes == null)
        'cancellationDeadline.unset',
      if (event.format != EventFormat.offline) 'format',
      if (event.pricingMode != EventPricingMode.free) 'pricing',
    ];
  }

  /// Party size includes the person who books: an explicit `none` is 1.
  static int? _partySize(GuestPolicy? guest) {
    if (guest == null) return null;
    return switch (guest.mode) {
      GuestPolicyMode.none => 1,
      GuestPolicyMode.plusOne => 2,
      GuestPolicyMode.plusN =>
        (guest.maxGuests ?? 0) >= 1 && guest.maxGuests! <= 20
            ? guest.maxGuests! + 1
            : null,
      GuestPolicyMode.namedGuestsOnly => null,
    };
  }

  /// Only what the user chose; a missing value is simply absent (the server
  /// refuses it by name), never filled in here.
  Map<String, Object?> _internalRegistration(EventDraftData event) {
    final EventAdmissionDraft? admission = event.admission;
    final EventAccessWindow? window = admission?.registrationWindow;
    final bool relative =
        window?.kind == EventAccessWindowKind.occurrenceRelative;
    final int? party = _partySize(admission?.guestPolicy);
    final int? cancellation =
        admission?.cancellationClosesBeforeOccurrenceMinutes;
    return <String, Object?>{
      'mode': 'internal',
      if (admission?.confirmationMode == ConfirmationMode.instant)
        'confirmationMode': 'instant',
      if (party != null) 'maxPartySize': party,
      if (relative && window!.opensBeforeOccurrenceMinutes != null)
        'opensMinutesBeforeStart': window.opensBeforeOccurrenceMinutes,
      if (relative && window!.closesBeforeOccurrenceMinutes != null)
        'closesMinutesBeforeStart': window.closesBeforeOccurrenceMinutes,
      if (cancellation != null)
        'cancellationClosesMinutesBeforeStart': cancellation,
    };
  }

  static String? _text(String? value) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
