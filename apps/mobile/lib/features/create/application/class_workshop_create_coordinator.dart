import '../domain/entities/class_workshop_draft_data.dart';
import '../domain/entities/class_workshop_validation_issue.dart';
import '../domain/entities/create_availability.dart';
import '../domain/entities/create_draft_entity.dart';
import '../domain/usecases/build_class_workshop_content_body.dart';
import '../domain/usecases/validate_class_workshop_draft_usecase.dart';

/// Coordinates `ClassWorkshopDraftData` inside the common Create draft
/// envelope (D3.6, CW-V1), like `SessionCreateCoordinator`. Presentation sends
/// intents; the rules live here and in the domain use cases.
class ClassWorkshopCreateCoordinator {
  const ClassWorkshopCreateCoordinator({
    required ClassWorkshopContentBodyMapper mapper,
    ValidateClassWorkshopDraftUseCase validateDraft =
        const ValidateClassWorkshopDraftUseCase(),
  }) : _mapper = mapper,
       _validateDraft = validateDraft;

  final ClassWorkshopContentBodyMapper _mapper;
  final ValidateClassWorkshopDraftUseCase _validateDraft;

  /// Null for a draft whose raw typed payload this version cannot read: it
  /// stays read-only instead of being replaced by defaults (spec §7.4).
  ClassWorkshopDraftData? ensureData(
    CreateDraftEntity draft, {
    required String timezoneId,
  }) {
    final ClassWorkshopDraftData? data = draft.classWorkshopData;
    if (data != null) return data;
    if (draft.sectionData.containsKey(
      ClassWorkshopContentBodyMapper.persistenceSection,
    )) {
      return null;
    }
    return ClassWorkshopDraftData.defaults(timezoneId: timezoneId);
  }

  /// Applies the typed data and keeps the generic envelope in step: the first
  /// declared class drives the shared start/end used by the local list views.
  CreateDraftEntity apply(
    CreateDraftEntity draft,
    ClassWorkshopDraftData data,
  ) {
    final ClassWorkshopDraftData normalized = data.copyWith(
      occurrences: _sorted(_withValidFolds(data)),
    );
    final List<({DateTime start, DateTime end})> utc =
        <({DateTime start, DateTime end})>[];
    for (final ClassWorkshopOccurrence item in normalized.occurrences) {
      final ({DateTime start, DateTime end})? value = _mapper.utcOf(
        normalized,
        item,
      );
      if (value != null) utc.add(value);
    }
    return draft.copyWith(
      classWorkshopData: normalized,
      availabilityKind: CreateAvailabilityKind.eventSlots,
      startDateTimeUtc: utc.isEmpty ? null : utc.first.start,
      clearStartDateTimeUtc: utc.isEmpty,
      endDateTimeUtc: utc.isEmpty ? null : utc.last.end,
      clearEndDateTimeUtc: utc.isEmpty,
      timezone: normalized.timezoneId,
      updatedAtUtc: DateTime.now().toUtc(),
    );
  }

  List<ClassWorkshopValidationIssue> validate(
    CreateDraftEntity draft, {
    required bool rightsConfirmed,
  }) => _validateDraft(
    draft,
    pinConfirmed: ClassWorkshopContentBodyMapper.pinConfirmed(draft),
    rightsConfirmed: rightsConfirmed,
  );

  bool isAmbiguous(ClassWorkshopDraftData data, ClassWorkshopOccurrence item) =>
      _mapper.isAmbiguous(
        data.timezoneId,
        item.localDate,
        item.startMinuteLocal,
      ) ||
      _mapper.isAmbiguous(data.timezoneId, item.localDate, item.endMinuteLocal);

  /// True when the wall time of the class cannot be placed on the UTC timeline
  /// (DST gap, unchosen overlap or an unknown zone).
  bool hasUnresolvedTime(
    ClassWorkshopDraftData data,
    ClassWorkshopOccurrence item,
  ) => _mapper.utcOf(data, item) == null;

  ClassWorkshopDraftData addOccurrence(
    ClassWorkshopDraftData data, {
    required String id,
    required String localDate,
    required int startMinuteLocal,
    required int endMinuteLocal,
  }) => data.copyWith(
    occurrences: <ClassWorkshopOccurrence>[
      ...data.occurrences,
      ClassWorkshopOccurrence(
        id: id,
        localDate: localDate,
        startMinuteLocal: startMinuteLocal,
        endMinuteLocal: endMinuteLocal,
      ),
    ],
  );

  ClassWorkshopDraftData removeOccurrence(
    ClassWorkshopDraftData data,
    String id,
  ) => data.copyWith(
    occurrences: data.occurrences
        .where((ClassWorkshopOccurrence item) => item.id != id)
        .toList(growable: false),
  );

  ClassWorkshopDraftData setFold(
    ClassWorkshopDraftData data,
    String id,
    ClassWorkshopFold? fold,
  ) => data.copyWith(
    occurrences: <ClassWorkshopOccurrence>[
      for (final ClassWorkshopOccurrence item in data.occurrences)
        item.id == id
            ? item.copyWith(fold: fold, clearFold: fold == null)
            : item,
    ],
  );

  /// Free-text lines → trimmed, de-duplicated, ordered items.
  static List<String> linesToItems(String text) {
    final List<String> items = <String>[];
    for (final String line in text.split('\n')) {
      final String value = line.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (value.isNotEmpty && !items.contains(value)) items.add(value);
    }
    return List<String>.unmodifiable(items);
  }

  /// Programme titles keep the local id of an unchanged position so the wire
  /// id of a step stays stable across edits.
  static List<ClassWorkshopModule> titlesToModules(
    List<ClassWorkshopModule> current,
    String text,
    String Function() nextId,
  ) {
    final List<String> titles = linesToItems(text);
    return List<ClassWorkshopModule>.unmodifiable(<ClassWorkshopModule>[
      for (final (int index, String title) in titles.indexed)
        ClassWorkshopModule(
          id: index < current.length ? current[index].id : nextId(),
          title: title,
        ),
    ]);
  }

  /// A fold is kept only where the wall time really is ambiguous.
  List<ClassWorkshopOccurrence> _withValidFolds(ClassWorkshopDraftData data) =>
      <ClassWorkshopOccurrence>[
        for (final ClassWorkshopOccurrence item in data.occurrences)
          item.fold != null && !isAmbiguous(data, item)
              ? item.copyWith(clearFold: true)
              : item,
      ];

  static List<ClassWorkshopOccurrence> _sorted(
    List<ClassWorkshopOccurrence> items,
  ) =>
      List<ClassWorkshopOccurrence>.of(items)
        ..sort((ClassWorkshopOccurrence a, ClassWorkshopOccurrence b) {
          final int byDate = a.localDate.compareTo(b.localDate);
          return byDate != 0
              ? byDate
              : a.startMinuteLocal.compareTo(b.startMinuteLocal);
        });
}
