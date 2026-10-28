import '../entities/event_admission.dart';
import '../entities/event_draft_data.dart';
import '../entities/event_inventory.dart';
import '../entities/event_validation_issue.dart';

class EventAccessReadiness {
  const EventAccessReadiness({
    this.internalRegistration = false,
    this.providerManagedConfirmation = false,
    this.auditableLottery = false,
    this.authoritativeWaitlist = false,
    this.assignedSeatingHolds = false,
    this.externalInventory = false,
    this.eligiblePolicyRefs = const <String>{},
  });

  final bool internalRegistration;
  final bool providerManagedConfirmation;
  final bool auditableLottery;
  final bool authoritativeWaitlist;
  final bool assignedSeatingHolds;
  final bool externalInventory;
  final Set<String> eligiblePolicyRefs;
}

class ValidateEventAccessConfigurationUseCase {
  const ValidateEventAccessConfigurationUseCase();

  List<EventValidationIssue> call({
    required EventAdmissionDraft? admission,
    required EventInventoryConfiguration? inventory,
    required EventCapacityMode capacityMode,
    required int? capacity,
    required EventFormat format,
    required EventScheduleMode scheduleMode,
    required List<EventOccurrenceDraft> occurrences,
    required String? externalRegistrationUrl,
    EventAccessReadiness readiness = const EventAccessReadiness(),
  }) {
    final List<EventValidationIssue> issues = <EventValidationIssue>[];
    void add(String code, String field) {
      issues.add(EventValidationIssue(code: code, fieldId: field, step: 3));
    }

    if (capacityMode == EventCapacityMode.known && (capacity ?? 0) <= 0) {
      add('capacity_required', 'capacity');
    }
    if (capacityMode != EventCapacityMode.known && capacity != null) {
      add('capacity_mode_conflict', 'capacity');
    }
    if (admission != null) {
      _validateAdmission(
        admission,
        scheduleMode: scheduleMode,
        occurrences: occurrences,
        externalRegistrationUrl: externalRegistrationUrl,
        inventory: inventory,
        readiness: readiness,
        add: add,
      );
    }
    if (inventory != null) {
      _validateInventory(
        inventory,
        format: format,
        eventCapacityMode: capacityMode,
        eventCapacity: capacity,
        readiness: readiness,
        add: add,
      );
    }
    return List<EventValidationIssue>.unmodifiable(issues);
  }

  void _validateAdmission(
    EventAdmissionDraft value, {
    required EventScheduleMode scheduleMode,
    required List<EventOccurrenceDraft> occurrences,
    required String? externalRegistrationUrl,
    required EventInventoryConfiguration? inventory,
    required EventAccessReadiness readiness,
    required void Function(String, String) add,
  }) {
    if (!value.isComplete) {
      add('admission_axes_incomplete', 'admission');
      return;
    }
    if (value.admissionMode == AdmissionMode.openEntry &&
        (value.registrationMode != EventRegistrationMode.none ||
            value.confirmationMode != ConfirmationMode.none)) {
      add('open_entry_axes_conflict', 'admissionMode');
    }
    final InterestPolicy? interest = value.interestPolicy;
    if (interest != null &&
        (!interest.reminderConsentRequired ||
            interest.createsBooking ||
            interest.reservesInventory ||
            interest.registrationAtDoorRequired)) {
      add('interest_policy_not_non_reserving', 'interestPolicy');
    }
    final GuestPolicy? guest = value.guestPolicy;
    if (guest != null) {
      if (!guest.countsAgainstCapacity) {
        add('guest_capacity_bypass_unsupported', 'guestPolicy');
      }
      final bool usesCustomLimit =
          guest.mode == GuestPolicyMode.plusN ||
          guest.mode == GuestPolicyMode.namedGuestsOnly;
      if (usesCustomLimit && (guest.maxGuests ?? 0) <= 0) {
        add('guest_limit_required', 'guestMaxGuests');
      }
      if (!usesCustomLimit && guest.maxGuests != null) {
        add('guest_limit_mode_conflict', 'guestMaxGuests');
      }
    }
    final Set<String> ruleIds = <String>{};
    for (final EligibilityRule rule in value.eligibilityRules) {
      if (!_stableLocalId(rule.id) || !ruleIds.add(rule.id)) {
        add('eligibility_rule_id_invalid', 'eligibilityRules');
      }
      if (rule.policyRef != null && !_safeReference(rule.policyRef!)) {
        add('eligibility_policy_ref_invalid', 'eligibilityRules');
      } else if (rule.policyRef != null &&
          !readiness.eligiblePolicyRefs.contains(rule.policyRef)) {
        add('eligibility_policy_not_ready', 'eligibilityRules');
      }
    }
    _validateWindow(
      value.registrationWindow,
      fieldId: 'registrationWindow',
      allowZeroClosing:
          readiness.internalRegistration &&
          value.registrationMode == EventRegistrationMode.internal,
      scheduleMode: scheduleMode,
      occurrences: occurrences,
      add: add,
    );
    _validateWindow(
      value.applicationWindow,
      fieldId: 'applicationWindow',
      scheduleMode: scheduleMode,
      occurrences: occurrences,
      add: add,
    );
    if (value.registrationMode == EventRegistrationMode.external &&
        !_safeHttps(externalRegistrationUrl)) {
      add('external_registration_handoff_required', 'externalBookingUrl');
    }
    if (value.registrationMode == EventRegistrationMode.internal) {
      final int? cancellation = value.cancellationClosesBeforeOccurrenceMinutes;
      if (cancellation == null) {
        add('cancellation_deadline_required', 'cancellationDeadline');
      } else if (cancellation < 0 || cancellation > 10080) {
        add('cancellation_deadline_invalid', 'cancellationDeadline');
      }
      if (value.guestPolicy == null) {
        add('guest_policy_required', 'guestPolicy');
      }
    }
    if (value.registrationMode == EventRegistrationMode.internal &&
        !readiness.internalRegistration) {
      add('internal_registration_not_ready', 'registrationMode');
    }
    if (value.confirmationMode == ConfirmationMode.providerManaged &&
        (value.registrationMode != EventRegistrationMode.external ||
            !readiness.providerManagedConfirmation)) {
      add('provider_confirmation_not_ready', 'confirmationMode');
    }
    if (value.confirmationMode == ConfirmationMode.lottery &&
        (value.applicationWindow == null || !readiness.auditableLottery)) {
      add('lottery_not_ready', 'confirmationMode');
    }
    final WaitlistConfiguration? waitlist = value.waitlistPolicy;
    if (waitlist?.enabled == true) {
      final bool finite =
          inventory?.pools.any(
            (pool) => pool.capacityMode == EventCapacityMode.known,
          ) ==
          true;
      if (!finite || !readiness.authoritativeWaitlist) {
        add('waitlist_not_ready', 'waitlistPolicy');
      }
      if (waitlist!.promotionMode == WaitlistPromotionMode.fifoAutomatic &&
          (waitlist.offerTtlMinutes ?? 0) <= 0) {
        add('waitlist_offer_ttl_required', 'waitlistOfferTtl');
      }
    }
  }

