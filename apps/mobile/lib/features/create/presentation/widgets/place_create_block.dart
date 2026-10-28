import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../../../core/parsing/input_parsers.dart';

import '../../application/controllers/create_controller.dart';
import '../../application/get_category_criteria_usecase.dart';
import '../../application/place_create_config.dart';
import '../../application/state/create_state.dart';
import '../../application/create_taxonomy.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/location_search_suggestion.dart';
import '../../domain/entities/place_draft_data.dart';
import '../../domain/entities/place_duplicate_candidate.dart';
import '../../domain/entities/place_enrichment_proposal.dart';
import '../../domain/entities/place_creation_policy.dart';
import '../../domain/entities/place_validation_issue.dart';
import 'location_search_suggestion_list.dart';
import 'create_texts.dart';
import 'create_form_texts.dart';

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

  // Matches LocationSearchRuntimeConfig.debounceMilliseconds' default.
  static const Duration _locationSearchDebounce = Duration(milliseconds: 350);
  Timer? _locationSearchDebounceTimer;

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
    _locationSearchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onTitleChanged(String value) {
    widget.controller.updateTitle(value);
    _locationSearchDebounceTimer?.cancel();
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      widget.controller.clearPlaceLocationSuggestions();
      return;
    }
    _locationSearchDebounceTimer = Timer(_locationSearchDebounce, () {
      if (!mounted) return;
      widget.controller.searchPlaceLocation(trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final CreateDraftEntity draft = widget.state.draft;
    final PlaceDraftData? place = draft.placeData;
    if (place == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(context.l10n.createFormPlaceDataBeingPrepared),
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
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Read-only draft'),
              subtitle: Text(
                context.l10n.createFormCreatePlaceCapabilityRequiredEditPublish,
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
            CreateTexts.notice(context.l10n, widget.state.message!),
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
      title: context.l10n.createFormWhatPlace,
      subtitle: context.l10n.createFormChooseCategoryFormKeepsOnlyRelevant,
      children: <Widget>[
        _textField(
          id: 'title',
          label: context.l10n.createFormPlaceName,
          value: draft.title,
          maxLength: 100,
          onChanged: _onTitleChanged,
        ),
        if (widget.state.placeLocationSearchLoading)
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (widget.state.placeLocationSuggestions.isNotEmpty)
          LocationSearchSuggestionList(
            suggestions: widget.state.placeLocationSuggestions,
            onSelected: (LocationSearchSuggestion suggestion) {
              widget.controller.selectPlaceLocationSuggestion(suggestion);
            },
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CreateTaxonomyCategory>(
          isExpanded: true,
          initialValue: selectedCategory,
          decoration: _decoration(
            context.l10n.createFormCategoryRequired,
            'mainCategory',
          ),
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
          isExpanded: true,
          initialValue: selectedSubcategory,
          decoration: _decoration(
            context.l10n.createFormSubcategoryRequired,
            'subcategory',
          ),
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
              title: Text(context.l10n.createPlacePolicyLabel(policy.id.name)),
              subtitle: Text(
                context.l10n.createPlacePolicyDescription(policy.id.name),
              ),
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
              : context.l10n.createFormYouCanAddImproveLater,
          onChanged: widget.controller.updateShortDescription,
        ),
        const SizedBox(height: 4),
        ExpansionTile(
          key: const ValueKey<String>('place-more-about'),
          tilePadding: EdgeInsets.zero,
          title: Text(context.l10n.createFormMoreAboutPlace),
          subtitle: Text(
            context.l10n.createFormOptionalDescriptionLanguageAttribution,
          ),
          children: <Widget>[
            _textField(
              id: 'full-description',
              errorFieldId: 'fullDescription',
              label: context.l10n.createFormDetailedDescription,
              value: draft.fullDescription,
              maxLength: 5000,
              maxLines: 5,
              onChanged: widget.controller.updateFullDescription,
            ),
            const SizedBox(height: 12),
            if (policy.isManaged)
              DropdownButtonFormField<PlaceRelationship>(
                isExpanded: true,
                key: const ValueKey<String>('place-relationship'),
                initialValue: place.relationshipToPlace,
                decoration: _decoration(
                  context.l10n.createFormYourRelationship,
                  'relationshipToPlace',
                ),
                items: PlaceRelationship.values
                    .map(
                      (PlaceRelationship value) =>
                          DropdownMenuItem<PlaceRelationship>(
                            value: value,
                            child: Text(
                              _relationshipLabel(context.l10n, value),
                            ),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.people_outline),
                title: Text(context.l10n.createFormCommunityContribution),
                subtitle: Text(
                  context.l10n.createFormPublicLandmarksDoNotRequireOwnership,
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: place.contentLocale,
              decoration: _decoration(
                context.l10n.createFormContentLanguage,
                'contentLocale',
              ),
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
      title: Text(context.l10n.createFormCategoryDetails),
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
          title: Text(context.l10n.createFormChangeCategory),
          content: Text(
            context.l10n.createFormCompatibleCategoryDetailsWillKeptFields,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.createFormCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.createFormChange),
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
          title: context.l10n.createFormWhere,
          subtitle: context.l10n.createFormTapMapConfirmRepresentativePoint,
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
                location.pinConfirmed
                    ? context.l10n.createFormPinConfirmed
                    : context.l10n.createFormConfirmPin,
              ),
            ),
            const SizedBox(height: 12),
            _textField(
              id: 'formatted-address',
              errorFieldId: 'formattedAddress',
              label: context.l10n.createFormFormattedAddress,
              value: location.formattedAddress ?? '',
              onChanged: widget.controller.updatePlaceAddress,
            ),
            const SizedBox(height: 12),
            _textField(
              id: 'location-label',
              errorFieldId: 'locationLabel',
              label: context.l10n.createFormLocationLabel,
              value: location.locationLabel ?? '',
              helper: context.l10n.createFormRequiredWhenThereNoPostalAddress,
              onChanged: widget.controller.updatePlaceLocationLabel,
            ),
            if (policy.accessNote.isVisible) ...<Widget>[
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                initiallyExpanded:
                    (location.entranceHint?.trim().isNotEmpty ?? false),
                title: Text(context.l10n.createFormAddDirections),
                subtitle: const Text(
                  'Optional: entrance, path or meeting point',
                ),
                children: <Widget>[
                  _textField(
                    id: 'entrance-hint',
                    label: context.l10n.createFormHowFindPlace,
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
            title: context.l10n.createFormAccessRestrictions,
            subtitle: context.l10n.createFormAddHoursOnlyWhenPlaceReally,
            children: <Widget>[
              ExpansionTile(
                key: const ValueKey<String>('place-optional-hours'),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: place.hours.mode != null,
                title: Text(context.l10n.createFormAddOpeningAccessHours),
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
            title: context.l10n.createFormOptionalVisitDetails,
            subtitle: context.l10n.createFormAddOnlyInformationThatUsefulPlace,
            children: <Widget>[
              ExpansionTile(
                key: const ValueKey<String>('place-optional-visit-details'),
                tilePadding: EdgeInsets.zero,
                title: Text(context.l10n.createFormAddMoreVisitInformation),
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
      title: context.l10n.createFormWhenCanPeopleVisit,
      subtitle: context.l10n.createFormUnknownBetterThanInventedHours,
      children: <Widget>[
        DropdownButtonFormField<PlaceHoursMode>(
          isExpanded: true,
          initialValue: hours.mode,
          decoration: _decoration(
            required
                ? context.l10n.createFormHoursMode
                : context.l10n.createFormHoursMode2,
            'mode',
          ),
          items: <DropdownMenuItem<PlaceHoursMode>>[
            DropdownMenuItem(
              value: PlaceHoursMode.regular,
              child: Text(context.l10n.createFormRegularSchedule),
            ),
            DropdownMenuItem(
              value: PlaceHoursMode.alwaysOpen,
              child: Text('Open 24/7'),
            ),
            DropdownMenuItem(
              value: PlaceHoursMode.unknown,
              child: Text(context.l10n.createFormHoursUnknown),
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
                child: Text(_weekdayShort(context, period.dayOfWeek)),
              ),
              title: Text(
                '${_minuteLabel(period.openMinute)} – ${_minuteLabel(period.closeMinute)}',
              ),
              subtitle: period.closesNextDay
                  ? Text(context.l10n.createFormClosesNextDay)
                  : null,
              trailing: IconButton(
                tooltip: context.l10n.createFormRemovePeriod,
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
            context.l10n.createFormDateExceptions,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final OpeningException exception in hours.exceptions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(exception.localDate),
              subtitle: Text(
                exception.kind == OpeningExceptionKind.closedAllDay
                    ? context.l10n.createFormClosedAllDay
                    : context.l10n.createFormCustomHours,
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
                child: Text(context.l10n.createFormAddClosedDay),
              ),
            ],
          ),
        ],
        const Divider(height: 32),
        DropdownButtonFormField<PlaceOperationalStatus>(
          isExpanded: true,
          initialValue: place.operationalStatus.status,
          decoration: InputDecoration(
            labelText: context.l10n.createFormCurrentOperationalStatus,
            border: OutlineInputBorder(),
          ),
          items: PlaceOperationalStatus.values
              .map(
                (PlaceOperationalStatus value) =>
                    DropdownMenuItem<PlaceOperationalStatus>(
                      value: value,
                      child: Text(createOptionText(context.l10n, value)),
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
                  label: context.l10n.createFormClosedFrom,
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
                isExpanded: true,
                initialValue: _periodDay,
                decoration: InputDecoration(
                  labelText: context.l10n.createFormDay,
                  border: OutlineInputBorder(),
                ),
                items: List<DropdownMenuItem<int>>.generate(
                  7,
                  (int index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(_weekdayShort(context, index + 1)),
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
                label: context.l10n.createFormOpenHhMm,
                value: '09:00',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _textField(
                id: 'period-close',
                label: context.l10n.createFormCloseHhMm,
                value: '18:00',
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.createFormClosesNextDay),
          value: _periodOvernight,
          onChanged: (bool value) => setState(() => _periodOvernight = value),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              final int? open = parseClockMinute(
                _field('period-open', '09:00').text,
              );
              final int? close = parseClockMinute(
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
            label: Text(context.l10n.createFormAddInterval),
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
            title: context.l10n.createFormHelpPeoplePlanVisit,
            subtitle: context.l10n.createFormTheseValuesImproveTimeFitWithout,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _textField(
                      id: 'recommended-minutes',
                      label: context.l10n.createFormRecommendedMinutes,
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
                      label: context.l10n.createFormMinimumMinutes,
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
                title: Text(context.l10n.createFormWeatherDependent),
                value: planning.weatherDependent,
                onChanged: (bool value) => widget.controller
                    .updatePlaceVisitPlanning(weatherDependent: value),
              ),
              _bufferSlider(
                label: context.l10n.createFormArrivalBuffer,
                value: planning.arrivalBufferMinutes,
                onChanged: (int value) => widget.controller
                    .updatePlaceVisitPlanning(arrivalBufferMinutes: value),
              ),
              _bufferSlider(
                label: context.l10n.createFormExitBuffer,
                value: planning.exitBufferMinutes,
                onChanged: (int value) => widget.controller
                    .updatePlaceVisitPlanning(exitBufferMinutes: value),
              ),
            ],
          ),
        if (policy.amenities.isVisible) const SizedBox(height: 12),
        if (policy.amenities.isVisible)
          _StepCard(
            title: context.l10n.createFormAmenities,
            subtitle: context.l10n.createFormChooseYesUnknownUnsetNeverTreated,
            children: placeAmenityTaxonomy
                .map((PlaceAmenityDefinition amenity) {
                  final bool isPresent = place.amenityIds.contains(amenity.id);
                  final bool isUnknown = place.amenityUnknownIds.contains(
                    amenity.id,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.createAmenityLabel(amenity.id)),
                    subtitle: Text(
                      context.l10n.createAmenityGroup(amenity.group),
                    ),
                    trailing: SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        ButtonSegment<int>(
                          value: 1,
                          label: Text(context.l10n.createFormYes),
                        ),
                        ButtonSegment<int>(
                          value: 0,
                          label: Text(context.l10n.createFormUnset),
                        ),
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
            title: context.l10n.createFormPrice,
            subtitle: context.l10n.createFormEntryPriceTypicalSpendAreSeparate,
            children: <Widget>[
              if (policy.admission.isVisible)
                DropdownButtonFormField<PlaceEntryType>(
                  isExpanded: true,
                  initialValue: pricing.entryType,
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
                                  child: Text(
                                    _entryTypeLabel(context.l10n, value),
                                  ),
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
                        label: context.l10n.createFormEntryFrom(
                          pricing.currencyCode,
                        ),
                        value: pricing.entryPriceFrom?.formatMajor() ?? '',
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
                        label: context.l10n.createFormEntry(
                          pricing.currencyCode,
                        ),
                        value: pricing.entryPriceTo?.formatMajor() ?? '',
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
                        label: context.l10n.createFormTypicalSpendFrom,
                        value: pricing.typicalSpendFrom?.formatMajor() ?? '',
                        keyboardType: TextInputType.number,
                        onChanged: (String value) => widget.controller
                            .updatePlacePricing(spendFrom: value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _textField(
                        id: 'spend-to',
                        label: context.l10n.createFormTypicalSpend,
                        value: pricing.typicalSpendTo?.formatMajor() ?? '',
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
                      ? context.l10n.createFormPricingExplanation
                      : context.l10n.createFormPricingNote,
                  value: pricing.pricingNote ?? '',
                  maxLength: 300,
                  onChanged: (String value) =>
                      widget.controller.updatePlacePricing(note: value),
                ),
                const SizedBox(height: 12),
                _textField(
                  id: 'pricing-url',
                  errorFieldId: 'officialPricingUrl',
                  label: context.l10n.createFormOfficialPricingUrlHttps,
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
            title: context.l10n.createFormOptionalPublicContacts,
            subtitle: context.l10n.createFormAddOnlyOfficialPublicDetailsHttps,
            children: <Widget>[
              if (policy.contacts.isVisible) ...<Widget>[
                _textField(
                  id: 'website-url',
                  label: context.l10n.createFormOfficialWebsite,
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
                        label: context.l10n.createFormPublicPhone,
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
                        label: context.l10n.createFormPublicEmail,
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
                  label: context.l10n.createFormOfficialBookingLandingPage,
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
          title: context.l10n.createFormPhotos,
          subtitle: policy.cover.isRequired
              ? context.l10n.createFormCoverRequiredGalleryOptional
              : 'A cover is recommended and can be added later.',
          children: <Widget>[
            _textField(
              id: 'cover-image',
              errorFieldId: 'coverImage',
              label: policy.cover.isRequired
                  ? context.l10n.createFormCoverImageUrlPath
                  : context.l10n.createFormCoverImageUrlPathRecommended,
              value: draft.media.coverImage,
              onChanged: widget.controller.updateCoverImage,
            ),
            ExpansionTile(
              key: const ValueKey<String>('place-gallery-details'),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: draft.media.gallery.isNotEmpty,
              title: Text(context.l10n.createFormAddGalleryImages),
              subtitle: const Text('Optional · maximum 12'),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _textField(
                        id: 'gallery-image',
                        label: context.l10n.createFormGalleryImageUrlPath,
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
                      child: Text(context.l10n.createFormAdd),
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
                    context.l10n.createFormCouldPlaceAlreadyExist,
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
                    child: Text(context.l10n.createFormDifferentPlace),
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
              child: Text(context.l10n.createFormBack),
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
                  label: Text(
                    busy ? 'Publishing…' : context.l10n.createFormSendReview,
                  ),
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
      errorText: switch (widget.state.validationErrors[fieldId]) {
        final String id => CreateTexts.fieldError(context.l10n, id),
        null => null,
      },
    );
  }
}

class _PlaceProgressHeader extends StatelessWidget {
  const _PlaceProgressHeader({required this.state});

  final CreateState state;

  @override
  Widget build(BuildContext context) {
    final String saveLabel = switch (state.saveStatus) {
      CreateSaveStatus.saved => context.l10n.createFormSaved,
      CreateSaveStatus.saving => context.l10n.createFormSaving,
      CreateSaveStatus.unsaved => context.l10n.createFormUnsavedChanges,
      CreateSaveStatus.failed =>
        context.l10n.createFormSaveFailedRetryAvailable,
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
                    context.l10n.createFormCreatePlace,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    saveLabel,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (state.placeStep + 1) / placeCreateSteps.length,
            ),
            const SizedBox(height: 10),
            Text(
              '${state.placeStep + 1}/${placeCreateSteps.length} • '
              '${createFormText(context.l10n, placeCreateSteps[state.placeStep].titleId)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              createFormText(
                context.l10n,
                placeCreateSteps[state.placeStep].descriptionId,
              ),
            ),
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
                    context.l10n.createFormFinishWithAi,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Flexible(
                  child: Chip(
                    label: Text(
                      context.l10n.createFormLocalDemo,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.createFormReviewDraftSuggestTaxonomyMatchIdentify,
            ),
            if (state.placeEnrichmentError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                CreateTexts.notice(context.l10n, state.placeEnrichmentError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (proposal != null) ...<Widget>[
              const Divider(height: 24),
              if (proposal.suggestedSubcategoryId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.category_outlined),
                  title: Text(context.l10n.createFormSuggestedCategory),
                  subtitle: Text(
                    '${proposal.suggestedCategoryId} / '
                    '${proposal.suggestedSubcategoryId}',
                  ),
                ),
              if (proposal.suggestedShortDescription != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notes_outlined),
                  title: Text(context.l10n.createFormEditableDescriptionDraft),
                  subtitle: Text(proposal.suggestedShortDescription!),
                ),
              if (proposal.suggestedVisitMinutes != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timelapse_outlined),
                  title: Text(
                    context.l10n.createFormEstimatedVisitMin(
                      proposal.suggestedVisitMinutes!,
                    ),
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
                  context.l10n
                      .createFormCouldImproveLaterProposalMissingrecommendedfieldidsJoin(
                        proposal.missingRecommendedFieldIds.length,
                      ),
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
                      child: Text(context.l10n.createFormDiscard),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey<String>('apply-place-assist'),
                      onPressed: proposal.canApply ? onApply : null,
                      child: Text(context.l10n.createFormApplySuggestions),
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
                      : context.l10n.createFormReviewPlace,
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
            Text(context.l10n.createFormPreview),
            const SizedBox(height: 8),
            Text(
              draft.title.isEmpty
                  ? context.l10n.createFormUntitledPlace
                  : draft.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            if (draft.shortDescription.trim().isNotEmpty)
              Text(draft.shortDescription)
            else
              Text(
                '${context.l10n.createPlacePolicyLabel(policy.id.name)} · ${place.location.city}',
              ),
            const SizedBox(height: 12),
            _PreviewRow(icon: Icons.route, text: location),
            if (policy.hours.isVisible && place.hours.mode != null)
              _PreviewRow(
                icon: Icons.schedule,
                text: _hoursModeLabel(context.l10n, place.hours.mode),
              ),
            if (policy.admission.isVisible && place.pricing.entryType != null)
              _PreviewRow(
                icon: Icons.payments_outlined,
                text: _entryTypeLabel(context.l10n, place.pricing.entryType),
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
              context.l10n.placeFinalChecks,
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
                // L4: the stable code and section stay in the issue; only
                // their display is localized.
                title: Text(context.l10n.placeValidationIssue(issue.code)),
                subtitle: Text(
                  context.l10n.placeValidationSection(issue.sectionId),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _relationshipLabel(AppLocalizations l10n, PlaceRelationship value) =>
    switch (value) {
      PlaceRelationship.owner => l10n.createFormOwner,
      PlaceRelationship.staff => l10n.createFormStaffMember,
      PlaceRelationship.visitor => l10n.createFormVisitor,
      PlaceRelationship.curator => l10n.createFormLocalCurator,
    };

String _entryTypeLabel(AppLocalizations l10n, PlaceEntryType? value) =>
    switch (value) {
      PlaceEntryType.free => l10n.createFormFreeEntry,
      PlaceEntryType.paid => l10n.createFormPaidEntry,
      PlaceEntryType.mixed => l10n.createFormFreePaidAreas,
      PlaceEntryType.notApplicable => l10n.createFormNoEntryTicketConcept,
      PlaceEntryType.unknown => l10n.createFormUnknown,
      null => l10n.createFormNotSelected,
    };

String _hoursModeLabel(AppLocalizations l10n, PlaceHoursMode? value) =>
    switch (value) {
      PlaceHoursMode.regular => l10n.createFormRegularOpeningHours,
      PlaceHoursMode.alwaysOpen => l10n.createFormOpen247,
      PlaceHoursMode.seasonal => l10n.createFormSeasonalHours,
      PlaceHoursMode.unknown => l10n.createFormOpeningHoursUnknown,
      null => l10n.createFormHoursNotSelected,
    };

String _weekdayShort(BuildContext context, int day) =>
    RechargeFormats.weekdayShort(
      day,
      Localizations.localeOf(context).languageCode,
    );

String _minuteLabel(int minute) {
  return '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}
