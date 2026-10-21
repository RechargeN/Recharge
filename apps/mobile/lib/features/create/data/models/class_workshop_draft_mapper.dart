import '../../domain/entities/class_workshop_draft_data.dart';

class UnsupportedClassWorkshopSchemaException implements Exception {
  const UnsupportedClassWorkshopSchemaException(this.version);

  final Object? version;

  @override
  String toString() => 'Unsupported Class / Workshop schema version: $version';
}

/// Strict, lossless persistence mapper for `ClassWorkshopDraftData`
/// (D3.6, CW-V1). A newer schema refuses instead of guessing. A known key
/// whose raw value does not parse is not repaired into a default: it is kept
/// verbatim in `unknownFields`, so the draft stays lossless and publication
/// refuses it explicitly instead of sending a coerced value.
abstract final class ClassWorkshopDraftMapper {
  static Map<String, Object?> toJson(
    ClassWorkshopDraftData data,
  ) => <String, Object?>{
    'schema_version': data.schemaVersion,
    if (data.offeringKind != null) 'offering_kind': data.offeringKind!.wireName,
    'context_kind': data.contextKind.wireName,
    'delivery_format': data.deliveryFormat.wireName,
    'public_location_mode': data.locationMode.wireName,
    'safe_area_label': data.safeAreaLabel,
    'online_provider_label': data.onlineProviderLabel,
    'timezone_id': data.timezoneId,
    'timezone_confirmed': data.timezoneConfirmed,
    'dst_policy_version': data.dstPolicyVersion,
    'occurrences': <Object?>[
      for (final ClassWorkshopOccurrence item in data.occurrences)
        <String, Object?>{
          'id': item.id,
          'local_date': item.localDate,
          'start_minute_local': item.startMinuteLocal,
          'end_minute_local': item.endMinuteLocal,
          if (item.fold != null) 'fold': item.fold!.wireName,
          if (item.title != null) 'title': item.title,
        },
    ],
    'instructor': <String, Object?>{
      'same_as_publisher': data.instructor.sameAsPublisher,
      'display_name': data.instructor.displayName,
      'short_bio': data.instructor.shortBio,
    },
    'outcomes': data.outcomes,
    'modules': <Object?>[
      for (final ClassWorkshopModule module in data.modules)
        <String, Object?>{'id': module.id, 'title': module.title},
    ],
    if (data.prerequisitesListed != null)
      'prerequisites_listed': data.prerequisitesListed,
    'prerequisites': data.prerequisites,
    'take_home_result': data.takeHomeResult,
    'included_materials': data.includedMaterials,
    'requirements': data.requirements,
    if (data.declaredGroupLimit != null)
      'declared_group_limit': data.declaredGroupLimit,
    'price': <String, Object?>{
      'mode': data.price.mode.wireName,
      if (data.price.amountMinor != null)
        'amount_minor': data.price.amountMinor,
      if (data.price.currencyCode != null)
        'currency_code': data.price.currencyCode,
      if (data.price.scope != null) 'scope': data.price.scope!.wireName,
    },
    'enrollment': <String, Object?>{
      'mode': data.enrollment.mode.wireName,
      'external_url': data.enrollment.externalUrl,
      'information_reason': data.enrollment.informationReason.wireName,
    },
    ...data.unknownFields,
  };

