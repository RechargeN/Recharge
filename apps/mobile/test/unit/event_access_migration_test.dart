import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/features/create/data/models/event_draft_mapper.dart';
import 'package:recharge/features/create/domain/entities/event_admission.dart';
import 'package:recharge/features/create/domain/entities/event_draft_data.dart';
import 'package:recharge/features/create/domain/entities/event_inventory.dart';

void main() {
  final EventDraftData defaults = EventDraftData.defaults(
    marketCityId: 'riga',
    countryCode: 'LV',
    city: 'Riga',
    timezoneId: 'Europe/Riga',
    currencyCode: 'EUR',
  );

  test('schema v2 reads and writes without automatic v3 fields', () {
    final Map<String, Object?> raw = EventDraftMapper.toJson(defaults);
    expect(raw['schemaVersion'], 2);
    expect(raw.containsKey('admission'), isFalse);
    expect(raw.containsKey('inventory'), isFalse);

    final EventDraftData restored = EventDraftMapper.fromJson(
      raw,
      defaults: defaults,
    );
    final Map<String, Object?> written = EventDraftMapper.toJson(restored);
    expect(restored.schemaVersion, 2);
    expect(written['schemaVersion'], 2);
    expect(written.containsKey('admission'), isFalse);
  });

  test('explicit schema v3 round-trips every authority and shape name', () {
    final EventDraftData value = defaults.copyWith(
      schemaVersion: EventDraftData.accessSchemaVersion,
      admission: const EventAdmissionDraft(
        admissionMode: AdmissionMode.openEntry,
        registrationMode: EventRegistrationMode.none,
        confirmationMode: ConfirmationMode.none,
      ),
      inventory: EventInventoryConfiguration(
        authority: InventoryAuthority.recharge,
        primaryShape: InventoryShape.generalCapacity,
        additionalShapes: InventoryShape.values.skip(1).toSet(),
        pools: const <EventInventoryPoolDraft>[
          EventInventoryPoolDraft(
            id: 'loc_pool',
            label: 'Main',
            shape: InventoryShape.generalCapacity,
            channel: InventoryChannel.onsite,
            capacityMode: EventCapacityMode.known,
            capacity: 10,
          ),
        ],
      ),
    );
    final Map<String, Object?> raw = EventDraftMapper.toJson(value);
    final EventDraftData restored = EventDraftMapper.fromJson(
      raw,
      defaults: defaults,
    );

    expect(restored.schemaVersion, 3);
    expect(restored.admission!.admissionMode, AdmissionMode.openEntry);
    expect(restored.inventory!.authority, InventoryAuthority.recharge);
    expect(restored.inventory!.additionalShapes, hasLength(9));
    expect(raw.containsKey('registrationMode'), isFalse);
    expect(raw.containsKey('currentParticipants'), isFalse);
    expect(raw.containsKey('availability'), isFalse);
    expect(raw.containsKey('inventorySnapshot'), isFalse);
    expect((raw['admission']! as Map).containsKey('selectedPreset'), isFalse);
  });

  test('unknown nested v3 field is preserved and marked unsupported', () {
    final Map<String, Object?> raw = EventDraftMapper.toJson(
      defaults.copyWith(
        schemaVersion: 3,
        admission: const EventAdmissionDraft(
          admissionMode: AdmissionMode.openEntry,
          registrationMode: EventRegistrationMode.none,
          confirmationMode: ConfirmationMode.none,
        ),
      ),
    );
    final Map<String, Object?> admission = Map<String, Object?>.from(
      raw['admission']! as Map,
    )..['futureAuthority'] = 'future';
    raw['admission'] = admission;

    final EventDraftData restored = EventDraftMapper.fromJson(
      raw,
      defaults: defaults,
    );
    final Map<String, Object?> written = EventDraftMapper.toJson(restored);

    expect(restored.unsupportedFieldIds, contains('admission'));
    expect(
      (written['admission']! as Map<Object?, Object?>)['futureAuthority'],
      'future',
    );
  });

  test('unknown eligibility payload is preserved without partial rewrite', () {
    final Map<String, Object?> raw = EventDraftMapper.toJson(
      defaults.copyWith(
        schemaVersion: 3,
        admission: const EventAdmissionDraft(
          admissionMode: AdmissionMode.openEntry,
          registrationMode: EventRegistrationMode.none,
          confirmationMode: ConfirmationMode.none,
          eligibilityRules: <EligibilityRule>[
            EligibilityRule(
              id: 'loc_rule',
              kind: EligibilityRuleKind.invitation,
            ),
          ],
        ),
      ),
    );
    final Map<String, Object?> admission = Map<String, Object?>.from(
      raw['admission']! as Map,
    );
    final List<Object?> rules = List<Object?>.from(
      admission['eligibilityRules']! as List,
    );
    rules[0] = <String, Object?>{
      ...Map<String, Object?>.from(rules[0]! as Map),
      'futureSecretEnvelope': <String, Object?>{'kind': 'future'},
    };
    admission['eligibilityRules'] = rules;
    raw['admission'] = admission;

    final EventDraftData restored = EventDraftMapper.fromJson(
      raw,
      defaults: defaults,
    );
    final Map<String, Object?> written = EventDraftMapper.toJson(restored);

    expect(restored.unsupportedFieldIds, contains('admission'));
    expect(written['admission'], raw['admission']);
  });

  test('unexpected v2 access payload is preserved without schema bump', () {
    final Map<String, Object?> raw = EventDraftMapper.toJson(defaults);
    raw['admission'] = <String, Object?>{'admissionMode': 'futureMode'};
    final EventDraftData restored = EventDraftMapper.fromJson(
      raw,
      defaults: defaults,
    );

    expect(restored.schemaVersion, 2);
    expect(restored.unsupportedFieldIds, contains('admission'));
    expect(EventDraftMapper.toJson(restored)['admission'], raw['admission']);
  });

  test('newer schema is preserved byte-semantically and fails closed', () {
    final Map<String, Object?> raw = <String, Object?>{
      'schemaVersion': 9,
      'future': <String, Object?>{'authority': 'future'},
    };
    final EventDraftData restored = EventDraftMapper.fromJson(
      raw,
      defaults: defaults,
    );

    expect(restored.unsupportedFieldIds, contains('eventData'));
    expect(EventDraftMapper.toJson(restored), raw);
  });
}
