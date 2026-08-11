import '../../domain/entities/scenario_item_draft.dart';
import '../../domain/entities/scenario_object_intake.dart';
import '../../domain/entities/scenario_object_intake_session.dart';

class ScenarioObjectIntakeSessionModel {
  const ScenarioObjectIntakeSessionModel._();

  static Map<String, Object?> toJson(ScenarioObjectIntakeSession value) =>
      <String, Object?>{
        'schemaVersion': ScenarioObjectIntakeSession.currentSchemaVersion,
        'intent': _intentToJson(value.intent),
        'createdAtUtc': value.createdAtUtc.toUtc().toIso8601String(),
        'expiresAtUtc': value.expiresAtUtc.toUtc().toIso8601String(),
        'status': value.status.name,
        'consumedTargetDraftId': value.consumedTargetDraftId,
        'consumedTargetRevision': value.consumedTargetRevision,
      };

  static ScenarioObjectIntakeSession fromJson(Map<String, dynamic> json) {
    final schemaVersion = (json['schemaVersion'] as num?)?.toInt();
    if (schemaVersion != ScenarioObjectIntakeSession.currentSchemaVersion) {
      throw const FormatException('Unsupported Scenario intake session.');
    }
    final statusName = json['status'] as String?;
    final status = ScenarioObjectIntakeSessionStatus.values.where(
      (value) => value.name == statusName,
    );
    if (status.length != 1) {
      throw const FormatException('Invalid Scenario intake session status.');
    }
    final session = ScenarioObjectIntakeSession(
      schemaVersion: schemaVersion!,
      intent: _intentFromJson(_map(json['intent'])),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
      status: status.single,
      consumedTargetDraftId: _nullableString(json['consumedTargetDraftId']),
      consumedTargetRevision: (json['consumedTargetRevision'] as num?)?.toInt(),
    );
    if (!session.expiresAtUtc.isAfter(session.createdAtUtc) ||
        (session.status == ScenarioObjectIntakeSessionStatus.consumed &&
            (session.consumedTargetDraftId == null ||
                session.consumedTargetRevision == null))) {
      throw const FormatException('Invalid Scenario intake session values.');
    }
    return session;
  }

  static Map<String, Object?> _intentToJson(ScenarioObjectIntakeIntent value) =>
      <String, Object?>{
        'contractVersion': value.contractVersion,
        'intentId': value.intentId,
        'requesterId': value.requesterId,
        'sourceSurface': value.sourceSurface.name,
        'candidates': value.candidates
            .map(_candidateToJson)
            .toList(growable: false),
      };

