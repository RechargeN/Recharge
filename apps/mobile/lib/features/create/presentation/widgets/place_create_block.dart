import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../application/controllers/create_controller.dart';
import '../../application/get_category_criteria_usecase.dart';
import '../../application/place_create_config.dart';
import '../../application/state/create_state.dart';
import '../../application/create_taxonomy.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/place_draft_data.dart';
import '../../domain/entities/place_duplicate_candidate.dart';
import '../../domain/entities/place_enrichment_proposal.dart';
import '../../domain/entities/place_creation_policy.dart';
import '../../domain/entities/place_validation_issue.dart';

class PlaceCreateBlock extends StatefulWidget {
  const PlaceCreateBlock({
    required this.controller,
    required this.state,
    required this.onPublished,
    super.key,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  State<PlaceCreateBlock> createState() => _PlaceCreateBlockState();
}

class _PlaceCreateBlockState extends State<PlaceCreateBlock> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};
  int _periodDay = 1;
  bool _periodOvernight = false;

  TextEditingController _field(String id, String value) {
    final TextEditingController controller = _fields.putIfAbsent(
      id,
      TextEditingController.new,
    );
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    return controller;
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
    final PlaceDraftData? place = draft.placeData;
    if (place == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Place data is being prepared…'),
        ),
      );
    }
    final PlaceCreationPolicy policy = placeCreationPolicyFor(
      draft.subcategory,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!widget.controller.canManagePlace) ...<Widget>[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Read-only draft'),
              subtitle: Text(
                'The create.place capability is required to edit or publish.',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _PlaceCreatorAssistPanel(
          state: widget.state,
          onGenerate: widget.controller.generatePlaceEnrichment,
          onApply: widget.controller.applyPlaceEnrichment,
          onDiscard: widget.controller.discardPlaceEnrichment,
        ),
        const SizedBox(height: 12),
        _PlaceProgressHeader(state: widget.state),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: !widget.controller.canManagePlace,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey<int>(widget.state.placeStep),
              child: switch (widget.state.placeStep) {
                0 => _identityStep(draft, place, policy),
                1 => _visitStep(place, policy),
                _ => _publishStep(draft, place, policy),
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: !widget.controller.canManagePlace,
          child: _navigation(),
        ),
        if (widget.state.message != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            widget.state.message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.state.validationErrors.isEmpty
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _identityStep(
    CreateDraftEntity draft,
    PlaceDraftData place,
    PlaceCreationPolicy policy,
  ) {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      CreateObjectType.place,
    );
    final CreateTaxonomyCategory? selectedCategory = categories
        .where((CreateTaxonomyCategory item) => item.id == draft.mainCategory)
        .firstOrNull;
    final CreateTaxonomySubcategory? selectedSubcategory = selectedCategory
        ?.subcategories
        .where((CreateTaxonomySubcategory item) => item.id == draft.subcategory)
        .firstOrNull;
    return _StepCard(
      title: 'What is this place?',
      subtitle: 'Choose a category and the form keeps only relevant fields.',
      children: <Widget>[
        _textField(
          id: 'title',
          label: 'Place name *',
          value: draft.title,
          maxLength: 100,
          onChanged: widget.controller.updateTitle,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CreateTaxonomyCategory>(
          value: selectedCategory,
          decoration: _decoration('Category *', 'mainCategory'),
          items: categories
              .map(
                (CreateTaxonomyCategory category) =>
                    DropdownMenuItem<CreateTaxonomyCategory>(
                      value: category,
                      child: Text(category.title),
                    ),
              )
              .toList(growable: false),
          onChanged: (CreateTaxonomyCategory? category) {
            if (category == null) return;
            final CreateTaxonomySubcategory? subcategory =
                createDefaultSubcategoryFor(category);
            _applyTaxonomyWithConfirmation(
              draft: draft,
              mainCategory: category.id,
              subcategory: subcategory?.id ?? '',
            );
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CreateTaxonomySubcategory>(
          value: selectedSubcategory,
          decoration: _decoration('Subcategory *', 'subcategory'),
          items:
              (selectedCategory?.subcategories ??
                      const <CreateTaxonomySubcategory>[])
                  .map(
                    (CreateTaxonomySubcategory subcategory) =>
                        DropdownMenuItem<CreateTaxonomySubcategory>(
                          value: subcategory,
                          child: Text(subcategory.title),
                        ),
                  )
                  .toList(growable: false),
          onChanged: selectedCategory == null
              ? null
              : (CreateTaxonomySubcategory? subcategory) {
                  if (subcategory == null) return;
                  _applyTaxonomyWithConfirmation(
                    draft: draft,
                    mainCategory: selectedCategory.id,
                    subcategory: subcategory.id,
                  );
                },
        ),
        if (selectedSubcategory != null) ...<Widget>[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(policy.label),
              subtitle: Text(policy.description),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _textField(
          id: 'short-description',
          errorFieldId: 'shortDescription',
          label: switch (policy.shortDescription) {
            PlaceFieldRequirement.required => 'Description *',
            PlaceFieldRequirement.recommended => 'Description (recommended)',
            _ => 'Description',
          },
          value: draft.shortDescription,
          maxLength: 180,
          maxLines: 3,
          helper: policy.shortDescription.isRequired
              ? '20–180 characters.'
              : 'You can add or improve this later.',
          onChanged: widget.controller.updateShortDescription,
        ),
        const SizedBox(height: 4),
        ExpansionTile(
          key: const ValueKey<String>('place-more-about'),
          tilePadding: EdgeInsets.zero,
          title: const Text('More about this place'),
          subtitle: const Text(
            'Optional description, language and attribution',
          ),
          children: <Widget>[
            _textField(
              id: 'full-description',
              errorFieldId: 'fullDescription',
              label: 'Detailed description',
              value: draft.fullDescription,
              maxLength: 5000,
              maxLines: 5,
              onChanged: widget.controller.updateFullDescription,
            ),
            const SizedBox(height: 12),
            if (policy.isManaged)
              DropdownButtonFormField<PlaceRelationship>(
                key: const ValueKey<String>('place-relationship'),
                value: place.relationshipToPlace,
                decoration: _decoration(
                  'Your relationship',
                  'relationshipToPlace',
                ),
                items: PlaceRelationship.values
                    .map(
                      (PlaceRelationship value) =>
                          DropdownMenuItem<PlaceRelationship>(
                            value: value,
                            child: Text(_relationshipLabel(value)),
                          ),
                    )
                    .toList(growable: false),
                onChanged: (PlaceRelationship? value) {
                  if (value != null) {
                    widget.controller.updatePlaceRelationship(value);
                  }
                },
              )
            else
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.people_outline),
                title: Text('Community contribution'),
                subtitle: Text(
                  'Public landmarks do not require an ownership claim.',
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: place.contentLocale,
              decoration: _decoration('Content language', 'contentLocale'),
              items: widget.controller.supportedContentLocales
                  .map(
                    (String locale) => DropdownMenuItem<String>(
                      value: locale,
                      child: Text(locale.toUpperCase()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) {
                if (value != null) {
                  widget.controller.updatePlaceContentLocale(value);
                }
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: widget.controller.supportedServiceLanguages
                  .map((String id) {
                    return FilterChip(
                      label: Text(id.toUpperCase()),
                      selected: place.languages.contains(id),
                      onSelected: (bool selected) {
                        final Set<String> next = <String>{...place.languages};
                        selected ? next.add(id) : next.remove(id);
                        widget.controller.updatePlaceLanguages(next);
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
        if (draft.subcategory.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          _criteriaFields(draft),
        ],
      ],
    );
  }

  Widget _criteriaFields(CreateDraftEntity draft) {
    final CategoryCriteriaResult? result = const GetCategoryCriteriaUseCase()(
      draft.subcategory,
    );
    if (result == null || result.fields.isEmpty) return const SizedBox.shrink();
    final Map<String, Object?> values = <String, Object?>{
      ...?draft.sectionData['criteria'] as Map<String, Object?>?,
    };
    return ExpansionTile(
      initiallyExpanded: result.profile.requiredFieldIds.isNotEmpty,
      tilePadding: EdgeInsets.zero,
      title: const Text('Category details'),
      subtitle: Text('Profile: ${result.profile.id.replaceAll('_', ' ')}'),
      children: result.fields
          .map((field) {
            final bool required = result.profile.requiredFieldIds.contains(
              field.id,
            );
            if (field.type == 'bool') {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${field.id.replaceAll('_', ' ')}${required ? ' *' : ''}',
                ),
                value: values[field.id] as bool? ?? false,
                onChanged: (bool value) =>
                    widget.controller.updateCategoryCriterion(field.id, value),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _textField(
                id: 'criterion-${field.id}',
                label:
                    '${field.id.replaceAll('_', ' ')}${required ? ' *' : ''}',
                value: values[field.id]?.toString() ?? '',
                helper: field.description,
                onChanged: (String value) =>
                    widget.controller.updateCategoryCriterion(field.id, value),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> _applyTaxonomyWithConfirmation({
    required CreateDraftEntity draft,
    required String mainCategory,
    required String subcategory,
  }) async {
    final bool changesSelection =
        draft.mainCategory != mainCategory || draft.subcategory != subcategory;
    final Map<String, Object?> currentCriteria = <String, Object?>{
      ...?draft.sectionData['criteria'] as Map<String, Object?>?,
    };
    if (changesSelection && currentCriteria.isNotEmpty) {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Change category?'),
          content: const Text(
            'Compatible category details will be kept. Fields that do not '
            'belong to the new profile will be removed from publication.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Change'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    widget.controller.applyTaxonomySelection(
      mainCategory: mainCategory,
      subcategory: subcategory,
    );
  }

  Widget _visitStep(PlaceDraftData place, PlaceCreationPolicy policy) {
    final PlaceLocationDraft location = place.location;
    return Column(
      children: <Widget>[
        _StepCard(
          title: 'Where is it?',
          subtitle: 'Tap the map and confirm the representative point.',
          children: <Widget>[
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      location.latitude ?? widget.controller.marketCenterLat,
                      location.longitude ?? widget.controller.marketCenterLng,
                    ),
                    zoom: 13,
                  ),
                  markers:
                      location.latitude == null || location.longitude == null
                      ? const <Marker>{}
                      : <Marker>{
                          Marker(
                            markerId: const MarkerId('place-draft-pin'),
                            position: LatLng(
                              location.latitude!,
                              location.longitude!,
                            ),
                          ),
                        },
                  onTap: (LatLng point) {
                    widget.controller.updatePlaceCoordinates(
                      latitude: point.latitude.toStringAsFixed(6),
                      longitude: point.longitude.toStringAsFixed(6),
                    );
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              key: const ValueKey<String>('confirm-place-pin'),
              onPressed: location.latitude == null || location.longitude == null
                  ? null
                  : widget.controller.confirmPlacePin,
              icon: Icon(
                location.pinConfirmed ? Icons.verified : Icons.location_on,
              ),
              label: Text(
                location.pinConfirmed ? 'Pin confirmed' : 'Confirm this pin',
              ),
            ),
            const SizedBox(height: 12),
            _textField(
              id: 'formatted-address',
              errorFieldId: 'formattedAddress',
              label: 'Formatted address',
              value: location.formattedAddress ?? '',
              onChanged: widget.controller.updatePlaceAddress,
            ),
            const SizedBox(height: 12),
            _textField(
              id: 'location-label',
              errorFieldId: 'locationLabel',
              label: 'Location label',
              value: location.locationLabel ?? '',
              helper: 'Required when there is no postal address.',
              onChanged: widget.controller.updatePlaceLocationLabel,
            ),
            if (policy.accessNote.isVisible) ...<Widget>[
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded:
                    (location.entranceHint?.trim().isNotEmpty ?? false),
                title: const Text('Add directions'),
                subtitle: const Text(
                  'Optional: entrance, path or meeting point',
                ),
                children: <Widget>[
                  _textField(
                    id: 'entrance-hint',
                    label: 'How to find this place',
                    value: location.entranceHint ?? '',
                    maxLength: 300,
                    maxLines: 2,
                    onChanged: widget.controller.updatePlaceEntranceHint,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${location.city}, ${location.countryCode} • ${location.timezoneId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (policy.hours.isRequired) ...<Widget>[
          const SizedBox(height: 12),
          _hoursCard(place),
        ] else if (policy.hours.isVisible) ...<Widget>[
          const SizedBox(height: 12),
          _StepCard(
            title: 'Access restrictions',
            subtitle: 'Add hours only when this place really has them.',
            children: <Widget>[
              ExpansionTile(
                key: const ValueKey<String>('place-optional-hours'),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: place.hours.mode != null,
                title: const Text('Add opening or access hours'),
                children: <Widget>[_hoursCard(place, required: false)],
              ),
            ],
          ),
        ],
        if (policy.visitPlanning.isVisible ||
            policy.amenities.isVisible ||
            policy.admission.isVisible ||
            policy.typicalSpend.isVisible) ...<Widget>[
          const SizedBox(height: 12),
          _StepCard(
            title: 'Optional visit details',
            subtitle: 'Add only information that is useful for this place.',
            children: <Widget>[
              ExpansionTile(
                key: const ValueKey<String>('place-optional-visit-details'),
                tilePadding: EdgeInsets.zero,
                title: const Text('Add more visit information'),
                children: <Widget>[_additionalVisitDetails(place, policy)],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _hoursCard(PlaceDraftData place, {bool required = true}) {
    final PlaceHoursDraft hours = place.hours;
    return _StepCard(
      title: 'When can people visit?',
      subtitle: 'Unknown is better than invented hours.',
      children: <Widget>[
        DropdownButtonFormField<PlaceHoursMode>(
          value: hours.mode,
          decoration: _decoration(
            required ? 'Hours mode *' : 'Hours mode',
            'mode',
          ),
          items: const <DropdownMenuItem<PlaceHoursMode>>[
            DropdownMenuItem(
              value: PlaceHoursMode.regular,
              child: Text('Regular schedule'),
            ),
            DropdownMenuItem(
              value: PlaceHoursMode.alwaysOpen,
              child: Text('Open 24/7'),
            ),
            DropdownMenuItem(
              value: PlaceHoursMode.unknown,
              child: Text('Hours unknown'),
            ),
            DropdownMenuItem(
              value: PlaceHoursMode.seasonal,
              enabled: false,
              child: Text('Seasonal (Phase 2)'),
            ),
          ],
          onChanged: (PlaceHoursMode? value) {
            if (value != null) widget.controller.updatePlaceHoursMode(value);
          },
        ),
        if (hours.mode == PlaceHoursMode.regular) ...<Widget>[
          const SizedBox(height: 14),
          for (final LocalOpeningPeriod period in hours.weeklyPeriods)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(_weekdayShort(period.dayOfWeek)),
              ),
              title: Text(
                '${_minuteLabel(period.openMinute)} – ${_minuteLabel(period.closeMinute)}',
              ),
              subtitle: period.closesNextDay
                  ? const Text('Closes next day')
                  : null,
              trailing: IconButton(
                tooltip: 'Remove period',
                onPressed: () =>
                    widget.controller.removePlaceOpeningPeriod(period.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          _periodEditor(),
        ],
        if (hours.mode == PlaceHoursMode.regular ||
            hours.mode == PlaceHoursMode.alwaysOpen) ...<Widget>[
          const Divider(height: 32),
          Text(
            'Date exceptions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final OpeningException exception in hours.exceptions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(exception.localDate),
              subtitle: Text(
                exception.kind == OpeningExceptionKind.closedAllDay
                    ? 'Closed all day'
                    : 'Custom hours',
              ),
              trailing: IconButton(
                onPressed: () =>
                    widget.controller.removePlaceException(exception.id),
                icon: const Icon(Icons.close),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: _textField(
                  id: 'exception-date',
                  label: 'YYYY-MM-DD',
                  value: '',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  widget.controller.addPlaceException(
                    localDate: _field('exception-date', '').text,
                    kind: OpeningExceptionKind.closedAllDay,
                  );
                  _field('exception-date', '').clear();
                },
                child: const Text('Add closed day'),
              ),
            ],
          ),
        ],
        const Divider(height: 32),
        DropdownButtonFormField<PlaceOperationalStatus>(
          value: place.operationalStatus.status,
          decoration: const InputDecoration(
            labelText: 'Current operational status',
            border: OutlineInputBorder(),
          ),
          items: PlaceOperationalStatus.values
              .map(
                (PlaceOperationalStatus value) =>
                    DropdownMenuItem<PlaceOperationalStatus>(
                      value: value,
                      child: Text(
                        value.name.replaceAllMapped(
                          RegExp(r'([A-Z])'),
                          (Match match) => ' ${match.group(1)!.toLowerCase()}',
                        ),
                      ),
                    ),
              )
              .toList(growable: false),
          onChanged: (PlaceOperationalStatus? status) {
            if (status == null) return;
            widget.controller.updatePlaceOperationalStatus(status: status);
          },
        ),
        if (place.operationalStatus.status ==
            PlaceOperationalStatus.temporarilyClosed) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _textField(
                  id: 'closed-from',
                  label: 'Closed from *',
                  value: place.operationalStatus.closedFromLocalDate ?? '',
                  onChanged: (String value) =>
                      widget.controller.updatePlaceOperationalStatus(
                        status: PlaceOperationalStatus.temporarilyClosed,
                        closedFromLocalDate: value,
                        closedUntilLocalDate:
                            place.operationalStatus.closedUntilLocalDate,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _textField(
                  id: 'closed-until',
                  label: 'Until (inclusive)',
                  value: place.operationalStatus.closedUntilLocalDate ?? '',
                  onChanged: (String value) =>
                      widget.controller.updatePlaceOperationalStatus(
                        status: PlaceOperationalStatus.temporarilyClosed,
                        closedFromLocalDate:
                            place.operationalStatus.closedFromLocalDate,
                        closedUntilLocalDate: value,
                      ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _periodEditor() {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _periodDay,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  border: OutlineInputBorder(),
                ),
                items: List<DropdownMenuItem<int>>.generate(
                  7,
                  (int index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(_weekdayShort(index + 1)),
                  ),
                ),
                onChanged: (int? value) =>
                    setState(() => _periodDay = value ?? 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _textField(
                id: 'period-open',
                label: 'Open HH:mm',
                value: '09:00',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _textField(
                id: 'period-close',
                label: 'Close HH:mm',
                value: '18:00',
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Closes next day'),
          value: _periodOvernight,
          onChanged: (bool value) => setState(() => _periodOvernight = value),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              final int? open = _parseTime(_field('period-open', '09:00').text);
              final int? close = _parseTime(
                _field('period-close', '18:00').text,
              );
              if (open == null || close == null) return;
              widget.controller.addPlaceOpeningPeriod(
                dayOfWeek: _periodDay,
                openMinute: open,
                closeMinute: close,
                closesNextDay: _periodOvernight,
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add interval'),
          ),
        ),
      ],
    );
  }

  Widget _additionalVisitDetails(
    PlaceDraftData place,
    PlaceCreationPolicy policy,
  ) {
    final PlaceVisitPlanningDraft planning = place.visitPlanning;
    final PlacePricingDraft pricing = place.pricing;
    return Column(
      children: <Widget>[
        if (policy.visitPlanning.isVisible)
          _StepCard(
            title: 'Help people plan the visit',
            subtitle:
                'These values improve time-fit without changing opening hours.',
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _textField(
                      id: 'recommended-minutes',
                      label: 'Recommended minutes',
                      value: planning.recommendedVisitMinutes?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      onChanged: (String value) => widget.controller
                          .updatePlaceVisitPlanning(recommendedMinutes: value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _textField(
                      id: 'minimum-minutes',
                      label: 'Minimum minutes',
                      value: planning.minimumVisitMinutes?.toString() ?? '',
                      keyboardType: TextInputType.number,
                      onChanged: (String value) => widget.controller
                          .updatePlaceVisitPlanning(minimumMinutes: value),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('A shorter visit can still work'),
                value: planning.allowsShortVisit,
                onChanged: (bool value) => widget.controller
                    .updatePlaceVisitPlanning(allowsShortVisit: value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Weather dependent'),
                value: planning.weatherDependent,
                onChanged: (bool value) => widget.controller
                    .updatePlaceVisitPlanning(weatherDependent: value),
              ),
              _bufferSlider(
                label: 'Arrival buffer',
                value: planning.arrivalBufferMinutes,
                onChanged: (int value) => widget.controller
                    .updatePlaceVisitPlanning(arrivalBufferMinutes: value),
              ),
              _bufferSlider(
                label: 'Exit buffer',
                value: planning.exitBufferMinutes,
                onChanged: (int value) => widget.controller
                    .updatePlaceVisitPlanning(exitBufferMinutes: value),
              ),
            ],
          ),
        if (policy.amenities.isVisible) const SizedBox(height: 12),
        if (policy.amenities.isVisible)
          _StepCard(
            title: 'Amenities',
            subtitle: 'Choose Yes or Unknown. Unset is never treated as No.',
            children: placeAmenityTaxonomy
                .map((PlaceAmenityDefinition amenity) {
                  final bool isPresent = place.amenityIds.contains(amenity.id);
                  final bool isUnknown = place.amenityUnknownIds.contains(
                    amenity.id,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(amenity.label),
                    subtitle: Text(amenity.group),
                    trailing: SegmentedButton<int>(
                      segments: const <ButtonSegment<int>>[
                        ButtonSegment<int>(value: 1, label: Text('Yes')),
                        ButtonSegment<int>(value: 0, label: Text('Unset')),
                        ButtonSegment<int>(value: -1, label: Text('?')),
                      ],
                      selected: <int>{isPresent ? 1 : (isUnknown ? -1 : 0)},
                      onSelectionChanged: (Set<int> selected) {
                        final int value = selected.first;
                        widget.controller.setPlaceAmenity(
                          amenity.id,
                          available: value == 1
                              ? true
                              : (value == -1 ? null : false),
                        );
                      },
                    ),
                  );
                })
                .toList(growable: false),
          ),
        if (policy.admission.isVisible || policy.typicalSpend.isVisible)
          const SizedBox(height: 12),
        if (policy.admission.isVisible || policy.typicalSpend.isVisible)
          _StepCard(
            title: 'Price',
            subtitle: 'Entry price and typical spend are separate concepts.',
            children: <Widget>[
              if (policy.admission.isVisible)
                DropdownButtonFormField<PlaceEntryType>(
                  value: pricing.entryType,
                  decoration: _decoration('Admission', 'entryType'),
                  items:
                      const <PlaceEntryType>[
                            PlaceEntryType.free,
                            PlaceEntryType.paid,
                            PlaceEntryType.mixed,
                            PlaceEntryType.unknown,
                          ]
                          .map(
                            (PlaceEntryType value) =>
                                DropdownMenuItem<PlaceEntryType>(
                                  value: value,
                                  child: Text(_entryTypeLabel(value)),
                                ),
                          )
                          .toList(growable: false),
                  onChanged: (PlaceEntryType? value) {
                    if (value != null) {
                      widget.controller.updatePlaceEntryType(value);
                    }
                  },
                ),
              if (policy.admission.isVisible &&
                  (pricing.entryType == PlaceEntryType.paid ||
                      pricing.entryType == PlaceEntryType.mixed)) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _textField(
                        id: 'entry-from',
                        errorFieldId: 'entryPriceFrom',
                        label: 'Entry from, ${pricing.currencyCode} *',
                        value: pricing.entryPriceFrom?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        onChanged: (String value) => widget.controller
                            .updatePlacePricing(entryFrom: value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _textField(
                        id: 'entry-to',
                        errorFieldId: 'entryPriceTo',
                        label: 'Entry to, ${pricing.currencyCode}',
                        value: pricing.entryPriceTo?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        onChanged: (String value) => widget.controller
                            .updatePlacePricing(entryTo: value),
                      ),
                    ),
                  ],
                ),
              ],
              if (policy.typicalSpend.isVisible) const SizedBox(height: 12),
              if (policy.typicalSpend.isVisible)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _textField(
                        id: 'spend-from',
                        label: 'Typical spend from',
                        value: pricing.typicalSpendFrom?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        onChanged: (String value) => widget.controller
                            .updatePlacePricing(spendFrom: value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _textField(
                        id: 'spend-to',
                        label: 'Typical spend to',
                        value: pricing.typicalSpendTo?.toString() ?? '',
                        keyboardType: TextInputType.number,
                        onChanged: (String value) => widget.controller
                            .updatePlacePricing(spendTo: value),
                      ),
                    ),
                  ],
                ),
              if (policy.admission.isVisible ||
                  policy.typicalSpend.isVisible) ...<Widget>[
                const SizedBox(height: 12),
                _textField(
                  id: 'pricing-note',
                  errorFieldId: 'pricingNote',
                  label: pricing.entryType == PlaceEntryType.mixed
                      ? 'Pricing explanation *'
                      : 'Pricing note',
                  value: pricing.pricingNote ?? '',
                  maxLength: 300,
                  onChanged: (String value) =>
                      widget.controller.updatePlacePricing(note: value),
                ),
                const SizedBox(height: 12),
                _textField(
                  id: 'pricing-url',
                  errorFieldId: 'officialPricingUrl',
                  label: 'Official pricing URL (https)',
                  value: pricing.officialPricingUrl ?? '',
                  keyboardType: TextInputType.url,
                  onChanged: (String value) =>
                      widget.controller.updatePlacePricing(pricingUrl: value),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _publishStep(
    CreateDraftEntity draft,
    PlaceDraftData place,
    PlaceCreationPolicy policy,
  ) {
    final List<PlaceValidationIssue> issues =
        widget.state.placeValidationIssues;
    final List<PlaceValidationIssue> warnings = issues
        .where(
          (PlaceValidationIssue issue) =>
              issue.severity == PlaceValidationSeverity.warning,
        )
        .toList(growable: false);
    return Column(
      children: <Widget>[
        if (policy.contacts.isVisible || policy.booking.isVisible)
          _StepCard(
            title: 'Optional public contacts',
            subtitle:
                'Add only official public details. HTTPS links are required.',
            children: <Widget>[
              if (policy.contacts.isVisible) ...<Widget>[
                _textField(
                  id: 'website-url',
                  label: 'Official website',
                  value: place.contacts.websiteUrl ?? '',
                  keyboardType: TextInputType.url,
                  onChanged: (String value) =>
                      widget.controller.updatePlaceContacts(websiteUrl: value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _textField(
                        id: 'place-phone',
                        label: 'Public phone',
                        value: place.contacts.phone ?? '',
                        keyboardType: TextInputType.phone,
                        onChanged: (String value) =>
                            widget.controller.updatePlaceContacts(phone: value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _textField(
                        id: 'place-email',
                        label: 'Public email',
                        value: place.contacts.email ?? '',
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (String value) =>
                            widget.controller.updatePlaceContacts(email: value),
                      ),
                    ),
                  ],
                ),
              ],
              if (policy.booking.isVisible) ...<Widget>[
                const SizedBox(height: 12),
                _textField(
                  id: 'booking-url',
                  label: 'Official booking landing page',
                  value: place.contacts.bookingUrl ?? '',
                  keyboardType: TextInputType.url,
                  onChanged: (String value) =>
                      widget.controller.updatePlaceContacts(bookingUrl: value),
                ),
              ],
            ],
          ),
        if (policy.contacts.isVisible || policy.booking.isVisible)
          const SizedBox(height: 12),
        _StepCard(
          title: 'Photos',
          subtitle: policy.cover.isRequired
              ? 'A cover is required. Gallery is optional.'
              : 'A cover is recommended and can be added later.',
          children: <Widget>[
            _textField(
              id: 'cover-image',
              errorFieldId: 'coverImage',
              label: policy.cover.isRequired
                  ? 'Cover image URL/path *'
                  : 'Cover image URL/path (recommended)',
              value: draft.media.coverImage,
              onChanged: widget.controller.updateCoverImage,
            ),
            ExpansionTile(
              key: const ValueKey<String>('place-gallery-details'),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: draft.media.gallery.isNotEmpty,
              title: const Text('Add gallery images'),
              subtitle: const Text('Optional · maximum 12'),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _textField(
                        id: 'gallery-image',
                        label: 'Gallery image URL/path',
                        value: '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: draft.media.gallery.length >= 12
                          ? null
                          : () {
                              widget.controller.addGalleryImage(
                                _field('gallery-image', '').text,
                              );
                              _field('gallery-image', '').clear();
                            },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                for (int index = 0; index < draft.media.gallery.length; index++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(
                      draft.media.gallery[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      onPressed: () =>
                          widget.controller.removeGalleryImageAt(index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PlacePreview(draft: draft, place: place, policy: policy),
        if (widget.state.placeDuplicateMatches.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Could this place already exist?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final PlaceDuplicateMatch match
                      in widget.state.placeDuplicateMatches)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.content_copy_outlined),
                      title: Text(match.candidate.title),
                      subtitle: Text(
                        '${match.distanceMeters.round()} m • '
                        '${match.reasons.join(', ').replaceAll('_', ' ')}',
                      ),
                    ),
                  FilledButton.tonal(
                    onPressed: widget.controller.confirmPlaceIsDifferent,
                    child: const Text('This is a different place'),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (issues.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _ValidationSummary(issues: issues),
        ],
        if (warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => widget.controller.acceptPlaceWarnings(
              warnings.map((PlaceValidationIssue issue) => issue.code),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('I reviewed these warnings'),
          ),
        ],
      ],
    );
  }

  Widget _navigation() {
    final bool busy =
        widget.state.status == CreateStatus.saving ||
        widget.state.status == CreateStatus.publishing;
    final int step = widget.state.placeStep;
    return Row(
      children: <Widget>[
        if (step > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () => widget.controller.goToPlaceStep(step - 1),
              child: const Text('Back'),
            ),
          ),
        if (step > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: step < 2
              ? FilledButton(
                  key: const ValueKey<String>('place-next-step'),
                  onPressed: busy
                      ? null
                      : () => widget.controller.goToPlaceStep(step + 1),
                  child: const Text('Save & continue'),
                )
              : FilledButton.icon(
                  key: const ValueKey<String>('publish-place'),
                  onPressed: busy
                      ? null
                      : () async {
                          final bool published = await widget.controller
                              .publishDraft();
                          if (published) widget.onPublished();
                        },
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(busy ? 'Publishing…' : 'Send for review'),
                ),
        ),
      ],
    );
  }

  Widget _bufferSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$label: $value min'),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 120,
          divisions: 24,
          label: '$value min',
          onChanged: (double next) => onChanged(next.round()),
        ),
      ],
    );
  }

  Widget _textField({
    required String id,
    required String label,
    required String value,
    ValueChanged<String>? onChanged,
    String? helper,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? errorFieldId,
  }) {
    return TextField(
      key: ValueKey<String>('place-$id'),
      controller: _field(id, value),
      onChanged: onChanged,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _decoration(
        label,
        errorFieldId ?? id,
      ).copyWith(helperText: helper),
    );
  }

  InputDecoration _decoration(String label, String fieldId) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      errorText: widget.state.validationErrors[fieldId],
    );
  }
}

class _PlaceProgressHeader extends StatelessWidget {
  const _PlaceProgressHeader({required this.state});

  final CreateState state;

  @override
  Widget build(BuildContext context) {
    final String saveLabel = switch (state.saveStatus) {
      CreateSaveStatus.saved => 'Saved',
      CreateSaveStatus.saving => 'Saving…',
      CreateSaveStatus.unsaved => 'Unsaved changes',
      CreateSaveStatus.failed => 'Save failed • retry available',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Create a place',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(saveLabel, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (state.placeStep + 1) / placeCreateSteps.length,
            ),
            const SizedBox(height: 10),
            Text(
              '${state.placeStep + 1}/${placeCreateSteps.length} • '
              '${placeCreateSteps[state.placeStep].title}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(placeCreateSteps[state.placeStep].description),
          ],
        ),
      ),
    );
  }
}

class _PlaceCreatorAssistPanel extends StatelessWidget {
  const _PlaceCreatorAssistPanel({
    required this.state,
    required this.onGenerate,
    required this.onApply,
    required this.onDiscard,
  });

  final CreateState state;
  final Future<void> Function() onGenerate;
  final VoidCallback onApply;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final PlaceEnrichmentProposal? proposal = state.placeEnrichmentProposal;
    return Card(
      key: const ValueKey<String>('place-creator-assist'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Finish with AI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Chip(label: Text('Local demo')),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Review this draft, suggest a taxonomy match and identify useful '
              'missing details. Nothing is published automatically.',
            ),
            if (state.placeEnrichmentError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                state.placeEnrichmentError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (proposal != null) ...<Widget>[
              const Divider(height: 24),
              if (proposal.suggestedSubcategoryId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Suggested category'),
                  subtitle: Text(
                    '${proposal.suggestedCategoryId} / '
                    '${proposal.suggestedSubcategoryId}',
                  ),
                ),
              if (proposal.suggestedShortDescription != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notes_outlined),
                  title: const Text('Editable description draft'),
                  subtitle: Text(proposal.suggestedShortDescription!),
                ),
              if (proposal.suggestedVisitMinutes != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timelapse_outlined),
                  title: Text(
                    'Estimated visit: ${proposal.suggestedVisitMinutes} min',
                  ),
                ),
              if (proposal.clarifyingQuestion != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline),
                  title: Text(proposal.clarifyingQuestion!),
                ),
              if (proposal.missingRecommendedFieldIds.isNotEmpty)
                Text(
                  'Could improve later: '
                  '${proposal.missingRecommendedFieldIds.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              for (final String disclosure in proposal.disclosures)
                Text(
                  '• $disclosure',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDiscard,
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>('apply-place-assist'),
                      onPressed: proposal.canApply ? onApply : null,
                      child: const Text('Apply suggestions'),
                    ),
                  ),
                ],
              ),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const ValueKey<String>('generate-place-assist'),
                onPressed: state.placeEnrichmentLoading ? null : onGenerate,
                icon: state.placeEnrichmentLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(
                  state.placeEnrichmentLoading
                      ? 'Reviewing…'
                      : 'Review this Place',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PlacePreview extends StatelessWidget {
  const _PlacePreview({
    required this.draft,
    required this.place,
    required this.policy,
  });

  final CreateDraftEntity draft;
  final PlaceDraftData place;
  final PlaceCreationPolicy policy;

  @override
  Widget build(BuildContext context) {
    final String location =
        place.location.formattedAddress ??
        place.location.locationLabel ??
        place.location.city;
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: .35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Preview'),
            const SizedBox(height: 8),
            Text(
              draft.title.isEmpty ? 'Untitled place' : draft.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if (draft.shortDescription.trim().isNotEmpty)
              Text(draft.shortDescription)
            else
              Text('${policy.label} · ${place.location.city}'),
            const SizedBox(height: 12),
            _PreviewRow(icon: Icons.route, text: location),
            if (policy.hours.isVisible && place.hours.mode != null)
              _PreviewRow(
                icon: Icons.schedule,
                text: _hoursModeLabel(place.hours.mode),
              ),
            if (policy.admission.isVisible && place.pricing.entryType != null)
              _PreviewRow(
                icon: Icons.payments_outlined,
                text: _entryTypeLabel(place.pricing.entryType),
              ),
            if (policy.visitPlanning.isVisible &&
                place.visitPlanning.recommendedVisitMinutes != null)
              _PreviewRow(
                icon: Icons.timelapse,
                text:
                    '${place.visitPlanning.recommendedVisitMinutes} min recommended',
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Route (primary action)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.issues});

  final List<PlaceValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Final checks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final PlaceValidationIssue issue in issues)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  issue.severity == PlaceValidationSeverity.error
                      ? Icons.error_outline
                      : Icons.warning_amber,
                  color: issue.severity == PlaceValidationSeverity.error
                      ? Theme.of(context).colorScheme.error
                      : Colors.orange.shade800,
                ),
                title: Text(issue.code.replaceAll('_', ' ')),
                subtitle: Text(issue.sectionId),
              ),
          ],
        ),
      ),
    );
  }
}

String _relationshipLabel(PlaceRelationship value) => switch (value) {
  PlaceRelationship.owner => 'Owner',
  PlaceRelationship.staff => 'Staff member',
  PlaceRelationship.visitor => 'Visitor',
  PlaceRelationship.curator => 'Local curator',
};

String _entryTypeLabel(PlaceEntryType? value) => switch (value) {
  PlaceEntryType.free => 'Free entry',
  PlaceEntryType.paid => 'Paid entry',
  PlaceEntryType.mixed => 'Free and paid areas',
  PlaceEntryType.notApplicable => 'No entry ticket concept',
  PlaceEntryType.unknown => 'Unknown',
  null => 'Not selected',
};

String _hoursModeLabel(PlaceHoursMode? value) => switch (value) {
  PlaceHoursMode.regular => 'Regular opening hours',
  PlaceHoursMode.alwaysOpen => 'Open 24/7',
  PlaceHoursMode.seasonal => 'Seasonal hours',
  PlaceHoursMode.unknown => 'Opening hours unknown',
  null => 'Hours not selected',
};

String _weekdayShort(int day) => const <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
][day.clamp(1, 7) - 1];

String _minuteLabel(int minute) {
  return '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}

int? _parseTime(String raw) {
  final List<String> parts = raw.trim().split(':');
  if (parts.length != 2) return null;
  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}
