import 'package:flutter/material.dart';

import 'create_media_pick_actions.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/config/recharge_category_criteria.dart';
import '../../../../core/localization/taxonomy_labels.dart';
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
import 'create_form_texts.dart';
import 'create_texts.dart';
import '../../../../core/localization/recharge_formats.dart';

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
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(context.l10n.createSessionLoadingBookableSessionDraft),
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
              CreateTexts.notice(context.l10n, widget.state.message!),
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
      title: context.l10n.createSessionWhatWhere,
      required: true,
      children: <Widget>[
        TextFormField(
          controller: _field('title', draft.title),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionTitle,
          ),
          onChanged: widget.controller.updateTitle,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CreateTaxonomyCategory>(
          isExpanded: true,
          initialValue: selectedCategory,
          decoration: InputDecoration(
            labelText: context.l10n.createSessionCategory,
          ),
          items: <DropdownMenuItem<CreateTaxonomyCategory>>[
            for (final CreateTaxonomyCategory category in categories)
              DropdownMenuItem<CreateTaxonomyCategory>(
                value: category,
                child: Text(taxonomyLabel(context.l10n, category.id)),
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
          isExpanded: true,
          initialValue: selectedSubcategory,
          decoration: InputDecoration(
            labelText: context.l10n.createSessionSubcategory,
          ),
          items: <DropdownMenuItem<CreateTaxonomySubcategory>>[
            for (final CreateTaxonomySubcategory sub
                in selectedCategory?.subcategories ??
                    const <CreateTaxonomySubcategory>[])
              DropdownMenuItem<CreateTaxonomySubcategory>(
                value: sub,
                child: Text(taxonomyLabel(context.l10n, sub.id)),
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
          decoration: InputDecoration(
            labelText: context.l10n.createSessionShortDescription,
          ),
          onChanged: widget.controller.updateShortDescription,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('fullDescription', draft.fullDescription),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionFullDescription,
          ),
          maxLines: 4,
          onChanged: widget.controller.updateFullDescription,
        ),
        const SizedBox(height: 12),
        CreateMediaPickActions(
          controller: widget.controller,
          target: CreateMediaTarget.cover,
        ),
        if (showCreateMediaPathField(widget.controller))
          TextFormField(
            controller: _field('coverImage', draft.media.coverImage),
            decoration: InputDecoration(
              labelText: context.l10n.createSessionCoverImageUrl,
            ),
            onChanged: widget.controller.updateCoverImage,
          ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: widget.controller.sessionContentLocale,
          decoration: InputDecoration(
            labelText: context.l10n.createSessionContentLanguage,
          ),
          items: <DropdownMenuItem<String>>[
            for (final locale in widget.controller.supportedContentLocales)
              DropdownMenuItem(value: locale, child: Text(locale)),
          ],
          onChanged: (value) =>
              widget.controller.updateSessionMediaMetadata(locale: value),
        ),
        TextFormField(
          controller: _field(
            'sessionCoverAlt:${widget.controller.sessionContentLocale}', // l10n-ignore: field id
            widget.controller.sessionMediaAltText(),
          ),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionCoverImageDescription,
          ),
          onChanged: (value) =>
              widget.controller.updateSessionMediaMetadata(coverAltText: value),
        ),
        for (final reference in draft.media.gallery)
          TextFormField(
            controller: _field(
              'sessionGalleryAlt:$reference:${widget.controller.sessionContentLocale}', // l10n-ignore: field id
              widget.controller.sessionMediaAltText(reference),
            ),
            decoration: InputDecoration(
              labelText: context.l10n.createSessionGalleryImageDescription,
            ),
            onChanged: (value) => widget.controller.updateSessionMediaMetadata(
              galleryRef: reference,
              galleryAltText: value,
            ),
          ),
        CheckboxListTile(
          value:
              widget.controller.sessionMediaMetadata['rightsConfirmed'] == true,
          title: Text(context.l10n.createFormImagesPermission),
          onChanged: (value) => widget.controller.updateSessionMediaMetadata(
            rightsConfirmed: value ?? false,
          ),
        ),

        const SizedBox(height: 12),
        TextFormField(
          controller: _field('resourceName', session.resourceName),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionResourceNameEGSauna1,
          ),
          onChanged: (String value) {
            widget.controller.updateSessionResourceName(value);
            widget.controller.updateVenueName(value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('address', draft.addressLine1),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionAddress,
          ),
          onChanged: widget.controller.updateAddress,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('city', draft.city),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionCity,
          ),
          onChanged: widget.controller.updateCity,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _field('timezoneId', session.timezoneId),
                decoration: InputDecoration(
                  labelText: context.l10n.createSessionTimezoneField,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // L4.6: long lv/ru labels wrap at 200% text instead of overflowing.
            Flexible(
              flex: 2,
              child: FilledButton(
                onPressed: () => widget.controller.confirmSessionTimezone(
                  _fields['timezoneId']?.text ?? session.timezoneId,
                ),
                child: Text(
                  session.timezoneConfirmed
                      ? context.l10n.createFormConfirmed
                      : context.l10n.createFormConfirm,
                ),
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _field(
            'sessionLatitude',
            draft.latitude?.toString() ?? '',
          ),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionLatitude,
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        TextFormField(
          controller: _field(
            'sessionLongitude',
            draft.longitude?.toString() ?? '',
          ),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionLongitude,
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        OutlinedButton(
          onPressed: () => widget.controller.confirmSessionLocation(
            latitude: _fields['sessionLatitude']?.text ?? '',
            longitude: _fields['sessionLongitude']?.text ?? '',
          ),
          child: Text(context.l10n.createSessionConfirmLocation),
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
      title: context.l10n.createSessionWhen,
      required: true,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final SessionWeeklyPreset preset in sessionWeeklyPresets)
              ActionChip(
                label: Text(createFormText(context.l10n, preset.labelId)),
                onPressed: () =>
                    widget.controller.applySessionWeeklyPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (session.schedule.weeklyRules.isEmpty)
          Text(context.l10n.createSessionNoWeeklyRuleYetPickPreset)
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
        Text(
          context.l10n.createSessionSlotDuration,
          style: Theme.of(context).textTheme.labelLarge,
        ),
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
          '${context.l10n.createSessionBuffer(session.schedule.bufferAfterSlotMinutes)} · '
          '${context.l10n.createSessionNotice(session.schedule.minNoticeMinutes)} — '
          '${context.l10n.createSessionPlatformDefaults}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (preview.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            context.l10n.createSessionNextOffers,
            style: Theme.of(context).textTheme.labelLarge,
          ),
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
      title: context.l10n.createSessionPriceBooking,
      required: true,
      children: <Widget>[
        Wrap(
          spacing: 8,
          children: <Widget>[
            ChoiceChip(
              label: Text(context.l10n.createSessionFree),
              selected: isFree,
              onSelected: (_) => widget.controller.setSessionPriceFree(),
            ),
            ChoiceChip(
              label: Text(context.l10n.createSessionPriceFixed),
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
            decoration: InputDecoration(
              labelText: context.l10n.createSessionPricePerSlotEur,
            ),
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
          decoration: InputDecoration(
            labelText: context.l10n.createSessionExternalBookingUrlHttps,
          ),
          onChanged: widget.controller.setSessionExternalBookingUrl,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field(
            'externalTermsUrl',
            session.externalTermsUrl ?? '',
          ),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionTermsUrlOptionalHttps,
          ),
          onChanged: widget.controller.setSessionExternalTermsUrl,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('maxPartySize', session.maxPartySize.toString()),
          decoration: InputDecoration(
            labelText: context.l10n.createSessionMaxPartySize,
          ),
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
                  Expanded(
                    child: Text(
                      context.l10n.createSessionOptionalLater,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
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
        Text(
          context.l10n.createSessionBlockedDates,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: dateController,
                decoration: InputDecoration(
                  labelText: context.l10n.createFormDateIso,
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
              child: Text(context.l10n.createSessionBlock),
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
        Text(
          context.l10n.createSessionAmenities,
          style: Theme.of(context).textTheme.labelLarge,
        ),
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
                    label: Text(context.l10n.createAmenityLabel(amenity.id)),
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
          context.l10n.createSessionRecommendedDetailsCategory,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.createSessionNeverRequiredPublishSesD14,
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
              context.l10n.sessionFixBeforePublishing,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final SessionValidationIssue issue in _issues)
              if (issue.isBlocking)
                Text(
                  '• ${context.l10n.sessionValidationIssue(issue.code)}',
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
            context.l10n.sessionValidationIssue(issue.code),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
  ];

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          OutlinedButton(
            onPressed: widget.controller.saveDraft,
            child: Text(context.l10n.createSessionSaveDraft),
          ),
          FilledButton(
            onPressed: () async {
              final bool published = await widget.controller.publishDraft();
              if (published) widget.onPublished();
            },
            child: Text(context.l10n.createSessionPublish),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(int isoWeekday) => RechargeFormats.weekdayShort(
    isoWeekday,
    Localizations.localeOf(context).languageCode,
  );

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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
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
        context.l10n.createSessionOnlyWhatMarkedRequiredBlocksPublishing,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
