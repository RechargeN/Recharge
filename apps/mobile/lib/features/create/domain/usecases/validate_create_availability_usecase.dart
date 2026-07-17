import '../entities/create_availability.dart';
import '../entities/create_draft_entity.dart';

class ValidateCreateAvailabilityUseCase {
  const ValidateCreateAvailabilityUseCase();

  Map<String, String> call(CreateDraftEntity draft) {
    final Map<String, String> errors = <String, String>{};
    if (draft.bufferBeforeMinutes < 0 || draft.bufferAfterMinutes < 0) {
      errors['availabilityBuffers'] = 'Buffers cannot be negative';
    }
    if (draft.allowsPartialAttendance &&
        (draft.minimumVisitDurationMinutes == null ||
            draft.minimumVisitDurationMinutes! <= 0)) {
      errors['minimumVisitDurationMinutes'] =
          'Minimum visit duration is required for partial attendance';
    }
    switch (draft.availabilityKind) {
      case CreateAvailabilityKind.eventSlots:
        if (draft.scheduleSlots.isEmpty) {
          errors['scheduleSlots'] = 'Add at least one schedule slot';
        }
        if (draft.openingHours.isNotEmpty) {
          errors['openingHours'] = 'Slots and opening hours cannot be combined';
        }
      case CreateAvailabilityKind.openingHours:
        if (draft.openingHours.isEmpty) {
          errors['openingHours'] = 'Add at least one opening-hours rule';
        }
        if (draft.scheduleSlots.isNotEmpty) {
          errors['scheduleSlots'] =
              'Slots and opening hours cannot be combined';
        }
      case CreateAvailabilityKind.none:
        if (draft.scheduleSlots.isNotEmpty || draft.openingHours.isNotEmpty) {
          errors['availabilityKind'] =
              'Availability data must be empty when kind is none';
        }
    }
    for (final CreateTimeSlotDraft slot in draft.scheduleSlots) {
      if (!slot.startAtUtc.isBefore(slot.endAtUtc)) {
        errors['scheduleSlots'] = 'Slot end must be after start';
      }
    }
    for (final CreateOpeningHoursDraftRule rule in draft.openingHours) {
      if ((rule.dayOfWeek == null) == (rule.exceptionDateIso == null)) {
        errors['openingHours'] =
            'Each rule needs either weekday or exception date';
      }
      if (rule.dayOfWeek != null &&
          (rule.dayOfWeek! < 1 || rule.dayOfWeek! > 7)) {
        errors['openingHours'] = 'Weekday must be from 1 to 7';
      }
      if (!rule.isClosedAllDay &&
          (rule.openMinutesSinceLocalMidnight == null ||
              rule.closeMinutesSinceLocalMidnight == null)) {
        errors['openingHours'] = 'Open and close times are required';
      }
    }
    return errors;
  }
}
