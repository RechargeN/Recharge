import 'scenario_budget_draft.dart';

enum ScenarioItemKind {
  visit,
  event,
  activity,
  route,
  bookableSession,
  stay,
  plannedTransport,
  timeBlock,
}

enum ScenarioItemRole { mandatory, optional, alternative }

enum ScenarioSourceStatus { ready, stale, unresolved, unavailable }

enum ScenarioCatalogObjectType {
  event,
  place,
  activity,
  route,
  bookableSession,
}

enum ScenarioLocationDisclosure { private, approximate, public }

enum ScenarioTimeMode { fixed, window, flexible }

enum ScenarioPlannedTransportKind {
  bus,
  train,
  tram,
  trolleybus,
  ferry,
  flight,
  other,
}

enum ScenarioScheduleFreshness { current, stale, unknown, notApplicable }

class ScenarioLocalDateDraft {
  const ScenarioLocalDateDraft({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  String get iso8601 =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  bool get isValid {
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) {
      return false;
    }
    final DateTime candidate = DateTime.utc(year, month, day);
    return candidate.year == year &&
        candidate.month == month &&
        candidate.day == day;
  }
}

class ScenarioLocalTimeDraft {
  const ScenarioLocalTimeDraft({required this.hour, required this.minute});

  final int hour;
  final int minute;

  int get minuteOfDay => hour * 60 + minute;

  String get hhmm =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';