  void _validateWindow(
    EventAccessWindow? value, {
    bool allowZeroClosing = false,
    required String fieldId,
    required EventScheduleMode scheduleMode,
    required List<EventOccurrenceDraft> occurrences,
    required void Function(String, String) add,
  }) {
    if (value == null) return;
    if (scheduleMode != EventScheduleMode.oneTime &&
        value.kind != EventAccessWindowKind.occurrenceRelative) {
      add('access_window_must_be_relative', fieldId);
      return;
    }
    if (value.kind == EventAccessWindowKind.absolute) {
      final DateTime? occurrenceStart = occurrences.isEmpty
          ? null
          : occurrences
                .map((occurrence) => occurrence.startAtUtc)
                .reduce((a, b) => a.isBefore(b) ? a : b);
      if (value.opensAtUtc == null ||
          value.closesAtUtc == null ||
          !value.opensAtUtc!.isBefore(value.closesAtUtc!) ||
          occurrenceStart == null ||
          !value.closesAtUtc!.isBefore(occurrenceStart)) {
        add('absolute_access_window_invalid', fieldId);
      }
      if (value.opensBeforeOccurrenceMinutes != null ||
          value.closesBeforeOccurrenceMinutes != null) {
        add('access_window_kind_conflict', fieldId);
      }
    } else {
      final int opens = value.opensBeforeOccurrenceMinutes ?? 0;
      final int closes = value.closesBeforeOccurrenceMinutes ?? 0;
      if (opens <= 0 ||
          value.closesBeforeOccurrenceMinutes == null ||
          (allowZeroClosing ? closes < 0 : closes <= 0) ||
          opens <= closes) {
        add('relative_access_window_invalid', fieldId);
      }
      if (value.opensAtUtc != null || value.closesAtUtc != null) {
        add('access_window_kind_conflict', fieldId);
      }
    }
  }

