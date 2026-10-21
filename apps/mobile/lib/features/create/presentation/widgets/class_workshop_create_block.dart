import 'package:flutter/material.dart';

import '../../application/class_workshop_create_config.dart';
import '../../application/controllers/create_controller.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/class_workshop_draft_data.dart';
import '../../domain/entities/class_workshop_validation_issue.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/usecases/build_class_workshop_content_body.dart';

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
      return const Card(
        key: Key('class-workshop-read-only'),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'This Class draft was saved by a newer app version and is read-only.',
          ),
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
            child: Text(widget.state.message!, textAlign: TextAlign.center),
          ),
      ],
    );
  }

  List<Widget> _basics(
    CreateDraftEntity draft,
    ClassWorkshopDraftData data,
  ) => <Widget>[
    DropdownButtonFormField<ClassWorkshopOfferingKind>(
      key: const Key('class-workshop-kind'),
      initialValue: data.offeringKind,
      decoration: const InputDecoration(labelText: 'Offering kind'),
      items: <DropdownMenuItem<ClassWorkshopOfferingKind>>[
        for (final ClassWorkshopOfferingKind kind
            in ClassWorkshopOfferingKind.values)
          DropdownMenuItem(value: kind, child: Text(kind.wireName)),
      ],
      onChanged: (ClassWorkshopOfferingKind? value) {
        if (value != null) _c.setClassWorkshopOfferingKind(value);
      },
    ),
    _text('class-workshop-title', 'Title', draft.title, _c.updateTitle),
    _text(
      'class-workshop-short',
      'Short description',
      draft.shortDescription,
      _c.updateShortDescription,
    ),
    _text(
      'class-workshop-full',
      'Full description',
      draft.fullDescription,
      _c.updateFullDescription,
      lines: 4,
    ),
    _text(
      'class-workshop-cover',
      'Cover image',
      draft.media.coverImage,
      _c.updateCoverImage,
      errorText: widget.state.validationErrors['coverImage'],
    ),
    DropdownButtonFormField<String>(
      key: const Key('class-workshop-locale'),
      initialValue: _c.classWorkshopContentLocale,
      decoration: const InputDecoration(labelText: 'Content language'),
      items: <DropdownMenuItem<String>>[
        for (final String locale in _c.supportedContentLocales)
          DropdownMenuItem(value: locale, child: Text(locale)),
      ],
      onChanged: (String? value) =>
          _c.updateClassWorkshopMediaMetadata(locale: value),
    ),
    _text(
      'class-workshop-cover-alt:${_c.classWorkshopContentLocale}',
      'Cover image description',
      _c.classWorkshopMediaAltText(),
      (String v) => _c.updateClassWorkshopMediaMetadata(coverAltText: v),
    ),
    for (final String reference in draft.media.gallery)
      _text(
        'class-workshop-gallery-alt:$reference:${_c.classWorkshopContentLocale}',
        'Gallery image description',
        _c.classWorkshopMediaAltText(reference),
        (String v) => _c.updateClassWorkshopMediaMetadata(
          galleryRef: reference,
          galleryAltText: v,
        ),
      ),
    CheckboxListTile(
      key: const Key('class-workshop-rights'),
      value: _c.classWorkshopMediaMetadata['rightsConfirmed'] == true,
      title: const Text('I have permission to use these images'),
      onChanged: (bool? value) =>
          _c.updateClassWorkshopMediaMetadata(rightsConfirmed: value ?? false),
    ),
  ];

  List<Widget> _learning(ClassWorkshopDraftData data) => <Widget>[
    _text(
      'class-workshop-outcomes',
      'Outcomes (one per line)',
      data.outcomes.join('\n'),
      _c.setClassWorkshopOutcomes,
      lines: 3,
    ),
    _text(
      'class-workshop-modules',
      'Programme steps (one per line)',
      data.modules.map((ClassWorkshopModule m) => m.title).join('\n'),
      _c.setClassWorkshopModules,
      lines: 3,
    ),
    SwitchListTile(
      key: const Key('class-workshop-prerequisites-none'),
      value: data.prerequisitesListed == false,
      title: const Text('No prerequisites'),
      onChanged: (bool none) => _c.setClassWorkshopPrerequisites(listed: !none),
    ),
    if (data.prerequisitesListed == true)
      _text(
        'class-workshop-prerequisites',
        'Prerequisites (one per line)',
        data.prerequisites.join('\n'),
        (String v) => _c.setClassWorkshopPrerequisites(listed: true, lines: v),
        lines: 2,
      ),
    _text(
      'class-workshop-result',
      'What participants take home',
      data.takeHomeResult,
      _c.setClassWorkshopTakeHomeResult,
    ),
    SwitchListTile(
      key: const Key('class-workshop-instructor-same'),
      value: data.instructor.sameAsPublisher,
      title: const Text('I lead this class myself'),
      onChanged: (bool value) =>
          _c.setClassWorkshopInstructor(sameAsPublisher: value),
    ),
    if (!data.instructor.sameAsPublisher)
      _text(
        'class-workshop-instructor-name',
        'Instructor name',
        data.instructor.displayName,
        (String v) => _c.setClassWorkshopInstructor(displayName: v),
      ),
    _text(
      'class-workshop-instructor-bio',
      'Instructor bio',
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
          title: const Text('This draft has an old schedule'),
          subtitle: const Text('It is not published; clear it explicitly.'),
          trailing: TextButton(
            onPressed: _c.clearClassWorkshopLegacySchedule,
            child: const Text('Clear'),
          ),
        ),
      SegmentedButton<ClassWorkshopContextKind>(
        key: const Key('class-workshop-context'),
        segments: const <ButtonSegment<ClassWorkshopContextKind>>[
          ButtonSegment(
            value: ClassWorkshopContextKind.singleClass,
            label: Text('Single class'),
          ),
          ButtonSegment(
            value: ClassWorkshopContextKind.fixedSeries,
            label: Text('Fixed series'),
          ),
        ],
        selected: <ClassWorkshopContextKind>{data.contextKind},
        onSelectionChanged: (Set<ClassWorkshopContextKind> value) =>
            _c.setClassWorkshopContextKind(value.first),
      ),
      CheckboxListTile(
        key: const Key('class-workshop-timezone'),
        value: data.timezoneConfirmed,
        title: Text('Times are in ${data.timezoneId}'),
        onChanged: (bool? value) {
          if (value == true) _c.confirmClassWorkshopTimezone(data.timezoneId);
        },
      ),
      for (final ClassWorkshopOccurrence item in data.occurrences)
        _occurrenceTile(data, item),
      _addOccurrence(),
      DropdownButtonFormField<ClassWorkshopDeliveryFormat>(
        key: const Key('class-workshop-delivery'),
        initialValue: data.deliveryFormat,
        decoration: const InputDecoration(labelText: 'Delivery'),
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
          'Online provider',
          data.onlineProviderLabel,
          _c.setClassWorkshopOnlineProviderLabel,
        ),
      if (hasPlace) ...<Widget>[
        _text(
          'class-workshop-venue',
          'Venue',
          draft.venueName,
          _c.updateVenueName,
        ),
        _text(
          'class-workshop-address',
          'Address',
          draft.addressLine1,
          _c.updateAddress,
        ),
        _text('class-workshop-city', 'City', draft.city, _c.updateCity),
        _text(
          'class-workshop-latitude',
          'Latitude',
          draft.latitude?.toString() ?? '',
          (_) {},
        ),
        _text(
          'class-workshop-longitude',
          'Longitude',
          draft.longitude?.toString() ?? '',
          (_) {},
        ),
        OutlinedButton(
          key: const Key('class-workshop-confirm-location'),
          onPressed: () => _c.confirmClassWorkshopLocation(
            latitude: _fields['class-workshop-latitude']?.text ?? '',
            longitude: _fields['class-workshop-longitude']?.text ?? '',
          ),
          child: Text(pinned ? 'Location confirmed' : 'Confirm this location'),
        ),
        SwitchListTile(
          key: const Key('class-workshop-area-only'),
          value: data.locationMode == ClassWorkshopLocationMode.areaOnly,
          title: const Text('Show only the area publicly'),
          onChanged: (bool value) => _c.setClassWorkshopLocationMode(
            value
                ? ClassWorkshopLocationMode.areaOnly
                : ClassWorkshopLocationMode.point,
          ),
        ),
        if (data.locationMode == ClassWorkshopLocationMode.areaOnly)
          _text(
            'class-workshop-area',
            'Public area',
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
              ? const Text('This local time does not exist or is ambiguous')
              : null,
          trailing: IconButton(
            tooltip: 'Remove date',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _c.removeClassWorkshopOccurrence(item.id),
          ),
        ),
        if (ambiguous)
          SegmentedButton<ClassWorkshopFold>(
            emptySelectionAllowed: true,
            segments: const <ButtonSegment<ClassWorkshopFold>>[
              ButtonSegment(
                value: ClassWorkshopFold.earlier,
                label: Text('First (summer time)'),
              ),
              ButtonSegment(
                value: ClassWorkshopFold.later,
                label: Text('Second (winter time)'),
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
          'Date (YYYY-MM-DD)',
          '',
          (_) {},
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _text('class-workshop-new-start', 'Start (HH:MM)', '', (_) {}),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _text('class-workshop-new-end', 'End (HH:MM)', '', (_) {}),
      ),
      IconButton(
        key: const Key('class-workshop-add-date'),
        tooltip: 'Add date',
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
        'Included materials (one per line)',
        data.includedMaterials.join('\n'),
        _c.setClassWorkshopIncludedMaterials,
        lines: 2,
      ),
      _text(
        'class-workshop-requirements',
        'What to bring or know (one per line)',
        data.requirements.join('\n'),
        _c.setClassWorkshopRequirements,
        lines: 2,
      ),
      _text(
        'class-workshop-group',
        'Declared group size (optional)',
        data.declaredGroupLimit?.toString() ?? '',
        (String v) => _c.setClassWorkshopGroupLimit(int.tryParse(v.trim())),
      ),
      DropdownButtonFormField<ClassWorkshopPriceMode>(
        key: const Key('class-workshop-price-mode'),
        initialValue: price.mode,
        decoration: const InputDecoration(labelText: 'Price'),
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
          'Amount in cents (${price.currencyCode ?? ''})',
          price.amountMinor?.toString() ?? '',
          (String v) => _c.setClassWorkshopPriceFixed(
            amountMinor: int.tryParse(v.trim()) ?? 0,
            scope: price.scope ?? ClassWorkshopPriceScope.perPersonPerClass,
          ),
        ),
        DropdownButtonFormField<ClassWorkshopPriceScope>(
          key: const Key('class-workshop-price-scope'),
          initialValue: price.scope,
          decoration: const InputDecoration(labelText: 'The price covers'),
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
        title: const Text('Enrollment on the organiser site'),
        onChanged: (bool value) => value
            ? _c.setClassWorkshopExternalEnrollment(enrollment.externalUrl)
            : _c.setClassWorkshopInformationOnly(
                ClassWorkshopInformationReason.notProvided,
              ),
      ),
      if (enrollment.mode == ClassWorkshopEnrollmentMode.external)
        _text(
          'class-workshop-enrollment-url',
          'Enrollment link (https)',
          enrollment.externalUrl,
          _c.setClassWorkshopExternalEnrollment,
        )
      else
        DropdownButtonFormField<ClassWorkshopInformationReason>(
          key: const Key('class-workshop-information'),
          initialValue: enrollment.informationReason,
          decoration: const InputDecoration(labelText: 'Enrollment state'),
          items: <DropdownMenuItem<ClassWorkshopInformationReason>>[
            for (final ClassWorkshopInformationReason reason
                in ClassWorkshopInformationReason.values)
              DropdownMenuItem(value: reason, child: Text(reason.wireName)),
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
          child: const Text('Save draft'),
        ),
        FilledButton(
          onPressed: () async {
            if (await _c.publishDraft()) widget.onPublished();
          },
          child: const Text('Publish'),
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
          Text(config.title, style: Theme.of(context).textTheme.titleMedium),
          Text(
            config.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ...children,
          for (final ClassWorkshopValidationIssue issue in issues)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                issue.message,
                key: Key('class-workshop-issue-${issue.code}'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}
