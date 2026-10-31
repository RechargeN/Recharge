import 'package:flutter/material.dart';

import '../../application/controllers/create_controller.dart';
import '../../application/rental_create_config.dart';
import '../../application/state/create_state.dart';
import '../../domain/entities/create_draft_entity.dart';
import '../../domain/entities/rental_draft_data.dart';
import '../../domain/entities/rental_listing.dart';
import '../../domain/entities/rental_validation_issue.dart';
import 'rental_template_panel.dart';
import 'create_texts.dart';
import '../../../../core/localization/l10n_context.dart';
import 'create_form_texts.dart';
import '../../../../core/localization/recharge_formats.dart';
import '../../../../shared/primitives/money/money.dart';

/// Rental / Equipment create block — RNT-CRT-01. A shell + step navigation
/// (mirrors `PlaceCreateBlock`), with all 8 spec §13 steps rendered as
/// private builder methods in this single file rather than split into one
/// widget per section: Rental's steps are individually simpler than
/// Place's, so the Find People-style single-file approach reads more
/// clearly here than six separate small widget files would.
class RentalCreateBlock extends StatefulWidget {
  const RentalCreateBlock({
    required this.controller,
    required this.state,
    required this.onPublished,
    super.key,
  });

  final CreateController controller;
  final CreateState state;
  final VoidCallback onPublished;

  @override
  State<RentalCreateBlock> createState() => _RentalCreateBlockState();
}