  static ClassWorkshopDraftData fromJson(
    Map<String, Object?> json, {
    required String defaultTimezoneId,
  }) {
    final Object? version = json['schema_version'];
    if (version != null &&
        (version is! int ||
            version > ClassWorkshopDraftData.currentSchemaVersion)) {
      throw UnsupportedClassWorkshopSchemaException(version);
    }
    final Map<String, Object?> unknown = <String, Object?>{};
    T? read<T>(String key, T? Function(Object? raw) parse) {
      if (!json.containsKey(key)) return null;
      final Object? raw = json[key];
      final T? value = parse(raw);
      if (value == null && raw != null) unknown[key] = raw;
      return value;
    }

    String? text(Object? raw) => raw is String ? raw : null;
    bool? flag(Object? raw) => raw is bool ? raw : null;
    int? integer(Object? raw) => raw is int ? raw : null;
    List<String>? strings(Object? raw) =>
        raw is List && raw.every((Object? item) => item is String)
        ? List<String>.unmodifiable(raw.cast<String>())
        : null;

    for (final MapEntry<String, Object?> entry in json.entries) {
      if (!_known.contains(entry.key)) unknown[entry.key] = entry.value;
    }

    final List<ClassWorkshopOccurrence>? occurrences =
        read<List<ClassWorkshopOccurrence>>('occurrences', _occurrences);
    final ClassWorkshopInstructor? instructor = read<ClassWorkshopInstructor>(
      'instructor',
      _instructor,
    );
    final List<ClassWorkshopModule>? modules = read<List<ClassWorkshopModule>>(
      'modules',
      _modules,
    );
    final ClassWorkshopPrice? price = read<ClassWorkshopPrice>('price', _price);
    final ClassWorkshopEnrollment? enrollment = read<ClassWorkshopEnrollment>(
      'enrollment',
      _enrollment,
    );

    return ClassWorkshopDraftData(
      offeringKind: read('offering_kind', ClassWorkshopOfferingKind.fromWire),
      contextKind:
          read('context_kind', ClassWorkshopContextKind.fromWire) ??
          ClassWorkshopContextKind.singleClass,
      deliveryFormat:
          read('delivery_format', ClassWorkshopDeliveryFormat.fromWire) ??
          ClassWorkshopDeliveryFormat.offline,
      locationMode:
          read('public_location_mode', ClassWorkshopLocationMode.fromWire) ??
          ClassWorkshopLocationMode.point,
      safeAreaLabel: read('safe_area_label', text) ?? '',
      onlineProviderLabel: read('online_provider_label', text) ?? '',
      timezoneId: read('timezone_id', text) ?? defaultTimezoneId,
      timezoneConfirmed: read('timezone_confirmed', flag) ?? false,
      dstPolicyVersion: read('dst_policy_version', integer) ?? 1,
      occurrences: occurrences ?? const <ClassWorkshopOccurrence>[],
      instructor: instructor ?? const ClassWorkshopInstructor(),
      outcomes: read('outcomes', strings) ?? const <String>[],
      modules: modules ?? const <ClassWorkshopModule>[],
      prerequisitesListed: read('prerequisites_listed', flag),
      prerequisites: read('prerequisites', strings) ?? const <String>[],
      takeHomeResult: read('take_home_result', text) ?? '',
      includedMaterials:
          read('included_materials', strings) ?? const <String>[],
      requirements: read('requirements', strings) ?? const <String>[],
      declaredGroupLimit: read('declared_group_limit', integer),
      price: price ?? ClassWorkshopPrice.notProvided,
      enrollment: enrollment ?? const ClassWorkshopEnrollment(),
      unknownFields: Map<String, Object?>.unmodifiable(unknown),
    );
  }

  static const Set<String> _known = <String>{
    'schema_version',
    'offering_kind',
    'context_kind',
    'delivery_format',
    'public_location_mode',
    'safe_area_label',
    'online_provider_label',
    'timezone_id',
    'timezone_confirmed',
    'dst_policy_version',
    'occurrences',
    'instructor',
    'outcomes',
    'modules',
    'prerequisites_listed',
    'prerequisites',
    'take_home_result',
    'included_materials',
    'requirements',
    'declared_group_limit',
    'price',
    'enrollment',
  };

  static bool _onlyKeys(Map<Object?, Object?> map, Set<String> keys) =>
      map.keys.every(keys.contains);

