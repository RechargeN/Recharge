import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'create_media_pick_actions.dart';

import '../../../../core/localization/taxonomy_labels.dart';
import '../../../../core/parsing/input_parsers.dart';

import '../../application/controllers/create_controller.dart';
import 'content_language_field.dart';
import '../../application/event_create_config.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/event_draft_data.dart';
import '../../domain/entities/event_validation_issue.dart';
import 'event_template_panel.dart';
import 'event_admission_section.dart';
import 'event_classification_section.dart';
import 'event_inventory_section.dart';
import 'create_texts.dart';
import '../../../../core/localization/l10n_context.dart';
import 'create_form_texts.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../../../shared/primitives/money/money.dart';

class EventCreateBlock extends StatelessWidget {
  const EventCreateBlock({
    super.key,
    required this.controller,
    required this.state,
    required this.taxonomySection,
    required this.onPublished,
  });

  final CreateController controller;
  final CreateState state;
  final Widget taxonomySection;
  final VoidCallback onPublished;

  @override
  Widget build(BuildContext context) {
    final CreateDraftEntity draft = state.draft;
    final EventDraftData? event = draft.eventData;
    if (event == null) {
      return _EventCard(
        child: Text(
          context.l10n.createFormEventDraftUnavailableReopenCreateHub,
        ),
      );
    }
    final int step = state.eventStep;
    final EventCreateStepConfig stepConfig = eventCreateSteps[step];
    return Column(
      key: const Key('event-create-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EventTemplatePanel(controller: controller),
        const SizedBox(height: 16),
        CreateFlowProgressBar(
          stepCount: eventCreateSteps.length,
          currentStep: step,
        ),
        const SizedBox(height: 8),
        CreateFlowStepLabel(
          stepNumber: step + 1,
          stepCount: eventCreateSteps.length,
          title: createFormText(context.l10n, stepConfig.titleId),
          description: createFormText(context.l10n, stepConfig.descriptionId),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (step) {
            0 => _basics(context, draft, event),
            1 => _schedule(context, event),
            2 => _requirements(context, event),
            3 => _price(context, event),
            _ => _preview(context, draft, event),
          },
        ),
        const SizedBox(height: 12),
        _issues(context, step),
        const SizedBox(height: 12),
        _navigation(context, step),
      ],
    );
  }

