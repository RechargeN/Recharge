import 'package:flutter/material.dart';

import '../../../../core/config/recharge_category_criteria.dart';
import '../../application/controllers/create_controller.dart';
import '../../application/create_taxonomy.dart';
import '../../application/event_create_config.dart';
import '../../application/get_category_criteria_usecase.dart';
import '../../application/session_create_config.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/session_availability_exception.dart';
import '../../domain/entities/session_draft_data.dart';
import '../../domain/entities/session_price_disclosure.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/entities/session_slot_projection.dart';
import '../../domain/entities/session_validation_issue.dart';

/// Bookable Session create block (BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md v1.1
/// §12): guard + three required blocks on one scrollable page, plus a
/// non-blocking "optional" zone — not a step wizard.
class SessionCreateBlock extends StatefulWidget {
  const SessionCreateBlock({
    super.key,
    required this.controller,
    required this.state,
    required this.onPublished,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  State<SessionCreateBlock> createState() => _SessionCreateBlockState();
}

class _SessionCreateBlockState extends State<SessionCreateBlock> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};
  bool _showOptional = false;

  TextEditingController _field(String id, String value) {
    final TextEditingController? existing = _fields[id];
    if (existing != null) {
      if (existing.text != value && !existing.selection.isValid) {
        existing.text = value;
      }
      return existing;
    }
    final TextEditingController created = TextEditingController(text: value);
    _fields[id] = created;
    return created;
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<SessionValidationIssue> get _issues =>
      widget.state.sessionValidationIssues;

  @override
  Widget build(BuildContext context) {
    final CreateDraftEntity draft = widget.state.draft;
    final SessionDraftData? session = draft.sessionData;
    if (session == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Loading Bookable session draft…'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _InfoBanner(),
        _whatAndWhereBlock(draft, session),
        _whenBlock(session),
        _priceAndBookingBlock(session),
        _optionalZone(draft, session),
        if (_issues.any((SessionValidationIssue issue) => issue.isBlocking))
          _blockingIssuesCard(),
        _footer(),
        if (widget.state.message != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.state.message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.state.validationErrors.isEmpty
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // --- Блок 1. Что и где ---

  Widget _whatAndWhereBlock(CreateDraftEntity draft, SessionDraftData session) {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      CreateObjectType.session,
    );
    final CreateTaxonomyCategory? selectedCategory = categories
        .where((CreateTaxonomyCategory item) => item.id == draft.mainCategory)
        .firstOrNull;
    final CreateTaxonomySubcategory? selectedSubcategory = selectedCategory
        ?.subcategories
        .where((CreateTaxonomySubcategory item) => item.id == draft.subcategory)
        .firstOrNull;
    return _BlockCard(
      title: 'What and where',
      required: true,
      children: <Widget>[
        TextFormField(
          controller: _field('title', draft.title),
          decoration: const InputDecoration(labelText: 'Title'),
          onChanged: widget.controller.updateTitle,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CreateTaxonomyCategory>(
          initialValue: selectedCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: <DropdownMenuItem<CreateTaxonomyCategory>>[
            for (final CreateTaxonomyCategory category in categories)
              DropdownMenuItem<CreateTaxonomyCategory>(
                value: category,
                child: Text(category.title),
              ),
          ],
          onChanged: (CreateTaxonomyCategory? category) {
            if (category == null) return;
            final CreateTaxonomySubcategory? defaultSub =
                category.subcategories.firstOrNull;
            widget.controller.applyTaxonomySelection(
              mainCategory: category.id,
              subcategory: defaultSub?.id ?? '',
            );
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CreateTaxonomySubcategory>(
          initialValue: selectedSubcategory,
          decoration: const InputDecoration(labelText: 'Subcategory'),
          items: <DropdownMenuItem<CreateTaxonomySubcategory>>[
            for (final CreateTaxonomySubcategory sub
                in selectedCategory?.subcategories ??
                    const <CreateTaxonomySubcategory>[])
              DropdownMenuItem<CreateTaxonomySubcategory>(
                value: sub,
                child: Text(sub.title),
              ),
          ],
          onChanged: selectedCategory == null
              ? null
              : (CreateTaxonomySubcategory? sub) {
                  if (sub == null) return;
                  widget.controller.applyTaxonomySelection(
                    mainCategory: selectedCategory.id,
                    subcategory: sub.id,
                  );
                },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('shortDescription', draft.shortDescription),
          decoration: const InputDecoration(labelText: 'Short description'),
          onChanged: widget.controller.updateShortDescription,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('fullDescription', draft.fullDescription),
          decoration: const InputDecoration(labelText: 'Full description'),
          maxLines: 4,
          onChanged: widget.controller.updateFullDescription,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('coverImage', draft.media.coverImage),
          decoration: const InputDecoration(labelText: 'Cover image URL'),
          onChanged: widget.controller.updateCoverImage,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('resourceName', session.resourceName),
          decoration: const InputDecoration(
            labelText: 'Resource name (e.g. "Sauna 1")',
          ),
          onChanged: (String value) {
            widget.controller.updateSessionResourceName(value);
            widget.controller.updateVenueName(value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('address', draft.addressLine1),
          decoration: const InputDecoration(labelText: 'Address'),
          onChanged: widget.controller.updateAddress,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('city', draft.city),
          decoration: const InputDecoration(labelText: 'City'),
          onChanged: widget.controller.updateCity,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _field('timezoneId', session.timezoneId),
                decoration: const InputDecoration(
                  labelText: 'Timezone (IANA, e.g. Europe/Riga)',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => widget.controller.confirmSessionTimezone(
                _fields['timezoneId']?.text ?? session.timezoneId,
              ),
              child: Text(session.timezoneConfirmed ? 'Confirmed' : 'Confirm'),
            ),
          ],
        ),
        ..._fieldIssues(<String>{
          'title',
          'categoryId',
          'resourceName',
          'timezoneId',
          'cover',
        }),
      ],
    );
  }

  // --- Блок 2. Когда ---

  Widget _whenBlock(SessionDraftData session) {
    final List<SessionSlotProjection> preview = widget
        .controller
        .sessionSchedulePreview
        .where(
          (SessionSlotProjection p) =>
              p.internalStatus == SessionProjectionStatus.offeredBySchedule,
        )
        .take(7)
        .toList(growable: false);
    return _BlockCard(
      title: 'When',
      required: true,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final SessionWeeklyPreset preset in sessionWeeklyPresets)
              ActionChip(
                label: Text(preset.label),
                onPressed: () =>
                    widget.controller.applySessionWeeklyPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (session.schedule.weeklyRules.isEmpty)
          const Text('No weekly rule yet — pick a preset above.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SessionWeeklyRule rule in session.schedule.weeklyRules)
                InputChip(
                  label: Text(
                    '${_weekdayLabel(rule.isoWeekday)} '
                    '${_minutesLabel(rule.startMinuteLocal)}–'
                    '${_minutesLabel(rule.endMinuteLocalExclusive)}',
                  ),
                  onDeleted: () =>
                      widget.controller.removeSessionWeeklyRule(rule.id),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Text('Slot duration', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final int minutes in const <int>[30, 60, 90, 120])
              ChoiceChip(
                label: Text('$minutes min'),
                selected: session.schedule.slotDurationMinutes == minutes,
                onSelected: (_) =>
                    widget.controller.setSessionSlotDuration(minutes),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Buffer ${session.schedule.bufferAfterSlotMinutes} min · '
          'notice ${session.schedule.minNoticeMinutes} min — '
          'platform defaults, change anytime',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (preview.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text('Next offers', style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SessionSlotProjection slot in preview)
                Chip(label: Text(_slotLabel(slot))),
            ],
          ),
        ],
        ..._fieldIssues(<String>{'weeklyRules', 'slotDurationMinutes'}),
      ],
    );
  }

  // --- Блок 3. Цена и бронь ---

  Widget _priceAndBookingBlock(SessionDraftData session) {
    final bool isFree = session.price.mode == SessionPricingMode.free;
    return _BlockCard(
      title: 'Price and booking',
      required: true,
      children: <Widget>[
        Wrap(
          spacing: 8,
          children: <Widget>[
            ChoiceChip(
              label: const Text('Free'),
              selected: isFree,
              onSelected: (_) => widget.controller.setSessionPriceFree(),
            ),
            ChoiceChip(
              label: const Text('€ Fixed'),
              selected: !isFree,
              onSelected: (_) => widget.controller.setSessionPriceFixed(
                amountMinor: session.price.amount?.amountMinor ?? 0,
                currencyCode: session.price.amount?.currencyCode ?? 'EUR',
              ),
            ),
          ],
        ),
        if (!isFree) ...<Widget>[
          const SizedBox(height: 8),
          TextFormField(
            controller: _field(
              'priceAmount',
              session.price.amount == null
                  ? ''
                  : (session.price.amount!.amountMinor / 100).toStringAsFixed(
                      2,
                    ),
            ),
            decoration: const InputDecoration(labelText: 'Price per slot, EUR'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String value) {
              final double? parsed = double.tryParse(
                value.replaceAll(',', '.'),
              );
              if (parsed != null) {
                widget.controller.setSessionPriceFixed(
                  amountMinor: (parsed * 100).round(),
                  currencyCode: session.price.amount?.currencyCode ?? 'EUR',
                );
              }
            },
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('externalBookingUrl', session.externalBookingUrl),
          decoration: const InputDecoration(
            labelText: 'External booking URL (https://…)',
          ),
          onChanged: widget.controller.setSessionExternalBookingUrl,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field(
            'externalTermsUrl',
            session.externalTermsUrl ?? '',
          ),
          decoration: const InputDecoration(
            labelText: 'Terms URL (optional, https://…)',
          ),
          onChanged: widget.controller.setSessionExternalTermsUrl,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('maxPartySize', session.maxPartySize.toString()),
          decoration: const InputDecoration(labelText: 'Max party size'),
          keyboardType: TextInputType.number,
          onChanged: (String value) {
            final int? parsed = int.tryParse(value);
            if (parsed != null) {
              widget.controller.setSessionMaxPartySize(parsed);
            }
          },
        ),
        ..._fieldIssues(<String>{
          'price',
          'externalBookingUrl',
          'maxPartySize',
        }),
      ],
    );
  }

  // --- Необязательно ---

  Widget _optionalZone(CreateDraftEntity draft, SessionDraftData session) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () => setState(() => _showOptional = !_showOptional),
              child: Row(
                children: <Widget>[
                  Text(
                    'Optional — add now or after publishing',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Icon(_showOptional ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_showOptional) ...<Widget>[
              const SizedBox(height: 12),
              _blockedDatesSection(session),
              const Divider(height: 24),
              _amenitiesSection(session),
              const Divider(height: 24),
              _categoryCriteriaSection(draft),
            ],
          ],
        ),
      ),
    );
  }

  Widget _blockedDatesSection(SessionDraftData session) {
    final TextEditingController dateController = _field('newExceptionDate', '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Blocked dates', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (YYYY-MM-DD)',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                final String date = dateController.text.trim();
                if (date.isEmpty) return;
                widget.controller.addSessionException(
                  startDateLocal: date,
                  endDateLocal: date,
                  allDay: true,
                );
                dateController.clear();
              },
              child: const Text('Block'),
            ),
          ],
        ),
        if (session.exceptions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final SessionAvailabilityException exception
                  in session.exceptions)
                InputChip(
                  label: Text(exception.startDateLocal),
                  onDeleted: () =>
                      widget.controller.removeSessionException(exception.id),
                ),
            ],
          ),
      ],
    );
  }

  Widget _amenitiesSection(SessionDraftData session) {
    // Reuses the shared amenity taxonomy (eventAmenityTaxonomy) instead of
    // free text or a third independent list — bounded-extended with a
    // Wellness group for Session's own use (§12 «Необязательно», §7).
    final Map<String, List<EventAmenityDefinition>> byGroup =
        <String, List<EventAmenityDefinition>>{};
    for (final EventAmenityDefinition amenity in eventAmenityTaxonomy) {
      byGroup
          .putIfAbsent(amenity.group, () => <EventAmenityDefinition>[])
          .add(amenity);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Amenities', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final MapEntry<String, List<EventAmenityDefinition>> group
            in byGroup.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final EventAmenityDefinition amenity in group.value)
                  FilterChip(
                    label: Text(amenity.label),
                    selected: session.amenityIds.contains(amenity.id),
                    onSelected: (bool selected) {
                      final Set<String> next = <String>{...session.amenityIds};
                      if (selected) {
                        next.add(amenity.id);
                      } else {
                        next.remove(amenity.id);
                      }
                      widget.controller.setSessionAmenityIds(next);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _categoryCriteriaSection(CreateDraftEntity draft) {
    final CategoryCriteriaResult? criteria = const GetCategoryCriteriaUseCase()(
      draft.subcategory,
    );
    if (criteria == null || criteria.fields.isEmpty) {
      return const SizedBox.shrink();
    }
    final Map<String, Object?> criteriaValues = <String, Object?>{
      ...?draft.sectionData['criteria'] as Map<String, Object?>?,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Recommended details for this category',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Never required to publish (SES-D14).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final RechargeCriteriaFieldDefinition field in criteria.fields)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: field.type == 'bool'
                ? SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(field.id.replaceAll('_', ' ')),
                    value: criteriaValues[field.id] as bool? ?? false,
                    onChanged: (bool value) => widget.controller
                        .updateCategoryCriterion(field.id, value),
                  )
                : TextFormField(
                    controller: _field(
                      'criterion-${field.id}',
                      criteriaValues[field.id]?.toString() ?? '',
                    ),
                    decoration: InputDecoration(
                      labelText: field.id.replaceAll('_', ' '),
                    ),
                    onChanged: (String value) => widget.controller
                        .updateCategoryCriterion(field.id, value),
                  ),
          ),
      ],
    );
  }

  Widget _blockingIssuesCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Fix before publishing',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final SessionValidationIssue issue in _issues)
              if (issue.isBlocking)
                Text(
                  '• ${issue.code}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fieldIssues(Set<String> fieldIds) => <Widget>[
    for (final SessionValidationIssue issue in _issues)
      if (issue.isBlocking && fieldIds.contains(issue.fieldId))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            issue.code,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
  ];

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          OutlinedButton(
            onPressed: widget.controller.saveDraft,
            child: const Text('Save draft'),
          ),
          FilledButton(
            onPressed: () async {
              final bool published = await widget.controller.publishDraft();
              if (published) widget.onPublished();
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  static String _weekdayLabel(int isoWeekday) => const <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ][(isoWeekday - 1).clamp(0, 6)];

  static String _minutesLabel(int minutesSinceMidnight) {
    final int hours = minutesSinceMidnight ~/ 60;
    final int minutes = minutesSinceMidnight % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }

  static String _slotLabel(SessionSlotProjection slot) {
    final DateTime local = slot.startAtUtc.toLocal();
    return '${slot.localDate} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.title,
    required this.required,
    required this.children,
  });

  final String title;
  final bool required;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                if (required)
                  Text(
                    'required',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Only what is marked "required" blocks publishing. Everything '
        'else is optional and can be added now or later.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
