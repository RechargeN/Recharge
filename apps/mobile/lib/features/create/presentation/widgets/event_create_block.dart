import 'package:flutter/material.dart';

import '../../application/controllers/create_controller.dart';
import '../../application/event_create_config.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/event_draft_data.dart';
import '../../domain/entities/event_validation_issue.dart';
import 'event_template_panel.dart';

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
      return const _EventCard(
        child: Text('Event draft is unavailable. Reopen Create Hub.'),
      );
    }
    final int step = state.eventStep;
    return Column(
      key: const Key('event-create-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EventTemplatePanel(controller: controller),
        const SizedBox(height: 12),
        _StepHeader(step: step, onSelected: controller.goToEventStep),
        const SizedBox(height: 12),
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
        _navigation(step),
      ],
    );
  }

  Widget _basics(
    BuildContext context,
    CreateDraftEntity draft,
    EventDraftData event,
  ) => _EventCard(
    key: const ValueKey<String>('event-step-basics'),
    title: '1. Basics & media',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        taxonomySection,
        const SizedBox(height: 12),
        _TextField(
          id: 'event-title',
          label: 'Event title *',
          value: draft.title,
          error: _error('title'),
          onChanged: controller.updateTitle,
        ),
        _TextField(
          id: 'event-short-description',
          label: 'Short description *',
          value: draft.shortDescription,
          minLines: 2,
          maxLines: 3,
          error: _error('shortDescription'),
          onChanged: controller.updateShortDescription,
        ),
        _TextField(
          id: 'event-full-description',
          label: 'Full description',
          value: draft.fullDescription,
          minLines: 3,
          maxLines: 6,
          onChanged: controller.updateFullDescription,
        ),
        _TextField(
          id: 'event-cover',
          label: 'Cover image URL/path *',
          value: draft.media.coverImage,
          error: _error('coverImage'),
          onChanged: controller.updateCoverImage,
        ),
        _TextField(
          id: 'event-cover-alt',
          label: 'Cover description for screen readers *',
          value: event.mediaMetadata.coverAltText,
          error: _error('coverAltText'),
          onChanged: (String value) =>
              controller.updateEventMediaMetadata(coverAltText: value),
        ),
        _EventGalleryEditor(
          gallery: draft.media.gallery,
          altText: event.mediaMetadata.galleryAltText,
          onAdd: controller.addGalleryImage,
          onRemoveAt: controller.removeGalleryImageAt,
          onAltChanged: controller.updateEventGalleryAltText,
          errorFor: _error,
        ),
        CheckboxListTile(
          key: const Key('event-media-rights'),
          contentPadding: EdgeInsets.zero,
          value: event.mediaMetadata.rightsConfirmed,
          onChanged: (bool? value) => controller.updateEventMediaMetadata(
            rightsConfirmed: value ?? false,
          ),
          title: const Text('I have the right to publish this media *'),
          subtitle: _error('mediaRights') == null
              ? null
              : Text(
                  _error('mediaRights')!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
        ),
      ],
    ),
  );

  Widget _schedule(BuildContext context, EventDraftData event) => _EventCard(
    key: const ValueKey<String>('event-step-schedule'),
    title: '2. Location & schedule',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EnumDropdown<EventFormat>(
          id: 'event-format',
          label: 'Format',
          value: event.format,
          values: EventFormat.values,
          onChanged: controller.updateEventFormat,
        ),
        if (event.format != EventFormat.online) ...<Widget>[
          _TextField(
            id: 'event-city',
            label: 'City *',
            value: event.location.city,
            error: _error('city'),
            onChanged: (String value) =>
                controller.updateEventLocation(city: value),
          ),
          _TextField(
            id: 'event-venue',
            label: 'Venue',
            value: event.location.venueName ?? '',
            onChanged: (String value) =>
                controller.updateEventLocation(venueName: value),
          ),
          _TextField(
            id: 'event-address',
            label: 'Address',
            value: event.location.formattedAddress ?? '',
            error: _error('location'),
            onChanged: (String value) =>
                controller.updateEventLocation(address: value),
          ),
          _TextField(
            id: 'event-meeting-point',
            label: 'Meeting point instructions',
            value: event.location.meetingPoint ?? '',
            onChanged: (String value) =>
                controller.updateEventLocation(meetingPoint: value),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _TextField(
                  id: 'event-latitude',
                  label: 'Latitude *',
                  value: event.location.latitude?.toString() ?? '',
                  error: _error('locationCoordinates'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (String value) => controller.updateEventLocation(
                    latitude: double.tryParse(value.replaceAll(',', '.')),
                    clearLatitude: value.trim().isEmpty,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TextField(
                  id: 'event-longitude',
                  label: 'Longitude *',
                  value: event.location.longitude?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (String value) => controller.updateEventLocation(
                    longitude: double.tryParse(value.replaceAll(',', '.')),
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
            title: const Text('Confirm this physical location pin *'),
            subtitle: _error('locationPin') == null
                ? null
                : Text(
                    _error('locationPin')!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
          ),
        ],
        if (event.format != EventFormat.offline) ...<Widget>[
          _EnumDropdown<EventOnlineAccessMode>(
            id: 'event-online-access',
            label: 'Online access',
            value: event.onlineAccessMode,
            values: const <EventOnlineAccessMode>[
              EventOnlineAccessMode.publicLink,
              EventOnlineAccessMode.externalRegistration,
            ],
            error: _error('onlineAccessMode'),
            onChanged: (EventOnlineAccessMode value) =>
                controller.updateEventOnlineAccess(mode: value),
          ),
          if (event.onlineAccessMode == EventOnlineAccessMode.publicLink)
            _TextField(
              id: 'event-public-url',
              label: 'Public HTTPS event URL *',
              value: event.publicOnlineUrl ?? '',
              error: _error('publicOnlineUrl'),
              onChanged: (String value) =>
                  controller.updateEventOnlineAccess(publicUrl: value),
            ),
        ],
        const Divider(height: 28),
        _EnumDropdown<EventScheduleMode>(
          id: 'event-schedule-mode',
          label: 'Schedule mode',
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
          title: const Text('All-day event'),
        ),
        _TextField(
          id: 'event-local-date',
          label: 'First local date (YYYY-MM-DD)',
          value: event.localStartDate,
          error: _error('localStartDate'),
          onChanged: (String value) =>
              controller.updateEventSchedule(localStartDate: value),
        ),
        if (!event.allDay)
          _TextField(
            id: 'event-local-time',
            label: 'Local start time (HH:mm)',
            value: _time(event.startMinute),
            error: _error('startMinute'),
            onChanged: (String value) {
              final int? minute = _minute(value);
              if (minute != null) {
                controller.updateEventSchedule(startMinute: minute);
              }
            },
          ),
        _TextField(
          id: 'event-duration',
          label: event.allDay
              ? 'Duration in minutes (1440 = 1 day)'
              : 'Duration in minutes',
          value: '${event.durationMinutes}',
          error: _error('durationMinutes'),
          keyboardType: TextInputType.number,
          onChanged: (String value) => controller.updateEventSchedule(
            durationMinutes: int.tryParse(value),
          ),
        ),
        _TextField(
          id: 'event-timezone',
          label: 'IANA timezone',
          value: event.timezoneId,
          error: _error('timezoneId'),
          onChanged: (String value) =>
              controller.updateEventSchedule(timezoneId: value),
        ),
        if (event.scheduleMode == EventScheduleMode.multiDate)
          _TextField(
            id: 'event-multi-dates',
            label: 'Dates separated by commas',
            value: event.multiDateLocalDates.join(', '),
            error: _error('multiDateLocalDates'),
            onChanged: (String value) =>
                controller.updateEventMultiDates(value.split(',')),
          ),
        if (event.scheduleMode == EventScheduleMode.recurring)
          _recurrence(event),
        if (event.occurrences.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '${event.occurrences.length} occurrence(s) materialized',
            key: const Key('event-occurrence-count'),
          ),
          Text(
            'Next: ${event.occurrences.first.startAtUtc.toIso8601String()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );

  Widget _recurrence(EventDraftData event) {
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
          label: 'Repeat',
          value: rule.frequency,
          values: EventRecurrenceFrequency.values,
          onChanged: (EventRecurrenceFrequency value) =>
              controller.updateEventRecurrence(rule.copyWith(frequency: value)),
        ),
        _TextField(
          id: 'event-recurrence-interval',
          label: 'Every N periods',
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
              return FilterChip(
                key: Key('event-weekday-$weekday'),
                label: Text(
                  const <String>[
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ][index],
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
          label: 'Ends',
          value: rule.endMode,
          values: EventRecurrenceEndMode.values,
          onChanged: (EventRecurrenceEndMode value) =>
              controller.updateEventRecurrence(rule.copyWith(endMode: value)),
        ),
        if (rule.endMode == EventRecurrenceEndMode.untilDate)
          _TextField(
            id: 'event-recurrence-until',
            label: 'Until local date',
            value: rule.untilLocalDate ?? '',
            error: _error('untilLocalDate'),
            onChanged: (String value) => controller.updateEventRecurrence(
              rule.copyWith(untilLocalDate: value),
            ),
          ),
        if (rule.endMode == EventRecurrenceEndMode.occurrenceCount)
          _TextField(
            id: 'event-recurrence-count',
            label: 'Occurrence count',
            value: '${rule.occurrenceCount ?? 8}',
            error: _error('occurrenceCount'),
            keyboardType: TextInputType.number,
            onChanged: (String value) => controller.updateEventRecurrence(
              rule.copyWith(occurrenceCount: int.tryParse(value)),
            ),
          ),
        _TextField(
          id: 'event-recurrence-exceptions',
          label: 'Excluded dates, comma-separated',
          value: rule.exceptionLocalDates.join(', '),
          error: _error('exceptionLocalDates'),
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
        title: '3. Requirements & amenities',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _TextField(
              id: 'event-requirements',
              label: 'What attendees should know or bring',
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
                    (EventAmenityDefinition item) => FilterChip(
                      key: Key('event-amenity-${item.id}'),
                      label: Text(item.label),
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
                    label: 'Minimum age',
                    value: event.ageMin?.toString() ?? '',
                    error: _error('ageMin'),
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
                    label: 'Maximum age',
                    value: event.ageMax?.toString() ?? '',
                    error: _error('ageMax'),
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
              label: 'Family friendly',
              value: event.familyFriendly,
              onChanged: (bool value) =>
                  controller.updateEventAudience(familyFriendly: value),
            ),
            _Flag(
              label: 'Kids allowed',
              value: event.kidsAllowed,
              onChanged: (bool value) =>
                  controller.updateEventAudience(kidsAllowed: value),
            ),
            _Flag(
              label: 'Pets allowed',
              value: event.petFriendly,
              onChanged: (bool value) =>
                  controller.updateEventAudience(petFriendly: value),
            ),
            _Flag(
              label: 'Partial attendance allowed',
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
    title: '4. Price & participants',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EnumDropdown<EventPricingMode>(
          id: 'event-pricing-mode',
          label: 'Pricing',
          value: event.pricingMode,
          values: const <EventPricingMode>[
            EventPricingMode.free,
            EventPricingMode.fixed,
          ],
          error: _error('pricingMode'),
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
            label: 'Price (${event.currencyCode})',
            value: event.price == null
                ? ''
                : (event.price!.amountMinor / 100).toStringAsFixed(2),
            error: _error('price'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String value) => controller.updateEventPricing(
              mode: EventPricingMode.fixed,
              collectionMode: event.paymentCollectionMode,
              amountMinor: _minor(value),
            ),
          ),
          _EnumDropdown<EventPaymentCollectionMode>(
            id: 'event-payment-collection',
            label: 'Payment collection',
            value: event.paymentCollectionMode,
            values: const <EventPaymentCollectionMode>[
              EventPaymentCollectionMode.onsite,
              EventPaymentCollectionMode.external,
            ],
            error: _error('paymentCollectionMode'),
            onChanged: (EventPaymentCollectionMode value) =>
                controller.updateEventPricing(
                  mode: EventPricingMode.fixed,
                  collectionMode: value,
                ),
          ),
        ],
        _EnumDropdown<EventCapacityMode>(
          id: 'event-capacity-mode',
          label: 'Capacity',
          value: event.capacityMode,
          values: EventCapacityMode.values,
          onChanged: (EventCapacityMode value) =>
              controller.updateEventCapacity(value, capacity: event.capacity),
        ),
        if (event.capacityMode == EventCapacityMode.known)
          _TextField(
            id: 'event-capacity',
            label: 'Maximum participants',
            value: event.capacity?.toString() ?? '',
            error: _error('capacity'),
            keyboardType: TextInputType.number,
            onChanged: (String value) => controller.updateEventCapacity(
              EventCapacityMode.known,
              capacity: int.tryParse(value),
            ),
          ),
        _EnumDropdown<EventRegistrationMode>(
          id: 'event-registration-mode',
          label: 'Registration',
          value: event.registrationMode,
          values: const <EventRegistrationMode>[
            EventRegistrationMode.none,
            EventRegistrationMode.external,
          ],
          error: _error('registrationMode'),
          onChanged: (EventRegistrationMode value) =>
              controller.updateEventRegistration(mode: value),
        ),
        if (event.registrationMode == EventRegistrationMode.external)
          _TextField(
            id: 'event-booking-url',
            label: 'External HTTPS registration URL',
            value: event.externalBookingUrl ?? '',
            error: _error('externalBookingUrl'),
            onChanged: (String value) => controller.updateEventRegistration(
              mode: EventRegistrationMode.external,
              externalBookingUrl: value,
            ),
          ),
        _EnumDropdown<EventVisibility>(
          id: 'event-visibility',
          label: 'Visibility',
          value: event.visibility,
          values: const <EventVisibility>[
            EventVisibility.public,
            EventVisibility.unlisted,
          ],
          error: _error('visibility'),
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
      title: '5. Preview & publish',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            draft.title.isEmpty ? 'Untitled event' : draft.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('${draft.mainCategory} / ${draft.subcategory}'),
          const SizedBox(height: 8),
          Text('${event.format.name} · ${event.scheduleMode.name}'),
          Text(
            '${event.occurrences.length} occurrence(s) · ${event.timezoneId}',
          ),
          Text(
            event.pricingMode == EventPricingMode.free
                ? 'Free'
                : '${event.price?.amountMinor ?? 0} minor ${event.currencyCode}',
          ),
          Text('Registration: ${event.registrationMode.name}'),
          Text('Visibility: ${event.visibility.name}'),
          const SizedBox(height: 12),
          Text(
            blocking.isEmpty
                ? 'Publishable on local/mock moderation pipeline'
                : '${blocking.length} blocking issue(s)',
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
                  ? 'Sending…'
                  : 'Send for review',
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
                  '• ${issue.message}',
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

  Widget _navigation(int step) => Row(
    children: <Widget>[
      if (step > 0)
        Expanded(
          child: OutlinedButton(
            key: const Key('event-step-back'),
            onPressed: () => controller.goToEventStep(step - 1),
            child: const Text('Back'),
          ),
        ),
      if (step > 0) const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          key: const Key('event-save-draft'),
          onPressed: state.status == CreateStatus.saving
              ? null
              : controller.saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save draft'),
        ),
      ),
      if (step < 4) ...<Widget>[
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            key: const Key('event-step-next'),
            onPressed: () => controller.goToEventStep(step + 1),
            child: const Text('Continue'),
          ),
        ),
      ],
    ],
  );

  String? _error(String fieldId) {
    for (final EventValidationIssue issue in state.eventValidationIssues) {
      if (issue.fieldId == fieldId && issue.isBlocking) return issue.message;
    }
    return state.validationErrors[fieldId];
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.onSelected});

  final int step;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Event creation step ${step + 1} of ${eventCreateSteps.length}',
    child: SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: eventCreateSteps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final EventCreateStepConfig item = eventCreateSteps[index];
          return ChoiceChip(
            key: Key('event-step-${item.id}'),
            selected: step == index,
            onSelected: (_) => onSelected(index),
            label: SizedBox(
              width: 118,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.title, overflow: TextOverflow.ellipsis),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    ),
  );
}

class _EventGalleryEditor extends StatefulWidget {
  const _EventGalleryEditor({
    required this.gallery,
    required this.altText,
    required this.onAdd,
    required this.onRemoveAt,
    required this.onAltChanged,
    required this.errorFor,
  });

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
      Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              key: const Key('event-gallery-input'),
              controller: _input,
              decoration: const InputDecoration(
                labelText: 'Gallery image URL/path',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const Key('event-gallery-add'),
            tooltip: 'Add gallery image',
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
                label: 'Gallery image ${index + 1} description *',
                value: widget.altText[widget.gallery[index]] ?? '',
                error: widget.errorFor('galleryAlt:${widget.gallery[index]}'),
                onChanged: (String value) =>
                    widget.onAltChanged(widget.gallery[index], value),
              ),
            ),
            IconButton(
              key: Key('event-gallery-remove-$index'),
              tooltip: 'Remove gallery image ${index + 1}',
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
        border: const OutlineInputBorder(),
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
      value: values.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        border: const OutlineInputBorder(),
      ),
      items: values
          .map(
            (T item) => DropdownMenuItem<T>(
              value: item,
              child: Text(_enumLabel(item.name)),
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

String _enumLabel(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (Match match) => '${match.group(1)} ${match.group(2)}',
    )
    .replaceAll('_', ' ')
    .toLowerCase();

String _time(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

int? _minute(String value) {
  final List<String> parts = value.trim().split(':');
  if (parts.length != 2) return null;
  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}

int? _minor(String value) {
  final double? parsed = double.tryParse(value.trim().replaceAll(',', '.'));
  return parsed == null ? null : (parsed * 100).round();
}
