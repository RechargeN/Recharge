import 'dart:math';

import 'package:recharge/features/create/data/models/scenario_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/create_draft_entity.dart';
import 'package:uuid/uuid.dart';

/// A new Scenario id in the server's ULID shape (I2 `scenarioId`).
String newScenarioId() {
  const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  final Random random = Random.secure();
  return '0${List<String>.generate(25, (_) => alphabet[random.nextInt(32)]).join()}';
}

/// A Create Scenario with two own public places and a coffee break in Riga:
/// the shape the Scenario Builder stores and I2 syncs (mapper JSON).
CreateDraftEntity userScenarioDraft({
  required String userId,
  required String coverPath,
  String? scenarioId,
  String title = 'Riga old town walk',
}) {
  String id() => const Uuid().v4();
  final String day = id(), a = id(), b = id(), c = id(), l1 = id(), l2 = id();
  Map<String, Object?> item(
    String itemId,
    String kind,
    Map<String, Object?> source,
    String? location,
  ) => <String, Object?>{
    'id': itemId,
    'dayId': day,
    'startLocationId': location,
    'endLocationId': location,
    'kind': kind,
    'source': source,
    'sourceStatus': 'ready',
    'schedule': <String, Object?>{
      'mode': 'flexible',
      'planned': <String, Object?>{
        'type': 'template',
        'startDayIndex': 0,
        'preferredStart': <String, Object?>{'hour': 10, 'minute': 0},
        'windowEndDayOffset': 0,
      },
    },
    'durationMinutes': 60,
    'cost': <String, Object?>{'components': <Object?>[]},
    'role': 'mandatory',
    'selected': false,
    'publicNote': '',
  };
  Map<String, Object?> location(
    String locationId,
    String name,
    double latitude,
    double longitude,
  ) => <String, Object?>{
    'id': locationId,
    'point': <String, Object?>{'latitude': latitude, 'longitude': longitude},
    'title': name,
    'marketId': 'LV',
    'timezoneId': 'Europe/Riga',
    'disclosure': 'public',
  };
  final Map<String, Object?> json = <String, Object?>{
    'schemaVersion': 2,
    'revision': 1,
    'format': 'day',
    'dateMode': 'template',
    'defaultTimezoneId': 'Europe/Riga',
    'displayCurrencyCode': 'EUR',
    'party': <String, Object?>{'peopleCount': 2, 'kind': 'couple'},
    'days': <Object?>[
      <String, Object?>{
        'id': day,
        'title': 'Old town',
        'dayIndex': 0,
        'timezoneId': 'Europe/Riga',
        'itemIds': <String>[a, b, c],
      },
    ],
    'locations': <Object?>[
      location(l1, 'Town Hall Square', 56.9474, 24.1063),
      location(l2, 'Dome cathedral', 56.949, 24.104),
    ],
    'items': <Object?>[
      item(a, 'visit', <String, Object?>{
        'type': 'custom_location',
        'locationId': l1,
      }, l1),
      item(b, 'visit', <String, Object?>{
        'type': 'custom_location',
        'locationId': l2,
      }, l2),
      item(c, 'time_block', <String, Object?>{
        'type': 'time_block',
        'title': 'Coffee break',
      }, null),
    ],
    'unscheduledItemIds': <String>[],
    'legs': <Object?>[],
  };
  return CreateDraftEntity.defaults(
    organizerId: userId,
    organizerEmail: 'creator@example.org',
    organizerName: 'Creator',
    marketCityId: 'riga',
    timezone: 'Europe/Riga',
    country: 'LV',
    city: 'Riga',
    currency: 'EUR',
  ).copyWith(
    id: scenarioId ?? newScenarioId(),
    objectType: CreateObjectType.scenario,
    clearEventData: true,
    title: title,
    shortDescription: 'A short walk through the Riga old town',
    fullDescription:
        'Two old town places and a coffee break, as a reusable template.',
    media: MediaEntity(coverImage: coverPath, gallery: const <String>[]),
    scenarioData: ScenarioDraftMapper.fromJson(json),
  );
}