  static ScenarioObjectIntakeIntent _intentFromJson(Map<String, dynamic> json) {
    final surface = ScenarioIntakeSourceSurface.values.where(
      (value) => value.name == json['sourceSurface'],
    );
    final candidates = json['candidates'];
    if (surface.length != 1 || candidates is! List || candidates.isEmpty) {
      throw const FormatException('Invalid Scenario intake intent.');
    }
    return ScenarioObjectIntakeIntent(
      contractVersion: (json['contractVersion'] as num).toInt(),
      intentId: json['intentId'] as String,
      requesterId: json['requesterId'] as String,
      sourceSurface: surface.single,
      candidates: candidates
          .map((value) => _candidateFromJson(_map(value)))
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _candidateToJson(
    ScenarioIntakeCandidate value,
  ) => <String, Object?>{
    'objectId': value.ref.objectId,
    'objectType': value.ref.objectType.name,
    'sourceRevision': value.sourceRevision,
    'sourceStatus': value.sourceStatus.name,
    'snapshot': <String, Object?>{
      'title': value.snapshot.title,
      'coverMediaId': value.snapshot.coverMediaId,
      'publisherId': value.snapshot.publisherId,
      'sourceLocationVersion': value.snapshot.sourceLocationVersion,
      'durationMinutes': value.snapshot.durationMinutes,
      'distanceM': value.snapshot.distanceM,
      'checkedAtUtc': value.snapshot.checkedAtUtc?.toUtc().toIso8601String(),
    },
    'location': value.location == null
        ? null
        : <String, Object?>{
            'title': value.location!.title,
            'latitude': value.location!.point.latitude,
            'longitude': value.location!.point.longitude,
            'address': value.location!.address,
            'marketId': value.location!.marketId,
            'regionId': value.location!.regionId,
            'timezoneId': value.location!.timezoneId,
            'disclosure': value.location!.disclosure.name,
          },
    'schedule': _scheduleToJson(value.schedule),
  };

  static ScenarioIntakeCandidate _candidateFromJson(Map<String, dynamic> json) {
    final objectType = ScenarioCatalogObjectType.values.where(
      (value) => value.name == json['objectType'],
    );
    final sourceStatus = ScenarioSourceStatus.values.where(
      (value) => value.name == json['sourceStatus'],
    );
    if (objectType.length != 1 || sourceStatus.length != 1) {
      throw const FormatException('Invalid Scenario intake candidate enums.');
    }
    final snapshot = _map(json['snapshot']);
    final location = json['location'] == null ? null : _map(json['location']);
    final disclosure = location == null
        ? const <ScenarioLocationDisclosure>[]
        : ScenarioLocationDisclosure.values
              .where((value) => value.name == location['disclosure'])
              .toList(growable: false);
    if (location != null && disclosure.length != 1) {
      throw const FormatException('Invalid intake location disclosure.');
    }
    return ScenarioIntakeCandidate(
      ref: ScenarioObjectRef(
        objectId: json['objectId'] as String,
        objectType: objectType.single,
      ),
      sourceRevision: (json['sourceRevision'] as num?)?.toInt(),
      snapshot: ScenarioObjectSnapshotDraft(
        title: snapshot['title'] as String,
        coverMediaId: _nullableString(snapshot['coverMediaId']),
        publisherId: _nullableString(snapshot['publisherId']),
        sourceLocationVersion: (snapshot['sourceLocationVersion'] as num?)
            ?.toInt(),
        durationMinutes: (snapshot['durationMinutes'] as num?)?.toInt(),
        distanceM: (snapshot['distanceM'] as num?)?.toDouble(),
        checkedAtUtc: _nullableDateTime(snapshot['checkedAtUtc']),
      ),
      sourceStatus: sourceStatus.single,
      location: location == null
          ? null
          : ScenarioIntakeLocationSnapshot(
              title: location['title'] as String,
              point: ScenarioGeoPointDraft(
                latitude: (location['latitude'] as num).toDouble(),
                longitude: (location['longitude'] as num).toDouble(),
              ),
              address: _nullableString(location['address']),
              marketId: _nullableString(location['marketId']),
              regionId: _nullableString(location['regionId']),
              timezoneId: _nullableString(location['timezoneId']),
              disclosure: disclosure.single,
            ),
      schedule: _scheduleFromJson(json['schedule']),
    );
  }

  static Map<String, Object?>? _scheduleToJson(ScenarioScheduleDraft? value) {
    if (value == null) return null;
    final planned = value.planned;
    return <String, Object?>{
      'mode': value.mode.name,
      'plannedType': planned is ScenarioTemplatePlannedTimeDraft
          ? 'template'
          : 'dated',
      'planned': planned is ScenarioTemplatePlannedTimeDraft
          ? <String, Object?>{
              'startDayIndex': planned.startDayIndex,
              'preferredStart': _timeToJson(planned.preferredStart),
              'windowStart': _timeToJson(planned.windowStart),
              'windowEnd': _timeToJson(planned.windowEnd),
              'windowEndDayOffset': planned.windowEndDayOffset,
              'endDayIndex': planned.endDayIndex,
              'preferredEnd': _timeToJson(planned.preferredEnd),
              'startTimezoneId': planned.startTimezoneId,
              'endTimezoneId': planned.endTimezoneId,
            }
          : <String, Object?>{
              'fixedStartAtUtc': (planned as ScenarioDatedPlannedTimeDraft)
                  .fixedStartAtUtc
                  ?.toUtc()
                  .toIso8601String(),
              'fixedEndAtUtc': planned.fixedEndAtUtc?.toUtc().toIso8601String(),
              'windowStart': _timeToJson(planned.windowStart),
              'windowEnd': _timeToJson(planned.windowEnd),
              'windowEndDayOffset': planned.windowEndDayOffset,
              'startTimezoneId': planned.startTimezoneId,
              'endTimezoneId': planned.endTimezoneId,
            },
    };
  }

  static ScenarioScheduleDraft? _scheduleFromJson(Object? value) {
    if (value == null) return null;
    final json = _map(value);
    final modes = ScenarioTimeMode.values.where(
      (mode) => mode.name == json['mode'],
    );
    if (modes.length != 1) {
      throw const FormatException('Invalid intake schedule mode.');
    }
    final plannedJson = _map(json['planned']);
    final plannedType = json['plannedType'];
    final ScenarioPlannedTimeDraft planned = switch (plannedType) {
      'template' => ScenarioTemplatePlannedTimeDraft(
        startDayIndex: (plannedJson['startDayIndex'] as num).toInt(),
        preferredStart: _timeFromJson(plannedJson['preferredStart']),
        windowStart: _timeFromJson(plannedJson['windowStart']),
        windowEnd: _timeFromJson(plannedJson['windowEnd']),
        windowEndDayOffset:
            (plannedJson['windowEndDayOffset'] as num?)?.toInt() ?? 0,
        endDayIndex: (plannedJson['endDayIndex'] as num?)?.toInt(),
        preferredEnd: _timeFromJson(plannedJson['preferredEnd']),
        startTimezoneId: _nullableString(plannedJson['startTimezoneId']),
        endTimezoneId: _nullableString(plannedJson['endTimezoneId']),
      ),
      'dated' => ScenarioDatedPlannedTimeDraft(
        fixedStartAtUtc: _nullableDateTime(plannedJson['fixedStartAtUtc']),
        fixedEndAtUtc: _nullableDateTime(plannedJson['fixedEndAtUtc']),
        windowStart: _timeFromJson(plannedJson['windowStart']),
        windowEnd: _timeFromJson(plannedJson['windowEnd']),
        windowEndDayOffset:
            (plannedJson['windowEndDayOffset'] as num?)?.toInt() ?? 0,
        startTimezoneId: _nullableString(plannedJson['startTimezoneId']),
        endTimezoneId: _nullableString(plannedJson['endTimezoneId']),
      ),
      _ => throw const FormatException('Invalid intake planned time.'),
    };
    return ScenarioScheduleDraft(mode: modes.single, planned: planned);
  }

  static Map<String, Object?>? _timeToJson(ScenarioLocalTimeDraft? value) =>
      value == null
      ? null
      : <String, Object?>{'hour': value.hour, 'minute': value.minute};

  static ScenarioLocalTimeDraft? _timeFromJson(Object? value) {
    if (value == null) return null;
    final json = _map(value);
    return ScenarioLocalTimeDraft(
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) throw const FormatException('Expected JSON object.');
    return Map<String, dynamic>.from(value);
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Expected string.');
    return value;
  }

  static DateTime? _nullableDateTime(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
}
