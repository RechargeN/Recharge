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
    void add(String code, String field, String message) {
      issues.add(
        EventValidationIssue(
          code: code,
          fieldId: field,
          step: 3,
          message: message,
        ),
      );
    }

    if (capacityMode == EventCapacityMode.known && (capacity ?? 0) <= 0) {
      add('capacity_required', 'capacity', 'Enter a positive capacity.');
    }
    if (capacityMode != EventCapacityMode.known && capacity != null) {
      add(
        'capacity_mode_conflict',
        'capacity',
        'Unknown or unlimited capacity cannot store a numeric limit.',
      );
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
    required void Function(String, String, String) add,
  }) {
    if (!value.isComplete) {
      add(
        'admission_axes_incomplete',
        'admission',
        'Choose admission, registration and confirmation modes.',
      );
      return;
    }
    if (value.admissionMode == AdmissionMode.openEntry &&
        (value.registrationMode != EventRegistrationMode.none ||
            value.confirmationMode != ConfirmationMode.none)) {
      add(
        'open_entry_axes_conflict',
        'admissionMode',
        'Open entry requires no registration and no confirmation.',
      );
    }
    final InterestPolicy? interest = value.interestPolicy;
    if (interest != null &&
        (!interest.reminderConsentRequired ||
            interest.createsBooking ||
            interest.reservesInventory ||
            interest.registrationAtDoorRequired)) {
      add(
        'interest_policy_not_non_reserving',
        'interestPolicy',
        'Optional interest cannot create a booking or reserve inventory.',
      );
    }
    final GuestPolicy? guest = value.guestPolicy;
    if (guest != null) {
      if (!guest.countsAgainstCapacity) {
        add(
          'guest_capacity_bypass_unsupported',
          'guestPolicy',
          'Guests must count against visitor capacity.',
        );
      }
      final bool usesCustomLimit =
          guest.mode == GuestPolicyMode.plusN ||
          guest.mode == GuestPolicyMode.namedGuestsOnly;
      if (usesCustomLimit && (guest.maxGuests ?? 0) <= 0) {
        add(
          'guest_limit_required',
          'guestMaxGuests',
          'Plus-N guest policy requires a positive guest limit.',
        );
      }
      if (!usesCustomLimit && guest.maxGuests != null) {
        add(
          'guest_limit_mode_conflict',
          'guestMaxGuests',
          'Only Plus-N guest policy stores a custom guest limit.',
        );
      }
    }
    final Set<String> ruleIds = <String>{};
    for (final EligibilityRule rule in value.eligibilityRules) {
      if (!_stableLocalId(rule.id) || !ruleIds.add(rule.id)) {
        add(
          'eligibility_rule_id_invalid',
          'eligibilityRules',
          'Eligibility rules require unique stable IDs.',
        );
      }
      if (rule.policyRef != null && !_safeReference(rule.policyRef!)) {
        add(
          'eligibility_policy_ref_invalid',
          'eligibilityRules',
          'Eligibility policy references cannot contain secret values.',
        );
      } else if (rule.policyRef != null &&
          !readiness.eligiblePolicyRefs.contains(rule.policyRef)) {
        add(
          'eligibility_policy_not_ready',
          'eligibilityRules',
          'Eligibility policy reference is not available in this runtime.',
        );
      }
    }
    _validateWindow(
      value.registrationWindow,
      fieldId: 'registrationWindow',
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
      add(
        'external_registration_handoff_required',
        'externalBookingUrl',
        'External registration requires a safe HTTPS handoff.',
      );
    }
    if (value.registrationMode == EventRegistrationMode.internal &&
        !readiness.internalRegistration) {
      add(
        'internal_registration_not_ready',
        'registrationMode',
        'Internal registration is configuration-only until ECL-03.',
      );
    }
    if (value.confirmationMode == ConfirmationMode.providerManaged &&
        (value.registrationMode != EventRegistrationMode.external ||
            !readiness.providerManagedConfirmation)) {
      add(
        'provider_confirmation_not_ready',
        'confirmationMode',
        'Provider-managed confirmation requires a verified provider.',
      );
    }
    if (value.confirmationMode == ConfirmationMode.lottery &&
        (value.applicationWindow == null || !readiness.auditableLottery)) {
      add(
        'lottery_not_ready',
        'confirmationMode',
        'Lottery requires an application window and auditable selector.',
      );
    }
    final WaitlistConfiguration? waitlist = value.waitlistPolicy;
    if (waitlist?.enabled == true) {
      final bool finite =
          inventory?.pools.any(
            (pool) => pool.capacityMode == EventCapacityMode.known,
          ) ==
          true;
      if (!finite || !readiness.authoritativeWaitlist) {
        add(
          'waitlist_not_ready',
          'waitlistPolicy',
          'Active waitlist requires finite authoritative inventory lifecycle.',
        );
      }
      if (waitlist!.promotionMode == WaitlistPromotionMode.fifoAutomatic &&
          (waitlist.offerTtlMinutes ?? 0) <= 0) {
        add(
          'waitlist_offer_ttl_required',
          'waitlistOfferTtl',
          'Automatic waitlist requires a positive offer TTL.',
        );
      }
    }
  }

  void _validateWindow(
    EventAccessWindow? value, {
    required String fieldId,
    required EventScheduleMode scheduleMode,
    required List<EventOccurrenceDraft> occurrences,
    required void Function(String, String, String) add,
  }) {
    if (value == null) return;
    if (scheduleMode != EventScheduleMode.oneTime &&
        value.kind != EventAccessWindowKind.occurrenceRelative) {
      add(
        'access_window_must_be_relative',
        fieldId,
        'Multi-date and recurring access windows must be occurrence-relative.',
      );
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
        add(
          'absolute_access_window_invalid',
          fieldId,
          'Absolute access must open before it closes and close before start.',
        );
      }
      if (value.opensBeforeOccurrenceMinutes != null ||
          value.closesBeforeOccurrenceMinutes != null) {
        add(
          'access_window_kind_conflict',
          fieldId,
          'Absolute windows cannot store relative offsets.',
        );
      }
    } else {
      final int opens = value.opensBeforeOccurrenceMinutes ?? 0;
      final int closes = value.closesBeforeOccurrenceMinutes ?? 0;
      if (opens <= 0 || closes <= 0 || opens <= closes) {
        add(
          'relative_access_window_invalid',
          fieldId,
          'Relative opening offset must be greater than closing offset.',
        );
      }
      if (value.opensAtUtc != null || value.closesAtUtc != null) {
        add(
          'access_window_kind_conflict',
          fieldId,
          'Relative windows cannot store absolute timestamps.',
        );
      }
    }
  }

  void _validateInventory(
    EventInventoryConfiguration value, {
    required EventFormat format,
    required EventCapacityMode eventCapacityMode,
    required int? eventCapacity,
    required EventAccessReadiness readiness,
    required void Function(String, String, String) add,
  }) {
    if (value.authority == InventoryAuthority.none &&
        (value.primaryShape != null || value.pools.isNotEmpty)) {
      add(
        'inventory_authority_none_conflict',
        'inventoryAuthority',
        'No inventory authority cannot own shapes or pools.',
      );
    }
    if (value.authority != InventoryAuthority.none &&
        value.primaryShape == null) {
      add(
        'inventory_primary_shape_required',
        'inventoryPrimaryShape',
        'Choose a primary inventory shape.',
      );
    }
    if (value.authority != InventoryAuthority.none && value.pools.isEmpty) {
      add(
        'inventory_pools_required',
        'inventoryPools',
        'Configured inventory authority requires at least one pool.',
      );
    }
    if (value.primaryShape != null &&
        value.additionalShapes.contains(value.primaryShape)) {
      add(
        'inventory_shape_duplicate',
        'inventoryAdditionalShapes',
        'Primary shape cannot be repeated as an additional shape.',
      );
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
        add(
          'inventory_pool_id_invalid',
          'inventoryPools',
          'Inventory pools require unique stable IDs.',
        );
      }
      if (pool.label.trim().isEmpty) {
        add(
          'inventory_pool_label_required',
          'inventoryPools',
          'Every inventory pool needs a public label.',
        );
      }
      if (!configuredShapes.contains(pool.shape)) {
        add(
          'inventory_pool_shape_unconfigured',
          'inventoryPools',
          'Every pool shape must be selected in the inventory configuration.',
        );
      }
      if (pool.capacityMode == EventCapacityMode.known &&
          (pool.capacity ?? 0) <= 0) {
        add(
          'inventory_pool_capacity_required',
          'inventoryPools',
          'Known inventory pool capacity must be positive.',
        );
      }
      if (pool.capacityMode != EventCapacityMode.known &&
          pool.capacity != null) {
        add(
          'inventory_pool_capacity_conflict',
          'inventoryPools',
          'Unknown or unlimited pool cannot store numeric capacity.',
        );
      }
      if ((pool.shape == InventoryShape.participantRoles ||
              pool.shape == InventoryShape.roleBalancedSlots) &&
          pool.roleIds.isEmpty) {
        add(
          'inventory_pool_roles_required',
          'inventoryPools',
          'Role-based pools require neutral role IDs.',
        );
      }
      if (pool.roleIds.toSet().length != pool.roleIds.length ||
          pool.roleIds.any((roleId) => !_safeReference(roleId))) {
        add(
          'inventory_pool_roles_invalid',
          'inventoryPools',
          'Role IDs must be unique neutral identifiers.',
        );
      }
      if ((pool.shape == InventoryShape.zones ||
              pool.shape == InventoryShape.tableInventory) &&
          (pool.zoneRef?.trim().isEmpty ?? true)) {
        add(
          'inventory_pool_zone_required',
          'inventoryPools',
          'Zone and table pools require a stable public reference.',
        );
      }
      if (pool.providerPoolRef != null &&
          !_safeReference(pool.providerPoolRef!)) {
        add(
          'inventory_provider_pool_ref_invalid',
          'inventoryPools',
          'Provider pool references must be opaque identifiers.',
        );
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
        add(
          'inventory_pool_total_exceeds_event_capacity',
          'inventoryPools',
          'Onsite pool capacity exceeds Event capacity.',
        );
      }
      if (onlineTotal > eventCapacity) {
        add(
          'inventory_pool_total_exceeds_event_capacity',
          'inventoryPools',
          'Online pool capacity exceeds Event capacity.',
        );
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
      add(
        'hybrid_onsite_pool_required',
        'inventoryPools',
        'Finite physical capacity requires a bounded onsite pool.',
      );
    }
    final bool assignedSeating =
        value.primaryShape == InventoryShape.assignedSeating ||
        value.additionalShapes.contains(InventoryShape.assignedSeating) ||
        value.pools.any((pool) => pool.shape == InventoryShape.assignedSeating);
    if (assignedSeating && !readiness.assignedSeatingHolds) {
      add(
        'assigned_seating_not_ready',
        'inventoryPrimaryShape',
        'Assigned seating requires an authoritative hold API.',
      );
    }
    if (value.authority == InventoryAuthority.recharge &&
        !readiness.internalRegistration) {
      add(
        'recharge_inventory_not_ready',
        'inventoryAuthority',
        'Recharge inventory is configuration-only until ECL-03.',
      );
    }
    if (value.authority == InventoryAuthority.externalProvider) {
      final bool providerRefsPresent =
          value.pools.isNotEmpty &&
          value.pools.every(
            (pool) => (pool.providerPoolRef?.trim().isNotEmpty ?? false),
          );
      if (!providerRefsPresent || !readiness.externalInventory) {
        add(
          'external_inventory_not_ready',
          'inventoryAuthority',
          'External inventory requires verified provider references and freshness.',
        );
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