  bool get isValid => hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

class ScenarioGeoPointDraft {
  const ScenarioGeoPointDraft({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

class ScenarioObjectSnapshotDraft {
  const ScenarioObjectSnapshotDraft({
    required this.title,
    this.coverMediaId,
    this.publisherId,
    this.sourceLocationVersion,
    this.durationMinutes,
    this.distanceM,
    this.checkedAtUtc,
  });

  final String title;
  final String? coverMediaId;
  final String? publisherId;
  final int? sourceLocationVersion;
  final int? durationMinutes;
  final double? distanceM;
  final DateTime? checkedAtUtc;
}

sealed class ScenarioItemSourceDraft {
  const ScenarioItemSourceDraft();
}

class ScenarioCatalogObjectSourceDraft extends ScenarioItemSourceDraft {
  const ScenarioCatalogObjectSourceDraft({
    required this.objectId,
    required this.objectType,
    required this.snapshot,
  });

  final String objectId;
  final ScenarioCatalogObjectType objectType;
  final ScenarioObjectSnapshotDraft snapshot;
}

class ScenarioCustomLocationSourceDraft extends ScenarioItemSourceDraft {
  const ScenarioCustomLocationSourceDraft({required this.locationId});

  final String locationId;
}

class ScenarioScheduleSnapshotDraft {
  const ScenarioScheduleSnapshotDraft({
    required this.freshness,
    this.providerCode,
    this.serviceDate,
    this.feedUpdatedAtUtc,
    this.retrievedAtUtc,
    this.carrierName,
    this.serviceLabel,
    this.originLabel,
    this.destinationLabel,
    this.plannedDeparture,
    this.plannedArrival,
    this.sourceUrl,
  });

  final ScenarioScheduleFreshness freshness;
  final String? providerCode;
  final ScenarioLocalDateDraft? serviceDate;
  final DateTime? feedUpdatedAtUtc;
  final DateTime? retrievedAtUtc;
  final String? carrierName;
  final String? serviceLabel;
  final String? originLabel;
  final String? destinationLabel;
  final ScenarioLocalTimeDraft? plannedDeparture;
  final ScenarioLocalTimeDraft? plannedArrival;
  final String? sourceUrl;
}

class ScenarioPlannedTransportSourceDraft extends ScenarioItemSourceDraft {
  const ScenarioPlannedTransportSourceDraft({
    this.kind = ScenarioPlannedTransportKind.other,
    this.carrierName,
    this.publicServiceLabel,
    this.scheduleSnapshot,
  });

  final ScenarioPlannedTransportKind kind;
  final String? carrierName;
  final String? publicServiceLabel;
  final ScenarioScheduleSnapshotDraft? scheduleSnapshot;
}

class ScenarioTimeBlockSourceDraft extends ScenarioItemSourceDraft {
  const ScenarioTimeBlockSourceDraft({required this.title, this.categoryId});

  final String title;
  final String? categoryId;
}

sealed class ScenarioPlannedTimeDraft {
  const ScenarioPlannedTimeDraft();
}

class ScenarioTemplatePlannedTimeDraft extends ScenarioPlannedTimeDraft {
  const ScenarioTemplatePlannedTimeDraft({
    required this.startDayIndex,
    this.preferredStart,
    this.windowStart,
    this.windowEnd,
    this.windowEndDayOffset = 0,
    this.endDayIndex,
    this.preferredEnd,
    this.startTimezoneId,
    this.endTimezoneId,
  });

  final int startDayIndex;
  final ScenarioLocalTimeDraft? preferredStart;
  final ScenarioLocalTimeDraft? windowStart;
  final ScenarioLocalTimeDraft? windowEnd;
  final int windowEndDayOffset;
  final int? endDayIndex;
  final ScenarioLocalTimeDraft? preferredEnd;
  final String? startTimezoneId;
  final String? endTimezoneId;
}

class ScenarioDatedPlannedTimeDraft extends ScenarioPlannedTimeDraft {
  const ScenarioDatedPlannedTimeDraft({
    this.fixedStartAtUtc,
    this.fixedEndAtUtc,
    this.windowStart,
    this.windowEnd,
    this.windowEndDayOffset = 0,
    this.startTimezoneId,
    this.endTimezoneId,
  });

  final DateTime? fixedStartAtUtc;
  final DateTime? fixedEndAtUtc;
  final ScenarioLocalTimeDraft? windowStart;
  final ScenarioLocalTimeDraft? windowEnd;
  final int windowEndDayOffset;
  final String? startTimezoneId;
  final String? endTimezoneId;
}

sealed class ScenarioCalculatedTimeDraft {
  const ScenarioCalculatedTimeDraft();
}

class ScenarioTemplateCalculatedTimeDraft extends ScenarioCalculatedTimeDraft {
  const ScenarioTemplateCalculatedTimeDraft({
    required this.startDayIndex,
    required this.start,
    required this.endDayIndex,
    required this.end,
  });

  final int startDayIndex;
  final ScenarioLocalTimeDraft start;
  final int endDayIndex;
  final ScenarioLocalTimeDraft end;
}

class ScenarioDatedCalculatedTimeDraft extends ScenarioCalculatedTimeDraft {
  const ScenarioDatedCalculatedTimeDraft({
    required this.startAtUtc,
    required this.endAtUtc,
  });

  final DateTime startAtUtc;
  final DateTime endAtUtc;
}

class ScenarioScheduleDraft {
  const ScenarioScheduleDraft({
    required this.mode,
    required this.planned,
    this.calculated,
  });

  final ScenarioTimeMode mode;
  final ScenarioPlannedTimeDraft planned;
  final ScenarioCalculatedTimeDraft? calculated;
}

class ScenarioLocationDraft {
  const ScenarioLocationDraft({
    required this.id,
    required this.point,
    required this.title,
    required this.disclosure,
    this.address,
    this.marketId,
    this.regionId,
    this.timezoneId,
    this.sourceObjectId,
    this.sourceObjectType,
  });

  final String id;
  final ScenarioGeoPointDraft point;
  final String title;
  final String? address;
  final String? marketId;
  final String? regionId;
  final String? timezoneId;
  final ScenarioLocationDisclosure disclosure;
  final String? sourceObjectId;
  final ScenarioCatalogObjectType? sourceObjectType;
}

class ScenarioItemDraft {
  const ScenarioItemDraft({
    required this.id,
    required this.kind,
    required this.source,
    required this.sourceStatus,
    required this.schedule,
    required this.cost,
    required this.orderLocked,
    required this.timeLocked,
    required this.role,
    required this.selected,
    required this.publicNote,
    this.dayId,
    this.startLocationId,
    this.endLocationId,
    this.durationMinutes,
    this.alternativeGroupId,
  });

  final String id;
  final String? dayId;
  final String? startLocationId;
  final String? endLocationId;
  final ScenarioItemKind kind;
  final ScenarioItemSourceDraft source;
  final ScenarioSourceStatus sourceStatus;
  final ScenarioScheduleDraft schedule;
  final int? durationMinutes;
  final ScenarioCostDraft cost;
  final bool orderLocked;
  final bool timeLocked;
  final ScenarioItemRole role;
  final String? alternativeGroupId;
  final bool selected;
  final String publicNote;

  bool get isRoleActive {
    return switch (role) {
      ScenarioItemRole.mandatory => true,
      ScenarioItemRole.optional || ScenarioItemRole.alternative => selected,
    };
  }
}
