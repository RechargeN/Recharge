import 'package:flutter/material.dart';

import '../../application/controllers/create_controller.dart';
import '../../application/create_taxonomy.dart';
import '../../application/find_people_create_config.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/create_availability.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/find_people_draft_data.dart';
import '../../domain/entities/find_people_validation_issue.dart';

class FindPeopleCreateBlock extends StatefulWidget {
  const FindPeopleCreateBlock({
    super.key,
    required this.controller,
    required this.state,
    required this.onPublished,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  State<FindPeopleCreateBlock> createState() => _FindPeopleCreateBlockState();
}

class _FindPeopleCreateBlockState extends State<FindPeopleCreateBlock> {
  final TextEditingController _slotStart = TextEditingController();
  final TextEditingController _slotEnd = TextEditingController();
  final TextEditingController _latitude = TextEditingController();
  final TextEditingController _longitude = TextEditingController();
  final TextEditingController _question = TextEditingController();
  final TextEditingController _expenseCategory = TextEditingController();
  final TextEditingController _expenseAmount = TextEditingController();
  final TextEditingController _coHostUserId = TextEditingController();

  @override
  void dispose() {
    _slotStart.dispose();
    _slotEnd.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _question.dispose();
    _expenseCategory.dispose();
    _expenseAmount.dispose();
    _coHostUserId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreateDraftEntity draft = widget.state.draft;
    final FindPeopleDraftData? data = draft.findPeopleData;
    if (data == null) {
      return const _Panel(
        child: Text('Find People draft data is being prepared…'),
      );
    }
    final int step = widget.state.findPeopleStep;
    final FindPeopleCreateStepConfig config = findPeopleCreateSteps[step];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StepHeader(
          step: step,
          config: config,
          saveStatus: widget.state.saveStatus,
          onStepSelected: widget.controller.goToFindPeopleStep,
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey<int>(step),
            child: switch (step) {
              0 => _activityStep(draft, data),
              1 => _scheduleStep(draft, data),
              2 => _meetingStep(data),
              3 => _groupStep(data),
              4 => _hostsStep(draft, data),
              _ => _publishStep(draft, data),
            },
          ),
        ),
        const SizedBox(height: 12),
        _navigation(step),
      ],
    );
  }

  Widget _activityStep(CreateDraftEntity draft, FindPeopleDraftData data) {
    final List<CreateTaxonomyCategory> categories = rechargeCreateTaxonomy;
    final CreateTaxonomyCategory category =
        createTaxonomyCategoryById(draft.mainCategory) ?? categories.first;
    final List<CreateTaxonomySubcategory> subcategories =
        category.subcategories;
    return _Panel(
      title: 'Activity and description',
      subtitle:
          'Public content must describe a concrete activity without contacts or payment links.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: const ValueKey<String>('find-people-category'),
            initialValue: category.id,
            decoration: _decoration('Category *'),
            items: categories
                .map(
                  (CreateTaxonomyCategory item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.title),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? id) {
              if (id == null) return;
              final CreateTaxonomyCategory selected =
                  createTaxonomyCategoryById(id)!;
              final CreateTaxonomySubcategory? subcategory =
                  createDefaultSubcategoryFor(selected);
              widget.controller.applyTaxonomySelection(
                mainCategory: id,
                subcategory: subcategory?.id ?? '',
              );
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('find-people-subcategory-${category.id}'),
            initialValue:
                subcategories.any(
                  (CreateTaxonomySubcategory item) =>
                      item.id == draft.subcategory,
                )
                ? draft.subcategory
                : (subcategories.isEmpty ? null : subcategories.first.id),
            decoration: _decoration('Subcategory *'),
            items: subcategories
                .map(
                  (CreateTaxonomySubcategory item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.title),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? id) {
              if (id != null) {
                widget.controller.applyTaxonomySelection(
                  mainCategory: category.id,
                  subcategory: id,
                );
              }
            },
          ),
          const SizedBox(height: 10),
          _DraftTextField(
            label: 'Title *',
            value: draft.title,
            maxLength: 80,
            onChanged: widget.controller.updateTitle,
          ),
          _DraftTextField(
            label: 'Short description *',
            value: draft.shortDescription,
            minLines: 2,
            maxLines: 3,
            maxLength: 180,
            onChanged: widget.controller.updateShortDescription,
          ),
          _DraftTextField(
            label: 'Full description *',
            value: draft.fullDescription,
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            onChanged: widget.controller.updateFullDescription,
          ),
          _DraftTextField(
            label: 'Tags (comma-separated, up to 8)',
            value: draft.tags.join(', '),
            onChanged: (String value) =>
                widget.controller.updateTags(value.split(',')),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<FindPeopleSkillLevel>(
            initialValue: data.skillLevel,
            decoration: _decoration('Skill level *'),
            items: FindPeopleSkillLevel.values
                .map(
                  (FindPeopleSkillLevel value) =>
                      DropdownMenuItem<FindPeopleSkillLevel>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleSkillLevel? value) {
              if (value != null) _update(data.copyWith(skillLevel: value));
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<FindPeopleParticipationGoal>(
            initialValue: data.participationGoal,
            decoration: _decoration('Participation goal *'),
            items: FindPeopleParticipationGoal.values
                .map(
                  (FindPeopleParticipationGoal value) =>
                      DropdownMenuItem<FindPeopleParticipationGoal>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleParticipationGoal? value) {
              if (value != null) {
                _update(data.copyWith(participationGoal: value));
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Communication languages *',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Wrap(
            spacing: 8,
            children: widget.controller.supportedContentLocales
                .map((String code) {
                  return FilterChip(
                    label: Text(code.toUpperCase()),
                    selected: data.languageCodes.contains(code),
                    onSelected: (bool selected) {
                      final Set<String> next = <String>{...data.languageCodes};
                      selected ? next.add(code) : next.remove(code);
                      if (next.length <= 3) {
                        _update(data.copyWith(languageCodes: next));
                      }
                    },
                  );
                })
                .toList(growable: false),
          ),
          _DraftTextField(
            label: 'Pace (optional)',
            value: data.pace ?? '',
            onChanged: (String value) => _update(
              data.copyWith(
                pace: _text(value),
                clearPace: _text(value) == null,
              ),
            ),
          ),
          _DraftTextField(
            label: 'Experience requirements (one per line)',
            value: data.experienceRequirements.join('\n'),
            minLines: 2,
            maxLines: 5,
            onChanged: (String value) =>
                _update(data.copyWith(experienceRequirements: _lines(value))),
          ),
          _DraftTextField(
            label: 'Equipment notes',
            value: data.equipmentNotes ?? '',
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            onChanged: (String value) => _update(
              data.copyWith(
                equipmentNotes: _text(value),
                clearEquipmentNotes: _text(value) == null,
              ),
            ),
          ),
          _DraftTextField(
            label: 'Accessibility notes',
            value: data.accessibilityNotes ?? '',
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            onChanged: (String value) => _update(
              data.copyWith(
                accessibilityNotes: _text(value),
                clearAccessibilityNotes: _text(value) == null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('House rules', style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: findPeopleHouseRuleOptions
                .map(
                  (String id) => FilterChip(
                    label: Text(_enumLabel(id)),
                    selected: data.houseRuleIds.contains(id),
                    onSelected: (bool selected) {
                      final Set<String> next = <String>{...data.houseRuleIds};
                      selected ? next.add(id) : next.remove(id);
                      _update(data.copyWith(houseRuleIds: next));
                    },
                  ),
                )
                .toList(growable: false),
          ),
          _DraftTextField(
            label: 'House rules note',
            value: data.houseRulesNote ?? '',
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            onChanged: (String value) => _update(
              data.copyWith(
                houseRulesNote: _text(value),
                clearHouseRulesNote: _text(value) == null,
              ),
            ),
          ),
          _issuesFor('activity'),
        ],
      ),
    );
  }

  Widget _scheduleStep(CreateDraftEntity draft, FindPeopleDraftData data) {
    return _Panel(
      title: 'Schedule',
      subtitle:
          'All times are stored in UTC and displayed using ${draft.timezone}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<FindPeopleScheduleMode>(
            key: const ValueKey<String>('find-people-schedule-mode'),
            initialValue: data.scheduleMode,
            decoration: _decoration('Schedule mode *'),
            items: FindPeopleScheduleMode.values
                .map(
                  (FindPeopleScheduleMode value) =>
                      DropdownMenuItem<FindPeopleScheduleMode>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleScheduleMode? value) {
              if (value == null) return;
              if (value == FindPeopleScheduleMode.single &&
                  draft.scheduleSlots.length > 1) {
                widget.controller.replaceScheduleSlots(<CreateTimeSlotDraft>[
                  draft.scheduleSlots.first,
                ]);
              }
              _update(
                data.copyWith(
                  scheduleMode: value,
                  clearRecurrenceRule:
                      value != FindPeopleScheduleMode.recurring,
                  clearSeriesEndAtUtc:
                      value != FindPeopleScheduleMode.recurring,
                  clearMaxOccurrences:
                      value != FindPeopleScheduleMode.recurring,
                  clearPollResponseDeadlineUtc:
                      value != FindPeopleScheduleMode.timePoll,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _slotStart,
                  decoration: _decoration(
                    'Start UTC *',
                    hint: '2026-08-20T16:00:00Z',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _slotEnd,
                  decoration: _decoration(
                    'End UTC *',
                    hint: '2026-08-20T18:00:00Z',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _addSlot(draft, data),
            icon: const Icon(Icons.add_alarm_outlined),
            label: Text(
              data.scheduleMode == FindPeopleScheduleMode.single
                  ? 'Set meeting time'
                  : 'Add time option',
            ),
          ),
          const SizedBox(height: 8),
          ...draft.scheduleSlots.map(
            (CreateTimeSlotDraft slot) => Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text('${slot.startAtUtc.toIso8601String()} →'),
                subtitle: Text(
                  '${slot.endAtUtc.toIso8601String()} • ${slot.endAtUtc.difference(slot.startAtUtc).inMinutes} min',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove slot',
                  onPressed: () =>
                      widget.controller.removeScheduleSlot(slot.localId),
                ),
              ),
            ),
          ),
          if (data.scheduleMode == FindPeopleScheduleMode.timePoll)
            _DraftTextField(
              label: 'Poll response deadline UTC *',
              value: data.pollResponseDeadlineUtc?.toIso8601String() ?? '',
              hint: '2026-08-18T18:00:00Z',
              onChanged: (String value) {
                final DateTime? date = DateTime.tryParse(value)?.toUtc();
                _update(
                  data.copyWith(
                    pollResponseDeadlineUtc: date,
                    clearPollResponseDeadlineUtc: date == null,
                  ),
                );
              },
            )
          else
            _DraftTextField(
              label: 'Application deadline UTC *',
              value: draft.registrationDeadlineUtc?.toIso8601String() ?? '',
              hint: '2026-08-19T18:00:00Z',
              onChanged: widget.controller.updateRegistrationDeadline,
            ),
          if (data.scheduleMode ==
              FindPeopleScheduleMode.recurring) ...<Widget>[
            _DraftTextField(
              label: 'Recurrence rule *',
              value: data.recurrenceRule ?? '',
              hint: 'FREQ=WEEKLY;BYDAY=SA',
              onChanged: (String value) => _update(
                data.copyWith(
                  recurrenceRule: _text(value),
                  clearRecurrenceRule: _text(value) == null,
                ),
              ),
            ),
            _DraftTextField(
              label: 'Series end UTC',
              value: data.seriesEndAtUtc?.toIso8601String() ?? '',
              onChanged: (String value) {
                final DateTime? date = DateTime.tryParse(value)?.toUtc();
                _update(
                  data.copyWith(
                    seriesEndAtUtc: date,
                    clearSeriesEndAtUtc: date == null,
                  ),
                );
              },
            ),
            _DraftTextField(
              label: 'Maximum occurrences (2–52)',
              value: data.maxOccurrences?.toString() ?? '',
              keyboardType: TextInputType.number,
              onChanged: (String value) {
                final int? count = int.tryParse(value);
                _update(
                  data.copyWith(
                    maxOccurrences: count,
                    clearMaxOccurrences: count == null,
                  ),
                );
              },
            ),
          ],
          _issuesFor('schedule'),
        ],
      ),
    );
  }

  Widget _meetingStep(FindPeopleDraftData data) {
    final bool physical = data.meetingMode != FindPeopleMeetingMode.online;
    final bool online = data.meetingMode != FindPeopleMeetingMode.inPerson;
    return _Panel(
      title: 'Meeting location',
      subtitle:
          'Only the approximate public area appears in Discover. Exact details stay private.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<FindPeopleMeetingMode>(
            key: const ValueKey<String>('find-people-meeting-mode'),
            initialValue: data.meetingMode,
            decoration: _decoration('Meeting mode *'),
            items: FindPeopleMeetingMode.values
                .map(
                  (FindPeopleMeetingMode value) =>
                      DropdownMenuItem<FindPeopleMeetingMode>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleMeetingMode? value) {
              if (value == null) return;
              _update(
                data.copyWith(
                  meetingMode: value,
                  clearMeetingPlaceName: value == FindPeopleMeetingMode.online,
                  clearPublicAreaLabel: value == FindPeopleMeetingMode.online,
                  clearPublicGeo: value == FindPeopleMeetingMode.online,
                  clearExactGeo: value == FindPeopleMeetingMode.online,
                  clearExactAddressLine: value == FindPeopleMeetingMode.online,
                  clearMeetingInstructions:
                      value == FindPeopleMeetingMode.online,
                  publicPlaceConfirmed: value == FindPeopleMeetingMode.online
                      ? false
                      : data.publicPlaceConfirmed,
                  clearOnlineProvider: value == FindPeopleMeetingMode.inPerson,
                  clearOnlineAccessSecretRef:
                      value == FindPeopleMeetingMode.inPerson,
                ),
              );
            },
          ),
          if (physical) ...<Widget>[
            _DraftTextField(
              label: 'Meeting place name *',
              value: data.meetingPlaceName ?? '',
              onChanged: (String value) => _update(
                data.copyWith(
                  meetingPlaceName: _text(value),
                  clearMeetingPlaceName: _text(value) == null,
                ),
              ),
            ),
            _DraftTextField(
              label: 'Public area label *',
              value: data.publicAreaLabel ?? '',
              hint: 'Old Town, near Central Park',
              onChanged: (String value) => _update(
                data.copyWith(
                  publicAreaLabel: _text(value),
                  clearPublicAreaLabel: _text(value) == null,
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _latitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: _decoration('Exact latitude *'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _longitude,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: _decoration('Exact longitude *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => widget.controller.setFindPeopleExactLocation(
                latitude: _latitude.text,
                longitude: _longitude.text,
              ),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text(
                'Set exact point and generate safe public point',
              ),
            ),
            if (data.publicGeo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Public map point: ${data.publicGeo!.latitude}, ${data.publicGeo!.longitude}',
                ),
              ),
            _DraftTextField(
              label: 'Exact address (private) *',
              value: data.exactAddressLine ?? '',
              onChanged: (String value) => _update(
                data.copyWith(
                  exactAddressLine: _text(value),
                  clearExactAddressLine: _text(value) == null,
                ),
              ),
            ),
            _DraftTextField(
              label: 'Meeting instructions (private)',
              value: data.meetingInstructions ?? '',
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              onChanged: (String value) => _update(
                data.copyWith(
                  meetingInstructions: _text(value),
                  clearMeetingInstructions: _text(value) == null,
                ),
              ),
            ),
            SwitchListTile.adaptive(
              value: data.publicPlaceConfirmed,
              contentPadding: EdgeInsets.zero,
              title: const Text('This is a public meeting place *'),
              subtitle: const Text(
                'Private homes and residential access details are not allowed.',
              ),
              onChanged: (bool value) =>
                  _update(data.copyWith(publicPlaceConfirmed: value)),
            ),
          ],
          if (online) ...<Widget>[
            _DraftTextField(
              label: 'Online provider *',
              value: data.onlineProvider ?? '',
              hint: 'Google Meet, Zoom, Discord…',
              onChanged: (String value) => _update(
                data.copyWith(
                  onlineProvider: _text(value),
                  clearOnlineProvider: _text(value) == null,
                ),
              ),
            ),
            _DraftTextField(
              label: 'Private access secret reference *',
              value: data.onlineAccessSecretRef ?? '',
              hint: 'Session-scoped secure reference; never shown publicly',
              onChanged: (String value) => _update(
                data.copyWith(
                  onlineAccessSecretRef: _text(value),
                  clearOnlineAccessSecretRef: _text(value) == null,
                ),
              ),
            ),
          ],
          _DraftTextField(
            label: 'Backup meeting plan',
            value: data.backupMeetingPlan ?? '',
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            onChanged: (String value) => _update(
              data.copyWith(
                backupMeetingPlan: _text(value),
                clearBackupMeetingPlan: _text(value) == null,
              ),
            ),
          ),
          _issuesFor('meeting'),
        ],
      ),
    );
  }

  Widget _groupStep(FindPeopleDraftData data) {
    return _Panel(
      title: 'Group and participation',
      subtitle:
          'Group size includes hosts. Expected spend is information, never a payment to the host.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _NumberStepper(
            label: 'Target group size',
            value: data.targetGroupSize,
            min: 2,
            max: 20,
            onChanged: (int value) => _update(
              data.copyWith(
                targetGroupSize: value,
                hostSeatCount: data.hostSeatCount.clamp(1, value - 1),
                maxSeatsPerApplication: data.maxSeatsPerApplication.clamp(
                  1,
                  (value - 1).clamp(1, 4),
                ),
              ),
            ),
          ),
          _NumberStepper(
            label: 'Host seats',
            value: data.hostSeatCount,
            min: 1,
            max: (data.targetGroupSize - 1).clamp(1, 19),
            onChanged: (int value) =>
                _update(data.copyWith(hostSeatCount: value)),
          ),
          DropdownButtonFormField<FindPeopleApprovalMode>(
            initialValue: data.approvalMode,
            decoration: _decoration('Approval mode *'),
            items: FindPeopleApprovalMode.values
                .map(
                  (FindPeopleApprovalMode value) =>
                      DropdownMenuItem<FindPeopleApprovalMode>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleApprovalMode? value) {
              if (value == null) return;
              _update(
                data.copyWith(
                  approvalMode: value,
                  visibility: value == FindPeopleApprovalMode.inviteOnly
                      ? FindPeopleVisibility.inviteOnly
                      : data.visibility,
                ),
              );
            },
          ),
          SwitchListTile.adaptive(
            value: data.allowPartyApplications,
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow party applications'),
            onChanged: (bool value) => _update(
              data.copyWith(
                allowPartyApplications: value,
                maxSeatsPerApplication: value ? data.maxSeatsPerApplication : 1,
              ),
            ),
          ),
          if (data.allowPartyApplications)
            _NumberStepper(
              label: 'Maximum seats per application',
              value: data.maxSeatsPerApplication,
              min: 1,
              max: (data.targetGroupSize - data.hostSeatCount).clamp(1, 4),
              onChanged: (int value) =>
                  _update(data.copyWith(maxSeatsPerApplication: value)),
            ),
          DropdownButtonFormField<FindPeopleVerificationLevel>(
            initialValue: data.verificationRequirement,
            decoration: _decoration('Verification requirement *'),
            items: FindPeopleVerificationLevel.values
                .map(
                  (FindPeopleVerificationLevel value) =>
                      DropdownMenuItem<FindPeopleVerificationLevel>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleVerificationLevel? value) {
              if (value != null) {
                _update(data.copyWith(verificationRequirement: value));
              }
            },
          ),
          SwitchListTile.adaptive(
            value: data.waitlistEnabled,
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable waitlist'),
            onChanged: (bool value) =>
                _update(data.copyWith(waitlistEnabled: value)),
          ),
          if (data.waitlistEnabled) ...<Widget>[
            DropdownButtonFormField<FindPeopleWaitlistPolicy>(
              initialValue: data.waitlistPolicy,
              decoration: _decoration('Waitlist policy'),
              items: FindPeopleWaitlistPolicy.values
                  .map(
                    (FindPeopleWaitlistPolicy value) =>
                        DropdownMenuItem<FindPeopleWaitlistPolicy>(
                          value: value,
                          child: Text(_enumLabel(value.name)),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (FindPeopleWaitlistPolicy? value) {
                if (value != null) {
                  _update(data.copyWith(waitlistPolicy: value));
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<FindPeopleSeatFitPolicy>(
              initialValue: data.waitlistSeatFitPolicy,
              decoration: _decoration('Seat-fit policy'),
              items: FindPeopleSeatFitPolicy.values
                  .map(
                    (FindPeopleSeatFitPolicy value) =>
                        DropdownMenuItem<FindPeopleSeatFitPolicy>(
                          value: value,
                          child: Text(_enumLabel(value.name)),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (FindPeopleSeatFitPolicy? value) {
                if (value != null) {
                  _update(data.copyWith(waitlistSeatFitPolicy: value));
                }
              },
            ),
          ],
          SwitchListTile.adaptive(
            value: data.attendanceConfirmationRequired,
            contentPadding: EdgeInsets.zero,
            title: const Text('Require attendance reconfirmation'),
            onChanged: (bool value) =>
                _update(data.copyWith(attendanceConfirmationRequired: value)),
          ),
          const Divider(height: 28),
          Text(
            'Application questions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _question,
                  decoration: _decoration('Safe question'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                tooltip: 'Add question',
                onPressed: () => _addQuestion(data),
              ),
            ],
          ),
          ...data.applicationQuestions.map(
            (FindPeopleApplicationQuestionDraft item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: Text(item.prompt),
              subtitle: Text(
                '${_enumLabel(item.type.name)} • ${item.required ? 'required' : 'optional'}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _update(
                  data.copyWith(
                    applicationQuestions: data.applicationQuestions
                        .where(
                          (FindPeopleApplicationQuestionDraft current) =>
                              current.id != item.id,
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 28),
          DropdownButtonFormField<FindPeopleCostType>(
            initialValue: data.costType,
            decoration: _decoration('Expected cost *'),
            items: FindPeopleCostType.values
                .map(
                  (FindPeopleCostType value) =>
                      DropdownMenuItem<FindPeopleCostType>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleCostType? value) {
              if (value != null) {
                _update(
                  data.copyWith(
                    costType: value,
                    clearExpectedSpendAmount:
                        value != FindPeopleCostType.estimated,
                  ),
                );
              }
            },
          ),
          if (data.costType == FindPeopleCostType.estimated)
            _DraftTextField(
              label: 'Expected spend per person (${data.currencyCode}) *',
              value: data.expectedSpendAmount?.toString() ?? '',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (String value) {
                final double? amount = double.tryParse(
                  value.replaceAll(',', '.'),
                );
                _update(
                  data.copyWith(
                    expectedSpendAmount: amount,
                    clearExpectedSpendAmount: amount == null,
                  ),
                );
              },
            ),
          _DraftTextField(
            label: 'Cost note',
            value: data.costNote ?? '',
            maxLength: 300,
            minLines: 2,
            maxLines: 3,
            onChanged: (String value) => _update(
              data.copyWith(
                costNote: _text(value),
                clearCostNote: _text(value) == null,
              ),
            ),
          ),
          DropdownButtonFormField<FindPeopleExpenseSplitMode>(
            initialValue: data.expenseSplitMode,
            decoration: _decoration('Expense split mode *'),
            items: FindPeopleExpenseSplitMode.values
                .map(
                  (FindPeopleExpenseSplitMode value) =>
                      DropdownMenuItem<FindPeopleExpenseSplitMode>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleExpenseSplitMode? value) {
              if (value != null) {
                _update(data.copyWith(expenseSplitMode: value));
              }
            },
          ),
          if (data.expenseSplitMode ==
              FindPeopleExpenseSplitMode.itemized) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _expenseCategory,
                    decoration: _decoration('Expense item'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _expenseAmount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('Amount'),
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add expense',
                  onPressed: () => _addExpense(data),
                ),
              ],
            ),
            ...data.plannedExpenseItems.map(
              (FindPeopleExpenseItemDraft item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.category),
                subtitle: Text(
                  '${item.amount.toStringAsFixed(2)} ${data.currencyCode} • ${item.payerNote}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _update(
                    data.copyWith(
                      plannedExpenseItems: data.plannedExpenseItems
                          .where(
                            (FindPeopleExpenseItemDraft current) =>
                                current.id != item.id,
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
          _issuesFor('group'),
        ],
      ),
    );
  }

  Widget _hostsStep(CreateDraftEntity draft, FindPeopleDraftData data) {
    return _Panel(
      title: 'Hosts, visibility, and communication',
      subtitle:
          'Co-host permissions remain inactive until the invited user accepts the role.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<FindPeoplePublisherType>(
            initialValue: data.publisherType,
            decoration: _decoration('Publish as *'),
            items: FindPeoplePublisherType.values
                .map(
                  (FindPeoplePublisherType value) =>
                      DropdownMenuItem<FindPeoplePublisherType>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeoplePublisherType? value) {
              if (value != null) {
                _update(
                  data.copyWith(
                    publisherType: value,
                    publisherId: value == FindPeoplePublisherType.user
                        ? draft.organizerId
                        : data.publisherId,
                  ),
                );
              }
            },
          ),
          _DraftTextField(
            label: data.publisherType == FindPeoplePublisherType.page
                ? 'Managed Page ID *'
                : 'Publisher user ID *',
            value: data.publisherId,
            onChanged: (String value) =>
                _update(data.copyWith(publisherId: value.trim())),
          ),
          const SizedBox(height: 8),
          Text('Responsible hosts: ${data.responsibleHostUserIds.join(', ')}'),
          const SizedBox(height: 12),
          Text('Invite co-host', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _coHostUserId,
                  decoration: _decoration('User ID'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.person_add_alt),
                tooltip: 'Invite co-host',
                onPressed: () => _addCoHost(data),
              ),
            ],
          ),
          ...data.coHosts.map(
            (FindPeopleCoHostDraft item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.supervisor_account_outlined),
              title: Text(item.userId),
              subtitle: Text(
                '${item.accepted ? 'Accepted' : 'Invitation pending'} • ${item.capabilityIds.map(_enumLabel).join(', ')}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _update(
                  data.copyWith(
                    coHosts: data.coHosts
                        .where(
                          (FindPeopleCoHostDraft current) =>
                              current.id != item.id,
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 28),
          DropdownButtonFormField<FindPeopleVisibility>(
            initialValue: data.visibility,
            decoration: _decoration('Visibility *'),
            items: FindPeopleVisibility.values
                .map(
                  (FindPeopleVisibility value) =>
                      DropdownMenuItem<FindPeopleVisibility>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleVisibility? value) {
              if (value != null) {
                _update(
                  data.copyWith(
                    visibility: value,
                    approvalMode: value == FindPeopleVisibility.inviteOnly
                        ? FindPeopleApprovalMode.inviteOnly
                        : data.approvalMode,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<FindPeopleConversationPolicy>(
            initialValue: data.conversationPolicy,
            decoration: _decoration('Conversation policy *'),
            items: FindPeopleConversationPolicy.values
                .map(
                  (FindPeopleConversationPolicy value) =>
                      DropdownMenuItem<FindPeopleConversationPolicy>(
                        value: value,
                        child: Text(_enumLabel(value.name)),
                      ),
                )
                .toList(growable: false),
            onChanged: (FindPeopleConversationPolicy? value) {
              if (value != null) {
                _update(data.copyWith(conversationPolicy: value));
              }
            },
          ),
          SwitchListTile.adaptive(
            value: data.allowParticipantInvites,
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow accepted participants to invite'),
            onChanged: (bool value) =>
                _update(data.copyWith(allowParticipantInvites: value)),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _DraftTextField(
                  label: 'Quiet hours start (0–1439)',
                  value: data.quietHoursStartMinute?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  onChanged: (String value) {
                    final int? minute = int.tryParse(value);
                    _update(
                      data.copyWith(
                        quietHoursStartMinute: minute,
                        clearQuietHoursStartMinute: minute == null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DraftTextField(
                  label: 'Quiet hours end (0–1439)',
                  value: data.quietHoursEndMinute?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  onChanged: (String value) {
                    final int? minute = int.tryParse(value);
                    _update(
                      data.copyWith(
                        quietHoursEndMinute: minute,
                        clearQuietHoursEndMinute: minute == null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          _issuesFor('hosts'),
        ],
      ),
    );
  }

  Widget _publishStep(CreateDraftEntity draft, FindPeopleDraftData data) {
    final List<FindPeopleValidationIssue> issues =
        widget.state.findPeopleValidationIssues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Panel(
          title: 'Public preview',
          subtitle: 'This mirrors the safe public Details contract.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                draft.title.isEmpty
                    ? 'Untitled Find People request'
                    : draft.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                draft.shortDescription.isEmpty
                    ? 'Add a short description.'
                    : draft.shortDescription,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(label: Text(_enumLabel(data.meetingMode.name))),
                  Chip(label: Text(_enumLabel(data.scheduleMode.name))),
                  Chip(label: Text('${data.targetGroupSize} people')),
                  Chip(
                    label: Text(
                      data.languageCodes
                          .map((String item) => item.toUpperCase())
                          .join(' · '),
                    ),
                  ),
                  Chip(label: Text(_enumLabel(data.costType.name))),
                ],
              ),
              if (data.publicAreaLabel != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(data.publicAreaLabel!),
                  subtitle: const Text('Approximate public area'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Private host preview',
          subtitle:
              'These fields are never included in public DTO, analytics, or push payloads.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Exact address: ${data.exactAddressLine ?? 'Not set'}'),
              Text(
                'Exact geo: ${data.exactGeo == null ? 'Not set' : '${data.exactGeo!.latitude}, ${data.exactGeo!.longitude}'}',
              ),
              Text(
                'Online access reference: ${data.onlineAccessSecretRef == null ? 'Not set' : 'Configured'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Media and publication',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _DraftTextField(
                label: 'Cover image URL (optional)',
                value: draft.media.coverImage,
                onChanged: widget.controller.updateCoverImage,
              ),
              _DraftTextField(
                label: 'Schedule publication UTC (optional)',
                value: data.publishAtUtc?.toIso8601String() ?? '',
                onChanged: (String value) {
                  final DateTime? date = DateTime.tryParse(value)?.toUtc();
                  _update(
                    data.copyWith(
                      publishAtUtc: date,
                      clearPublishAtUtc: date == null,
                    ),
                  );
                },
              ),
              CheckboxListTile(
                value: data.ageRequirementConfirmed,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('This request is only for adults 18+ *'),
                onChanged: (bool? value) => _update(
                  data.copyWith(ageRequirementConfirmed: value ?? false),
                ),
              ),
              CheckboxListTile(
                value: data.safetyRulesAccepted,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('I accept the Find People Safety Rules *'),
                subtitle: const Text(
                  'Meet publicly, do not send money to strangers, and use Report/Block when needed.',
                ),
                onChanged: (bool? value) =>
                    _update(data.copyWith(safetyRulesAccepted: value ?? false)),
              ),
              CheckboxListTile(
                value: data.accuracyConfirmed,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text('I confirm that all details are accurate *'),
                onChanged: (bool? value) =>
                    _update(data.copyWith(accuracyConfirmed: value ?? false)),
              ),
              if (issues.isNotEmpty) ...<Widget>[
                const Divider(height: 28),
                Text(
                  'Validation summary',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                ...issues.map(
                  (FindPeopleValidationIssue issue) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      issue.severity == FindPeopleValidationSeverity.error
                          ? Icons.error_outline
                          : Icons.warning_amber_outlined,
                      color:
                          issue.severity == FindPeopleValidationSeverity.error
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.tertiary,
                    ),
                    title: Text(issue.message),
                    subtitle: Text('${issue.sectionId} · ${issue.fieldId}'),
                    onTap: () => widget.controller.goToFindPeopleStep(
                      _stepIndex(issue.sectionId),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey<String>('publish-find-people'),
                onPressed: widget.state.status == CreateStatus.publishing
                    ? null
                    : () async {
                        final bool published = await widget.controller
                            .publishDraft();
                        if (published) widget.onPublished();
                      },
                icon: const Icon(Icons.publish_outlined),
                label: Text(
                  widget.state.status == CreateStatus.publishing
                      ? 'Publishing…'
                      : 'Publish Find People request',
                ),
              ),
            ],
          ),
        ),
        _issuesFor('publish'),
      ],
    );
  }

  Widget _navigation(int step) {
    return Row(
      children: <Widget>[
        if (step > 0)
          OutlinedButton.icon(
            onPressed: () => widget.controller.goToFindPeopleStep(step - 1),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
        const Spacer(),
        TextButton.icon(
          onPressed: widget.controller.saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save draft'),
        ),
        if (step < findPeopleCreateSteps.length - 1) ...<Widget>[
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => widget.controller.goToFindPeopleStep(step + 1),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continue'),
          ),
        ],
      ],
    );
  }

  Widget _issuesFor(String section) {
    final List<FindPeopleValidationIssue> issues = widget
        .state
        .findPeopleValidationIssues
        .where((FindPeopleValidationIssue issue) => issue.sectionId == section)
        .toList(growable: false);
    if (issues.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: issues
                .map(
                  (FindPeopleValidationIssue issue) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${issue.message}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }

  void _addSlot(CreateDraftEntity draft, FindPeopleDraftData data) {
    final DateTime? start = DateTime.tryParse(_slotStart.text)?.toUtc();
    final DateTime? end = DateTime.tryParse(_slotEnd.text)?.toUtc();
    if (start == null || end == null || !start.isBefore(end)) return;
    final CreateTimeSlotDraft slot = CreateTimeSlotDraft(
      localId: 'loc_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      startAtUtc: start,
      endAtUtc: end,
    );
    if (data.scheduleMode == FindPeopleScheduleMode.single) {
      widget.controller.replaceScheduleSlots(<CreateTimeSlotDraft>[slot]);
    } else {
      widget.controller.replaceScheduleSlots(<CreateTimeSlotDraft>[
        ...draft.scheduleSlots,
        slot,
      ]);
    }
    _slotStart.clear();
    _slotEnd.clear();
  }

  void _addQuestion(FindPeopleDraftData data) {
    final String? prompt = _text(_question.text);
    if (prompt == null || data.applicationQuestions.length >= 8) return;
    _update(
      data.copyWith(
        applicationQuestions: <FindPeopleApplicationQuestionDraft>[
          ...data.applicationQuestions,
          FindPeopleApplicationQuestionDraft(
            id: 'loc_${DateTime.now().toUtc().microsecondsSinceEpoch}',
            prompt: prompt,
            type: FindPeopleQuestionType.text,
          ),
        ],
      ),
    );
    _question.clear();
  }

  void _addExpense(FindPeopleDraftData data) {
    final String? category = _text(_expenseCategory.text);
    final double? amount = double.tryParse(
      _expenseAmount.text.replaceAll(',', '.'),
    );
    if (category == null || amount == null || amount <= 0) return;
    _update(
      data.copyWith(
        plannedExpenseItems: <FindPeopleExpenseItemDraft>[
          ...data.plannedExpenseItems,
          FindPeopleExpenseItemDraft(
            id: 'loc_${DateTime.now().toUtc().microsecondsSinceEpoch}',
            category: category,
            amount: amount,
            payerNote: 'shared',
          ),
        ],
      ),
    );
    _expenseCategory.clear();
    _expenseAmount.clear();
  }

  void _addCoHost(FindPeopleDraftData data) {
    final String? userId = _text(_coHostUserId.text);
    if (userId == null ||
        data.coHosts.any(
          (FindPeopleCoHostDraft item) => item.userId == userId,
        )) {
      return;
    }
    _update(
      data.copyWith(
        coHosts: <FindPeopleCoHostDraft>[
          ...data.coHosts,
          FindPeopleCoHostDraft(
            id: 'loc_${DateTime.now().toUtc().microsecondsSinceEpoch}',
            userId: userId,
            capabilityIds: const <String>{'review_applications'},
            accepted: false,
            occupiesSeat: false,
          ),
        ],
      ),
    );
    _coHostUserId.clear();
  }

  void _update(FindPeopleDraftData data) =>
      widget.controller.updateFindPeopleData(data);
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.config,
    required this.saveStatus,
    required this.onStepSelected,
  });

  final int step;
  final FindPeopleCreateStepConfig config;
  final CreateSaveStatus saveStatus;
  final Future<bool> Function(int) onStepSelected;

  @override
  Widget build(BuildContext context) {
    final String saveLabel = switch (saveStatus) {
      CreateSaveStatus.saved => 'Saved',
      CreateSaveStatus.saving => 'Saving…',
      CreateSaveStatus.unsaved => 'Unsaved changes',
      CreateSaveStatus.failed => 'Save error',
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Find People · ${step + 1}/${findPeopleCreateSteps.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(saveLabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (step + 1) / findPeopleCreateSteps.length,
          ),
          const SizedBox(height: 10),
          Text(config.title, style: Theme.of(context).textTheme.titleLarge),
          Text(config.description),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(
                findPeopleCreateSteps.length,
                (int index) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      '${index + 1}. ${findPeopleCreateSteps[index].title}',
                    ),
                    selected: index == step,
                    onSelected: (_) => onStepSelected(index),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({this.title, this.subtitle, required this.child});

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null)
              Text(
                title!,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (title != null || subtitle != null) const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _DraftTextField extends StatefulWidget {
  const _DraftTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;

  @override
  State<_DraftTextField> createState() => _DraftTextFieldState();
}

class _DraftTextFieldState extends State<_DraftTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  late final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant _DraftTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        keyboardType: widget.keyboardType,
        decoration: _decoration(widget.label, hint: widget.hint),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text('$label: $value')),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value <= min ? null : () => onChanged(value - 1),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value >= max ? null : () => onChanged(value + 1),
        ),
      ],
    );
  }
}

InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  border: const OutlineInputBorder(),
);

String _enumLabel(String value) {
  final String spaced = value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (Match match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ');
  return spaced.isEmpty
      ? spaced
      : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

String? _text(String value) {
  final String normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.isEmpty ? null : normalized;
}

List<String> _lines(String value) => value
    .split(RegExp(r'[\r\n]+'))
    .map((String item) => item.trim())
    .where((String item) => item.isNotEmpty)
    .toList(growable: false);

int _stepIndex(String sectionId) {
  final int index = findPeopleCreateSteps.indexWhere(
    (FindPeopleCreateStepConfig item) => item.id == sectionId,
  );
  return index < 0 ? 0 : index;
}
