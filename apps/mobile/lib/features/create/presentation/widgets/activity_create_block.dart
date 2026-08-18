import 'package:flutter/material.dart';

import '../../../../core/config/recharge_category_criteria.dart';
import '../../application/activity_create_config.dart';
import '../../application/controllers/create_controller.dart';
import '../../application/create_taxonomy.dart';
import '../../application/get_category_criteria_usecase.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/activity_draft_data.dart';
import '../../domain/entities/activity_validation_issue.dart';
import '../../domain/entities/create_draft_entity.dart';

class ActivityCreateBlock extends StatefulWidget {
  const ActivityCreateBlock({
    super.key,
    required this.controller,
    required this.state,
    required this.onPublished,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  State<ActivityCreateBlock> createState() => _ActivityCreateBlockState();
}

class _ActivityCreateBlockState extends State<ActivityCreateBlock> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};

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

  List<ActivityValidationIssue> _issuesFor(String sectionId) => widget
      .state
      .activityValidationIssues
      .where((ActivityValidationIssue issue) => issue.sectionId == sectionId)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final CreateDraftEntity draft = widget.state.draft;
    final ActivityDraftData? activity = draft.activityData;
    if (activity == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Loading Recharge Activity draft…'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ActivityProgressHeader(
          steps: activityCreateSteps,
          currentIndex: widget.state.activityStep,
          onStepTapped: (int index) => widget.controller.goToActivityStep(index),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey<int>(widget.state.activityStep),
            child: switch (widget.state.activityStep) {
              0 => _basicsStep(draft),
              1 => _locationStep(activity),
              2 => _whenForStep(activity, draft),
              _ => _publishStep(draft, activity),
            },
          ),
        ),
        _navigation(),
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

  Widget _basicsStep(CreateDraftEntity draft) {
    final List<CreateTaxonomyCategory> categories = createTaxonomyForObjectType(
      CreateObjectType.activity,
    );
    final CreateTaxonomyCategory? selectedCategory = categories
        .where((CreateTaxonomyCategory item) => item.id == draft.mainCategory)
        .firstOrNull;
    final CreateTaxonomySubcategory? selectedSubcategory = selectedCategory
        ?.subcategories
        .where(
          (CreateTaxonomySubcategory item) => item.id == draft.subcategory,
        )
        .firstOrNull;
    return _StepCard(
      title: 'About this activity',
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
            widget.controller.updateMainCategory(category.id);
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
                  widget.controller.updateSubcategory(sub.id);
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
          decoration: const InputDecoration(
            labelText: 'Full description (optional)',
          ),
          maxLines: 4,
          onChanged: widget.controller.updateFullDescription,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('coverImage', draft.media.coverImage),
          decoration: const InputDecoration(labelText: 'Cover image URL'),
          onChanged: widget.controller.updateCoverImage,
        ),
        for (final ActivityValidationIssue issue in _issuesFor('basics'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              issue.messageKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _locationStep(ActivityDraftData activity) {
    final ActivityAccessCautionDraft? caution = activity.location.accessCaution;
    final bool isInformal = caution?.isInformal ?? false;
    final ActivityOptionalContributionDraft? contribution =
        activity.optionalContribution;
    return _StepCard(
      title: 'Where is it, and how do I get there?',
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _field(
                  'latitude',
                  activity.location.latitude?.toString() ?? '',
                ),
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                onChanged: (String value) => widget.controller
                    .updateActivityCoordinates(
                      latitude: value,
                      longitude: _fields['longitude']?.text ?? '',
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _field(
                  'longitude',
                  activity.location.longitude?.toString() ?? '',
                ),
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
                onChanged: (String value) => widget.controller
                    .updateActivityCoordinates(
                      latitude: _fields['latitude']?.text ?? '',
                      longitude: value,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.controller.confirmActivityPin,
          child: Text(
            activity.location.pinConfirmed
                ? 'Pin confirmed'
                : 'Confirm this pin',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('addressLine', activity.location.addressLine ?? ''),
          decoration: const InputDecoration(labelText: 'Address line (optional)'),
          onChanged: widget.controller.updateActivityAddressLine,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('accessNotes', activity.location.accessNotes),
          decoration: const InputDecoration(labelText: 'Access notes'),
          maxLines: 2,
          onChanged: widget.controller.updateActivityAccessNotes,
        ),
        SwitchListTile(
          title: const Text('This is not an official spot'),
          value: isInformal,
          onChanged: (bool value) => widget.controller.updateActivityAccessCaution(
            isInformal: value,
            note: caution?.note,
          ),
        ),
        if (isInformal)
          TextFormField(
            controller: _field('accessCautionNote', caution?.note ?? ''),
            decoration: const InputDecoration(
              labelText: 'What to know before you go',
            ),
            maxLines: 2,
            onChanged: (String value) => widget.controller
                .updateActivityAccessCaution(isInformal: true, note: value),
          ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _field('linkedPlaceId', activity.location.linkedPlaceId ?? ''),
          decoration: const InputDecoration(
            labelText: 'Linked Place id (optional)',
          ),
          onChanged: widget.controller.updateActivityLinkedPlaceId,
        ),
        SwitchListTile(
          title: const Text('It is customary to leave something here'),
          value: contribution != null,
          onChanged: (bool value) {
            if (value) {
              widget.controller.updateActivityOptionalContribution(
                kind: ActivityContributionKind.donation,
              );
            } else {
              widget.controller.clearActivityOptionalContribution();
            }
          },
        ),
        if (contribution != null) ...<Widget>[
          DropdownButtonFormField<ActivityContributionKind>(
            initialValue: contribution.kind,
            decoration: const InputDecoration(labelText: 'Contribution kind'),
            items: const <DropdownMenuItem<ActivityContributionKind>>[
              DropdownMenuItem<ActivityContributionKind>(
                value: ActivityContributionKind.purchase,
                child: Text('Purchase (e.g. coffee at the counter)'),
              ),
              DropdownMenuItem<ActivityContributionKind>(
                value: ActivityContributionKind.donation,
                child: Text('Donation'),
              ),
              DropdownMenuItem<ActivityContributionKind>(
                value: ActivityContributionKind.other,
                child: Text('Other'),
              ),
            ],
            onChanged: (ActivityContributionKind? kind) {
              if (kind != null) {
                widget.controller.updateActivityOptionalContribution(
                  kind: kind,
                  note: contribution.note,
                  amountMinor: contribution.amountHint?.amountMinor,
                );
              }
            },
          ),
          TextFormField(
            controller: _field('contributionNote', contribution.note ?? ''),
            decoration: const InputDecoration(
              labelText: 'e.g. "Coffee on the counter, optional"',
            ),
            onChanged: (String value) => widget.controller
                .updateActivityOptionalContribution(
                  kind: contribution.kind,
                  note: value,
                  amountMinor: contribution.amountHint?.amountMinor,
                ),
          ),
          TextFormField(
            controller: _field(
              'contributionAmountHint',
              contribution.amountHint == null
                  ? ''
                  : (contribution.amountHint!.amountMinor / 100).toStringAsFixed(2),
            ),
            decoration: const InputDecoration(labelText: 'Approximate amount (optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String value) {
              final double? parsed = double.tryParse(value.replaceAll(',', '.'));
              widget.controller.updateActivityOptionalContribution(
                kind: contribution.kind,
                note: contribution.note,
                amountMinor: parsed == null ? null : (parsed * 100).round(),
              );
            },
          ),
        ],
        for (final ActivityValidationIssue issue in _issuesFor('location'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              issue.messageKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
  Widget _whenForStep(ActivityDraftData activity, CreateDraftEntity draft) {
    final CategoryCriteriaResult? criteria = const GetCategoryCriteriaUseCase()(
      draft.subcategory,
    );
    final Map<String, Object?> criteriaValues = <String, Object?>{
      ...?draft.sectionData['criteria'] as Map<String, Object?>?,
    };
    final ActivityIntRangeDraft? groupSize = activity.suggestedGroupSize;
    return _StepCard(
      title: 'When is it best, and how long does it take?',
      children: <Widget>[
        DropdownButtonFormField<ActivityTimeOfDay>(
          initialValue: activity.bestTime?.timeOfDay,
          decoration: const InputDecoration(
            labelText: 'Best time of day (optional)',
          ),
          items: <DropdownMenuItem<ActivityTimeOfDay>>[
            for (final ActivityTimeOfDay value in ActivityTimeOfDay.values)
              DropdownMenuItem<ActivityTimeOfDay>(
                value: value,
                child: Text(value.name),
              ),
          ],
          onChanged: (ActivityTimeOfDay? value) =>
              widget.controller.updateActivityBestTime(
                timeOfDay: value,
                season: activity.bestTime?.season,
              ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ActivitySeason>(
          initialValue: activity.bestTime?.season,
          decoration: const InputDecoration(labelText: 'Best season (optional)'),
          items: <DropdownMenuItem<ActivitySeason>>[
            for (final ActivitySeason value in ActivitySeason.values)
              DropdownMenuItem<ActivitySeason>(
                value: value,
                child: Text(value.name),
              ),
          ],
          onChanged: (ActivitySeason? value) =>
              widget.controller.updateActivityBestTime(
                timeOfDay: activity.bestTime?.timeOfDay,
                season: value,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                controller: _field(
                  'durationMin',
                  activity.typicalDurationMinutes.min.toString(),
                ),
                decoration: const InputDecoration(
                  labelText: 'Typical duration, min (minutes)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (String value) {
                  final int? min = int.tryParse(value);
                  if (min != null) {
                    widget.controller.updateActivityTypicalDuration(
                      min: min,
                      max: activity.typicalDurationMinutes.max,
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _field(
                  'durationMax',
                  activity.typicalDurationMinutes.max.toString(),
                ),
                decoration: const InputDecoration(
                  labelText: 'Typical duration, max (minutes)',
                ),
                keyboardType: TextInputType.number,
                onChanged: (String value) {
                  final int? max = int.tryParse(value);
                  if (max != null) {
                    widget.controller.updateActivityTypicalDuration(
                      min: activity.typicalDurationMinutes.min,
                      max: max,
                    );
                  }
                },
              ),
            ),
          ],
        ),
        SwitchListTile(
          title: const Text('Suggest a group size'),
          value: groupSize != null,
          onChanged: (bool value) {
            if (value) {
              widget.controller.updateActivitySuggestedGroupSize(
                min: 1,
                max: 10,
              );
            } else {
              widget.controller.clearActivitySuggestedGroupSize();
            }
          },
        ),
        if (groupSize != null)
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: _field('groupMin', groupSize.min.toString()),
                  decoration: const InputDecoration(
                    labelText: 'Group, min people',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (String value) {
                    final int? min = int.tryParse(value);
                    if (min != null) {
                      widget.controller.updateActivitySuggestedGroupSize(
                        min: min,
                        max: groupSize.max,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _field('groupMax', groupSize.max.toString()),
                  decoration: const InputDecoration(
                    labelText: 'Group, max people',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (String value) {
                    final int? max = int.tryParse(value);
                    if (max != null) {
                      widget.controller.updateActivitySuggestedGroupSize(
                        min: groupSize.min,
                        max: max,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        if (criteria != null)
          for (final RechargeCriteriaFieldDefinition field in criteria.fields)
            Padding(
              padding: const EdgeInsets.only(top: 12),
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
        for (final ActivityValidationIssue issue in _issuesFor('whenFor'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              issue.messageKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _publishStep(CreateDraftEntity draft, ActivityDraftData activity) {
    return _StepCard(
      title: 'Preview and publish',
      children: <Widget>[
        Text(draft.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(draft.shortDescription),
        const SizedBox(height: 8),
        Text(
          '${activity.typicalDurationMinutes.min}–${activity.typicalDurationMinutes.max} min',
        ),
        if (activity.location.accessCaution?.isInformal ?? false) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            activity.location.accessCaution!.note ?? '',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        for (final ActivityValidationIssue issue
            in widget.state.activityValidationIssues)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              issue.messageKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _navigation() {
    final int step = widget.state.activityStep;
    final bool isLast = step == activityCreateSteps.length - 1;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          if (step > 0)
            TextButton(
              onPressed: () => widget.controller.goToActivityStep(step - 1),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          FilledButton(
            onPressed: isLast
                ? () async {
                    final bool published = await widget.controller
                        .publishDraft();
                    if (published) widget.onPublished();
                  }
                : () => widget.controller.goToActivityStep(step + 1),
            child: Text(isLast ? 'Send for review' : 'Save & continue'),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActivityProgressHeader extends StatelessWidget {
  const _ActivityProgressHeader({
    required this.steps,
    required this.currentIndex,
    required this.onStepTapped,
  });

  final List<ActivityCreateStepConfig> steps;
  final int currentIndex;
  final ValueChanged<int> onStepTapped;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${currentIndex + 1}/${steps.length} • ${steps[currentIndex].title}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < steps.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onStepTapped(i),
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: i <= currentIndex
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