class _RentalCreateBlockState extends State<RentalCreateBlock> {
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{};

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
    final RentalDraftData? rental = draft.rentalData;
    if (rental == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(context.l10n.createFormRentalDataBeingPrepared),
        ),
      );
    }
    final bool canEdit = widget.controller.canCreateRental;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!canEdit) ...<Widget>[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text(context.l10n.createFormReadOnlyDraft),
              subtitle: Text(
                context
                    .l10n
                    .createFormCreateRentalCapabilityRequiredEditPublish,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        RentalTemplatePanel(controller: widget.controller),
        const SizedBox(height: 12),
        _RentalProgressHeader(state: widget.state),
        const SizedBox(height: 12),
        IgnorePointer(
          ignoring: !canEdit,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey<int>(widget.state.rentalStep),
              child: switch (widget.state.rentalStep) {
                0 => _listingStep(rental),
                1 => _inventoryStep(rental),
                2 => _availabilityStep(rental),
                3 => _handoverStep(rental),
                4 => _termsStep(rental),
                5 => _pricingStep(rental),
                6 => _fulfillmentStep(rental),
                _ => _reviewStep(draft, rental),
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _stepNav(),
      ],
    );
  }

  Widget _stepNav() {
    final int step = widget.state.rentalStep;
    final bool isLast = step == rentalCreateSteps.length - 1;
    return Row(
      children: <Widget>[
        if (step > 0)
          Flexible(
            child: OutlinedButton(
              onPressed: () => widget.controller.goToRentalStep(step - 1),
              child: Text(context.l10n.createFormBack),
            ),
          ),
        const Spacer(),
        if (!isLast)
          Flexible(
            child: ElevatedButton(
              onPressed: () => widget.controller.goToRentalStep(step + 1),
              child: Text(context.l10n.createFormNext),
            ),
          ),
      ],
    );
  }

  String? _error(String fieldId) {
    for (final RentalValidationIssue issue
        in widget.state.rentalValidationIssues) {
      if (issue.isBlocking && issue.fieldId == fieldId) {
        return CreateTexts.fieldError(context.l10n, issue.messageKey);
      }
    }
    return null;
  }

  // ---- Step 1: Listing and media ----------------------------------------

  Widget _listingStep(RentalDraftData rental) {
    return _StepCard(
      title: createFormText(context.l10n, rentalCreateSteps[0].titleId),
      description: createFormText(
        context.l10n,
        rentalCreateSteps[0].descriptionId,
      ),
      children: <Widget>[
        TextField(
          controller: _field('title', rental.title),
          decoration: InputDecoration(
            labelText: context.l10n.createFormTitle,
            errorText: _error('title'),
          ),
          onChanged: widget.controller.updateRentalTitle,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _field('brandModel', rental.brandModel ?? ''),
          decoration: InputDecoration(
            labelText: context.l10n.createRentalBrandModel,
          ),
          onChanged: widget.controller.updateRentalBrandModel,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _field('shortDescription', rental.shortDescription),
          decoration: InputDecoration(
            labelText: context.l10n.createFormShortDescription,
            errorText: _error('shortDescription'),
          ),
          maxLines: 2,
          onChanged: widget.controller.updateRentalShortDescription,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _field('fullDescription', rental.fullDescription),
          decoration: InputDecoration(
            labelText: context.l10n.createFormFullDescription,
            errorText: _error('fullDescription'),
          ),
          maxLines: 5,
          onChanged: widget.controller.updateRentalFullDescription,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _field('categoryId', rental.categoryId),
                decoration: InputDecoration(
                  labelText: context.l10n.createFormCategory,
                  errorText: _error('categoryId'),
                ),
                onChanged: (value) => widget.controller.updateRentalCategory(
                  categoryId: value,
                  subcategoryId: rental.subcategoryId,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _field('subcategoryId', rental.subcategoryId),
                decoration: InputDecoration(
                  labelText: context.l10n.createFormSubcategory,
                ),
                onChanged: (value) => widget.controller.updateRentalCategory(
                  categoryId: rental.categoryId,
                  subcategoryId: value,
                ),
              ),
            ),
          ],
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: rental.categoryConfirmed,
          title: Text(context.l10n.createRentalConfirmCategory),
          onChanged: (value) {
            if (value == true) widget.controller.confirmRentalCategory();
          },
        ),
      ],
    );
  }

  // ---- Step 2: Inventory --------------------------------------------------

  Widget _inventoryStep(RentalDraftData rental) {
    return _StepCard(
      title: createFormText(context.l10n, rentalCreateSteps[1].titleId),
      description: createFormText(
        context.l10n,
        rentalCreateSteps[1].descriptionId,
      ),
      children: <Widget>[
        for (final RentalInventoryGroup group in rental.inventoryGroups)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _field('group_label_${group.id}', group.label),
                    decoration: InputDecoration(
                      labelText: context.l10n.createFormLabel,
                    ),
                    onChanged: (value) =>
                        widget.controller.updateRentalInventoryGroup(
                          group.id,
                          (g) => g.copyWith(label: value),
                        ),
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _field(
                            'group_qty_${group.id}',
                            group.quantity.toString(),
                          ),
                          decoration: InputDecoration(
                            labelText: context.l10n.createFormQuantity,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final int? qty = int.tryParse(value);
                            if (qty == null) return;
                            widget.controller.updateRentalInventoryGroup(
                              group.id,
                              (g) => g.copyWith(quantity: qty),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<RentalCondition>(
                          isExpanded: true,
                          initialValue: group.condition,
                          decoration: InputDecoration(
                            labelText: context.l10n.createFormCondition,
                          ),
                          items: RentalCondition.values
                              .map(
                                (c) => DropdownMenuItem<RentalCondition>(
                                  value: c,
                                  child: Text(
                                    createOptionText(context.l10n, c),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            widget.controller.updateRentalInventoryGroup(
                              group.id,
                              (g) => g.copyWith(condition: value),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _field(
                      'group_size_${group.id}',
                      group.sizeOrVariant ?? '',
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.createRentalSizeVariant,
                    ),
                    onChanged: (value) =>
                        widget.controller.updateRentalInventoryGroup(
                          group.id,
                          (g) => g.copyWith(
                            sizeOrVariant: value.trim().isEmpty ? null : value,
                            clearSizeOrVariant: value.trim().isEmpty,
                          ),
                        ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => widget.controller
                              .duplicateRentalInventoryGroup(group.id),
                          child: Text(context.l10n.createFormDuplicate),
                        ),
                        TextButton(
                          onPressed: () => widget.controller
                              .removeRentalInventoryGroup(group.id),
                          child: Text(context.l10n.createFormRemove),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => widget.controller.addRentalInventoryGroup(
            RentalInventoryGroup(
              id: 'loc_${DateTime.now().microsecondsSinceEpoch}',
              label: '',
              quantity: 1,
              condition: RentalCondition.good,
            ),
          ),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.createFormAddAnotherItemType),
        ),
      ],
    );
  }

  // ---- Step 3: Availability -----------------------------------------------

  Widget _availabilityStep(RentalDraftData rental) {
    final RentalAvailabilityCoverage? coverage = rental.availability.coverage;
    return _StepCard(
      title: createFormText(context.l10n, rentalCreateSteps[2].titleId),
      description: createFormText(
        context.l10n,
        rentalCreateSteps[2].descriptionId,
      ),
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            coverage == null
                ? Icons.warning_amber_outlined
                : Icons.check_circle_outline,
          ),
          title: Text(
            coverage == null
                ? context.l10n.createFormCalendarNotConfirmedYet
                : context.l10n.createFormConfirmedOn(
                    RechargeFormats.dateTime(
                      coverage.confirmedAtUtc,
                      widget.state.draft.timezone,
                      context.l10n.localeName,
                    ),
                  ),
          ),
          subtitle: Text(
            context.l10n.createFormRechargeCannotSeeExternalBookingsConfirm,
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ElevatedButton(
            onPressed: () =>
                widget.controller.confirmRentalAvailabilityCoverage(
                  startsAtUtc: DateTime.now().toUtc(),
                  endsAtUtc: DateTime.now().toUtc().add(
                    const Duration(days: 90),
                  ),
                ),
            child: Text(context.l10n.createFormConfirmCalendar),
          ),
        ),
        const Divider(),
        for (final RentalAvailabilityBlock block
            in rental.availability.blocks.where((b) => b.isActive))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${_findGroupLabel(rental, block.groupId)}: '
              '${context.l10n.createRentalUnitsBlocked(block.unitsBlocked)}',
            ),
            subtitle: Text(
              '${RechargeFormats.dateTime(block.startsAtUtc, widget.state.draft.timezone, context.l10n.localeName)} → '
              '${RechargeFormats.dateTime(block.endsAtUtc, widget.state.draft.timezone, context.l10n.localeName)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () =>
                  widget.controller.cancelRentalAvailabilityBlock(block.id),
            ),
          ),
        if (rental.inventoryGroups.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _showAddBlockDialog(rental),
            icon: const Icon(Icons.event_busy),
            label: Text(context.l10n.createFormBlockDateRange),
          ),
      ],
    );
  }

  String _findGroupLabel(RentalDraftData rental, String groupId) {
    for (final RentalInventoryGroup g in rental.inventoryGroups) {
      if (g.id == groupId) {
        return g.label.isEmpty ? context.l10n.createFormGroup : g.label;
      }
    }
    return context.l10n.createFormGroup;
  }

  Future<void> _showAddBlockDialog(RentalDraftData rental) async {
    final RentalInventoryGroup group = rental.inventoryGroups.first;
    final DateTime now = DateTime.now().toUtc();
    final bool added = widget.controller.addRentalAvailabilityBlock(
      RentalAvailabilityBlock(
        id: 'loc_${now.microsecondsSinceEpoch}',
        groupId: group.id,
        startsAtUtc: now,
        endsAtUtc: now.add(const Duration(days: 1)),
        unitsBlocked: 1,
        source: RentalBlockSource.manualExternalRental,
        createdByUserId: widget.state.userId,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    if (!added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.createFormThatWouldExceedGroupCapacity),
        ),
      );
    }
  }

  // ---- Step 4: Handover -----------------------------------------------------

  Widget _handoverStep(RentalDraftData rental) {
    final RentalHandoverDraft h = rental.handover;
    return _StepCard(
      title: createFormText(context.l10n, rentalCreateSteps[3].titleId),
      description: createFormText(
        context.l10n,
        rentalCreateSteps[3].descriptionId,
      ),
      children: <Widget>[
        TextField(
          controller: _field('pickupPlaceName', h.pickupPlaceName),
          decoration: InputDecoration(
            labelText: context.l10n.createFormPickupPlaceName,
            errorText: _error('pickupPlaceName'),
          ),
          onChanged: (value) => widget.controller.updateRentalHandover(
            (handover) => handover.copyWith(pickupPlaceName: value),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _field('publicAreaLabel', h.publicAreaLabel),
          decoration: InputDecoration(
            labelText: context.l10n.createFormPublicAreaLabel,
          ),
          onChanged: (value) => widget.controller.updateRentalHandover(
            (handover) => handover.copyWith(publicAreaLabel: value),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _field(
                  'publicLatitude',
                  h.publicLatitude?.toString() ?? '',
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.createFormLatitude,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final double? lat = double.tryParse(value);
                  widget.controller.updateRentalHandover(
                    (handover) => handover.copyWith(
                      publicLatitude: lat,
                      clearPublicLatitude: lat == null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _field(
                  'publicLongitude',
                  h.publicLongitude?.toString() ?? '',
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.createFormLongitude,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final double? lng = double.tryParse(value);
                  widget.controller.updateRentalHandover(
                    (handover) => handover.copyWith(
                      publicLongitude: lng,
                      clearPublicLongitude: lng == null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        DropdownButtonFormField<RentalLocationDisclosure>(
          isExpanded: true,
          initialValue: h.disclosure,
          decoration: InputDecoration(
            labelText: context.l10n.createFormLocationDisclosure,
          ),
          items: RentalLocationDisclosure.values
              .map(
                (d) => DropdownMenuItem<RentalLocationDisclosure>(
                  value: d,
                  child: Text(
                    d == RentalLocationDisclosure.approximateArea
                        ? context.l10n.createFormApproximateAreaDefault
                        : context.l10n.createFormPublicBusinessAddress,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            widget.controller.updateRentalHandover(
              (handover) => handover.copyWith(disclosure: value),
            );
          },
        ),
        if (h.disclosure == RentalLocationDisclosure.publicBusinessAddress)
          TextField(
            controller: _field('publicAddress', h.publicAddress ?? ''),
            decoration: InputDecoration(
              labelText: context.l10n.createFormPublicBusinessAddress,
            ),
            onChanged: (value) => widget.controller.updateRentalHandover(
              (handover) => handover.copyWith(
                publicAddress: value.trim().isEmpty ? null : value,
                clearPublicAddress: value.trim().isEmpty,
              ),
            ),
          ),
        DropdownButtonFormField<RentalScheduleMode>(
          isExpanded: true,
          initialValue: h.scheduleMode,
          decoration: InputDecoration(
            labelText: context.l10n.createFormPickupSchedule,
          ),
          items: RentalScheduleMode.values
              .map(
                (m) => DropdownMenuItem<RentalScheduleMode>(
                  value: m,
                  child: Text(
                    m == RentalScheduleMode.openingHours
                        ? context.l10n.createFormOpeningHours
                        : context.l10n.createFormByArrangement,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            widget.controller.updateRentalHandover(
              (handover) => handover.copyWith(scheduleMode: value),
            );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: h.deliveryAvailable,
          title: Text(context.l10n.createFormOfferDelivery),
          onChanged: (value) => widget.controller.updateRentalHandover(
            (handover) => handover.copyWith(deliveryAvailable: value),
          ),
        ),
        if (h.deliveryAvailable) ...<Widget>[
          TextField(
            controller: _field(
              'deliveryRadiusKm',
              h.deliveryRadiusKm?.toString() ?? '',
            ),
            decoration: InputDecoration(
              labelText: context.l10n.createFormDeliveryRadiusKm,
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final double? radius = double.tryParse(value);
              widget.controller.updateRentalHandover(
                (handover) => handover.copyWith(deliveryRadiusKm: radius),
              );
            },
          ),
          TextField(
            controller: _field(
              'deliveryFee',
              h.deliveryFee?.amountMinor.toString() ?? '',
            ),
            decoration: InputDecoration(
              labelText: context.l10n.createFormDeliveryFeeMinorUnits,
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final int? minor = int.tryParse(value);
              if (minor == null) return;
              widget.controller.updateRentalHandover(
                (handover) => handover.copyWith(
                  deliveryFee: RentalMoneyDraft(
                    amountMinor: minor,
                    currencyCode: rental.pricing.currencyCode,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // ---- Step 5: Duration and safety -----------------------------------------

  Widget _termsStep(RentalDraftData rental) {
    final RentalTerms t = rental.terms;
    final RentalAdaptiveHint? hint = rentalAdaptiveHintFor(rental.categoryId);
    return _StepCard(
      title: createFormText(context.l10n, rentalCreateSteps[4].titleId),
      description: createFormText(
        context.l10n,
        rentalCreateSteps[4].descriptionId,
      ),
      children: <Widget>[
        if (hint != null)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: ListTile(
              title: Text(context.l10n.createFormSuggestedDefaultsCategory),
              subtitle: Text(context.l10n.createRentalDefaultsEditable),
              trailing: TextButton(
                onPressed: widget.controller.applyRentalAdaptiveHint,
                child: Text(context.l10n.createFormApply),
              ),
            ),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _field(
                  'offeredMinMinutes',
                  t.offeredMinMinutes.toString(),
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.createFormMinDurationMin,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final int? v = int.tryParse(value);
                  if (v == null) return;
                  widget.controller.updateRentalTerms(
                    (terms) => terms.copyWith(offeredMinMinutes: v),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _field(
                  'offeredMaxMinutes',
                  t.offeredMaxMinutes.toString(),
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.createFormMaxDurationMin,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final int? v = int.tryParse(value);
                  if (v == null) return;
                  widget.controller.updateRentalTerms(
                    (terms) => terms.copyWith(offeredMaxMinutes: v),
                  );
                },
              ),
            ),
          ],
        ),
        TextField(
          controller: _field('minRenterAge', t.minRenterAge?.toString() ?? ''),
          decoration: InputDecoration(
            labelText: context.l10n.createFormMinimumRenterAge,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final int? v = int.tryParse(value);
            widget.controller.updateRentalTerms(
              (terms) =>
                  terms.copyWith(minRenterAge: v, clearMinRenterAge: v == null),
            );
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: t.idRequiredAtHandover,
          title: Text(context.l10n.createRentalIdRequired),
          onChanged: (value) => widget.controller.updateRentalTerms(
            (terms) => terms.copyWith(idRequiredAtHandover: value ?? false),
          ),
        ),
        TextField(
          controller: _field('safetyNotice', t.safetyNotice ?? ''),
          decoration: InputDecoration(
            labelText: context.l10n.createFormSafetyNotice,
            errorText: _error('safetyNotice'),
          ),
          maxLines: 3,
          onChanged: (value) => widget.controller.updateRentalTerms(
            (terms) => terms.copyWith(
              safetyNotice: value.trim().isEmpty ? null : value,
              clearSafetyNotice: value.trim().isEmpty,
            ),
          ),
        ),
        TextField(
          controller: _field('usageRestrictions', t.usageRestrictions ?? ''),
          decoration: InputDecoration(
            labelText: context.l10n.createFormUsageRestrictions,
          ),
          maxLines: 2,
          onChanged: (value) => widget.controller.updateRentalTerms(
            (terms) => terms.copyWith(
              usageRestrictions: value.trim().isEmpty ? null : value,
              clearUsageRestrictions: value.trim().isEmpty,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Step 6: Pricing and deposit ------------------------------------------

  Widget _pricingStep(RentalDraftData rental) {
    final RentalPricingPolicy p = rental.pricing;
    return _StepCard(
      title: createFormText(context.l10n, rentalCreateSteps[5].titleId),
      description: createFormText(
        context.l10n,
        rentalCreateSteps[5].descriptionId,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _field('currencyCode', p.currencyCode),
                decoration: InputDecoration(
                  labelText: context.l10n.createRentalCurrencyField,
                  errorText: _error('currencyCode'),
                ),
                onChanged: (value) => widget.controller.updateRentalPricing(
                  (pricing) => pricing.copyWith(
                    currencyCode: value.trim().toUpperCase(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<RentalBillingUnit>(
                isExpanded: true,
                initialValue: p.billingUnit,
                decoration: InputDecoration(
                  labelText: context.l10n.createFormBillingUnit,
                ),
                items: RentalBillingUnit.values
                    .map(
                      (u) => DropdownMenuItem<RentalBillingUnit>(
                        value: u,
                        child: Text(createOptionText(context.l10n, u)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  widget.controller.updateRentalPricing(
                    (pricing) => pricing.copyWith(billingUnit: value),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < p.rateSteps.length; i++)
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.createRentalRateStep(
                    p.rateSteps[i].minUnits,
                    '${p.rateSteps[i].unitPrice.amountMinor} ${p.currencyCode}',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => widget.controller.removeRentalRateStepAt(i),
              ),
            ],
          ),
        OutlinedButton.icon(
          onPressed: () => widget.controller.addRentalRateStep(
            RentalRateStep(
              minUnits: p.rateSteps.isEmpty ? 1 : p.rateSteps.last.minUnits + 1,
              unitPrice: RentalMoneyDraft(
                amountMinor: 0,
                currencyCode: p.currencyCode,
              ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.createFormAddRateStep),
        ),
        const Divider(),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _field(
                  'depositAmount',
                  p.deposit.amount.amountMinor.toString(),
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.createRentalDepositField,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final int? minor = int.tryParse(value);
                  if (minor == null) return;
                  widget.controller.updateRentalPricing(
                    (pricing) => pricing.copyWith(
                      deposit: pricing.deposit.copyWith(
                        amount: RentalMoneyDraft(
                          amountMinor: minor,
                          currencyCode: pricing.currencyCode,
                        ),
                        collectionMethod: minor == 0
                            ? RentalDepositCollectionMethod.none
                            : (pricing.deposit.collectionMethod ==
                                      RentalDepositCollectionMethod.none
                                  ? RentalDepositCollectionMethod.atHandover
                                  : pricing.deposit.collectionMethod),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<RentalDepositCollectionMethod>(
                isExpanded: true,
                initialValue: p.deposit.collectionMethod,
                decoration: InputDecoration(
                  labelText: context.l10n.createFormCollectionMethod,
                ),
                items: RentalDepositCollectionMethod.values
                    .map(
                      (m) => DropdownMenuItem<RentalDepositCollectionMethod>(
                        value: m,
                        child: Text(createOptionText(context.l10n, m)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  widget.controller.updateRentalPricing(
                    (pricing) => pricing.copyWith(
                      deposit: pricing.deposit.copyWith(
                        collectionMethod: value,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        TextField(
          controller: _field('depositTerms', p.deposit.terms ?? ''),
          decoration: InputDecoration(
            labelText: context.l10n.createFormDepositTerms,
            errorText: _error('deposit'),
          ),
          onChanged: (value) => widget.controller.updateRentalPricing(
            (pricing) => pricing.copyWith(
              deposit: pricing.deposit.copyWith(
                terms: value.trim().isEmpty ? null : value,
                clearTerms: value.trim().isEmpty,
              ),
            ),
          ),
        ),
        TextField(
          controller: _field('damagePolicy', p.damagePolicy),
          decoration: InputDecoration(
            labelText: context.l10n.createFormDamagePolicy,
            errorText: _error('damagePolicy'),
          ),
          maxLines: 2,
          onChanged: (value) => widget.controller.updateRentalPricing(
            (pricing) => pricing.copyWith(damagePolicy: value),
          ),
        ),
        TextField(
          controller: _field('lateReturnPolicy', p.lateReturnPolicy ?? ''),
          decoration: InputDecoration(
            labelText: context.l10n.createFormLateReturnPolicy,
          ),
          onChanged: (value) => widget.controller.updateRentalPricing(
            (pricing) => pricing.copyWith(
              lateReturnPolicy: value.trim().isEmpty ? null : value,
              clearLateReturnPolicy: value.trim().isEmpty,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Step 7: External fulfillment -----------------------------------------

  Widget _fulfillmentStep(RentalDraftData rental) {
    final String? url = rental.fulfillment.externalBookingUrl;
    final String? host = url == null ? null : Uri.tryParse(url)?.host;
    return _StepCard(
      title: createFormText(context.l10n, rentalCreateSteps[6].titleId),
      description: createFormText(
        context.l10n,
        rentalCreateSteps[6].descriptionId,
      ),
      children: <Widget>[
        TextField(
          controller: _field('externalBookingUrl', url ?? ''),
          decoration: InputDecoration(
            labelText: context.l10n.createFormExternalBookingUrlHttps,
            errorText: _error('externalBookingUrl'),
          ),
          onChanged: widget.controller.updateRentalExternalBookingUrl,
        ),
        if (host != null && host.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.l10n.createFormYouWillLeaveRechargeGoCheck,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  // ---- Step 8: Review and submit ---------------------------------------------

  Widget _reviewStep(CreateDraftEntity draft, RentalDraftData rental) {
    final RentalListing? preview = widget.controller.rentalPublicPreview;
    final bool attestationComplete = rental.attestation.isComplete;
    return _StepCard(
      title: createFormText(context.l10n, rentalCreateSteps[7].titleId),
      description: createFormText(
        context.l10n,
        rentalCreateSteps[7].descriptionId,
      ),
      children: <Widget>[
        if (preview != null) ...<Widget>[
          Text(
            context.l10n.createFormPublicPreview,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            preview.title.isEmpty
                ? context.l10n.createFormNoTitleYet
                : preview.title,
          ),
          Text(
            '${context.l10n.createFormUnits(preview.totalUnitsAggregate)} · '
            '${createOptionText(context.l10n, preview.billingUnit)}',
          ),
          if (preview.hasDeposit)
            Text(
              context.l10n.createFormDepositLine(
                RechargeFormats.money(
                  Money(
                    minorUnits: preview.depositAmountMinor ?? 0,
                    currencyCode: preview.currencyCode,
                  ),
                  Localizations.localeOf(context).languageCode,
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(context.l10n.createRentalPrivateNotice),
          ),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: rental.attestation.hasRightToOffer,
          title: Text(context.l10n.createRentalRightToOffer),
          onChanged: (value) => widget.controller.acceptRentalAttestation(
            hasRightToOffer: value ?? false,
            listingAccurate: rental.attestation.listingAccurate,
            prohibitedItemsAcknowledged:
                rental.attestation.prohibitedItemsAcknowledged,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: rental.attestation.listingAccurate,
          title: Text(context.l10n.createFormListingAccurate),
          onChanged: (value) => widget.controller.acceptRentalAttestation(
            hasRightToOffer: rental.attestation.hasRightToOffer,
            listingAccurate: value ?? false,
            prohibitedItemsAcknowledged:
                rental.attestation.prohibitedItemsAcknowledged,
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: rental.attestation.prohibitedItemsAcknowledged,
          title: Text(context.l10n.createFormNotProhibitedUnsafeItem),
          onChanged: (value) => widget.controller.acceptRentalAttestation(
            hasRightToOffer: rental.attestation.hasRightToOffer,
            listingAccurate: rental.attestation.listingAccurate,
            prohibitedItemsAcknowledged: value ?? false,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: attestationComplete && widget.controller.canSubmitRental
              ? () async {
                  final bool ok = await widget.controller.publishDraft();
                  if (ok) widget.onPublished();
                }
              : null,
          child: Text(
            widget.controller.canPublishRentalDirect
                ? context.l10n.createFormPublish
                : context.l10n.createFormSubmitReview,
          ),
        ),
      ],
    );
  }
}

class _RentalProgressHeader extends StatelessWidget {
  const _RentalProgressHeader({required this.state});

  final CreateState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.createFormStepOf(
            state.rentalStep + 1,
            rentalCreateSteps.length,
          ),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (state.rentalStep + 1) / rentalCreateSteps.length,
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