  void _validateInventory(
    EventInventoryConfiguration value, {
    required EventFormat format,
    required EventCapacityMode eventCapacityMode,
    required int? eventCapacity,
    required EventAccessReadiness readiness,
    required void Function(String, String) add,
  }) {
    if (value.authority == InventoryAuthority.none &&
        (value.primaryShape != null || value.pools.isNotEmpty)) {
      add('inventory_authority_none_conflict', 'inventoryAuthority');
    }
    if (value.authority != InventoryAuthority.none &&
        value.primaryShape == null) {
      add('inventory_primary_shape_required', 'inventoryPrimaryShape');
    }
    if (value.authority != InventoryAuthority.none && value.pools.isEmpty) {
      add('inventory_pools_required', 'inventoryPools');
    }
    if (value.primaryShape != null &&
        value.additionalShapes.contains(value.primaryShape)) {
      add('inventory_shape_duplicate', 'inventoryAdditionalShapes');
    }
    final Set<String> poolIds = <String>{};
    final Set<InventoryShape> configuredShapes = <InventoryShape>{
      if (value.primaryShape != null) value.primaryShape!,
      ...value.additionalShapes,
    };
    int onsiteTotal = 0;
    int onlineTotal = 0;
    for (final EventInventoryPoolDraft pool in value.pools) {
      final bool newStableId = _stableLocalId(pool.id) && poolIds.add(pool.id);
      if (!newStableId) {
        add('inventory_pool_id_invalid', 'inventoryPools');
      }
      if (pool.label.trim().isEmpty) {
        add('inventory_pool_label_required', 'inventoryPools');
      }
      if (!configuredShapes.contains(pool.shape)) {
        add('inventory_pool_shape_unconfigured', 'inventoryPools');
      }
      if (pool.capacityMode == EventCapacityMode.known &&
          (pool.capacity ?? 0) <= 0) {
        add('inventory_pool_capacity_required', 'inventoryPools');
      }
      if (pool.capacityMode != EventCapacityMode.known &&
          pool.capacity != null) {
        add('inventory_pool_capacity_conflict', 'inventoryPools');
      }
      if ((pool.shape == InventoryShape.participantRoles ||
              pool.shape == InventoryShape.roleBalancedSlots) &&
          pool.roleIds.isEmpty) {
        add('inventory_pool_roles_required', 'inventoryPools');
      }
      if (pool.roleIds.toSet().length != pool.roleIds.length ||
          pool.roleIds.any((roleId) => !_safeReference(roleId))) {
        add('inventory_pool_roles_invalid', 'inventoryPools');
      }
      if ((pool.shape == InventoryShape.zones ||
              pool.shape == InventoryShape.tableInventory) &&
          (pool.zoneRef?.trim().isEmpty ?? true)) {
        add('inventory_pool_zone_required', 'inventoryPools');
      }
      if (pool.providerPoolRef != null &&
          !_safeReference(pool.providerPoolRef!)) {
        add('inventory_provider_pool_ref_invalid', 'inventoryPools');
      }
      if (newStableId &&
          pool.capacityMode == EventCapacityMode.known &&
          pool.capacity != null &&
          pool.capacity! > 0) {
        if (pool.channel == InventoryChannel.onsite ||
            pool.channel == InventoryChannel.any) {
          onsiteTotal += pool.capacity!;
        }
        if (pool.channel == InventoryChannel.online ||
            pool.channel == InventoryChannel.any) {
          onlineTotal += pool.capacity!;
        }
      }
    }
    if (eventCapacityMode == EventCapacityMode.known &&
        eventCapacity != null &&
        eventCapacity > 0) {
      if (onsiteTotal > eventCapacity) {
        add('inventory_pool_total_exceeds_event_capacity', 'inventoryPools');
      }
      if (onlineTotal > eventCapacity) {
        add('inventory_pool_total_exceeds_event_capacity', 'inventoryPools');
      }
    }
    final bool finitePhysicalEvent =
        format == EventFormat.hybrid &&
        eventCapacityMode == EventCapacityMode.known;
    final bool hasBoundedOnsite = value.pools.any(
      (pool) =>
          pool.channel == InventoryChannel.onsite &&
          pool.capacityMode == EventCapacityMode.known,
    );
    if (finitePhysicalEvent && !hasBoundedOnsite) {
      add('hybrid_onsite_pool_required', 'inventoryPools');
    }
    final bool assignedSeating =
        value.primaryShape == InventoryShape.assignedSeating ||
        value.additionalShapes.contains(InventoryShape.assignedSeating) ||
        value.pools.any((pool) => pool.shape == InventoryShape.assignedSeating);
    if (assignedSeating && !readiness.assignedSeatingHolds) {
      add('assigned_seating_not_ready', 'inventoryPrimaryShape');
    }
    if (value.authority == InventoryAuthority.recharge &&
        !readiness.internalRegistration) {
      add('recharge_inventory_not_ready', 'inventoryAuthority');
    }
    if (value.authority == InventoryAuthority.externalProvider) {
      final bool providerRefsPresent =
          value.pools.isNotEmpty &&
          value.pools.every(
            (pool) => (pool.providerPoolRef?.trim().isNotEmpty ?? false),
          );
      if (!providerRefsPresent || !readiness.externalInventory) {
        add('external_inventory_not_ready', 'inventoryAuthority');
      }
    }
  }

  bool _safeHttps(String? raw) {
    final Uri? uri = Uri.tryParse(raw?.trim() ?? '');
    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _stableLocalId(String value) =>
      value.trim().isNotEmpty &&
      !value.contains(RegExp(r'\s')) &&
      (value.startsWith('loc_') || value.length >= 10);

  bool _safeReference(String value) =>
      value.trim().isNotEmpty &&
      !value.contains(RegExp(r'[\s@:/\\]')) &&
      value.length <= 128;
}