  Widget _basics(
    BuildContext context,
    CreateDraftEntity draft,
    EventDraftData event,
  ) => _EventCard(
    key: const ValueKey<String>('event-step-basics'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        taxonomySection,
        const SizedBox(height: 12),
        EventClassificationSection(
          state: controller.eventClassificationState,
          onArchetypeChanged: controller.selectEventArchetype,
          onPrimaryParticipationChanged:
              controller.selectEventPrimaryParticipation,
          onAdditionalParticipationChanged:
              controller.setEventAdditionalParticipation,
          onOtherReasonChanged: controller.updateEventArchetypeOtherReason,
          onConfirmSuggestion: controller.confirmEventClassificationSuggestion,
          onClear: controller.clearEventClassification,
        ),
        if (controller.eventClassificationEnabled) const SizedBox(height: 12),
        ContentLanguageField(controller: controller),
        const SizedBox(height: 12),
        _TextField(
          id: 'event-title',
          label: context.l10n.createFormEventTitle,
          value: draft.title,
          error: _error(context, 'title'),
          onChanged: controller.updateTitle,
        ),
        _TextField(
          id: 'event-short-description',
          label: context.l10n.createFormShortDescription2,
          value: draft.shortDescription,
          minLines: 2,
          maxLines: 3,
          error: _error(context, 'shortDescription'),
          onChanged: controller.updateShortDescription,
        ),
        _TextField(
          id: 'event-full-description',
          label: context.l10n.createFormFullDescription,
          value: draft.fullDescription,
          minLines: 3,
          maxLines: 6,
          onChanged: controller.updateFullDescription,
        ),
        CreateMediaPickActions(
          controller: controller,
          target: CreateMediaTarget.cover,
        ),
        if (showCreateMediaPathField(controller))
          _TextField(
            id: 'event-cover',
            label: context.l10n.createFormCoverImageUrlPath,
            value: draft.media.coverImage,
            error: _error(context, 'coverImage'),
            onChanged: controller.updateCoverImage,
          ),
        _TextField(
          id: 'event-cover-alt',
          label: context.l10n.createFormCoverDescriptionScreenReaders,
          value: event.mediaMetadata.coverAltText,
          error: _error(context, 'coverAltText'),
          onChanged: (String value) =>
              controller.updateEventMediaMetadata(coverAltText: value),
        ),
        CreateMediaPickActions(
          controller: controller,
          target: CreateMediaTarget.gallery,
        ),
        _EventGalleryEditor(
          showInput: showCreateMediaPathField(controller),
          gallery: draft.media.gallery,
          altText: event.mediaMetadata.galleryAltText,
          onAdd: controller.addGalleryImage,
          onRemoveAt: controller.removeGalleryImageAt,
          onAltChanged: controller.updateEventGalleryAltText,
          errorFor: (String fieldId) => _error(context, fieldId),
        ),
        CheckboxListTile(
          key: const Key('event-media-rights'),
          contentPadding: EdgeInsets.zero,
          value: event.mediaMetadata.rightsConfirmed,
          onChanged: (bool? value) => controller.updateEventMediaMetadata(
            rightsConfirmed: value ?? false,
          ),
          title: Text(context.l10n.createEventMediaRights),
          subtitle: _error(context, 'mediaRights') == null
              ? null
              : Text(
                  _error(context, 'mediaRights')!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
        ),
      ],
    ),
  );