  static List<ClassWorkshopOccurrence>? _occurrences(Object? raw) {
    if (raw is! List) return null;
    final List<ClassWorkshopOccurrence> result = <ClassWorkshopOccurrence>[];
    for (final Object? item in raw) {
      if (item is! Map ||
          !_onlyKeys(item, const <String>{
            'id',
            'local_date',
            'start_minute_local',
            'end_minute_local',
            'fold',
            'title',
          })) {
        return null;
      }
      final Object? id = item['id'];
      final Object? date = item['local_date'];
      final Object? start = item['start_minute_local'];
      final Object? end = item['end_minute_local'];
      final Object? fold = item['fold'];
      final Object? title = item['title'];
      if (id is! String ||
          date is! String ||
          start is! int ||
          end is! int ||
          (fold != null && ClassWorkshopFold.fromWire(fold) == null) ||
          (title != null && title is! String)) {
        return null;
      }
      result.add(
        ClassWorkshopOccurrence(
          id: id,
          localDate: date,
          startMinuteLocal: start,
          endMinuteLocal: end,
          fold: ClassWorkshopFold.fromWire(fold),
          title: title as String?,
        ),
      );
    }
    return List<ClassWorkshopOccurrence>.unmodifiable(result);
  }

  static ClassWorkshopInstructor? _instructor(Object? raw) {
    if (raw is! Map ||
        !_onlyKeys(raw, const <String>{
          'same_as_publisher',
          'display_name',
          'short_bio',
        })) {
      return null;
    }
    final Object? same = raw['same_as_publisher'];
    final Object? name = raw['display_name'];
    final Object? bio = raw['short_bio'];
    if (same is! bool || name is! String || bio is! String) return null;
    return ClassWorkshopInstructor(
      sameAsPublisher: same,
      displayName: name,
      shortBio: bio,
    );
  }

  static List<ClassWorkshopModule>? _modules(Object? raw) {
    if (raw is! List) return null;
    final List<ClassWorkshopModule> result = <ClassWorkshopModule>[];
    for (final Object? item in raw) {
      if (item is! Map || !_onlyKeys(item, const <String>{'id', 'title'})) {
        return null;
      }
      final Object? id = item['id'];
      final Object? title = item['title'];
      if (id is! String || title is! String) return null;
      result.add(ClassWorkshopModule(id: id, title: title));
    }
    return List<ClassWorkshopModule>.unmodifiable(result);
  }

  static ClassWorkshopPrice? _price(Object? raw) {
    if (raw is! Map ||
        !_onlyKeys(raw, const <String>{
          'mode',
          'amount_minor',
          'currency_code',
          'scope',
        })) {
      return null;
    }
    final ClassWorkshopPriceMode? mode = ClassWorkshopPriceMode.fromWire(
      raw['mode'],
    );
    final Object? amount = raw['amount_minor'];
    final Object? currency = raw['currency_code'];
    final Object? scope = raw['scope'];
    if (mode == null ||
        (amount != null && amount is! int) ||
        (currency != null && currency is! String) ||
        (scope != null && ClassWorkshopPriceScope.fromWire(scope) == null)) {
      return null;
    }
    return ClassWorkshopPrice(
      mode: mode,
      amountMinor: amount as int?,
      currencyCode: currency as String?,
      scope: ClassWorkshopPriceScope.fromWire(scope),
    );
  }

  static ClassWorkshopEnrollment? _enrollment(Object? raw) {
    if (raw is! Map ||
        !_onlyKeys(raw, const <String>{
          'mode',
          'external_url',
          'information_reason',
        })) {
      return null;
    }
    final ClassWorkshopEnrollmentMode? mode =
        ClassWorkshopEnrollmentMode.fromWire(raw['mode']);
    final Object? url = raw['external_url'];
    final ClassWorkshopInformationReason? reason =
        ClassWorkshopInformationReason.fromWire(raw['information_reason']);
    if (mode == null || url is! String || reason == null) return null;
    return ClassWorkshopEnrollment(
      mode: mode,
      externalUrl: url,
      informationReason: reason,
    );
  }
}
