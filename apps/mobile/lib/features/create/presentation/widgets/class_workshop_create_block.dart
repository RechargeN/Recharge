import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../application/class_workshop_create_config.dart';
import '../../application/controllers/create_controller.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/class_workshop_draft_data.dart';
import '../../domain/entities/class_workshop_validation_issue.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/usecases/build_class_workshop_content_body.dart';
import 'create_form_texts.dart';
import 'create_texts.dart';

/// Class / Workshop Create block (D3.6, CW-V1). Its sections come from
/// `classWorkshopCreateSections`; taxonomy and criteria are the shared Create
/// sections above it. The block renders state and forwards intents only.
class ClassWorkshopCreateBlock extends StatefulWidget {
  const ClassWorkshopCreateBlock({
    super.key,
    required this.controller,
    required this.state,
    required this.onPublished,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  State<ClassWorkshopCreateBlock> createState() =>
      _ClassWorkshopCreateBlockState();
}

class _ClassWorkshopCreateBlockState extends State<ClassWorkshopCreateBlock> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};

  CreateController get _c => widget.controller;

  TextEditingController _field(String id, String value) {
    final TextEditingController? existing = _fields[id];
    if (existing != null) {
      if (existing.text != value && !existing.selection.isValid) {
        existing.text = value;
      }
      return existing;
    }
    return _fields[id] = TextEditingController(text: value);
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreateDraftEntity draft = widget.state.draft;
    final ClassWorkshopDraftData? data = draft.classWorkshopData;
    if (data == null) {
      return Card(
        key: Key('class-workshop-read-only'),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(context.l10n.createClassClassDraftWasSavedByNewer),
        ),
      );
    }
    final List<ClassWorkshopValidationIssue> issues = _c.classWorkshopIssues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ClassWorkshopCreateSectionConfig section
            in classWorkshopCreateSections)
          _SectionCard(
            key: Key('class-workshop-section-${section.id}'),
            config: section,
            issues: issues
                .where(
                  (ClassWorkshopValidationIssue i) => i.field == section.id,
                )
                .toList(),
            children: switch (section.id) {
              'basics' => _basics(draft, data),
              'learning' => _learning(data),
              'schedule' => _schedule(draft, data),
              _ => _participation(data),
            },
          ),
        _footer(),
        if (widget.state.message != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              CreateTexts.notice(context.l10n, widget.state.message!),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  List<Widget> _basics(
    CreateDraftEntity draft,
    ClassWorkshopDraftData data,
  ) => <Widget>[
    DropdownButtonFormField<ClassWorkshopOfferingKind>(
      isExpanded: true,
      key: const Key('class-workshop-kind'),
      initialValue: data.offeringKind,
      decoration: InputDecoration(
        labelText: context.l10n.createClassOfferingKind,
      ),
      items: <DropdownMenuItem<ClassWorkshopOfferingKind>>[
        for (final ClassWorkshopOfferingKind kind
            in ClassWorkshopOfferingKind.values)
          DropdownMenuItem(value: kind, child: Text(kind.wireName)),
      ],
      onChanged: (ClassWorkshopOfferingKind? value) {
        if (value != null) _c.setClassWorkshopOfferingKind(value);
      },
    ),
    _text(
      'class-workshop-title',
      context.l10n.createSessionTitle,
      draft.title,
      _c.updateTitle,
    ),
    _text(
      'class-workshop-short',
      context.l10n.createClassShortDescription,
      draft.shortDescription,
      _c.updateShortDescription,
    ),
    _text(
      'class-workshop-full',
      context.l10n.createClassFullDescription,
      draft.fullDescription,
      _c.updateFullDescription,
      lines: 4,
    ),
    _text(
      'class-workshop-cover',
      context.l10n.createClassCoverImage,
      draft.media.coverImage,
      _c.updateCoverImage,
      errorText: switch (widget.state.validationErrors['coverImage']) {
        final String id => CreateTexts.fieldError(context.l10n, id),
        null => null,
      },
    ),
    DropdownButtonFormField<String>(
      isExpanded: true,
      key: const Key('class-workshop-locale'),
      initialValue: _c.classWorkshopContentLocale,
      decoration: InputDecoration(
        labelText: context.l10n.createClassContentLanguage,
      ),
      items: <DropdownMenuItem<String>>[
        for (final String locale in _c.supportedContentLocales)
          DropdownMenuItem(value: locale, child: Text(locale)),
      ],
      onChanged: (String? value) =>
          _c.updateClassWorkshopMediaMetadata(locale: value),
    ),
    _text(
      'class-workshop-cover-alt:${_c.classWorkshopContentLocale}',
      context.l10n.createClassCoverImageDescription,
      _c.classWorkshopMediaAltText(),
      (String v) => _c.updateClassWorkshopMediaMetadata(coverAltText: v),
    ),
    for (final String reference in draft.media.gallery)
      _text(
        'class-workshop-gallery-alt:$reference:${_c.classWorkshopContentLocale}',
        context.l10n.createClassGalleryImageDescription,
        _c.classWorkshopMediaAltText(reference),
        (String v) => _c.updateClassWorkshopMediaMetadata(
          galleryRef: reference,
          galleryAltText: v,
        ),
      ),
    CheckboxListTile(
      key: const Key('class-workshop-rights'),
      value: _c.classWorkshopMediaMetadata['rightsConfirmed'] == true,
      title: Text(context.l10n.createFormImagesPermission),
      onChanged: (bool? value) =>
          _c.updateClassWorkshopMediaMetadata(rightsConfirmed: value ?? false),
    ),
  ];

  List<Widget> _learning(ClassWorkshopDraftData data) => <Widget>[
    _text(
      'class-workshop-outcomes',
      context.l10n.createClassOutcomesPerLine,
      data.outcomes.join('\n'),
      _c.setClassWorkshopOutcomes,
      lines: 3,
    ),
    _text(
      'class-workshop-modules',
      context.l10n.createClassProgrammeStepsOnePerLine,
      data.modules.map((ClassWorkshopModule m) => m.title).join('\n'),
      _c.setClassWorkshopModules,
      lines: 3,
    ),
    SwitchListTile(
      key: const Key('class-workshop-prerequisites-none'),
      value: data.prerequisitesListed == false,
      title: Text(context.l10n.createClassNoPrerequisites),
      onChanged: (bool none) => _c.setClassWorkshopPrerequisites(listed: !none),
    ),
    if (data.prerequisitesListed == true)
      _text(
        'class-workshop-prerequisites',
        context.l10n.createClassPrerequisitesPerLine,
        data.prerequisites.join('\n'),
        (String v) => _c.setClassWorkshopPrerequisites(listed: true, lines: v),
        lines: 2,
      ),
    _text(
      'class-workshop-result',
      context.l10n.createClassWhatParticipantsTakeHome,
      data.takeHomeResult,
      _c.setClassWorkshopTakeHomeResult,
    ),
    SwitchListTile(
      key: const Key('class-workshop-instructor-same'),
      value: data.instructor.sameAsPublisher,
      title: Text(context.l10n.createClassLeadMyself),
      onChanged: (bool value) =>
          _c.setClassWorkshopInstructor(sameAsPublisher: value),
    ),
    if (!data.instructor.sameAsPublisher)
      _text(
        'class-workshop-instructor-name',
        context.l10n.createClassInstructorName,
        data.instructor.displayName,
        (String v) => _c.setClassWorkshopInstructor(displayName: v),
      ),
    _text(
      'class-workshop-instructor-bio',
      context.l10n.createClassInstructorBio,
      data.instructor.shortBio,
      (String v) => _c.setClassWorkshopInstructor(shortBio: v),
      lines: 2,
    ),
  ];

  List<Widget> _schedule(CreateDraftEntity draft, ClassWorkshopDraftData data) {
    final bool hasPlace = data.deliveryFormat.hasPlace;
    final bool pinned = ClassWorkshopContentBodyMapper.pinConfirmed(draft);
    return <Widget>[
      if (draft.scheduleSlots.isNotEmpty)
        ListTile(
          key: const Key('class-workshop-legacy-schedule'),
          title: Text(context.l10n.createClassDraftHasOldSchedule),
          subtitle: Text(context.l10n.createClassNotPublishedClearExplicitly),
          trailing: TextButton(
            onPressed: _c.clearClassWorkshopLegacySchedule,
            child: Text(context.l10n.createClassClear),
          ),
        ),
      SegmentedButton<ClassWorkshopContextKind>(
        key: const Key('class-workshop-context'),
        segments: <ButtonSegment<ClassWorkshopContextKind>>[
          ButtonSegment(
            value: ClassWorkshopContextKind.singleClass,
            label: Text(context.l10n.createClassSingleClass),
          ),
          ButtonSegment(
            value: ClassWorkshopContextKind.fixedSeries,
            label: Text(context.l10n.createClassFixedSeries),
          ),
        ],
        selected: <ClassWorkshopContextKind>{data.contextKind},
        onSelectionChanged: (Set<ClassWorkshopContextKind> value) =>
            _c.setClassWorkshopContextKind(value.first),
      ),
      CheckboxListTile(
        key: const Key('class-workshop-timezone'),
        value: data.timezoneConfirmed,
        title: Text(context.l10n.createClassTimesAre(data.timezoneId)),
        onChanged: (bool? value) {
          if (value == true) _c.confirmClassWorkshopTimezone(data.timezoneId);
        },
      ),
      for (final ClassWorkshopOccurrence item in data.occurrences)
        _occurrenceTile(data, item),
      _addOccurrence(),
      DropdownButtonFormField<ClassWorkshopDeliveryFormat>(
        isExpanded: true,
        key: const Key('class-workshop-delivery'),
        initialValue: data.deliveryFormat,
        decoration: InputDecoration(
          labelText: context.l10n.createClassDelivery,
        ),
        items: <DropdownMenuItem<ClassWorkshopDeliveryFormat>>[
          for (final ClassWorkshopDeliveryFormat format
              in ClassWorkshopDeliveryFormat.values)
            DropdownMenuItem(value: format, child: Text(format.wireName)),
        ],
        onChanged: (ClassWorkshopDeliveryFormat? value) {
          if (value != null) _c.setClassWorkshopDeliveryFormat(value);
        },
      ),
      if (data.deliveryFormat != ClassWorkshopDeliveryFormat.offline)
        _text(
          'class-workshop-provider',
          context.l10n.createClassOnlineProvider,
          data.onlineProviderLabel,
          _c.setClassWorkshopOnlineProviderLabel,
        ),
      if (hasPlace) ...<Widget>[
        _text(
          'class-workshop-venue',
          context.l10n.createFormVenue,
          draft.venueName,
          _c.updateVenueName,
        ),
        _text(
          'class-workshop-address',
          context.l10n.createSessionAddress,
          draft.addressLine1,
          _c.updateAddress,
        ),
        _text(
          'class-workshop-city',
          context.l10n.createSessionCity,
          draft.city,
          _c.updateCity,
        ),
        _text(
          'class-workshop-latitude',
          context.l10n.createSessionLatitude,
          draft.latitude?.toString() ?? '',
          (_) {},
        ),
        _text(
          'class-workshop-longitude',
          context.l10n.createSessionLongitude,
          draft.longitude?.toString() ?? '',
          (_) {},
        ),
        OutlinedButton(
          key: const Key('class-workshop-confirm-location'),
          onPressed: () => _c.confirmClassWorkshopLocation(
            latitude: _fields['class-workshop-latitude']?.text ?? '',
            longitude: _fields['class-workshop-longitude']?.text ?? '',
          ),
          child: Text(
            pinned
                ? context.l10n.createClassLocationConfirmed
                : context.l10n.createClassConfirmLocation,
          ),
        ),
        SwitchListTile(
          key: const Key('class-workshop-area-only'),
          value: data.locationMode == ClassWorkshopLocationMode.areaOnly,
          title: Text(context.l10n.createClassShowOnlyAreaPublicly),
          onChanged: (bool value) => _c.setClassWorkshopLocationMode(
            value
                ? ClassWorkshopLocationMode.areaOnly
                : ClassWorkshopLocationMode.point,
          ),
        ),
        if (data.locationMode == ClassWorkshopLocationMode.areaOnly)
          _text(
            'class-workshop-area',
            context.l10n.createClassPublicArea,
            data.safeAreaLabel,
            _c.setClassWorkshopSafeAreaLabel,
          ),
      ],
    ];
  }

  Widget _occurrenceTile(
    ClassWorkshopDraftData data,
    ClassWorkshopOccurrence item,
  ) {
    final coordinator = _c.classWorkshopCoordinator;
    final bool ambiguous = coordinator?.isAmbiguous(data, item) ?? false;
    final bool unresolved = coordinator?.hasUnresolvedTime(data, item) ?? false;
    return Column(
      key: Key('class-workshop-occurrence-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ListTile(
          title: Text(
            '${item.localDate} ${_time(item.startMinuteLocal)}–'
            '${_time(item.endMinuteLocal)}',
          ),
          subtitle: unresolved
              ? Text(context.l10n.createClassLocalTimeDoesNotExistAmbiguous)
              : null,
          trailing: IconButton(
            tooltip: context.l10n.createClassRemoveDate,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _c.removeClassWorkshopOccurrence(item.id),
          ),
        ),
        if (ambiguous)
          SegmentedButton<ClassWorkshopFold>(
            emptySelectionAllowed: true,
            segments: <ButtonSegment<ClassWorkshopFold>>[
              ButtonSegment(
                value: ClassWorkshopFold.earlier,
                label: Text(context.l10n.createClassFirstSummerTime),
              ),
              ButtonSegment(
                value: ClassWorkshopFold.later,
                label: Text(context.l10n.createClassFoldSecond),
              ),
            ],
            selected: <ClassWorkshopFold>{?item.fold},
            onSelectionChanged: (Set<ClassWorkshopFold> value) =>
                _c.setClassWorkshopFold(item.id, value.firstOrNull),
          ),
      ],
    );
  }

  Widget _addOccurrence() => Row(
    children: <Widget>[
      Expanded(
        child: _text(
          'class-workshop-new-date',
          context.l10n.createFormDateIso,
          '',
          (_) {},
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _text(
          'class-workshop-new-start',
          context.l10n.createClassStartHhmm,
          '',
          (_) {},
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _text(
          'class-workshop-new-end',
          context.l10n.createClassEndHhmm,
          '',
          (_) {},
        ),
      ),
      IconButton(
        key: const Key('class-workshop-add-date'),
        tooltip: context.l10n.createClassAddDate,
        icon: const Icon(Icons.add),
        onPressed: () {
          final int? start = _minutes(
            _fields['class-workshop-new-start']?.text,
          );
          final int? end = _minutes(_fields['class-workshop-new-end']?.text);
          final String date =
              _fields['class-workshop-new-date']?.text.trim() ?? '';
          if (start == null || end == null || date.isEmpty) return;
          _c.addClassWorkshopOccurrence(
            localDate: date,
            startMinuteLocal: start,
            endMinuteLocal: end,
          );
        },
      ),
    ],
  );

  List<Widget> _participation(ClassWorkshopDraftData data) {
    final ClassWorkshopPrice price = data.price;
    final ClassWorkshopEnrollment enrollment = data.enrollment;
    return <Widget>[
      _text(
        'class-workshop-materials',
        context.l10n.createClassIncludedMaterialsOnePerLine,
        data.includedMaterials.join('\n'),
        _c.setClassWorkshopIncludedMaterials,
        lines: 2,
      ),
      _text(
        'class-workshop-requirements',
        context.l10n.createClassWhatBringKnowOnePerLine,
        data.requirements.join('\n'),
        _c.setClassWorkshopRequirements,
        lines: 2,
      ),
      _text(
        'class-workshop-group',
        context.l10n.createClassDeclaredGroupSizeOptional,
        data.declaredGroupLimit?.toString() ?? '',
        (String v) => _c.setClassWorkshopGroupLimit(int.tryParse(v.trim())),
      ),
      DropdownButtonFormField<ClassWorkshopPriceMode>(
        isExpanded: true,
        key: const Key('class-workshop-price-mode'),
        initialValue: price.mode,
        decoration: InputDecoration(labelText: context.l10n.createClassPrice),
        items: <DropdownMenuItem<ClassWorkshopPriceMode>>[
          for (final ClassWorkshopPriceMode mode
              in ClassWorkshopPriceMode.values)
            DropdownMenuItem(value: mode, child: Text(mode.wireName)),
        ],
        onChanged: (ClassWorkshopPriceMode? mode) => switch (mode) {
          ClassWorkshopPriceMode.free => _c.setClassWorkshopPriceFree(),
          ClassWorkshopPriceMode.notProvided =>
            _c.setClassWorkshopPriceNotProvided(),
          ClassWorkshopPriceMode.fixed => _c.setClassWorkshopPriceFixed(
            amountMinor: price.amountMinor ?? 0,
            scope: price.scope ?? ClassWorkshopPriceScope.perPersonPerClass,
          ),
          null => null,
        },
      ),
      if (price.mode == ClassWorkshopPriceMode.fixed) ...<Widget>[
        _text(
          'class-workshop-price-amount',
          context.l10n.createClassAmountCents(price.currencyCode ?? ''),
          price.amountMinor?.toString() ?? '',
          (String v) => _c.setClassWorkshopPriceFixed(
            amountMinor: int.tryParse(v.trim()) ?? 0,
            scope: price.scope ?? ClassWorkshopPriceScope.perPersonPerClass,
          ),
        ),
        DropdownButtonFormField<ClassWorkshopPriceScope>(
          isExpanded: true,
          key: const Key('class-workshop-price-scope'),
          initialValue: price.scope,
          decoration: InputDecoration(
            labelText: context.l10n.createClassPriceCovers,
          ),
          items: <DropdownMenuItem<ClassWorkshopPriceScope>>[
            for (final ClassWorkshopPriceScope scope
                in ClassWorkshopPriceScope.values)
              DropdownMenuItem(value: scope, child: Text(scope.wireName)),
          ],
          onChanged: (ClassWorkshopPriceScope? scope) {
            if (scope != null) {
              _c.setClassWorkshopPriceFixed(
                amountMinor: price.amountMinor ?? 0,
                scope: scope,
              );
            }
          },
        ),
      ],
      SwitchListTile(
        key: const Key('class-workshop-enrollment-external'),
        value: enrollment.mode == ClassWorkshopEnrollmentMode.external,
        title: Text(context.l10n.createClassEnrollmentOrganiserSite),
        onChanged: (bool value) => value
            ? _c.setClassWorkshopExternalEnrollment(enrollment.externalUrl)
            : _c.setClassWorkshopInformationOnly(
                ClassWorkshopInformationReason.notProvided,
              ),
      ),
      if (enrollment.mode == ClassWorkshopEnrollmentMode.external)
        _text(
          'class-workshop-enrollment-url',
          context.l10n.createClassEnrollmentLinkHttps,
          enrollment.externalUrl,
          _c.setClassWorkshopExternalEnrollment,
        )
      else
        DropdownButtonFormField<ClassWorkshopInformationReason>(
          isExpanded: true,
          key: const Key('class-workshop-information'),
          initialValue: enrollment.informationReason,
          decoration: InputDecoration(
            labelText: context.l10n.createClassEnrollmentState,
          ),
          items: <DropdownMenuItem<ClassWorkshopInformationReason>>[
            for (final ClassWorkshopInformationReason reason
                in ClassWorkshopInformationReason.values)
              DropdownMenuItem(
                value: reason,
                child: Text(
                  context.l10n.classWorkshopEnrollmentReason(reason.wireName),
                ),
              ),
          ],
          onChanged: (ClassWorkshopInformationReason? reason) {
            if (reason != null) _c.setClassWorkshopInformationOnly(reason);
          },
        ),
    ];
  }

  Widget _footer() => Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton(
          onPressed: _c.saveDraft,
          child: Text(context.l10n.createClassSaveDraft),
        ),
        FilledButton(
          onPressed: () async {
            if (await _c.publishDraft()) widget.onPublished();
          },
          child: Text(context.l10n.createClassPublish),
        ),
      ],
    ),
  );

  Widget _text(
    String key,
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int lines = 1,
    String? errorText,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      key: Key(key),
      controller: _field(key, value),
      decoration: InputDecoration(labelText: label, errorText: errorText),
      minLines: lines,
      maxLines: lines,
      onChanged: onChanged,
    ),
  );

  static int? _minutes(String? text) {
    final Match? match = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch((text ?? '').trim());
    if (match == null) return null;
    final int hours = int.parse(match.group(1)!);
    final int minutes = int.parse(match.group(2)!);
    if (hours > 24 || minutes > 59 || (hours == 24 && minutes != 0)) {
      return null;
    }
    return hours * 60 + minutes;
  }

  static String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.config,
    required this.issues,
    required this.children,
  });

  final ClassWorkshopCreateSectionConfig config;
  final List<ClassWorkshopValidationIssue> issues;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            createFormText(context.l10n, config.titleId),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            createFormText(context.l10n, config.descriptionId),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ...children,
          for (final ClassWorkshopValidationIssue issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                CreateTexts.classWorkshop(context.l10n, issue),
                key: Key('class-workshop-issue-${issue.code}'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}
