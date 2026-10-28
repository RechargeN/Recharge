import '../../../../core/localization/l10n_context.dart';
import '../../application/create_message_ids.dart';
import '../../application/state/create_notice.dart';
import '../../domain/entities/class_workshop_validation_issue.dart';
import '../../domain/entities/collection_validation_issue.dart';
import '../../domain/entities/event_validation_issue.dart';
import '../../domain/entities/find_people_validation_issue.dart';
import '../../domain/entities/quick_plan_conversion.dart';
import 'validation_texts.dart';

/// L4: the one place that turns Create codes and message ids into text.
/// Controllers, coordinators and validators keep codes and numbers; an
/// unknown code shows a safe general text, never the code itself.
abstract final class CreateTexts {
  /// A `CreateState.message` code (see `CreateNotice`).
  static String notice(AppLocalizations l10n, String code) =>
      code == CreateNotice.placeGalleryLimit
      ? l10n.createPlaceGalleryLimit(CreateNotice.placeGalleryMaxPhotos)
      : l10n.createNotice(code);

  /// A field-error id from `validationErrors` or a section `errorIdFor`.
  static String fieldError(AppLocalizations l10n, String id) {
    final (String prefix, String code) = _split(id);
    return switch (prefix) {
      'place.validation.' => l10n.placeValidationIssue(code),
      'activity.validation.' => l10n.activityValidationIssue(code),
      'rental.validation.' => l10n.rentalValidationIssue(code),
      CreateMessageIds.event => l10n.eventValidationIssue(code),
      CreateMessageIds.eventAdmissionPreset => l10n.eventAdmissionPresetIssue(
        code,
      ),
      CreateMessageIds.findPeople => l10n.findPeopleValidationIssue(code),
      CreateMessageIds.scenario => l10n.scenarioValidationIssue(code),
      CreateMessageIds.collection => l10n.collectionValidationIssue(code),
      CreateMessageIds.classWorkshop => l10n.classWorkshopValidationIssue(code),
      CreateMessageIds.availability => l10n.createAvailabilityIssue(code),
      CreateMessageIds.form => l10n.createFieldIssue(code),
      _ when id.startsWith('session_') => l10n.sessionValidationIssue(id),
      _ when id.startsWith('validation') => validationMessageText(l10n, id),
      _ => l10n.createFieldIssue(''),
    };
  }

  static (String, String) _split(String id) {
    for (final String prefix in const <String>[
      'place.validation.',
      'activity.validation.',
      'rental.validation.',
      CreateMessageIds.event,
      CreateMessageIds.eventAdmissionPreset,
      CreateMessageIds.findPeople,
      CreateMessageIds.scenario,
      CreateMessageIds.collection,
      CreateMessageIds.classWorkshop,
      CreateMessageIds.availability,
      CreateMessageIds.form,
    ]) {
      if (id.startsWith(prefix)) return (prefix, id.substring(prefix.length));
    }
    return ('', id);
  }

  static String event(AppLocalizations l10n, EventValidationIssue issue) =>
      fieldError(l10n, eventIssueMessageId(issue));

  static String findPeople(
    AppLocalizations l10n,
    FindPeopleValidationIssue issue,
  ) {
    final int? min = issue.params['min'];
    final int? max = issue.params['max'];
    if (issue.code.endsWith('_length') && max != null) {
      return min == null
          ? l10n.findPeopleMaxLengthIssue(issue.fieldId, max)
          : l10n.findPeopleLengthIssue(issue.fieldId, min, max);
    }
    return l10n.findPeopleValidationIssue(issue.code);
  }

  static String collection(
    AppLocalizations l10n,
    CollectionValidationIssue issue,
  ) {
    final int? count = issue.params['count'];
    final int? max = issue.params['max'];
    return switch (issue.code) {
      'min_items' when count != null => l10n.collectionMinItemsIssue(count),
      'item_count_high' when count != null => l10n.collectionItemCountHighIssue(
        count,
      ),
      'curator_note_length' when max != null =>
        l10n.collectionCuratorNoteLengthIssue(max),
      _ => l10n.collectionValidationIssue(issue.code),
    };
  }

  static String classWorkshop(
    AppLocalizations l10n,
    ClassWorkshopValidationIssue issue,
  ) => switch (issue.params['single']) {
    final int single when issue.code == 'occurrences' =>
      l10n.classWorkshopOccurrencesIssue(single == 1 ? 'single' : 'series'),
    _ => l10n.classWorkshopValidationIssue(issue.code),
  };

  static String scenario(AppLocalizations l10n, String code) =>
      l10n.scenarioValidationIssue(code);

  static String quickPlanConversion(
    AppLocalizations l10n,
    QuickPlanConversionIssue issue,
  ) => l10n.quickPlanConversionIssue(issue.code.name);
}
