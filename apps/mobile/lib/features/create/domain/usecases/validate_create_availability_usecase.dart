import '../entities/create_availability.dart';
import '../entities/create_draft_entity.dart';

class ValidateCreateAvailabilityUseCase {
  const ValidateCreateAvailabilityUseCase();

  /// Field id → stable message id (`availability.validation.<code>`); the
  /// UI resolves the id to text (L4).
  Map<String, String> call(CreateDraftEntity draft) {
    final Map<String, String> errors = <String, String>{};
    if (draft.bufferBeforeMinutes < 0 || draft.bufferAfterMinutes < 0) {
      errors['availabilityBuffers'] =
          'availability.validation.buffers_negative';
    }
    if (draft.allowsPartialAttendance &&
        (draft.minimumVisitDurationMinutes == null ||
            draft.minimumVisitDurationMinutes! <= 0)) {
      errors['minimumVisitDurationMinutes'] =
          'availability.validation.minimum_visit_required';
    }
    switch (draft.availabilityKind) {
      case CreateAvailabilityKind.eventSlots:
        if (draft.scheduleSlots.isEmpty) {
          errors['scheduleSlots'] = 'availability.validation.slots_required';
        }
        if (draft.openingHours.isNotEmpty) {
          errors['openingHours'] =
              'availability.validation.slots_hours_conflict';
        }
      case CreateAvailabilityKind.openingHours:
        if (draft.openingHours.isEmpty) {
          errors['openingHours'] =
              'availability.validation.opening_hours_required';
        }
        if (draft.scheduleSlots.isNotEmpty) {
          errors['scheduleSlots'] =
              'availability.validation.slots_hours_conflict';
        }
      case CreateAvailabilityKind.none:
        if (draft.scheduleSlots.isNotEmpty || draft.openingHours.isNotEmpty) {
          errors['availabilityKind'] =
              'availability.validation.availability_not_empty';
        }
    }
    for (final CreateTimeSlotDraft slot in draft.scheduleSlots) {
      if (!slot.startAtUtc.isBefore(slot.endAtUtc)) {
        errors['scheduleSlots'] = 'availability.validation.slot_order_invalid';
      }
    }
    for (final CreateOpeningHoursDraftRule rule in draft.openingHours) {
      if ((rule.dayOfWeek == null) == (rule.exceptionDateIso == null)) {
        errors['openingHours'] =
            'availability.validation.opening_rule_target_invalid';
      }
      if (rule.dayOfWeek != null &&
          (rule.dayOfWeek! < 1 || rule.dayOfWeek! > 7)) {
        errors['openingHours'] =
            'availability.validation.opening_weekday_invalid';
      }
      if (!rule.isClosedAllDay &&
          (rule.openMinutesSinceLocalMidnight == null ||
              rule.closeMinutesSinceLocalMidnight == null)) {
        errors['openingHours'] =
            'availability.validation.opening_times_required';
      }
    }
    return errors;
  }
}