  Widget _schedule(BuildContext context, EventDraftData event) => _EventCard(
    key: const ValueKey<String>('event-step-schedule'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EnumDropdown<EventFormat>(
          id: 'event-format',
          label: context.l10n.createFormFormat,
          value: event.format,
          values: EventFormat.values,
          onChanged: controller.updateEventFormat,
        ),
        if (event.format != EventFormat.online) ...<Widget>[
          _TextField(
            id: 'event-city',
            label: context.l10n.createFormCityRequired,
            value: event.location.city,
            error: _error(context, 'city'),
            onChanged: (String value) =>
                controller.updateEventLocation(city: value),
          ),
          _TextField(
            id: 'event-venue',
            label: context.l10n.createFormVenue,
            value: event.location.venueName ?? '',
            onChanged: (String value) =>
                controller.updateEventLocation(venueName: value),
          ),
          _TextField(
            id: 'event-address',
            label: context.l10n.createFormAddress,
            value: event.location.formattedAddress ?? '',
            error: _error(context, 'location'),
            onChanged: (String value) =>
                controller.updateEventLocation(address: value),
          ),
          _TextField(
            id: 'event-meeting-point',
            label: context.l10n.createFormMeetingPointInstructions,
            value: event.location.meetingPoint ?? '',
            onChanged: (String value) =>
                controller.updateEventLocation(meetingPoint: value),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _TextField(
                  id: 'event-latitude',
                  label: context.l10n.createFormLatitudeRequired,
                  value: event.location.latitude?.toString() ?? '',
                  error: _error(context, 'locationCoordinates'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (String value) => controller.updateEventLocation(
                    latitude: parseLocaleDecimalInput(value),
                    clearLatitude: value.trim().isEmpty,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TextField(
                  id: 'event-longitude',
                  label: context.l10n.createFormLongitudeRequired,
                  value: event.location.longitude?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (String value) => controller.updateEventLocation(
                    longitude: parseLocaleDecimalInput(value),
                    clearLongitude: value.trim().isEmpty,
                  ),
                ),
              ),
            ],
          ),
          CheckboxListTile(
            key: const Key('event-location-pin-confirmed'),
            contentPadding: EdgeInsets.zero,
            value: event.location.pinConfirmed,
            onChanged:
                event.location.latitude == null ||
                    event.location.longitude == null
                ? null
                : (bool? value) => controller.updateEventLocation(
                    pinConfirmed: value ?? false,
                  ),
            title: Text(context.l10n.createFormConfirmPhysicalLocationPin),
            subtitle: _error(context, 'locationPin') == null
                ? null
                : Text(
                    _error(context, 'locationPin')!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
          ),
        ],
        if (event.format != EventFormat.offline) ...<Widget>[
          _EnumDropdown<EventOnlineAccessMode>(
            id: 'event-online-access',
            label: context.l10n.createFormOnlineAccess,
            value: event.onlineAccessMode,
            values: const <EventOnlineAccessMode>[
              EventOnlineAccessMode.publicLink,
              EventOnlineAccessMode.externalRegistration,
            ],
            error: _error(context, 'onlineAccessMode'),
            onChanged: (EventOnlineAccessMode value) =>
                controller.updateEventOnlineAccess(mode: value),
          ),
          if (event.onlineAccessMode == EventOnlineAccessMode.publicLink)
            _TextField(
              id: 'event-public-url',
              label: context.l10n.createFormPublicHttpsEventUrl,
              value: event.publicOnlineUrl ?? '',
              error: _error(context, 'publicOnlineUrl'),
              onChanged: (String value) =>
                  controller.updateEventOnlineAccess(publicUrl: value),
            ),
        ],
        const Divider(height: 28),
        _EnumDropdown<EventScheduleMode>(
          id: 'event-schedule-mode',
          label: context.l10n.createFormScheduleMode,
          value: event.scheduleMode,
          values: EventScheduleMode.values,
          onChanged: (EventScheduleMode value) =>
              controller.updateEventSchedule(mode: value),
        ),
        SwitchListTile(
          key: const Key('event-all-day'),
          contentPadding: EdgeInsets.zero,
          value: event.allDay,
          onChanged: (bool value) =>
              controller.updateEventSchedule(allDay: value),
          title: Text(context.l10n.createEventAllDay),
        ),
        _TextField(
          id: 'event-local-date',
          label: context.l10n.createFormFirstLocalDateYyyyMmDd,
          value: event.localStartDate,
          error: _error(context, 'localStartDate'),
          onChanged: (String value) =>
              controller.updateEventSchedule(localStartDate: value),
        ),
        if (!event.allDay)
          _TextField(
            id: 'event-local-time',
            label: context.l10n.createFormLocalStartTimeHhMm,
            value: _time(event.startMinute),
            error: _error(context, 'startMinute'),
            onChanged: (String value) {
              final int? minute = parseClockMinute(value);
              if (minute != null) {
                controller.updateEventSchedule(startMinute: minute);
              }
            },
          ),
        _TextField(
          id: 'event-duration',
          label: event.allDay
              ? context.l10n.createFormDurationMinutes14401Day
              : context.l10n.createFormDurationMinutes,
          value: '${event.durationMinutes}',
          error: _error(context, 'durationMinutes'),
          keyboardType: TextInputType.number,
          onChanged: (String value) => controller.updateEventSchedule(
            durationMinutes: int.tryParse(value),
          ),
        ),
        _TextField(
          id: 'event-timezone',
          label: context.l10n.createEventIanaTimezone,
          value: event.timezoneId,
          error: _error(context, 'timezoneId'),
          onChanged: (String value) =>
              controller.updateEventSchedule(timezoneId: value),
        ),
        if (event.scheduleMode == EventScheduleMode.multiDate)
          _TextField(
            id: 'event-multi-dates',
            label: context.l10n.createFormDatesSeparatedByCommas,
            value: event.multiDateLocalDates.join(', '),
            error: _error(context, 'multiDateLocalDates'),
            onChanged: (String value) =>
                controller.updateEventMultiDates(value.split(',')),
          ),
        if (event.scheduleMode == EventScheduleMode.recurring)
          _recurrence(context, event),
        if (event.occurrences.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            context.l10n.createEventOccurrencesCount(event.occurrences.length),
            key: const Key('event-occurrence-count'),
          ),
          Text(
            '${context.l10n.createEventNextDateLabel}: '
            '${RechargeFormats.dateTime(event.occurrences.first.startAtUtc, event.timezoneId, context.l10n.localeName)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );

  Widget _recurrence(BuildContext context, EventDraftData event) {
    final EventRecurrenceRuleDraft rule =
        event.recurrence ??
        const EventRecurrenceRuleDraft(
          frequency: EventRecurrenceFrequency.weekly,
          weekdays: <int>{6},
        );
    if (event.recurrence == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.updateEventRecurrence(rule);
      });
    }
    return Column(
      children: <Widget>[
        _EnumDropdown<EventRecurrenceFrequency>(
          id: 'event-recurrence-frequency',
          label: context.l10n.createFormRepeat,
          value: rule.frequency,
          values: EventRecurrenceFrequency.values,
          onChanged: (EventRecurrenceFrequency value) =>
              controller.updateEventRecurrence(rule.copyWith(frequency: value)),
        ),
        _TextField(
          id: 'event-recurrence-interval',
          label: context.l10n.createFormEveryNPeriods,
          value: '${rule.interval}',
          keyboardType: TextInputType.number,
          onChanged: (String value) {
            final int? interval = int.tryParse(value);
            if (interval != null) {
              controller.updateEventRecurrence(
                rule.copyWith(interval: interval),
              );
            }
          },
        ),
        if (rule.frequency == EventRecurrenceFrequency.weekly)
          Wrap(
            spacing: 6,
            children: List<Widget>.generate(7, (int index) {
              final int weekday = index + 1;
              return CreateFlowChip(
                key: Key('event-weekday-$weekday'),
                label: RechargeFormats.weekdayShort(
                  weekday,
                  Localizations.localeOf(context).languageCode,
                ),
                selected: rule.weekdays.contains(weekday),
                onSelected: (bool selected) {
                  final Set<int> days = <int>{...rule.weekdays};
                  selected ? days.add(weekday) : days.remove(weekday);
                  controller.updateEventRecurrence(
                    rule.copyWith(weekdays: days),
                  );
                },
              );
            }),
          ),
        _EnumDropdown<EventRecurrenceEndMode>(
          id: 'event-recurrence-end',
          label: context.l10n.createFormEnds,
          value: rule.endMode,
          values: EventRecurrenceEndMode.values,
          onChanged: (EventRecurrenceEndMode value) =>
              controller.updateEventRecurrence(rule.copyWith(endMode: value)),
        ),
        if (rule.endMode == EventRecurrenceEndMode.untilDate)
          _TextField(
            id: 'event-recurrence-until',
            label: context.l10n.createFormUntilLocalDate,
            value: rule.untilLocalDate ?? '',
            error: _error(context, 'untilLocalDate'),
            onChanged: (String value) => controller.updateEventRecurrence(
              rule.copyWith(untilLocalDate: value),
            ),
          ),
        if (rule.endMode == EventRecurrenceEndMode.occurrenceCount)
          _TextField(
            id: 'event-recurrence-count',
            label: context.l10n.createFormOccurrenceCount,
            value: '${rule.occurrenceCount ?? 8}',
            error: _error(context, 'occurrenceCount'),
            keyboardType: TextInputType.number,
            onChanged: (String value) => controller.updateEventRecurrence(
              rule.copyWith(occurrenceCount: int.tryParse(value)),
            ),
          ),
        _TextField(
          id: 'event-recurrence-exceptions',
          label: context.l10n.createFormExcludedDatesCommaSeparated,
          value: rule.exceptionLocalDates.join(', '),
          error: _error(context, 'exceptionLocalDates'),
          onChanged: (String value) => controller.updateEventRecurrence(
            rule.copyWith(
              exceptionLocalDates: value
                  .split(',')
                  .map((String item) => item.trim())
                  .where((String item) => item.isNotEmpty)
                  .toSet(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _requirements(BuildContext context, EventDraftData event) =>
      _EventCard(
        key: const ValueKey<String>('event-step-requirements'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _TextField(
              id: 'event-requirements',
              label: context.l10n.createFormWhatAttendeesShouldKnowBring,
              value: event.requirements,
              minLines: 2,
              maxLines: 4,
              onChanged: controller.updateEventRequirements,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: eventAmenityTaxonomy
                  .map(
                    (EventAmenityDefinition item) => CreateFlowChip(
                      key: Key('event-amenity-${item.id}'),
                      label: context.l10n.createAmenityLabel(item.id),
                      selected: event.amenityIds.contains(item.id),
                      onSelected: (bool selected) =>
                          controller.setEventAmenity(item.id, selected),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _TextField(
                    id: 'event-age-min',
                    label: context.l10n.createFormMinimumAge,
                    value: event.ageMin?.toString() ?? '',
                    error: _error(context, 'ageMin'),
                    keyboardType: TextInputType.number,
                    onChanged: (String value) => controller.updateEventAudience(
                      ageMin: int.tryParse(value),
                      clearAgeMin: value.trim().isEmpty,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TextField(
                    id: 'event-age-max',
                    label: context.l10n.createFormMaximumAge,
                    value: event.ageMax?.toString() ?? '',
                    error: _error(context, 'ageMax'),
                    keyboardType: TextInputType.number,
                    onChanged: (String value) => controller.updateEventAudience(
                      ageMax: int.tryParse(value),
                      clearAgeMax: value.trim().isEmpty,
                    ),
                  ),
                ),
              ],
            ),
            _Flag(
              label: context.l10n.createFormFamilyFriendly,
              value: event.familyFriendly,
              onChanged: (bool value) =>
                  controller.updateEventAudience(familyFriendly: value),
            ),
            _Flag(
              label: context.l10n.createFormKidsAllowed,
              value: event.kidsAllowed,
              onChanged: (bool value) =>
                  controller.updateEventAudience(kidsAllowed: value),
            ),
            _Flag(
              label: context.l10n.createFormPetsAllowed,
              value: event.petFriendly,
              onChanged: (bool value) =>
                  controller.updateEventAudience(petFriendly: value),
            ),
            _Flag(
              label: context.l10n.createFormPartialAttendanceAllowed,
              value: event.allowsPartialAttendance,
              onChanged: (bool value) => controller.updateEventAudience(
                allowsPartialAttendance: value,
              ),
            ),
          ],
        ),
      );

  Widget _price(BuildContext context, EventDraftData event) => _EventCard(
    key: const ValueKey<String>('event-step-price'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EnumDropdown<EventPricingMode>(
          id: 'event-pricing-mode',
          label: context.l10n.createFormPricing,
          value: event.pricingMode,
          values: const <EventPricingMode>[
            EventPricingMode.free,
            EventPricingMode.fixed,
          ],
          error: _error(context, 'pricingMode'),
          onChanged: (EventPricingMode value) => controller.updateEventPricing(
            mode: value,
            collectionMode: value == EventPricingMode.free
                ? EventPaymentCollectionMode.none
                : EventPaymentCollectionMode.onsite,
          ),
        ),
        if (event.pricingMode == EventPricingMode.fixed) ...<Widget>[
          _TextField(
            id: 'event-price',
            label: context.l10n.createEventPriceIn(event.currencyCode),
            value: event.price == null
                ? ''
                : (event.price!.amountMinor / 100).toStringAsFixed(2),
            error: _error(context, 'price'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String value) => controller.updateEventPricing(
              mode: EventPricingMode.fixed,
              collectionMode: event.paymentCollectionMode,
              amountMinor: _minor(value),
            ),
          ),
          _EnumDropdown<EventPaymentCollectionMode>(
            id: 'event-payment-collection',
            label: context.l10n.createFormPaymentCollection,
            value: event.paymentCollectionMode,
            values: const <EventPaymentCollectionMode>[
              EventPaymentCollectionMode.onsite,
              EventPaymentCollectionMode.external,
            ],
            error: _error(context, 'paymentCollectionMode'),
            onChanged: (EventPaymentCollectionMode value) =>
                controller.updateEventPricing(
                  mode: EventPricingMode.fixed,
                  collectionMode: value,
                ),
          ),
        ],
        if (controller.eventAdmissionConfigurationEnabled) ...<Widget>[
          EventAdmissionSection(
            state: controller.eventAdmissionState,
            controller: controller,
            externalRegistrationUrl: event.externalBookingUrl,
          ),
          EventInventorySection(
            state: controller.eventInventoryState,
            controller: controller,
          ),
        ] else ...<Widget>[
          _EnumDropdown<EventCapacityMode>(
            id: 'event-capacity-mode',
            label: context.l10n.createFormCapacity,
            value: event.capacityMode,
            values: EventCapacityMode.values,
            onChanged: (EventCapacityMode value) =>
                controller.updateEventCapacity(value, capacity: event.capacity),
          ),
          if (event.capacityMode == EventCapacityMode.known)
            _TextField(
              id: 'event-capacity',
              label: context.l10n.createFormMaximumParticipants,
              value: event.capacity?.toString() ?? '',
              error: _error(context, 'capacity'),
              keyboardType: TextInputType.number,
              onChanged: (String value) => controller.updateEventCapacity(
                EventCapacityMode.known,
                capacity: int.tryParse(value),
              ),
            ),
          _EnumDropdown<EventRegistrationMode>(
            id: 'event-registration-mode',
            label: context.l10n.createFormRegistration,
            value: event.registrationMode,
            values: const <EventRegistrationMode>[
              EventRegistrationMode.none,
              EventRegistrationMode.external,
            ],
            error: _error(context, 'registrationMode'),
            onChanged: (EventRegistrationMode value) =>
                controller.updateEventRegistration(mode: value),
          ),
          if (event.registrationMode == EventRegistrationMode.external)
            _TextField(
              id: 'event-booking-url',
              label: context.l10n.createFormExternalHttpsRegistrationUrl,
              value: event.externalBookingUrl ?? '',
              error: _error(context, 'externalBookingUrl'),
              onChanged: (String value) => controller.updateEventRegistration(
                mode: EventRegistrationMode.external,
                externalBookingUrl: value,
              ),
            ),
        ],
        _EnumDropdown<EventVisibility>(
          id: 'event-visibility',
          label: context.l10n.createFormVisibility,
          value: event.visibility,
          values: const <EventVisibility>[
            EventVisibility.public,
            EventVisibility.unlisted,
          ],
          error: _error(context, 'visibility'),
          onChanged: controller.updateEventVisibility,
        ),
      ],
    ),
  );

  Widget _preview(
    BuildContext context,
    CreateDraftEntity draft,
    EventDraftData event,
  ) {
    final List<EventValidationIssue> blocking = state.eventValidationIssues
        .where((EventValidationIssue issue) => issue.isBlocking)
        .toList(growable: false);
    return _EventCard(
      key: const ValueKey<String>('event-step-preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            draft.title.isEmpty
                ? context.l10n.createFormUntitledEvent
                : draft.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            taxonomyLabel(
              context.l10n,
              '${draft.mainCategory}.${draft.subcategory}',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${createOptionText(context.l10n, event.format)} · '
            '${createOptionText(context.l10n, event.scheduleMode)}',
          ),
          // The IANA zone id is shown as is: it names the event's zone.
          Text(
            '${context.l10n.createFormOccurrences(event.occurrences.length)} · '
            '${event.timezoneId}',
          ),
          Text(
            event.pricingMode == EventPricingMode.free
                ? context.l10n.createFormFree
                : RechargeFormats.money(
                    Money(
                      minorUnits: event.price?.amountMinor ?? 0,
                      currencyCode: event.currencyCode,
                    ),
                    Localizations.localeOf(context).languageCode,
                  ),
          ),
          Text(
            context.l10n.createFormAdmissionLine(
              <String>[
                if (event.admission?.admissionMode case final mode?)
                  createOptionText(context.l10n, mode),
                createOptionText(
                  context.l10n,
                  event.admission?.registrationMode ?? event.registrationMode,
                ),
              ].join(' · '),
            ),
          ),
          Text(
            context.l10n.createFormVisibilityLine(
              createOptionText(context.l10n, event.visibility),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            blocking.isEmpty
                ? context.l10n.createFormPublishableLocalMockModerationPipeline
                : context.l10n.createFormBlockingIssues(blocking.length),
            key: const Key('event-publish-readiness'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: blocking.isEmpty
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('event-publish-button'),
            onPressed: state.status == CreateStatus.publishing
                ? null
                : () async {
                    final bool published = await controller.publishDraft();
                    if (published) onPublished();
                  },
            icon: const Icon(Icons.publish_outlined),
            label: Text(
              state.status == CreateStatus.publishing
                  ? context.l10n.createFormSending
                  : context.l10n.createFormSendReview,
            ),
          ),
        ],
      ),
    );
  }

  Widget _issues(BuildContext context, int step) {
    final List<EventValidationIssue> issues = state.eventValidationIssues
        .where((EventValidationIssue issue) => issue.step == step)
        .toList(growable: false);
    if (issues.isEmpty) return const SizedBox.shrink();
    return _EventCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: issues
            .map(
              (EventValidationIssue issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${CreateTexts.event(context.l10n, issue)}',
                  style: TextStyle(
                    color: issue.isBlocking
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  // Step 4 (preview) has its own dedicated "Send for review" CTA inside
  // _preview(), so the shared bottom bar only offers Back/Save draft there.
  Widget _navigation(BuildContext context, int step) => step < 4
      ? CreateFlowBottomBar(
          onBackPressed: step > 0
              ? () => controller.goToEventStep(step - 1)
              : null,
          backKey: const Key('event-step-back'),
          secondaryLabel: context.l10n.createFormSaveDraft,
          secondaryKey: const Key('event-save-draft'),
          onSecondaryPressed: state.status == CreateStatus.saving
              ? null
              : controller.saveDraft,
          primaryKey: const Key('event-step-next'),
          primaryLabel: context.l10n.createFormContinue,
          onPrimaryPressed: () => controller.goToEventStep(step + 1),
        )
      : Row(
          children: <Widget>[
            Expanded(
              child: TextButton.icon(
                key: const Key('event-step-back'),
                onPressed: () => controller.goToEventStep(step - 1),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(context.l10n.createFormBack),
                style: TextButton.styleFrom(
                  foregroundColor: RechargeTheme.mutedInk,
                ),
              ),
            ),
            Expanded(
              child: TextButton(
                key: const Key('event-save-draft'),
                onPressed: state.status == CreateStatus.saving
                    ? null
                    : controller.saveDraft,
                style: TextButton.styleFrom(
                  foregroundColor: RechargeTheme.emerald900,
                ),
                child: Text(context.l10n.createFormSaveDraft),
              ),
            ),
          ],
        );

  String? _error(BuildContext context, String fieldId) {
    for (final EventValidationIssue issue in state.eventValidationIssues) {
      if (issue.fieldId == fieldId && issue.isBlocking) {
        return CreateTexts.event(context.l10n, issue);
      }
    }
    return switch (state.validationErrors[fieldId]) {
      final String id => CreateTexts.fieldError(context.l10n, id),
      null => null,
    };
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CreateFlowSection(child: child);
}

class _EventGalleryEditor extends StatefulWidget {
  const _EventGalleryEditor({
    required this.showInput,
    required this.gallery,
    required this.altText,
    required this.onAdd,
    required this.onRemoveAt,
    required this.onAltChanged,
    required this.errorFor,
  });

  /// MP-OD-04: the URL/path input only in debug or with the picker off.
  final bool showInput;
  final List<String> gallery;
  final Map<String, String> altText;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemoveAt;
  final void Function(String mediaReference, String value) onAltChanged;
  final String? Function(String fieldId) errorFor;

  @override
  State<_EventGalleryEditor> createState() => _EventGalleryEditorState();
}

class _EventGalleryEditorState extends State<_EventGalleryEditor> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (widget.showInput)
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                key: const Key('event-gallery-input'),
                controller: _input,
                decoration: InputDecoration(
                  labelText: context.l10n.createFormGalleryImageUrlPath,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              key: const Key('event-gallery-add'),
              tooltip: context.l10n.createFormAddGalleryImage,
              onPressed: () {
                final String value = _input.text.trim();
                if (value.isEmpty) return;
                widget.onAdd(value);
                _input.clear();
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
          ],
        ),
      const SizedBox(height: 10),
      for (int index = 0; index < widget.gallery.length; index++) ...<Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _TextField(
                id: 'event-gallery-alt-$index',
                label: context.l10n.createFormGalleryImageDescription(
                  index + 1,
                ),
                value: widget.altText[widget.gallery[index]] ?? '',
                error: widget.errorFor(
                  'galleryAlt:${widget.gallery[index]}', // l10n-ignore: field id
                ),
                onChanged: (String value) =>
                    widget.onAltChanged(widget.gallery[index], value),
              ),
            ),
            IconButton(
              key: Key('event-gallery-remove-$index'),
              tooltip: context.l10n.createFormRemoveGalleryImage(index + 1),
              onPressed: () => widget.onRemoveAt(index),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ],
    ],
  );
}

class _TextField extends StatefulWidget {
  const _TextField({
    required this.id,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.minLines,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String id;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? error;
  final int? minLines;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _TextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && _controller.text != widget.value) {
      _replaceText(widget.value);
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _controller.text != widget.value) {
      _replaceText(widget.value);
    }
  }

  void _replaceText(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      key: Key(widget.id),
      controller: _controller,
      focusNode: _focusNode,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.error,
        filled: true,
        fillColor: RechargeTheme.createSoftGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: RechargeTheme.emerald900,
            width: 1.6,
          ),
        ),
      ),
      onChanged: widget.onChanged,
    ),
  );
}

class _EnumDropdown<T extends Enum> extends StatelessWidget {
  const _EnumDropdown({
    required this.id,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
    this.error,
  });

  final String id;
  final String label;
  final T? value;
  final List<T> values;
  final ValueChanged<T> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<T>(
      key: Key(id),
      isExpanded: true,
      initialValue: values.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        filled: true,
        fillColor: RechargeTheme.createSoftGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: RechargeTheme.emerald900,
            width: 1.6,
          ),
        ),
      ),
      items: values
          .map(
            (T item) => DropdownMenuItem<T>(
              value: item,
              child: Text(createOptionText(context.l10n, item as Enum)),
            ),
          )
          .toList(growable: false),
      onChanged: (T? value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}

class _Flag extends StatelessWidget {
  const _Flag({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    value: value,
    onChanged: onChanged,
  );
}

String _time(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

int? _minor(String value) {
  final double? parsed = parseLocaleDecimalInput(value);
  return parsed == null ? null : (parsed * 100).round();
}
